# Colosseum Submission Checklist

Submission window closes **2026-05-11**. Today is 2026-05-08. **Three days.**

Submit via [arena.colosseum.org](https://arena.colosseum.org).

## Right now (do this first when you pick up the phone)

The devnet airdrop has been silently failing, so commits return `devnet_fallback_*` instead of real signatures. I just hardened `DevnetSolanaService` to: (a) log the full wallet address to logcat under tag `HealthLog.Solana`, (b) check balance before airdropping, (c) eagerly fund on connect, (d) poll for airdrop confirmation up to 30s, (e) surface RPC errors via `lastError`. To take effect:

1. **Unlock the phone** and keep it awake (Settings → Display → Screen timeout → 10 min).
2. From `C:\Users\alexa\.gemini\antigravity\scratch\HealthLog`, rebuild:
   ```powershell
   flutter run -d 4c4957534c573398
   ```
3. In the app, toggle to **Devnet** (top-right pill). The wallet auto-connects and the eager `_ensureFunded` kicks off in the background.
4. In another terminal, watch logs:
   ```powershell
   adb -s 4c4957534c573398 logcat -s flutter:V "HealthLog.Solana:V" | Select-String "wallet|Airdrop|Balance|Memo"
   ```
   You'll see lines like `Connected wallet: <FULL_44_CHAR_ADDRESS>` and `Airdrop confirmed. Balance: 1000000000 lamports`.
5. If airdrop still fails (rate-limited from prior attempts), copy the full address from the log and fund manually:
   ```powershell
   $addr = "<paste_full_address>"
   curl -X POST -H "Content-Type: application/json" `
     -d "{`"jsonrpc`":`"2.0`",`"id`":1,`"method`":`"requestAirdrop`",`"params`":[`"$addr`",1000000000]}" `
     https://api.devnet.solana.com
   ```
   Or use the web faucet: <https://faucet.solana.com>.
6. Tap **Load Demo Session** → tap the session → **Encrypt locally** (~30s) → **Commit provenance to Solana**. Tx Signature should now be a real 88-char base58 string. Tap the row to copy, then verify on Solana Explorer:
   `https://explorer.solana.com/tx/<SIG>?cluster=devnet`
7. Repeat for **Issue Access Token** (Consent screen) and **Revoke**. Pin the three real signatures into:
   - `README.md` → "On-chain proof" section
   - Slide 6 of the deck
   - The arena.colosseum.org submission description

## Status

**Code ✅**
- [x] Builds and runs on Android (Galaxy S9 — `4c4957534c573398`)
- [x] Forced dark + Solana palette (`lib/core/app_colors.dart`)
- [x] Branded as "HealthLog Protocol" (Dashboard, About, AppBar)
- [x] Persisted devnet wallet (`flutter_secure_storage`, HD path `m/44'/501'/0'/0'`)
- [x] Auto-connect on Devnet toggle
- [x] Wallet card with copy + Solana Explorer link
- [x] Demo Flow card with active step gradient highlight
- [x] Verifier multi-claim ZK-ready interface
- [x] **Cryptographic Merkle inclusion proof** (`lib/data/crypto/merkle_proof_service.dart`)
- [x] Session Detail palette polish + improved copy
- [x] Consent screen → "Data Access Token" branding
- [x] AI Summary gradient header
- [x] Mock wallet/sig now use base58 alphabet (no more bogus `O`/`0` chars)

**Polish still worth doing in 3 days**
- [ ] Add `qr_flutter` and put a QR on each Data Access Token card
- [ ] Onboarding screen (3 pages, first-launch flag)
- [ ] Pre-flight `permission_handler` request on Dashboard `initState`
- [ ] Remove the deprecated Impeller opt-out from `AndroidManifest.xml`
- [ ] Custom launcher icon with HL gradient mark (`flutter pub run flutter_launcher_icons`)
- [ ] Ship a one-page Next.js landing in `nextjs_frontend/` (hero + GIF + 8-step explainer + GitHub button + Loom button)

**Documentation ✅**
- [x] `README.md` — hackathon-ready (TL;DR, demo flow, real-now/mocked/future, stack, run, privacy)
- [x] `HACKATHON_STRATEGY.md` — 7-point strategic consultation with copy, assets, plan, bug list
- [x] `SLIDESHOW.md` — 10-slide deck content + 2:30 in-person script + asset specs
- [x] `PITCH_SCRIPT.md` — 2:50 Loom script
- [x] `SUBMISSION_CHECKLIST.md` (this file)

## What still needs you (the human)

### Tonight
- [x] **Three real devnet signatures captured 2026-05-08** from wallet `BrKt8mtkQdNno34YJYttxQXVHtNUYEcYQPP78wsjut2y` (1 SOL faucet-funded). Pinned in `README.md` "On-chain proof" section and `SLIDESHOW.md` slide 6. Screenshots `102_after_commit_tap.png` (Tx Signature shows `3b8JsC6BUdsWrAYy...`), `108_token_card_revoke.png` (token ACTIVE with grant tx), `109_after_revoke.png` (token REVOKED).
  - commit: `3b8JsC6BUdsWrAYyV2SfexK4NaUEnvJh9b81to52rHD7KgwCBvfhv6TuoyABd6xKdyVzQ5MgeGpKJQ8tYt5DdKBS`
  - grant:  `4w4DDVo96ToCKnzhAJiDEFXzggcc76Fh5SQsqeGBG8rUHVAez485or2zb3iMuahBvF1cCDu1NxfeGwNczA9RDNko`
  - revoke: `LFu7qHkF7ssZoRkFc2fEKtfFaD3KBb4B1puP5e8AkS9i5EkXzcS13uiSYoa8VRw5FWxBEHo92t7VaF234iBfFAG`
- [x] Take 5 clean screenshots — golden-set captured 2026-05-08 in `screenshots/`:
  - **Dashboard with full demo flow ribbon**: `79_dashboard.png` (Import → Encrypt → Hash → Commit → Summarize → Grant → Verify all green, Verify chip highlighted purple)
  - **Session Detail (encrypted + committed + generated)**: `69_after_commit2.png` (all 3 status pills, real wallet owner, mock devnet tx signature, View on Solana Explorer link)
  - **AI Summary**: `33_ai_summary.png`
  - **Consent / Data Access Token issued (ACTIVE)**: `76_signed.png` (Live Data Access Tokens card with ACTIVE pill, recipient + purpose + expiry)
  - **Verifier — ACCESS VERIFIED + green checks**: `83_verify_result.png`
  - **Verifier — Permitted vs Denied scope + privacy-preserving claims**: `84_verify_scroll1.png` (AI summary ✓, Raw EEG ✗, Raw PPG/fNIRS/IMU ✗ + 5 green ZK-style claims)
  - **Verifier — Cryptographic Merkle inclusion proof (VERIFIED)**: `85_verify_scroll2.png` (leaf, hashed leaf, sibling[0], root, Light Protocol ZK roadmap footer)
  - Bonus: `62_verify_denied_full.png` (failure path — "Access denied / No grant for this session and wallet" with red Xs but **green check on "Raw data was not exposed"** — proves the privacy invariant holds even on denial)
- [ ] Record a 1080p screen recording with `scrcpy --record demo.mp4` while you walk the demo. Convert to GIF for the README hero (≤10MB).

### Tomorrow
- [ ] Build the deck in Figma / Pitch.com / Slides — paste content from `SLIDESHOW.md`. Export to PDF.
- [ ] Set up the GitHub repo:
  - `git init` (root is `C:/Users/alexa/.gemini/antigravity/scratch/HealthLog`)
  - Add a `.gitignore` for Flutter (not yet checked in — verify `build/`, `.dart_tool/`, `ios/Pods/`, etc are excluded)
  - First commit, push to a public repo. Use the name `healthlog-protocol`.
- [ ] Record the Loom (use `PITCH_SCRIPT.md` — 2:50 max).
- [ ] Optionally ship the Next.js landing page from `nextjs_frontend/` to Vercel.
- [ ] Submit on arena.colosseum.org with: GitHub URL, Loom URL, deck PDF, three pinned tx signatures.

### Day 3 (rehearsal)
- [ ] Read the 2:30 in-person script three times against a timer. Don't go over.
- [ ] Pre-load demo session on the phone. Pre-airdrop the devnet wallet so commits return instantly on stage.
- [ ] Have the Solana Explorer tab pre-loaded with a real commit tx ready to switch to during the Demo slide.
- [ ] Backup: 5 extra slides for Q&A (deeper architecture, market sizing, token mechanics, ZK roadmap, monetization).

## Friction points to watch

1. **Galaxy S9 BLE permissions** — Android 9 doesn't strictly require `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` but later Android versions do. If your judges' demo device is Android 12+, the first scan can silently fail without runtime prompts. Add `permission_handler.request()` in `Dashboard.initState`.
2. **Devnet airdrop rate limiting** — `requestAirdrop` is occasionally throttled. The persisted wallet means you only need the airdrop once per fresh install. Re-fund manually via faucet if needed: <https://faucet.solana.com>.
3. **Demo session state resets on app reinstall** — sessions are in-memory only. If you reinstall the APK between rehearsal and pitch, you'll need to re-load the demo. (Acceptable for now; persist to disk later.)
4. **Phone lock during demo** — Galaxy S9 sleeps fast. Set screen timeout to 5 min in Settings before the pitch. Or use `WakelockPlus` package.

## After submission

- [ ] Cross-post the Loom on Twitter / LinkedIn the morning of the deadline.
- [ ] Follow up with Solana DevRel and Superteam Canada on Twitter / Discord.
- [ ] DM judges who post about Colosseum on Twitter that day — keep it short, link to the project.

## What I'd cut if I get behind

If you're at risk of running out of time:
1. Skip the QR code on tokens (cosmetic).
2. Skip the onboarding screen (one-time flow, not in the demo path).
3. Skip the launcher icon (Material default still looks fine).
4. **Do not skip:** real devnet tx signatures, Loom video, GitHub push.

## What separates winning submissions

Per Colosseum's "How to Win" guide:
- Working demo > feature breadth (you have this).
- Founder-market fit (lead with MuseLog credibility — you built it).
- Pitch under 3 minutes, no hand-waving.
- Bring a team. If solo: be honest about it on the Team slide, signal you're hiring.
