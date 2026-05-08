import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('HealthLog Protocol',
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Crypto-native consent and provenance for wearable health data. '
            'Your data stays encrypted on your phone — Solana records who '
            'you let touch it.',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),

          _sectionCard(
            theme,
            Icons.error_outline,
            'Problem',
            'Wearable health data is fragmented across devices and platforms. '
                'As LLMs become more useful for interpreting personal health and '
                'brain-sensing data, users need a way to share data with AI, '
                'researchers, clinicians, and apps without losing control of '
                'privacy or provenance.',
          ),
          _sectionCard(
            theme,
            Icons.lightbulb_outline,
            'Solution',
            'HealthLog unifies wearable data from MuseLog and other devices, '
                'encrypts raw data offchain, and uses Solana to record '
                'privacy-safe consent, access, revocation, and verification events.',
          ),
          _sectionCard(
            theme,
            Icons.bolt,
            'Why Solana',
            '\u2022 Fast, low-cost user permission events\n'
                '\u2022 Wallet-native identity and signing\n'
                '\u2022 Onchain audit trail for consent and revocation\n'
                '\u2022 Future support for tokenized data access, rewards, '
                'and privacy-preserving verification',
          ),
          _sectionCard(
            theme,
            Icons.rocket_launch,
            'MVP Features',
            '\u2022 MuseLog EEG / IMU session import\n'
                '\u2022 Encrypted offchain storage\n'
                '\u2022 Session manifest and hash\n'
                '\u2022 Solana consent commitment\n'
                '\u2022 AI summary generation\n'
                '\u2022 Wallet-based grant and revoke flow\n'
                '\u2022 Verifier page\n'
                '\u2022 ZK-ready verification interface',
          ),
          _sectionCard(
            theme,
            Icons.shield_outlined,
            'Privacy Commitments',
            '\u2022 Raw health data never touches Solana.\n'
                '\u2022 Onchain records contain only hashes, wallet addresses, '
                'timestamps, scope codes, and revocation status.\n'
                '\u2022 HealthLog tokenizes permission to use health data, '
                'not the health data itself.\n'
                '\u2022 The LLM receives only the scope the user approved.\n'
                '\u2022 Demo data is synthetic \u2014 no real participant health data.',
          ),
          _sectionCard(
            theme,
            Icons.compare_arrows,
            'Real Now vs Future',
            'Real now:\n'
                '\u2022 MuseLog CSV import and parsing\n'
                '\u2022 AES-256-GCM encryption\n'
                '\u2022 SHA-256 hashing and manifest generation\n'
                '\u2022 Mock Solana consent service\n'
                '\u2022 AI summary generation\n'
                '\u2022 Grant, revoke, and verify flow\n\n'
                'Future:\n'
                '\u2022 Real Solana devnet / mainnet transactions\n'
                '\u2022 Anchor program for structured consent accounts\n'
                '\u2022 ZK proofs for privacy-preserving claims\n'
                '\u2022 Multi-wearable adapters (Oura, Whoop, Ray-Ban Meta)\n'
                '\u2022 Tokenized data access rewards',
          ),

          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primaryContainer.withAlpha(80),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Powered first by MuseLog',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'MuseLog brain-sensing sessions provide real data, '
                    'real novelty, and a defensible wedge for HealthLog.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
      ThemeData theme, IconData icon, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
