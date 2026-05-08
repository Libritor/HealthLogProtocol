import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ai/ai_report_service.dart';
import '../../data/crypto/encryption_service.dart';
import '../../data/crypto/hashing_service.dart';
import '../../data/crypto/merkle_proof_service.dart';
import '../../data/crypto/verification_service.dart';
import '../../data/demo/demo_data_service.dart';
import '../../data/solana/devnet_solana_service.dart';
import '../../data/solana/mock_solana_service.dart';
import '../../data/solana/solana_consent_service.dart';
import '../../domain/models/solana_models.dart';

// --- Service providers ---

final hashingServiceProvider = Provider<HashingService>(
  (_) => HashingService(),
);

final merkleProofServiceProvider = Provider<MerkleProofService>(
  (_) => MerkleProofService(),
);

final encryptionServiceProvider = Provider<EncryptionService>(
  (_) => EncryptionService(),
);

final aiReportServiceProvider = Provider<AIReportService>(
  (ref) => AIReportService(
    hashingService: ref.watch(hashingServiceProvider),
  ),
);

final verificationServiceProvider = Provider<VerificationService>(
  (ref) => MockVerificationService(
    hashingService: ref.watch(hashingServiceProvider),
  ),
);

final demoDataServiceProvider = Provider<DemoDataService>(
  (ref) => DemoDataService(
    hashingService: ref.watch(hashingServiceProvider),
  ),
);

final solanaServiceProvider =
    StateNotifierProvider<SolanaServiceNotifier, SolanaConsentService>(
  (_) => SolanaServiceNotifier(),
);

// --- State providers ---

final solanaModeProvider = StateProvider<SolanaMode>(
  (_) => SolanaMode.mock,
);

final walletAddressProvider = StateProvider<String?>((_) => null);

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<WearableSession>>(
  (ref) => SessionsNotifier(),
);

final aiReportsProvider =
    StateNotifierProvider<AIReportsNotifier, Map<String, AIReport>>(
  (ref) => AIReportsNotifier(),
);

// --- Notifiers ---

class SolanaServiceNotifier extends StateNotifier<SolanaConsentService> {
  SolanaServiceNotifier() : super(MockSolanaService());

  void switchMode(SolanaMode mode) {
    switch (mode) {
      case SolanaMode.mock:
        state = MockSolanaService();
      case SolanaMode.devnetMemo:
        state = DevnetSolanaService();
      case SolanaMode.anchor:
        state = MockSolanaService();
    }
  }
}

class SessionsNotifier extends StateNotifier<List<WearableSession>> {
  SessionsNotifier() : super([]);

  void addSession(WearableSession session) {
    state = [session, ...state];
  }

  void updateSession(WearableSession updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
  }

  WearableSession? getById(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  void clear() => state = [];
}

class AIReportsNotifier extends StateNotifier<Map<String, AIReport>> {
  AIReportsNotifier() : super({});

  void addReport(AIReport report) {
    state = {...state, report.sessionId: report};
  }

  AIReport? getBySessionId(String sessionId) => state[sessionId];
}
