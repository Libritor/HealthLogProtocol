# HealthLog Protocol — Colosseum Strategy

**3 days to submission. No tracks — flat competition for "most impactful product." Working demo and clarity beat feature breadth.**

---

## 1. Top UI/UX changes (ship today)

1. **Force dark theme.** Crypto-native users expect dark. `themeMode: ThemeMode.dark` in `main.dart`, drop the system toggle.
2. **Solana-accent palette.** Centralize colors in `lib/core/app_colors.dart`: Solana purple `#9945FF`, teal `#14F195`, deep ink `#0E0E11`, surface `#16171C`, success `#14F195`, danger `#FF6B6B`. Use the gradient `[#9945FF → #14F195]` exactly once on the brand title and the primary CTA — it should feel like a signature, not wallpaper.
3. **Wallet card on dashboard.** Persistent address chip with truncated wallet, devnet balance, and "View on Explorer" link. Currently the wallet only appears as a one-line text node — judges expect a chip with the standard Solana wallet UX.
4. **Demo Flow card with active step highlight.** Right now it's a static row of pills. Make the current step glow (purple→teal gradient outline), prior steps muted-green check, future steps muted. Pulls the eye through the demo without you narrating "next we…"
5. **Premium empty states.** "No sessions yet" should be a centered icon + headline + sub + primary CTA, not gray text. Use a subtle brain/EEG-wave illustration (SVG asset suggested below).
6. **Iconography pass.** Replace generic Material icons with consistent line-style ones (Lucide via `flutter_lucide` package, or Material Symbols Outlined). Specific swaps:
   - Brain Sensing → `brain_circuit` instead of `psychology`
   - Verify → `shield_check` instead of `verified`
   - Solana commit → `link_2` or custom Solana mark
   - Encryption → `lock_keyhole`
   - Grant → `key_round`
   - Revoke → `ban` or `circle_off`
7. **Tighter copy.** Replace "Powered first by MuseLog brain-sensing sessions" with "Your wearable data. Your consent. On Solana." (lifts the brand promise from the README into the AppBar.)
8. **Status chips need iconography.** `Encrypted`, `Committed`, `Generated` chips currently use color only. Add a leading icon to each so they read at a glance.
9. **Currently dual-rendered Mock Mode chip is the only crypto cue on the dashboard.** Add a "Devnet" tag near the wallet pill, and a "Solana" footer mark on every screen.
10. **Loading states.** Right now `_loading = true` swaps the entire body for a spinner. Don't full-screen-replace — keep context, show a progress indicator on the action button or a top linear progress bar.

## 2. Top product / crypto changes (high-impact, low-effort)

1. **Persist the wallet across launches.** ✅ DONE (devnet keypair seed in `flutter_secure_storage`, HD path `m/44'/501'/0'/0'`).
2. **Show real devnet balance.** After `connectWallet()`, call `client.rpcClient.getBalance(walletAddress)` and surface `<balance> SOL` on the dashboard wallet card. Re-airdrop button if balance < 0.05 SOL. Demonstrates the app is doing real on-chain reads.
3. **Pin three example transactions in the README** with `https://explorer.solana.com/tx/<sig>?cluster=devnet` links: one commit, one grant, one revoke. **This is the single highest-trust signal you can put in a hackathon submission.**
4. **Auto-connect wallet on Devnet mode toggle.** Currently `_toggleSolanaMode` clears the wallet — judges then have to commit a session to see the wallet appear. Fix so toggling immediately shows the persisted wallet.
5. **"Privacy Proof" Merkle path on Verifier.** Real ZK is too much for 3 days, but a constructed Merkle proof of `manifestHash ∈ committed_set` is real cryptography and reads as ZK-adjacent. Output: leaf hash, sibling path, root, verifier outcome. Label it "Cryptographic inclusion proof — ZK compression roadmapped via Light Protocol."
6. **Data Access Token PDF / QR receipt.** When a grant is created, generate a "Data Access Token" card view with QR encoding `{tokenId, sessionId, scope, expiresAt, grantTxSig}`. Sharable, printable, recognizable as a token.
7. **Make scope visualization concrete.** When the recipient verifies, render exactly what's in the approved bucket and what isn't — a visual scope matrix (rows: data types, columns: ✓/✗) instead of plain text. "Raw EEG: ✗" in red is more memorable than the current bullet list.
8. **Add an `OnChainStateBanner` at the top of SessionDetail** showing "Committed at slot 308,294,107 by 4F8x…q3T2" with a tap to copy. Reinforces "this is on-chain, not just an internal state."
9. **Light Protocol roadmap call-out.** Add a one-liner in the README + AboutScreen: "Roadmap: Light Protocol ZK compression for compressed `SessionCommitment` accounts at <1000 lamports each." Demonstrates you know the Solana ZK stack.

## 3. Screens to add or improve

| Screen | Status | Action |
| --- | --- | --- |
| Dashboard | Exists | Wallet card, active demo-flow step, source-card icon refresh, "Solana" footer mark |
| SessionDetail | Exists | Add `OnChainStateBanner`, scope matrix, polished hash chips with copy buttons |
| ConsentScreen | Exists | Convert "Active Grants" cards into "Data Access Token" cards (QR, scope matrix, big revoke button) |
| Verifier | Exists | Add **Privacy Proof** section with Merkle path visualization and "Open in Explorer" for cited txs |
| AISummary | Exists | Header gradient bar, scope visualization, "Verify this report" CTA that jumps to Verifier with prefilled IDs |
| About | Exists | New section: "Built on Solana" with logo, RPC endpoint, devnet program IDs |
| **NEW: WalletScreen** | Missing | Show full wallet address + QR, balance, recent on-chain activity, airdrop button, export seed for advanced users (dev-only) |
| **NEW: OnboardingScreen** | Missing | 3-screen swipe: "Your data, encrypted on your phone" / "Solana records the consent, not the data" / "Grant. Revoke. Verify." Set first-launch flag in SharedPreferences |
| **NEW: LandingPage (web)** | Missing | One-page Next.js landing in the existing `nextjs_frontend/` folder for the submission link — see slideshow notes |

## 4. Exact copy

### Dashboard
- AppBar title: `HealthLog Protocol`
- AppBar subtitle: `Your wearable data. Your consent. On Solana.`
- Demo Flow card heading: `Demo Flow — runs end-to-end on Solana devnet`
- "Load Demo Session" button: `Load Demo Session` / sub: `Synthetic 5-min MuseLog EEG + IMU`
- Sessions empty state headline: `No sessions yet`
- Sessions empty state sub: `Load a demo or import a MuseLog CSV to start the on-chain consent flow.`

### SessionDetail
- Encrypt button: `Encrypt locally (AES-256-GCM)`
- Manifest button: `Hash + create manifest`
- Commit button: `Commit provenance to Solana`
- Generate button: `Generate AI Summary (scope-gated)`
- Share button: `Issue Data Access Token`
- Provenance card subtitle: `Hashes commit on-chain. Raw data stays on this device.`

### Consent
- Page title: `Issue Access Token`
- Sign button: `Sign + Publish Consent on Solana`
- Active grants section: `Live Data Access Tokens`
- Revoke button: `Revoke on-chain`

### Verifier
- Page title: `Verify Access`
- Subtitle: `Privacy-preserving verification — proves access without revealing data.`
- Privacy Proof section title: `Cryptographic inclusion proof`
- Privacy Proof footnote: `Light Protocol ZK compression roadmapped.`

### About / first slide
- One-liner: `Crypto-native consent and provenance for wearable health data.`
- Two-liner: `Wearable data stays encrypted on your device. Solana holds the audit trail of who you let touch it. We tokenize permission to access health data — never the data itself.`

## 5. Visual assets to create or source

| Asset | Where to use | How to get it |
| --- | --- | --- |
| HealthLog Protocol wordmark (light + dark) | App splash, AppBar, deck, README header | Generate in Figma — Inter Bold + a small "HL" mark in Solana gradient. ~30 min in Figma. |
| HL icon mark (square 1024×1024) | Launcher icon, favicon, deck thumbnail | Square purple→teal gradient, white "HL" or stylized brain glyph. Use `flutter_launcher_icons` (already in pubspec). |
| Solana mark (official) | Footer of every screen, deck "Built on" slide | Download official assets at https://solana.com/branding |
| Architecture diagram: Off-chain vs On-chain | Slide 4, README | Mermaid diagram (provided in `SLIDESHOW.md`). Render via mermaid.live and screenshot, or use a Mermaid CLI. |
| Data Access Token card mockup | Slide 6, landing page | Figma frame: rounded card with QR, scope chips, expiry, revoke button. Gradient border. |
| Lifecycle diagram (8 demo steps with arrows) | Slide 7, in-app About | Build in Figma or as Mermaid flowchart, see `SLIDESHOW.md` |
| Brain-EEG-wave hero illustration | Splash, Dashboard empty state, Slide 1 | Free SVG: undraw.co (search "brain", "data privacy"), or `assets/brain_wave.svg` from a free pack. Tint it with Solana purple. |
| Lock-and-key shield illustration | "Privacy" slide, About screen | undraw.co — search "secure data" or "encryption". |
| Phone-mockup with screenshot | Slides 2 / 5, landing page hero | Use https://mockuphone.com (free) — drop your dashboard screenshot into a Galaxy S9 frame. Better looking than raw screenshots. |
| Solana Explorer screenshot of an actual commit tx | Slide 5, README "On-chain proof" section | After you run a real devnet commit, capture the `https://explorer.solana.com/tx/<sig>?cluster=devnet` page. |
| QR for Data Access Token | In-app + slide | Use `qr_flutter: ^4.1.0` package — generate at runtime from token JSON. |
| Lucide icon set | Throughout app | `flutter_lucide: ^1.0.0` package, or Material Symbols Outlined (already shipped with Flutter). |
| Loop demo GIF (≤10 MB) | README hero, landing page | Record device with `scrcpy --record demo.mp4`, convert to GIF with ffmpeg. |

## 6. Implementation plan (Cursor-executable, ordered)

**Day 1 — branding + dark theme (4–6h)**
- Add `lib/core/app_colors.dart` with Solana palette, gradients, surface tokens.
- Force `themeMode: ThemeMode.dark` in `main.dart`. Build a custom `ColorScheme.fromSeed(seedColor: AppColors.solanaPurple)` for both light and dark, force dark.
- Rename app: `MuseHeadbandApp` → `HealthLogProtocolApp`, `pubspec.yaml: name: healthlog`, `android/app/src/main/AndroidManifest.xml` `android:label="HealthLog Protocol"`, `ios/Runner/Info.plist` `CFBundleDisplayName`. Generate launcher icons.
- Update Dashboard subtitle, AppBar typography, footer "Built on Solana" mark.

**Day 1 — wallet card + auto-connect (2h)**
- Build `_WalletCard` widget on the dashboard: address pill, balance, "View on Explorer" link, "Airdrop" button when balance < 0.05 SOL.
- Add `getBalance()` call to `DevnetSolanaService`, expose as a Riverpod stream.
- On `_toggleSolanaMode` to Devnet, immediately `connectWallet()` and `setState`. Keep the persisted address visible.

**Day 1 — Demo Flow active step (2h)**
- Add `currentDemoStep` derived state (function of latest session's status: encrypted? committed? summarized? granted? revoked?).
- Refactor `_demoFlowSliver` to color steps based on the derived current index.

**Day 2 — Verifier privacy proof (4h)**
- Add `MerkleProofService` in `lib/data/crypto/`. Build a small in-memory tree of all committed manifest hashes; `proveInclusion(manifestHash) → MerkleProof { leaf, path, root }`.
- Add `Privacy Proof` section to `VerifierScreen` with a card that shows leaf, path (vertical list of sibling hashes), root, and a green "Inclusion verified" badge.
- Footer line: "Cryptographic inclusion proof — ZK compression roadmapped via Light Protocol."

**Day 2 — Data Access Token QR (3h)**
- Add `qr_flutter` dep.
- Refactor `_grantCard` in `ConsentScreen` to a richer `_TokenCard` widget: QR (encoding token JSON), scope chips, expiry, revoke button, gradient border.

**Day 2 — Onboarding (2h)**
- Build `OnboardingScreen` (PageView, 3 pages). Set `seen_onboarding=true` in SharedPreferences. Show on first launch only.

**Day 3 — Asset polish (3h)**
- Drop in Solana mark, brain illustration, app icon. Run `flutter pub run flutter_launcher_icons`.
- Capture a real devnet commit tx, paste sig + Explorer URL into README "On-chain proof" section.
- Record demo GIF with scrcpy + ffmpeg, embed in README.

**Day 3 — Submission package (3h)**
- Push to public GitHub. Add LICENSE (MIT — already), CONTRIBUTING (already), DEMO.md.
- Build the Next.js landing page (single page, hero + demo GIF + 8-step explainer + GitHub button + Loom button).
- Record Loom (use `PITCH_SCRIPT.md`).
- Submit on arena.colosseum.org with: GitHub URL, Loom URL, landing URL, three pinned tx signatures.

**Day 3 — Pitch rehearsal (2h)**
- Read script three times against timer.
- Have 5 backup slides in case Q&A goes long.

## 7. Bugs / weak points / confusing flows

1. **`_toggleSolanaMode` clears the wallet.** Toggle to Devnet → wallet shows nothing until first commit. Either auto-connect or remove the clearing line. (`healthlog_dashboard_screen.dart:88-99`)
2. **Mock Mode shows mocked wallet "addresses" that are NOT base58 — they're random alphanumerics 44 chars long, including the letter `0` and `O` that base58 explicitly excludes.** Looks fake to anyone who reads addresses. Use a deterministic but valid base58 string in `MockSolanaService._generateMockWallet()` — e.g. `Mock1111111111111111111111111111111111111111`. (`mock_solana_service.dart:225-228`)
3. **AI summary is rule-based, not actually an LLM call.** That's fine *if* the demo never claims otherwise. The current copy ("Generate AI Summary") implies an LLM. Either (a) call OpenAI when an API key is present, or (b) rename to "Generate Session Report" and make the rule-based nature obvious.
4. **`OnchainStatus.shared` is set after a grant but the UI never shows the difference between Committed and Shared meaningfully.** Decide if Shared is a strict superset of Committed and reflect that in the chip color.
5. **Verifier screen requires manual session ID + wallet entry.** Tedious for judges. The "Use Latest Demo Session" button is great but should also be the first thing they see — promote it above the form.
6. **Demo flow step "Hash" is implicit inside Create Manifest.** Either combine the labels (`Encrypt → Manifest → Commit → ...`) or actually surface a separate "View hash" step. Currently the 8-step pill list reads slightly off the actual button labels.
7. **The "Coming Soon" cards (Oura/Whoop/Ray-Ban) take real estate without earning it.** Either compress them into a single horizontal strip ("Adapters: Oura, Whoop, Ray-Ban Meta — coming soon"), or hide them behind a "More sources" expand.
8. **`MockSolanaService` random-generates an EXPENSIVE-looking 88-char hex string for "tx signatures"; real Solana sigs are 88 base58 chars.** Use base58 alphabet. (`mock_solana_service.dart:230-233`)
9. **`flutter_blue_plus` is required at startup on Android 12+ for the manifest permissions; if the user denies BLUETOOTH_SCAN the demo flow still works but later screens may glitch.** Pre-flight permission request at first launch (`permission_handler` is already in pubspec).
10. **Impeller opt-out warning in logs** — the AndroidManifest disables Impeller. Per the deprecation notice, remove the `EnableImpeller=false` meta-data; Impeller works fine on Galaxy S9.
11. **`HealthLog/HealthLog - Copy` are two divergent codebases.** The Copy is the *wrong* MuseLog-only snapshot. Either delete Copy or move it under `archive/` so collaborators / agents don't pick the wrong one. (Not in repo if it stays under `.gemini/antigravity/scratch/`.)
12. **`themeMode: ThemeMode.dark` already in `main.dart`** but `ColorScheme.fromSeed(brightness: Brightness.dark)` produces a near-black surface that lacks Solana feel. Replace with the centralized palette in step 1.

---

## What I'd cut to save time

- Anchor program (3+ days alone — memo program is enough for the demo).
- Real Mobile Wallet Adapter integration (deep Android/iOS native bridging — keep persisted keypair).
- Real OpenAI integration for summary (rule-based already passes the scope-gated narrative).
- Oura, Whoop, Ray-Ban adapters (placeholder is fine and reinforces "MuseLog first" wedge).

## What separates winning submissions from the field

Per Colosseum's own "How to Win" guide and the Cypherpunk / Renaissance winners:

- **Working demo > feature breadth.** Judges click Loom. If the first 30 seconds don't show a real on-chain transaction, you are competing against ~100 other "we connect to Solana" pitches.
- **Defensible wedge.** "Wearable + EEG + crypto consent" is a niche almost nobody else will submit. Lean in. Don't pivot to "general health data."
- **Founder-market fit.** Your MuseLog credibility is the founder-market story. Mention it in the team slide. "I built MuseLog. Researchers use it. Now I'm building the consent layer."
- **The pitch is your highest-leverage hour.** Spend more time on the script than on adding the 9th feature.
