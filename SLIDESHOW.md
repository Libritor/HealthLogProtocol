# HealthLog Protocol — 2.5-min Pitch Deck

10 slides, ~15s each. Designed for a live competition where the audience is reading on a screen behind you while you talk.

**Color system for every slide:** background `#0E0E11`, text `#F5F5F7`, accent gradient `#9945FF → #14F195` (Solana). Use Inter or Space Grotesk. Single brand mark in the bottom-right corner of every slide except 1 and 10.

Tooling: build in Figma, Slides (Google), Pitch.com, or Marp. Each slide spec below has **headline**, **body**, and **visual** sections — paste these into the deck tool and apply the color system.

---

## Slide 1 — Cover (15s)

**Headline:** HealthLog Protocol

**Sub:** Crypto-native consent and provenance for wearable health data.

**Visual:** Centered HL wordmark in the gradient. Below it: a faint EEG waveform (SVG, 30% opacity) crossing the lower third of the slide. Bottom-left: presenter name. Bottom-right: "Solana Frontier Hackathon · 2026."

**Asset to make:** Wordmark + EEG line. Generate the EEG line in Figma with a single SVG path or grab a free brain-wave SVG from undraw.co and tint it.

---

## Slide 2 — Problem (15s)

**Headline:** Wearable data has no consent layer.

**Body (3 bullets, large type, no commas):**
- Your data is fragmented across Muse, Oura, Whoop, Apple.
- AI is getting better at reading it.
- Permission lives in unreadable ToS pages — not on a chain.

**Visual:** Grid of 6 wearable logos in greyscale (Muse, Oura, Whoop, Apple Watch, Garmin, Fitbit) trapped behind a faint padlock icon. The point: data is locked and siloed. Use any open-license logo set; if you can't find one, just write the brand names in styled chips.

---

## Slide 3 — Solution (15s)

**Headline:** Your data on your phone. Your consent on Solana.

**Body:** HealthLog Protocol is a mobile app where wearable data stays encrypted on the device, and Solana records who you let touch it — with revocation, scope, and on-chain audit.

**Visual:** Two-column split. Left column: phone mockup with the dashboard screenshot, a lock icon overlay. Right column: a stylized Solana logo with three small chips around it labeled "Commit · Grant · Revoke." Arrow between columns labeled "manifest hash only."

**Asset:** mockuphone.com phone frame with `_screenshot_dashboard.png` dropped in. Solana mark from solana.com/branding.

---

## Slide 4 — Architecture (20s)

**Headline:** What's on-chain and what isn't.

**Visual:** Mermaid diagram (rendered as PNG via mermaid.live and exported). Single most important slide of the deck — read it from far away.

```mermaid
flowchart LR
    subgraph Device["On the device (encrypted)"]
        EEG[Raw EEG / IMU CSV] --> ENC[AES-256-GCM]
        ENC --> VAULT[(Encrypted vault)]
        ENC --> HASH[SHA-256 manifest]
    end
    subgraph Solana["On Solana (privacy-safe)"]
        COMMIT[session_commitment]
        GRANT[access_grant]
        REVOKE[access_revoke]
    end
    HASH -.committed.-> COMMIT
    GRANT -- token --> RECIPIENT[Recipient wallet]
    REVOKE -- terminates --> GRANT
    style Device fill:#16171C,stroke:#9945FF,color:#F5F5F7
    style Solana fill:#16171C,stroke:#14F195,color:#F5F5F7
```

**Footer line:** "Raw health data never touches the chain."

**Render tip:** Paste the Mermaid into https://mermaid.live, set theme to dark, export as PNG at 2x.

---

## Slide 5 — Demo (20s)

**Headline:** Eight steps. End-to-end on devnet.

**Visual:** Horizontal pill row of the 8 steps with arrows and a glowing gradient highlight on the current step. Same component as the in-app Demo Flow card.

```
Import → Encrypt → Hash → Commit → Summarize → Grant → Verify → Revoke
```

Below it: a 3-up screenshot strip — Dashboard, SessionDetail (Commit screen with explorer link), Verifier (green checks). Phone mockups.

**Visual asset:** Three real screenshots in Galaxy S9 mockups, side by side, with the Solana mark in the gutter between them.

---

## Slide 6 — On-chain proof (15s)

**Headline:** Real transactions, not mocks.

**Visual:** Screenshot of an actual Solana Explorer page (`https://explorer.solana.com/tx/<sig>?cluster=devnet`) for one of your `commit` transactions. Annotate with a callout arrow pointing to the memo payload showing `{type: "session_commitment", manifestHash: "...", ...}`.

**Body:** Three transaction signatures in monospace, each clickable in the live deck:
- `commit:` `<sig>`
- `grant:` `<sig>`
- `revoke:` `<sig>`

**This slide is your single biggest differentiator vs. the average submission. Spend the time to make the screenshot crisp.**

---

## Slide 7 — Data Access Token (15s)

**Headline:** Permission, not data.

**Body:** A `DataAccessToken` is a non-transferable receipt that says: *recipient X can see scope Y of session Z until time T*. Revocable on-chain. Verifiable without revealing the data.

**Visual:** Mockup of the in-app token card — QR code on the left, scope chips on the right (`AI Summary Only` ✓ in teal, `Raw EEG` ✗ in red), expiry, big "Revoke on-chain" button. Gradient border.

**Asset:** Build this card in Figma (5 min). The token-card mockup also doubles as the in-app component you'd build day 2.

---

## Slide 8 — Market and wedge (20s)

**Headline:** MuseLog first. Then every wearable.

**Body (two bullets):**
- **Wedge:** MuseLog is already used by neuro researchers and consumers. They export raw EEG and have nowhere good to put it.
- **Expansion:** Oura, Whoop, Apple Health, Ray-Ban Meta — every wearable becomes a HealthLog-attached source. The protocol stays the same.

**Visual:** A horizontal arrow timeline. Left: MuseLog logo (you own this). Middle: Oura, Whoop, Apple Health logos (greyed, "next"). Right: Ray-Ban Meta, Garmin, etc. (further out, "horizon"). Above the timeline: "1 protocol, N adapters."

---

## Slide 9 — Team and traction (15s)

**Headline:** Built by the people who ship MuseLog.

**Body:** [Founder name] — built MuseLog (used by N researchers / N CSV exports). [Cofounder names + roles]. Building HealthLog Protocol full-time.

**Visual:** Two or three faces with names + one-line credentials. If you don't have cofounders yet, single founder + a "Hiring: technical cofounder" call-out is honest and fine.

**Why this slide matters:** Per Colosseum's own playbook, judges weight founder-market fit heavily. Your MuseLog credibility *is* the founder-market story.

---

## Slide 10 — Close + ask (10s)

**Headline:** HealthLog Protocol

**Body:** Your wearable data. Your consent. On Solana.

**Visual:** Same as cover but with a row of links at the bottom (small text, all on one line):
`github.com/<you>/healthlog · Loom: <demo-url> · explorer.solana.com/tx/<sig>?cluster=devnet`

Below: "Frontier Hackathon · Submission #_____"

---

## Pitch script — 2:30 (paired to slides above)

> [Slide 1 — Cover, 0:00–0:10]
> Today every wearable company is your data landlord. They decide what AI sees, what researchers see, even what *you* see. HealthLog Protocol flips it.

> [Slide 2 — Problem, 0:10–0:25]
> Wearable health data is fragmented across six different apps. AI is getting better at reading it every month. And the permission to share it lives in ToS pages nobody reads — not on a chain anybody can audit.

> [Slide 3 — Solution, 0:25–0:40]
> HealthLog Protocol is one mobile app where your wearable data stays encrypted on your phone, and Solana records who you let touch it. We tokenize permission to access health data — never the data itself.

> [Slide 4 — Architecture, 0:40–1:00]
> Here's the rule. Raw EEG, IMU, biometrics — encrypted, on the device, never on chain. The chain holds three things: a manifest hash that commits the session, an access grant that says who you let in and what scope, and a revoke that terminates it. That's the whole protocol.

> [Slide 5 — Demo, 1:00–1:20]
> Eight steps, end-to-end on devnet. Import a MuseLog session — that's brain data from a Muse 2 EEG headband. Encrypt it locally with AES-256-GCM. Hash it. Commit the hash to Solana via the memo program. Generate a scope-gated AI summary. Grant access to a recipient wallet — they get a Data Access Token, not the data. Verify. Revoke.

> [Slide 6 — Proof, 1:20–1:35]
> These are real transaction signatures on Solana devnet. The commit, the grant, the revoke. You can click them right now and see the memo payload — manifest hash, owner wallet, scope code. The raw EEG never left my phone.

> [Slide 7 — Token, 1:35–1:50]
> The Data Access Token is the artifact. It's non-transferable, scope-bounded, time-bounded, and revocable on-chain. The recipient can prove they have valid access without ever decrypting your raw data.

> [Slide 8 — Market, 1:50–2:10]
> We're starting with MuseLog because I built it — researchers and neuro-hackers already use it, and they have nowhere good to put their EEG. From there, every wearable becomes a HealthLog-attached source. One protocol. N adapters. The TAM is the entire wearable health market — sixty billion dollars and growing every quarter.

> [Slide 9 — Team, 2:10–2:25]
> I'm [Name]. I shipped MuseLog. [Cofounder] is [role]. We're building HealthLog Protocol full-time on Solana.

> [Slide 10 — Close, 2:25–2:30]
> HealthLog Protocol. Your wearable data. Your consent. On Solana. Thanks.

---

## Slide build order if you're rushed

If you only have an hour to build the deck, prioritize: **6 → 4 → 5 → 1 → 10 → 3 → 2 → 7 → 8 → 9.** Slide 6 (proof) and 4 (architecture) are the most-discussed slides in any judges' Q&A — make them rock-solid first.

## Tools

- Figma (free) for slide design and the token card mockup
- mermaid.live for the architecture diagram
- mockuphone.com for the phone mockups
- undraw.co for free SVG illustrations (brain, lock, security)
- solana.com/branding for the official Solana mark
- Pitch.com or Slides.com to present (both export to PDF for the submission)

## Submission package

When you submit on arena.colosseum.org, attach:

- **Loom URL** (the sub-3-min Colosseum video — see `PITCH_SCRIPT.md`).
- **Pitch deck PDF** (this slideshow, exported).
- **GitHub URL** of the public repo.
- **Three pinned devnet tx signatures** in the description.
- **Live demo URL** if you ship the Next.js landing page (recommended — single page is enough).
