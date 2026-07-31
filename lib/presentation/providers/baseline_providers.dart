import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/rpc_config.dart';
import '../../data/baseline/baseline_anchor_service.dart';
import '../../data/baseline/baseline_hashing.dart';
import '../../data/baseline/devnet_baseline_anchor_service.dart';
import '../../data/baseline/mock_baseline_anchor_service.dart';
import '../../domain/models/baseline_models.dart';
import '../../domain/models/solana_models.dart';
import 'solana_providers.dart';

/// The active RPC endpoint (RPC Fast when injected via --dart-define).
final rpcConfigProvider = Provider<RpcConfig>(
  (_) => RpcConfig.fromEnvironment(),
);

final baselineHashingProvider = Provider<BaselineHashing>(
  (ref) => BaselineHashing(ref.watch(hashingServiceProvider)),
);

/// Baseline anchoring service. Follows the same Mock <-> Devnet toggle as the
/// session consent service ([solanaModeProvider]).
final baselineAnchorServiceProvider =
    Provider<BaselineAnchorService>((ref) {
  final mode = ref.watch(solanaModeProvider);
  final hashing = ref.watch(baselineHashingProvider);
  switch (mode) {
    case SolanaMode.mock:
      return MockBaselineAnchorService(hashing);
    case SolanaMode.devnetMemo:
    case SolanaMode.anchor:
      return DevnetBaselineAnchorService(
        hashing: hashing,
        rpcConfig: ref.watch(rpcConfigProvider),
      );
  }
});

/// The user's anchored baselines (their "baseline passport").
final baselinesProvider =
    StateNotifierProvider<BaselinesNotifier, List<WearableBaseline>>(
  (_) => BaselinesNotifier(),
);

class BaselinesNotifier extends StateNotifier<List<WearableBaseline>> {
  BaselinesNotifier() : super([]);

  void add(WearableBaseline baseline) => state = [baseline, ...state];

  void update(WearableBaseline updated) {
    state = [
      for (final b in state)
        if (b.baselineId == updated.baselineId) updated else b,
    ];
  }

  WearableBaseline? getById(String id) {
    for (final b in state) {
      if (b.baselineId == id) return b;
    }
    return null;
  }

  void clear() => state = [];
}
