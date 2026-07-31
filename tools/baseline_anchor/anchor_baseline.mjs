#!/usr/bin/env node
// anchor_baseline.mjs — commit a wearable baseline's integrity hash to Solana.
//
// The baseline itself (GMM params, EMG MVC, HRV norms) stays private and off
// chain; only a SHA-256 commitment + non-identifying shape metadata is sent.
//
// Usage:
//   node anchor_baseline.mjs --baseline samples/eeg_gmm_arousal.json
//   node anchor_baseline.mjs --baseline samples/hrv_resting.json --network mainnet
//
// Flags:
//   --baseline <path>   private baseline JSON (required)
//   --network <net>     devnet (default) | mainnet   (mainnet uses RPC Fast)
//   --dry-run           build + validate + hash, do NOT send a transaction

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  buildBaselineEnvelope, loadKeypair, connection, sendMemo, explorerTx, loadRpc,
} from './lib_baseline.mjs';

const __dir = path.dirname(fileURLToPath(import.meta.url));

function parseArgs() {
  const a = { network: 'devnet' };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--dry-run') a.dryRun = true;
    else if (k.startsWith('--')) { a[k.slice(2)] = argv[++i]; }
  }
  return a;
}

async function main() {
  const args = parseArgs();
  if (!args.baseline) {
    console.error('error: --baseline <path> is required');
    process.exit(1);
  }
  const network = args.network;
  const doc = JSON.parse(fs.readFileSync(args.baseline, 'utf8'));

  // A sample file separates the private `baseline` payload from public `meta`.
  const baseline = doc.baseline ?? doc;
  const meta = doc.meta ?? {};

  const kp = args.dryRun ? null : loadKeypair(network);
  const owner = meta.owner || (kp ? kp.publicKey.toBase58() : 'DRY_RUN_OWNER');

  // A fixed timestamp keeps the commitment reproducible when meta.ts is set.
  const ts = meta.ts || new Date().toISOString();

  const envelope = buildBaselineEnvelope(baseline, { ...meta, owner, ts });
  const memoText = JSON.stringify(envelope);

  console.log('─'.repeat(70));
  console.log(`Baseline:        ${path.basename(args.baseline)}`);
  console.log(`Signal / model:  ${envelope.signal} / ${envelope.model} v${envelope.modelVersion}`);
  console.log(`Feature schema:  ${envelope.featureSchema}`);
  console.log(`baselineHash:    ${envelope.baselineHash}`);
  console.log(`Shape (dims):    ${JSON.stringify(envelope.dims)}`);
  console.log(`Network:         ${network}  (${loadRpc(network).http.split('?')[0]})`);
  console.log(`Envelope bytes:  ${Buffer.byteLength(memoText, 'utf8')}`);
  console.log('─'.repeat(70));

  if (args.dryRun) {
    console.log('DRY RUN — envelope validated, nothing sent.\n');
    console.log(JSON.stringify(envelope, null, 2));
    return;
  }

  console.log(`Owner wallet:    ${owner}`);
  const conn = connection(network);
  const bal = await conn.getBalance(kp.publicKey);
  console.log(`Balance:         ${(bal / 1e9).toFixed(6)} SOL`);
  if (bal < 5000) {
    console.error('error: insufficient balance to pay the transaction fee.');
    process.exit(1);
  }

  process.stdout.write('Anchoring… ');
  const sig = await sendMemo(conn, kp, memoText);
  console.log('done.');
  console.log(`Tx signature:    ${sig}`);
  console.log(`Explorer:        ${explorerTx(sig, network)}`);

  const receipt = {
    network,
    owner,
    signal: envelope.signal,
    model: envelope.model,
    modelVersion: envelope.modelVersion,
    featureSchema: envelope.featureSchema,
    baselineHash: envelope.baselineHash,
    featureSchemaHash: envelope.featureSchemaHash,
    dims: envelope.dims,
    txSignature: sig,
    explorer: explorerTx(sig, network),
    ts: envelope.ts,
    anchoredAt: new Date().toISOString(),
  };
  const outDir = path.join(__dir, 'receipts');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `${envelope.signal}_${sig.slice(0, 8)}.json`);
  fs.writeFileSync(outPath, JSON.stringify(receipt, null, 2));
  console.log(`Receipt:         ${path.relative(process.cwd(), outPath)}`);
}

main().catch((e) => { console.error('\nanchor failed:', e.message); process.exit(1); });
