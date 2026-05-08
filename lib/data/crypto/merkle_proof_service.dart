import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Constructs Merkle inclusion proofs over session manifest hashes.
///
/// Use this to prove that a given `manifestHash` is part of the user's
/// committed set without revealing the other manifests in the set.
///
/// MVP scope:
///   - In-memory binary tree built fresh from a list of leaves.
///   - SHA-256 hashing for leaves and inner nodes.
///   - Domain-separation tags ("leaf", "node") to prevent second-preimage
///     attacks (RFC 6962 style — minus the actual RFC 6962 framing).
///
/// Roadmap:
///   - Periodically commit the Merkle root to Solana so a third party
///     can verify a proof against an on-chain root.
///   - Migrate the per-session memo commitments to compressed accounts
///     under [Light Protocol](https://lightprotocol.com), which uses
///     Solana-native ZK state compression.
class MerkleProofService {
  /// 64-char hex zero — Merkle root convention for an empty tree.
  static const _zeroRoot =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Build a Merkle tree from `leaves` and return the root + tree levels.
  /// Levels are stored from leaf-level (level 0) up to root.
  ///
  /// Empty input returns the all-zero root convention.
  MerkleTree buildTree(List<String> leaves) {
    if (leaves.isEmpty) {
      return const MerkleTree(
        leaves: [],
        levels: [
          [_zeroRoot],
        ],
      );
    }

    // Hash leaves with the leaf domain tag.
    final level0 = leaves.map(_hashLeaf).toList(growable: false);
    final levels = <List<String>>[level0];

    var current = level0;
    while (current.length > 1) {
      final next = <String>[];
      for (var i = 0; i < current.length; i += 2) {
        final left = current[i];
        final right = (i + 1 < current.length) ? current[i + 1] : current[i];
        next.add(_hashNode(left, right));
      }
      levels.add(next);
      current = next;
    }

    return MerkleTree(leaves: leaves, levels: levels);
  }

  /// Construct a proof that `target` is a leaf in `tree`. Returns null if
  /// not present.
  MerkleProof? proveInclusion({
    required MerkleTree tree,
    required String target,
  }) {
    if (tree.leaves.isEmpty) return null;
    final leafIndex = tree.leaves.indexOf(target);
    if (leafIndex < 0) return null;

    final hashedLeaf = _hashLeaf(target);
    final siblings = <MerkleSibling>[];

    var index = leafIndex;
    for (var level = 0; level < tree.levels.length - 1; level++) {
      final layer = tree.levels[level];
      final isRightChild = index.isOdd;
      final siblingIndex = isRightChild ? index - 1 : index + 1;
      final sibling =
          siblingIndex < layer.length ? layer[siblingIndex] : layer[index];
      siblings.add(MerkleSibling(
        hash: sibling,
        position: isRightChild ? SiblingPosition.left : SiblingPosition.right,
      ));
      index ~/= 2;
    }

    return MerkleProof(
      leaf: target,
      hashedLeaf: hashedLeaf,
      siblings: siblings,
      root: tree.root,
    );
  }

  /// Re-derive the root from a proof and confirm it matches.
  bool verifyProof(MerkleProof proof) {
    var current = proof.hashedLeaf;
    for (final sibling in proof.siblings) {
      switch (sibling.position) {
        case SiblingPosition.left:
          current = _hashNode(sibling.hash, current);
        case SiblingPosition.right:
          current = _hashNode(current, sibling.hash);
      }
    }
    return current == proof.root;
  }

  String _hashLeaf(String input) =>
      sha256.convert(utf8.encode('leaf:$input')).toString();

  String _hashNode(String left, String right) =>
      sha256.convert(utf8.encode('node:$left:$right')).toString();
}

class MerkleTree {
  final List<String> leaves;
  final List<List<String>> levels;

  const MerkleTree({required this.leaves, required this.levels});

  String get root => levels.last.first;
  int get depth => levels.length - 1;
  int get leafCount => leaves.length;
}

class MerkleProof {
  final String leaf;
  final String hashedLeaf;
  final List<MerkleSibling> siblings;
  final String root;

  const MerkleProof({
    required this.leaf,
    required this.hashedLeaf,
    required this.siblings,
    required this.root,
  });
}

enum SiblingPosition { left, right }

class MerkleSibling {
  final String hash;
  final SiblingPosition position;
  const MerkleSibling({required this.hash, required this.position});
}
