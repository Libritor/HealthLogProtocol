# HealthLog Protocol — Sub-3-min Pitch Script (Loom)

Total target: **2:50** at ~150 words/min. Loom recommended (per Colosseum's "How to Win" guide).

Fill in `[BRACKETED]` placeholders before recording.

---

## 0:00 – 0:15 — Hook

> Today, every wearable company is your data landlord. They decide what AI sees, what researchers see, and what you see. HealthLog Protocol flips that. Your wearable data stays encrypted on your phone. Solana records who you let touch it.

[Cut to dashboard, Mock Mode chip visible.]

## 0:15 – 0:35 — Team

> I'm [NAME]. I've spent [N] years building EEG and brain-sensing tools — most recently MuseLog, which records raw data from Muse headbands and is already used by researchers and consumers. I'm joined by [COFOUNDER NAMES + ROLES — technical, design, GTM]. We're building HealthLog Protocol full-time.

[Show MuseLog session card, your face/team photo if available.]

## 0:35 – 1:05 — Problem and product

> Wearable health data is fragmented across Muse, Oura, Whoop, Apple, the rest. As LLMs get better at reading personal health signals, users need a way to share with AI without losing the audit trail. Today there is no neutral consent layer — just opaque ToS pages and corporate logs.
>
> HealthLog Protocol is that layer. One mobile app where you import your wearable data, encrypt it locally, and use Solana to record exactly who you granted access to, what scope, and when you revoked it.

[Show the Demo Flow card: Import → Encrypt → Hash → Commit → Summarize → Grant → Verify → Revoke.]

## 1:05 – 2:15 — Demo walkthrough

> Here's the full lifecycle on Solana devnet.
>
> [Tap Devnet chip] I switch to devnet mode. The app uses a persisted Ed25519 keypair, auto-airdropped on first commit.
>
> [Tap Load Demo Session, then session card] I load a 5-minute demo MuseLog session. EEG, IMU, band powers, IS quality — same shape as a real Muse 2 recording.
>
> [Encrypt & Store] AES-256-GCM, key in the device keystore.
>
> [Create Manifest] SHA-256 of the raw file plus a deterministic manifest hash.
>
> [Commit Provenance to Solana — wait for confirmation, then tap explorer link] That's a real memo-program transaction on devnet. The manifest hash is now publicly committed. The raw EEG never left my phone.
>
> [Generate AI Summary, pick "AI Summary Only"] The LLM only sees the scope I approved.
>
> [Share / Grant Access — paste recipient wallet, sign] Second on-chain memo. The recipient now has a `DataAccessToken` for AI Summary Only — no raw access.
>
> [Verify tab → Run Verification → green checks] Seven checks pass: manifest match, wallet sig, grant active, token active, AI report chain, scope match, raw-data-not-exposed.
>
> [Back to session, tap Revoke] Third on-chain memo. Re-run verification — Access Denied.

## 2:15 – 2:40 — Market and acquisition

> Wearable health is a 60-billion-dollar market and AI-on-health is the next leg. We're starting with the MuseLog community — thousands of researchers, neuro-hackers, and meditators who already export raw EEG and have nowhere good to put it. Then Oura, then Whoop, then anyone who wants to ask an AI about their sleep without mailing it to a vendor.
>
> Why this wins on Solana: consent events are cheap enough to be ambient — every grant, revoke, and verification is on-chain. ZK compression is the natural next step.

## 2:40 – 2:50 — Close

> HealthLog Protocol. User-owned wearable data for private AI. Repo and devnet transactions in the description. Thanks.

---

## Recording tips

- Loom screen + camera bubble. Front-facing camera for the team segment, screen + voiceover for the demo.
- Pre-load the demo session and pre-airdrop the wallet so commits return in <5s on camera. Don't wait on devnet during the recording.
- Have the Solana Explorer tab pre-loaded with one of your past commit transactions so you can cut to it instantly when you say "real memo-program transaction on devnet".
- Read the script once dry, once with timer, then record. Don't ad-lib past 3:00 — submission disqualifies long pitches per Colosseum guidance.

## What to put in the submission description

- Github repo URL
- 2–3 example devnet tx signatures (commit, grant, revoke) with `https://explorer.solana.com/tx/<sig>?cluster=devnet` links
- Loom URL
- One-paragraph product description (lift the TL;DR from README)
- Team links (LinkedIn / Twitter / GitHub)
