# healthlog_baseline — Anchor program (PDA baseline commitments)

The structured successor to the memo-transaction MVP: on-chain baseline
commitments as **queryable program state** (one PDA per `(owner, baseline_hash)`)
with **native revocation**. This is the "Anchor program" milestone named in the
paper (`paper/baseline_anchoring/`).

Same privacy invariant as the rest of HealthLog: only a commitment hash + a
short signal tag + timestamps live on-chain; the fitted baseline parameters
never touch the chain.

## Status

**Build-ready, not yet deployed.** The Rust / Solana / Anchor toolchain is not
installed on the current machine, so the program has not been compiled or
deployed here (unlike the Flutter layer and the Node tool, which are tested). The
source, tests, and deploy steps below are complete and reviewable. To actually
deploy, install the toolchain and run the commands in "Deploy."

## Program

- `commit_baseline(baseline_hash, feature_schema_hash, signal, model_hash, valid_until)`
  — inits the `BaselineCommitment` PDA at seeds `["baseline", owner, baseline_hash]`.
  Re-anchoring the same baseline fails (PDA already exists).
- `revoke_baseline()` — owner-only; sets a native `revoked` flag.
- `signal`: `0=eeg 1=emg 2=hrv 3=eda 4=ppg 5=imu`.
- `baseline_hash` is the **same** SHA-256 the Dart and Node hashers produce (see
  `lib/data/baseline/baseline_hashing.dart` and
  `tools/baseline_anchor/lib_baseline.mjs`), so a baseline anchored via memo or
  via this program carries an identical commitment.

## One-time setup

```bash
# Rust
curl https://sh.rustup.rs -sSf | sh

# Solana CLI (provides the SBF build toolchain + `solana program deploy`)
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

# Anchor via avm
cargo install --git https://github.com/coral-xyz/anchor avm --locked
avm install 0.30.1 && avm use 0.30.1

# A solana-cli keypair (JSON byte array). To reuse the funded devnet key from
# ~/.axiom_resolve/devnet_keypair.json (a base58 string), convert it:
node -e 'const bs58=require("bs58"),fs=require("fs");const s=JSON.parse(fs.readFileSync(process.env.HOME+"/.axiom_resolve/devnet_keypair.json"));fs.mkdirSync(process.env.HOME+"/.config/solana",{recursive:true});fs.writeFileSync(process.env.HOME+"/.config/solana/id.json",JSON.stringify([...bs58.decode(s)]))'
solana config set --url devnet
```

## Build, test, deploy

```bash
cd anchor
anchor build                 # compiles the BPF program + generates the IDL/types
anchor keys sync             # writes the real program id into lib.rs + Anchor.toml
anchor test                  # runs tests/healthlog_baseline.ts against a local validator
anchor deploy --provider.cluster devnet   # deploy to devnet (needs ~1.5 SOL rent)
```

`anchor test` covers: commit → fetch/assert fields, reject double-commit of the
same baseline, owner revoke, and non-owner-revoke rejection.

## Flutter integration (after deploy)

Once deployed, wire `SolanaMode.anchor` in
`lib/presentation/providers/baseline_providers.dart` to an
`AnchorBaselineService` that derives the PDA and calls `commit_baseline` /
`revoke_baseline` (the `DevnetBaselineAnchorService` memo path stays as the
fallback). The verifier reads the PDA directly instead of parsing a memo log.
