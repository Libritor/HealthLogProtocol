// lib_baseline.mjs — shared logic for anchoring and verifying wearable baselines
// on Solana via the SPL Memo program.
//
// Privacy invariant (enforced at runtime by assertEnvelopeSafe):
//   The on-chain envelope carries ONLY a commitment hash + non-identifying
//   shape metadata. Raw baseline parameters (GMM means/covariances, EMG MVC
//   levels, HRV beat series, scaler statistics, feature vectors) NEVER appear
//   on-chain. The baseline itself stays encrypted off-chain and is shared,
//   when the user consents, out of band.
//
// RPC rails:
//   - RPC Fast (mainnet) is the production + verification rail. Config is read
//     from ~/.axiom_resolve/rpc.json.
//   - The free demo anchors on Solana devnet (public faucet keypair at
//     ~/.axiom_resolve/devnet_keypair.json), producing real, explorable txs at
//     zero cost. The anchor/verify logic is identical across networks.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const bs58 = require('bs58');
const {
  Keypair, Connection, PublicKey, Transaction, TransactionInstruction,
} = require('@solana/web3.js');

export const MEMO_PROGRAM_ID = new PublicKey(
  'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr',
);

const AXIOM_DIR = path.join(os.homedir(), '.axiom_resolve');

// Keys that must never appear in an on-chain envelope. Defense-in-depth: even
// if a caller builds a malformed envelope, assertEnvelopeSafe() refuses to send.
const FORBIDDEN_KEYS = new Set([
  'gmmMeans', 'gmmCovariances', 'gmmWeights', 'scalerMean', 'scalerScale',
  'means', 'covariances', 'weights', 'features', 'featureVector', 'pcaData',
  'raw', 'rawData', 'samples', 'beats', 'rr', 'rrIntervals', 'mvc', 'emg',
  'eeg', 'ppg', 'signal', 'name', 'email', 'notes', 'clusterToArousal',
]);
// `signal` as a SHORT string tag (e.g. "eeg") is allowed; the check below only
// rejects `signal`/`eeg`/... when they carry array/object payloads.

// ---------------------------------------------------------------------------
// Canonicalization + hashing
// ---------------------------------------------------------------------------

/**
 * Language-agnostic canonical serialization. Sorted keys, no whitespace, and a
 * number rule that MATCHES the Dart implementation
 * (BaselineHashing._canonicalSerialize): whole-valued numbers render without a
 * decimal point (2.0 -> "2", 0.0 -> "0"), everything else via shortest
 * round-trip. This is what makes a baseline hashed in Flutter verify in a
 * Node.js service and vice versa.
 */
export function canonicalSerialize(v) {
  if (v === null) return 'null';
  const t = typeof v;
  if (t === 'boolean') return v ? 'true' : 'false';
  if (t === 'number') {
    if (!Number.isFinite(v)) throw new Error('non-finite number in baseline');
    // JS String() already renders 2.0 as "2" and 0.0 as "0".
    return String(v);
  }
  if (t === 'string') return JSON.stringify(v);
  if (Array.isArray(v)) return '[' + v.map(canonicalSerialize).join(',') + ']';
  if (t === 'object') {
    const keys = Object.keys(v).sort();
    return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalSerialize(v[k])).join(',') + '}';
  }
  throw new Error('unserializable type: ' + t);
}

export function sha256Hex(input) {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return crypto.createHash('sha256').update(buf).digest('hex');
}

/** Deterministic, cross-language SHA-256 of a JSON-serializable object. */
export function hashObject(obj) {
  return sha256Hex(canonicalSerialize(obj));
}

// ---------------------------------------------------------------------------
// Baseline manifest (the privacy-safe on-chain envelope)
// ---------------------------------------------------------------------------

/**
 * Build the on-chain envelope for a baseline. `baseline` is the FULL private
 * baseline object (never sent). We commit only its hash plus shape metadata.
 *
 * @param {object} baseline  full private baseline (e.g. a GMM model_state)
 * @param {object} meta      { owner, signal, model, modelVersion,
 *                             featureSchema, featureSchemaSpec, dims,
 *                             recordedSeconds, validUntil, ts }
 */
export function buildBaselineEnvelope(baseline, meta) {
  const baselineHash = hashObject(baseline);
  const featureSchemaHash = meta.featureSchemaSpec
    ? hashObject(meta.featureSchemaSpec)
    : null;
  const env = {
    type: 'baseline_commitment',
    v: 1,
    owner: meta.owner,
    signal: meta.signal, // short tag: "eeg" | "emg" | "hrv" | "eda" | "ppg"
    model: meta.model, // e.g. "gmm-arousal"
    modelVersion: meta.modelVersion,
    featureSchema: meta.featureSchema, // schema id string, not the features
    featureSchemaHash,
    baselineHash,
    dims: meta.dims || null, // { features, clusters } — shape only
    recordedSeconds: meta.recordedSeconds ?? null,
    validUntil: meta.validUntil ?? null,
    ts: meta.ts,
  };
  assertEnvelopeSafe(env);
  return env;
}

/** Throw if an envelope carries anything other than commitment + shape metadata. */
export function assertEnvelopeSafe(env) {
  const walk = (obj, pathStr) => {
    if (Array.isArray(obj)) {
      // Arrays of raw numbers are how model params leak. Only allow the
      // envelope's known small string arrays (none currently) — reject numeric
      // arrays longer than a shape tuple.
      const numeric = obj.filter((x) => typeof x === 'number');
      if (numeric.length > 4) {
        throw new Error(`privacy gate: numeric array at ${pathStr} (len ${obj.length}) looks like raw parameters`);
      }
      obj.forEach((v, i) => walk(v, `${pathStr}[${i}]`));
      return;
    }
    if (obj && typeof obj === 'object') {
      for (const k of Object.keys(obj)) {
        const v = obj[k];
        const isPayload = Array.isArray(v) || (v && typeof v === 'object');
        if (FORBIDDEN_KEYS.has(k) && isPayload) {
          throw new Error(`privacy gate: forbidden payload key "${k}" at ${pathStr}`);
        }
        walk(v, `${pathStr}.${k}`);
      }
    }
  };
  walk(env, 'envelope');
  // Envelope size must fit comfortably in a memo (< 566 bytes leaves headroom).
  const size = Buffer.byteLength(JSON.stringify(env), 'utf8');
  if (size > 566) {
    throw new Error(`envelope too large for a single memo tx: ${size} bytes`);
  }
  return true;
}

// ---------------------------------------------------------------------------
// RPC + keypair loading
// ---------------------------------------------------------------------------

/** Load { http, wss, network } for a given network. */
export function loadRpc(network) {
  if (network === 'mainnet') {
    const p = path.join(AXIOM_DIR, 'rpc.json');
    if (!fs.existsSync(p)) {
      throw new Error(`RPC Fast config not found at ${p}`);
    }
    const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
    return { http: cfg.rpcfast_http, wss: cfg.rpcfast_wss, network: 'mainnet' };
  }
  // devnet (default): public endpoint, free faucet.
  return {
    http: 'https://api.devnet.solana.com',
    wss: 'wss://api.devnet.solana.com',
    network: 'devnet',
  };
}

/** Load the signing keypair for a network. Base58 secret-key string. */
export function loadKeypair(network) {
  const file = network === 'mainnet' ? 'mainnet_keypair.json' : 'devnet_keypair.json';
  const p = path.join(AXIOM_DIR, file);
  if (!fs.existsSync(p)) {
    throw new Error(`keypair not found at ${p} (drop a base58 secret key there)`);
  }
  const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
  const secret = typeof raw === 'string' ? bs58.decode(raw) : Uint8Array.from(raw);
  return Keypair.fromSecretKey(secret);
}

export function connection(network) {
  const { http } = loadRpc(network);
  return new Connection(http, 'confirmed');
}

export function explorerTx(sig, network) {
  return network === 'mainnet'
    ? `https://explorer.solana.com/tx/${sig}`
    : `https://explorer.solana.com/tx/${sig}?cluster=devnet`;
}

// ---------------------------------------------------------------------------
// Send + read memo transactions
// ---------------------------------------------------------------------------

export async function sendMemo(conn, payer, memoText) {
  const ix = new TransactionInstruction({
    keys: [{ pubkey: payer.publicKey, isSigner: true, isWritable: false }],
    programId: MEMO_PROGRAM_ID,
    data: Buffer.from(memoText, 'utf8'),
  });
  const tx = new Transaction().add(ix);
  const { sendAndConfirmTransaction } = require('@solana/web3.js');
  const sig = await sendAndConfirmTransaction(conn, tx, [payer], {
    commitment: 'confirmed',
  });
  return sig;
}

/** Read a tx back and extract the memo-program log payload, if any. */
export async function readMemo(conn, sig) {
  const tx = await conn.getTransaction(sig, {
    commitment: 'confirmed',
    maxSupportedTransactionVersion: 0,
  });
  if (!tx) return null;
  const logs = tx.meta?.logMessages || [];
  // Memo program logs: `Program log: Memo (len N): "<text>"`
  for (const line of logs) {
    const m = line.match(/Memo \(len \d+\): "(.*)"$/);
    if (m) {
      try { return JSON.parse(m[1].replace(/\\"/g, '"')); }
      catch { return { _raw: m[1] }; }
    }
  }
  return null;
}
