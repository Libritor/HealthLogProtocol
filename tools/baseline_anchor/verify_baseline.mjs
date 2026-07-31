#!/usr/bin/env node
// verify_baseline.mjs — the consumer side. A third-party BCI/wearable app that
// receives a baseline (out of band) verifies it against the on-chain commitment
// BEFORE trusting or loading it. Reads go through RPC Fast on mainnet.
//
// Usage:
//   node verify_baseline.mjs --baseline samples/eeg_gmm_arousal.json \
//        --tx <signature> --owner <wallet> [--network devnet|mainnet]
//   node verify_baseline.mjs --receipt receipts/eeg_xxxxxxxx.json \
//        --baseline samples/eeg_gmm_arousal.json
//
// Exit code 0 = all checks pass, 1 = verification failed.

import fs from 'node:fs';
import {
  hashObject, connection, readMemo, explorerTx,
} from './lib_baseline.mjs';

function parseArgs() {
  const a = { network: 'devnet' };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith('--')) a[k.slice(2)] = argv[++i];
  }
  return a;
}

function check(label, ok, detail = '') {
  console.log(`  ${ok ? '✓' : '✗'}  ${label}${detail ? `  (${detail})` : ''}`);
  return ok;
}

async function main() {
  const args = parseArgs();

  let tx = args.tx;
  let owner = args.owner;
  let network = args.network;
  if (args.receipt) {
    const r = JSON.parse(fs.readFileSync(args.receipt, 'utf8'));
    tx = tx || r.txSignature;
    owner = owner || r.owner;
    network = args.network || r.network;
  }
  if (!args.baseline || !tx) {
    console.error('error: need --baseline and (--tx or --receipt)');
    process.exit(1);
  }

  const doc = JSON.parse(fs.readFileSync(args.baseline, 'utf8'));
  const baseline = doc.baseline ?? doc;
  const localHash = hashObject(baseline);

  console.log('─'.repeat(70));
  console.log(`Verifying baseline against on-chain commitment`);
  console.log(`Network:   ${network}   Tx: ${tx}`);
  console.log(`Explorer:  ${explorerTx(tx, network)}`);
  console.log('─'.repeat(70));

  const conn = connection(network);
  const env = await readMemo(conn, tx);

  let allOk = true;
  const ok = (l, c, d) => { allOk = check(l, c, d) && allOk; };

  ok('Transaction found on-chain', !!env, env ? '' : 'tx not found or unconfirmed');
  if (!env) { finish(false); return; }

  ok('Envelope is a baseline commitment', env.type === 'baseline_commitment', `type=${env.type}`);
  ok('Local baseline hash matches on-chain commitment',
     env.baselineHash === localHash,
     `on-chain ${String(env.baselineHash).slice(0, 12)}… vs local ${localHash.slice(0, 12)}…`);
  if (owner) {
    ok('Owner wallet matches', env.owner === owner, `${String(env.owner).slice(0, 8)}…`);
  }
  // Recalibration horizon: warn if the baseline is past its validUntil.
  if (env.validUntil) {
    const fresh = new Date(env.validUntil).getTime() > Date.now();
    ok('Baseline within recalibration horizon', fresh, `validUntil ${env.validUntil}`);
  }
  // Privacy assertion: the on-chain envelope must not carry raw parameters.
  const envStr = JSON.stringify(env);
  const looksRaw = /"(gmmMeans|gmmCovariances|scalerMean|beats|rrIntervals|mvc)"/.test(envStr);
  ok('On-chain payload carries no raw parameters', !looksRaw);

  finish(allOk);

  function finish(pass) {
    console.log('─'.repeat(70));
    console.log(pass
      ? 'RESULT: VERIFIED — baseline integrity + provenance confirmed. Safe to load.'
      : 'RESULT: FAILED — do NOT trust this baseline.');
    process.exit(pass ? 0 : 1);
  }
}

main().catch((e) => { console.error('verify failed:', e.message); process.exit(1); });
