import '../../core/config/rpc_config.dart';
import '../../domain/models/baseline_models.dart';

/// Abstract interface for anchoring and verifying wearable baselines on Solana.
///
/// Implementations: [MockBaselineAnchorService] (in-memory, offline demo) and
/// [DevnetBaselineAnchorService] (real memo transactions via [RpcConfig], so
/// RPC Fast can serve as the write/verify rail).
///
/// This is a sibling of [SolanaConsentService]: sessions commit their manifest;
/// baselines commit their calibration hash. Both keep raw signals off-chain.
abstract class BaselineAnchorService {
  RpcConfig get rpcConfig;

  /// A human-readable, key-free mode label ("Mock", "rpcfast.com · mainnet").
  String get modeLabel;

  String? get connectedWallet;

  Future<String> connectWallet();

  /// Anchor a baseline's commitment hash + shape metadata on-chain.
  Future<BaselineCommitment> anchorBaseline(WearableBaseline baseline);

  /// Revoke a previously anchored baseline (e.g. after recalibration or leak).
  Future<String> revokeBaseline({required String baselineId});

  /// Consumer-side check: does [candidateParameters] hash to the commitment
  /// recorded at [txSignature], and is the commitment well-formed and fresh?
  Future<BaselineVerification> verifyBaseline({
    required String txSignature,
    required Map<String, dynamic> candidateParameters,
    String? expectedOwner,
  });
}
