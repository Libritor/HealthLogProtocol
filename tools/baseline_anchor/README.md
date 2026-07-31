# Baseline Anchor — wearable baselines on Solana

Anchor a user's **calibration baseline** (EEG arousal model, EMG MVC
normalization, HRV resting norms, …) to Solana so any app can **verify and reuse
it without re-recording**. Only a SHA-256 commitment + shape metadata goes
on-chain; the fitted parameters stay off-chain.

This is the reference implementation for the paper
`paper/baseline_anchoring/main.tex` and the source of the real signatures pinned
in the app README. It extends the HealthLog Colosseum consent protocol from
*sessions* to *baselines*.

## RPC rails

- **RPC Fast (mainnet)** — the production + verification rail. Config is read
  from `~/.axiom_resolve/rpc.json` (`rpcfast_http` / `rpcfast_wss`). Fast,
  reliable reads so a third-party BCI/wearable app can verify a commitment
  before trusting a baseline.
- **Devnet (default)** — the free demo rail. Anchors are signed by
  `~/.axiom_resolve/devnet_keypair.json` (a base58 secret key) and broadcast to
  the public devnet faucet network. Anchor + verify logic is identical to
  mainnet.

Secrets live only under `~/.axiom_resolve/` and are never committed.

## Usage

```bash
# validate + hash, send nothing
node anchor_baseline.mjs --baseline samples/eeg_gmm_arousal.json --dry-run

# anchor on devnet (free) — prints a real tx signature + explorer link,
# writes a receipt to receipts/
node anchor_baseline.mjs --baseline samples/eeg_gmm_arousal.json

# consumer side: re-hash the baseline you hold and check it on-chain
node verify_baseline.mjs --baseline samples/eeg_gmm_arousal.json \
     --receipt receipts/eeg_XXXXXXXX.json

# production: same commands with --network mainnet (needs a funded
# ~/.axiom_resolve/mainnet_keypair.json; reads go through RPC Fast)
node anchor_baseline.mjs --baseline samples/hrv_resting.json --network mainnet
```

`npm run anchor:eeg | anchor:emg | anchor:hrv | dry` are shortcuts.

## Baseline file format

Each sample separates the **private** payload from the **public** envelope:

```json
{
  "baseline": { ... fitted parameters — hashed, NEVER sent ... },
  "meta": {
    "signal": "eeg", "model": "gmm-arousal", "modelVersion": "1.0.0",
    "featureSchema": "muse-bandpower-4",
    "dims": { "features": 4, "clusters": 3 },
    "recordedSeconds": 300, "validUntil": "2027-07-31T00:00:00Z",
    "featureSchemaSpec": { ... hashed into featureSchemaHash, not sent ... }
  }
}
```

## Privacy gate

`lib_baseline.mjs:assertEnvelopeSafe()` refuses to broadcast any envelope that
contains a payload-shaped forbidden key (`gmmMeans`, `gmmCovariances`,
`scalerMean`, `mvc`, `rrIntervals`, …) or a numeric array longer than a shape
tuple. The on-chain envelope is a commitment plus metadata, nothing more — this
is checked at runtime, not just by convention.

## Verified end-to-end (Solana devnet, 2026-07-31)

Owner wallet `EKRgJifhv4xsfRNFnSLY93NDoLVa39udENVQLC59s4sg`.

| Signal | baselineHash (prefix) | Tx |
| --- | --- | --- |
| EEG | `509c8630cca7…` | `5JsYqPH3QbEyvFc5FoEnWDHwo83wgDJh1nbA9zqwcKKf3igrnk6uqmTCdzzdARx2tvpQKyuEqSs4mQPS5XhewMzK` |
| EMG | `2b9f99cd12d7…` | `3Xe2tn7fKmuxvAoXXfiaS5Sx1Pgz9di2hRUJA2bNa7kwMD9EAzonPVsLUDps4AGxjPnP5JvEo2zy5ix1mDU8eLQG` |
| HRV | `929e9e779c58…` | `Nqk4WXAS42qyTf26b7wLwAXoRk635p8SL71mypeWF2vF7QENi7mv5x9YCVZJAk5nUaxwujbvE4Wqx4LTgPkgAa2` |

All three round-trip **VERIFIED**. Flipping a single GMM weight changes the
commitment (`509c8630…` → `bf3eee54…`) and verification correctly **FAILS**.
