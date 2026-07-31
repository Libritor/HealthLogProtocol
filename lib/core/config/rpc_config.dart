/// Centralized Solana RPC endpoint configuration.
///
/// The endpoint is injected at build/run time so that secrets (an RPC Fast API
/// key) never live in the repository:
///
/// ```
/// flutter run \
///   --dart-define=HEALTHLOG_RPC_HTTP=https://solana-rpc.rpcfast.com/?api_key=YOUR_KEY \
///   --dart-define=HEALTHLOG_RPC_WSS=wss://solana-rpc.rpcfast.com/?api_key=YOUR_KEY \
///   --dart-define=HEALTHLOG_RPC_NETWORK=mainnet
/// ```
///
/// With no defines, the app targets the public Solana devnet — the free demo
/// rail. RPC Fast (mainnet) is the production + verification rail: fast,
/// reliable reads so a third-party BCI/wearable app can verify a user's
/// on-chain baseline commitment before trusting it.
class RpcConfig {
  final String httpUrl;
  final String wsUrl;

  /// 'devnet' or 'mainnet'. Drives the Solana Explorer cluster suffix.
  final String network;

  const RpcConfig({
    required this.httpUrl,
    required this.wsUrl,
    required this.network,
  });

  static const _defaultDevnetHttp = 'https://api.devnet.solana.com';
  static const _defaultDevnetWs = 'wss://api.devnet.solana.com';

  /// Read endpoints from --dart-define, falling back to public devnet.
  factory RpcConfig.fromEnvironment() {
    const http = String.fromEnvironment(
      'HEALTHLOG_RPC_HTTP',
      defaultValue: _defaultDevnetHttp,
    );
    const ws = String.fromEnvironment(
      'HEALTHLOG_RPC_WSS',
      defaultValue: _defaultDevnetWs,
    );
    const network = String.fromEnvironment(
      'HEALTHLOG_RPC_NETWORK',
      defaultValue: 'devnet',
    );
    return const RpcConfig(httpUrl: http, wsUrl: ws, network: network);
  }

  bool get isMainnet => network == 'mainnet';

  /// True when a real RPC Fast endpoint is configured (not the public default).
  bool get isRpcFast => httpUrl.contains('rpcfast.com');

  /// Cluster query param for explorer links ('' for mainnet).
  String get explorerClusterSuffix =>
      isMainnet ? '' : '?cluster=$network';

  String explorerTxUrl(String signature) =>
      'https://explorer.solana.com/tx/$signature$explorerClusterSuffix';

  String explorerAddressUrl(String address) =>
      'https://explorer.solana.com/address/$address$explorerClusterSuffix';

  /// A short, key-free label for UI display ("rpcfast.com · mainnet").
  String get displayLabel {
    final host = Uri.tryParse(httpUrl)?.host ?? httpUrl;
    return '$host · $network';
  }
}
