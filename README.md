# HealthLog

**A private, user-owned wearable data rail for AI, with Solana-based consent and provenance.**

Built for the [Solana Frontier Hackathon](https://colosseum.com/frontier) (Colosseum, 2026). HealthLog tokenizes *permission to use* health data, not the health data itself.

---

## TL;DR

- Wearable data (EEG, IMU, biometrics) stays **encrypted on the user's device**. It never touches the chain.
- **Solana records the consent**: who granted what scope to which wallet, when it was revoked, and a hash that proves the AI summary came from the committed session.
- One Flutter app demonstrates the full lifecycle on Solana **devnet**: Import → Encrypt → Hash → Commit → Summarize → Grant → Verify → Revoke.
- Toggle Mock ↔ Devnet at runtime; the dashboard chip says which mode you're in. Tx signatures open in the Solana Explorer.

## Why this matters

Wearable health data is fragmented across devices and platforms. As LLMs become more useful for interpreting personal health and brain-sensing data, users need a way to share data with AI, researchers, clinicians, and apps **without losing control of privacy or provenance**. Existing health platforms either lock data away or turn it into a B2B sales pipeline. There is no neutral, user-owned consent layer.

HealthLog is that layer. The wearable data lives encrypted on the user's device. The chain holds the audit trail for permission, scope, and revocation — the things that today live in nobody-reads-them ToS pages and opaque corporate logs.

## Why Solana

- Cheap enough to make consent *events* affordable, not just consent *contracts*.
- Wallet-native identity and signing — no separate identity vendor required.
- Public, permissionless audit trail for grants and revocations.
- Headroom for tokenized access, micropayments to data contributors, and ZK-compressed claims.

## Demo flow (8 steps, runs end-to-end on devnet)

```
Import -> Encrypt -> Hash -> Commit -> Summarize -> Grant -> Verify -> Revoke
```

1. Open the **HealthLog** dashboard.
2. Tap **Mock Mode** chip (top right) to switch to **Devnet (Memo)**. The app airdrops to a persisted devnet keypair on first commit.
3. Tap **MuseLog Brain Sensing** → **Load Demo Session**, or import a real `muse_session_*.csv`.
4. Open the session and tap **Encrypt & Store** — AES-256-GCM ciphertext written to local app storage; key in `flutter_secure_storage`.
5. Tap **Create Manifest** — SHA-256 of the raw file + canonical-JSON manifest hash.
6. Tap **Commit Provenance to Solana** — sends a memo-program transaction to devnet with `{type: session_commitment, manifestHash, rawFileHash, tags, owner, ts}`. The Solana Explorer link opens with the real signature.
7. Tap **Generate AI Summary** and pick the data scope (default: *AI Summary Only*). Raw EEG never leaves the device.
8. Tap **Share / Grant Access**, paste a recipient wallet, set scope/purpose/expiry, **Sign Consent** — second memo tx (`access_grant`).
9. Switch to the **Verify** tab — runs 7 checks (manifest match, wallet sig, grant active, token active, AI report chain, scope match, raw-data-not-exposed).
10. Open the session again, tap **Revoke Access** on the grant — third memo tx (`access_revoke`).
11. Re-run **Verify** — see **Access Denied**.

Every signature is real (or, on RPC failure, marked as a `devnet_fallback_*` placeholder so demos don't stall). The Mock mode is identical UX with synthetic signatures, for offline judging or air-gapped review.

## What's real now

- **MuseLog ingest**: import any `muse_session_*.csv` (Muse 2 / Muse S / Muse S Athena). Live BLE recording also wired through the existing platform-channel scaffolding.
- **Encryption**: AES-256-GCM, key stored in OS keystore via `flutter_secure_storage`.
- **Hashing**: SHA-256 of raw file + canonical-JSON manifest hash. Deterministic — same inputs always produce the same on-chain commitment.
- **Solana devnet writes**: memo-program transactions for `session_commitment`, `access_grant`, `access_revoke`. Persisted Ed25519 keypair (HD path `m/44'/501'/0'/0'`) and auto-airdrop on first use.
- **Consent + scope model**: *AI Summary Only*, *Derived Features Only*, *Research Metadata Only*, *Raw Encrypted Session*. Purpose codes (AI / Research / Rehab / Personal). Per-grant expiry with `DataAccessToken` lifecycle.
- **AI summary**: scope-aware report generation with input/output hash chain. Disclaimer enforced.
- **Verifier**: multi-claim ZK-ready interface — manifest match, wallet sig, grant/token state, AI report chain, scope match, negative-scope proof, raw-data-not-exposed assertion.
- **Mock mode**: full lifecycle works offline with simulated tx signatures, for fresh-clone demos and air-gapped review.

## What's mocked or stubbed

- ZK proofs are hash-based stand-ins behind the `VerificationService` interface. Interface is shaped for ZK compression / Merkle proofs / privacy-preserving claims.
- Wallet is a locally generated and persisted Ed25519 keypair, not Phantom or Solana Mobile Wallet Adapter. (Roadmap below.)
- Oura, Whoop, and Ray-Ban Meta adapter cards are placeholders behind a `WearableAdapter` interface — only MuseLog is wired up for the MVP.
- Anchor program with structured `SessionCommitment` and `AccessGrant` PDAs is the next milestone — devnet uses memo-program transactions for now.

## Roadmap

- Anchor program with PDAs for `SessionCommitment`, `AccessGrant`, and `AccessLog` accounts (move off the memo program, get queryable on-chain state).
- Real ZK proofs: Merkle proof for "session existed before date X", ZK proof for "report derived from committed manifest".
- Solana Mobile Wallet Adapter for Phantom signing on Saga / any Android.
- Additional adapters: Oura, Whoop, Apple Health, Ray-Ban Meta media import.
- Tokenized data access — recipient pays per-grant or stakes for a research cohort.

## Privacy rules

**What never goes on-chain:** raw EEG / IMU / PPG / fNIRS, CSV contents, local file paths, AI summary text, names, emails, medical notes, anything personally identifying.

**What goes on-chain (Solana):** session manifest hash, raw file hash, owner wallet, metadata category labels (e.g. `["EEG", "IMU"]`), timestamps, consent grant/revoke events, scope and purpose codes.

The LLM only sees the scope the user approved. Raw encrypted access is gated behind an explicit *Raw Encrypted Session* scope that the demo flow does not exercise by default.

## Stack

| Layer | Tech |
| --- | --- |
| Mobile UI | Flutter 3.x, Material 3, Riverpod |
| Solana | `solana: ^0.31` Dart SDK, devnet RPC, memo program |
| Crypto | `encrypt` (AES-256-GCM), `crypto` (SHA-256), `pointycastle` |
| Secure storage | `flutter_secure_storage` (Android Keystore / iOS Keychain) |
| Wearable I/O | `flutter_blue_plus`, custom MuseLog CSV adapter |
| Files | `csv`, `path_provider`, `file_picker`, `share_plus` |

## How to run

```bash
flutter pub get
flutter run            # picks the first connected device
# or target a specific device:
flutter run -d <device-id>
```

The app starts in **Mock Mode** — every Solana call is simulated locally and the full demo works offline. Tap the **Mock Mode** chip in the dashboard AppBar to toggle to **Devnet (Memo)**, which writes real memo-program transactions to `https://api.devnet.solana.com`.

No Muse SDK, real health data, or private keys are required. Demo data is 100% synthetic.

## Open-source safety

- No proprietary Muse SDK files are committed.
- No real participant health data is committed.
- No private keys or API secrets are committed.
- Demo CSV is generated deterministically with `Random(42)`.
- Wallet seed is generated on first use and stored only in the device keystore.

## License

MIT.
