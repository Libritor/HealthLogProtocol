import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import { createHash } from "crypto";
import { assert } from "chai";
import { HealthlogBaseline } from "../target/types/healthlog_baseline";

// PDA seed helper mirrors the program: ["baseline", owner, baselineHash].
function commitmentPda(programId: PublicKey, owner: PublicKey, baselineHash: Buffer) {
  return PublicKey.findProgramAddressSync(
    [Buffer.from("baseline"), owner.toBuffer(), baselineHash],
    programId
  )[0];
}

const sha256 = (s: string) => createHash("sha256").update(s).digest();

describe("healthlog_baseline", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const program = anchor.workspace.HealthlogBaseline as Program<HealthlogBaseline>;
  const owner = provider.wallet.publicKey;

  // A stand-in commitment (in production this is SHA-256 of the canonical
  // baseline parameters — identical to the Dart/Node hashers).
  const baselineHash = sha256("eeg-gmm-arousal-demo");
  const featureSchemaHash = sha256("muse-bandpower-4");
  const modelHash = sha256("eeg:gmm-arousal:1.0.0");
  const validUntil = new anchor.BN(Math.floor(Date.now() / 1000) + 365 * 24 * 3600);

  it("commits a baseline", async () => {
    const pda = commitmentPda(program.programId, owner, baselineHash);
    await program.methods
      .commitBaseline([...baselineHash], [...featureSchemaHash], 0, [...modelHash], validUntil)
      .accounts({ commitment: pda, owner })
      .rpc();

    const acct = await program.account.baselineCommitment.fetch(pda);
    assert.deepEqual([...acct.baselineHash], [...baselineHash]);
    assert.equal(acct.signal, 0);
    assert.isFalse(acct.revoked);
    assert.ok(acct.owner.equals(owner));
  });

  it("rejects a second commit of the same baseline (PDA already exists)", async () => {
    const pda = commitmentPda(program.programId, owner, baselineHash);
    let threw = false;
    try {
      await program.methods
        .commitBaseline([...baselineHash], [...featureSchemaHash], 0, [...modelHash], validUntil)
        .accounts({ commitment: pda, owner })
        .rpc();
    } catch (_e) {
      threw = true;
    }
    assert.isTrue(threw, "re-anchoring the same baseline should fail");
  });

  it("revokes a baseline (owner only)", async () => {
    const pda = commitmentPda(program.programId, owner, baselineHash);
    await program.methods.revokeBaseline().accounts({ commitment: pda, owner }).rpc();
    const acct = await program.account.baselineCommitment.fetch(pda);
    assert.isTrue(acct.revoked);
  });

  it("blocks a non-owner from revoking", async () => {
    const stranger = anchor.web3.Keypair.generate();
    const pda = commitmentPda(program.programId, owner, baselineHash);
    let threw = false;
    try {
      await program.methods
        .revokeBaseline()
        .accounts({ commitment: pda, owner: stranger.publicKey })
        .signers([stranger])
        .rpc();
    } catch (_e) {
      threw = true;
    }
    assert.isTrue(threw, "a non-owner must not be able to revoke");
  });
});
