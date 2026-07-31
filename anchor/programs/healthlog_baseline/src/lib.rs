use anchor_lang::prelude::*;

// Replaced with the real program id after `anchor keys sync` / first deploy.
declare_id!("BABE1ine1111111111111111111111111111111111");

/// On-chain baseline commitments as queryable program state (PDAs), the
/// structured successor to the memo-transaction MVP.
///
/// Privacy invariant (identical to the rest of HealthLog): only a commitment
/// hash + a short signal tag + timestamps live on-chain. The fitted baseline
/// parameters (GMM state / EMG MVC / HRV norms) never touch the chain.
#[program]
pub mod healthlog_baseline {
    use super::*;

    /// Anchor a baseline. One PDA per (owner, baseline_hash), so a commitment
    /// is unique and anyone can derive + read it to verify a baseline.
    pub fn commit_baseline(
        ctx: Context<CommitBaseline>,
        baseline_hash: [u8; 32],
        feature_schema_hash: [u8; 32],
        signal: u8,
        model_hash: [u8; 32],
        valid_until: i64,
    ) -> Result<()> {
        let c = &mut ctx.accounts.commitment;
        c.owner = ctx.accounts.owner.key();
        c.baseline_hash = baseline_hash;
        c.feature_schema_hash = feature_schema_hash;
        c.model_hash = model_hash;
        c.signal = signal;
        c.created_at = Clock::get()?.unix_timestamp;
        c.valid_until = valid_until;
        c.revoked = false;
        c.bump = ctx.bumps.commitment;
        emit!(BaselineCommitted {
            owner: c.owner,
            baseline_hash,
            signal,
        });
        Ok(())
    }

    /// Revoke a baseline (owner only). Sets a native, queryable flag; a correct
    /// verifier treats a revoked commitment as untrusted.
    pub fn revoke_baseline(ctx: Context<RevokeBaseline>) -> Result<()> {
        let c = &mut ctx.accounts.commitment;
        require_keys_eq!(c.owner, ctx.accounts.owner.key(), BaselineError::NotOwner);
        c.revoked = true;
        emit!(BaselineRevoked {
            owner: c.owner,
            baseline_hash: c.baseline_hash,
        });
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(baseline_hash: [u8; 32])]
pub struct CommitBaseline<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + BaselineCommitment::SIZE,
        seeds = [b"baseline", owner.key().as_ref(), baseline_hash.as_ref()],
        bump
    )]
    pub commitment: Account<'info, BaselineCommitment>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RevokeBaseline<'info> {
    #[account(
        mut,
        seeds = [b"baseline", owner.key().as_ref(), commitment.baseline_hash.as_ref()],
        bump = commitment.bump,
        has_one = owner @ BaselineError::NotOwner,
    )]
    pub commitment: Account<'info, BaselineCommitment>,
    pub owner: Signer<'info>,
}

#[account]
pub struct BaselineCommitment {
    pub owner: Pubkey,                  // 32
    pub baseline_hash: [u8; 32],        // 32  the commitment
    pub feature_schema_hash: [u8; 32],  // 32
    pub model_hash: [u8; 32],           // 32  hash of "signal:model:version"
    pub signal: u8,                     //  1  0=eeg 1=emg 2=hrv 3=eda 4=ppg 5=imu
    pub created_at: i64,                //  8
    pub valid_until: i64,               //  8  recalibration horizon
    pub revoked: bool,                  //  1
    pub bump: u8,                       //  1
}

impl BaselineCommitment {
    pub const SIZE: usize = 32 + 32 + 32 + 32 + 1 + 8 + 8 + 1 + 1;
}

#[event]
pub struct BaselineCommitted {
    pub owner: Pubkey,
    pub baseline_hash: [u8; 32],
    pub signal: u8,
}

#[event]
pub struct BaselineRevoked {
    pub owner: Pubkey,
    pub baseline_hash: [u8; 32],
}

#[error_code]
pub enum BaselineError {
    #[msg("Only the owner can revoke this baseline.")]
    NotOwner,
}
