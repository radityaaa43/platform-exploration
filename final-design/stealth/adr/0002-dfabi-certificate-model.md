# 0002. DFABI certificate model: one signer, several signers, or no certificate
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
Every `transferByPartitionStealth` needs a certificate from a registered signer (`docs/architecture-brief.md:456-461`; `besu@9890701:stealth-address/ts/chain.ts:46-49`). The signer must be online at bond transfer, bond funding of an escrow and `DvPFactory.create`; it is not needed for RD transfer, `settle()` and `cancel()` because the escrow stores its certificates (ARCHITECTURE-stealth.md hard limit 4). The matrix scores R2 as GAP (DFABI certificate): R2 says no transfer function may need BI online. This is DELTA 4 (custodian split, R2 GAP moves) in ARCHITECTURE-stealth.md; the AFTER has no separate numbered certificate-model item. Moving the signer off BI moves the mandatory third party and does not remove it. The AFTER lists two validator settings that would remove it and also remove control: several signers, or `registerTokenSetup` with `CertificateValidation.None` (then the allowlist, which holds only the custodian, blocks every stealth recipient, `ERC1400TokensValidator.sol:394-432` via ARCHITECTURE; allowlist off gives an open token).

## Decision
Left to the user. PLAN S13 stays BLOCKED(DFABI certificate model). The default plan keeps one online signer and records R2 as a documented GAP for DFABI (RD, settle and cancel pass the R2 test).

## Alternatives Considered
- (a) One certificate signer (the custodian). Pros: today's behaviour, BI or the custodian controls who may hold DFABI, no contract change. Cons: R2 GAP stays; DFABI stops when that signer is down; the signer sees every DFABI transfer request.
- (b) Several signers (each bank is a signer). Pros: no single online dependency; DFABI works while BI is down. Cons: any signer can certify any transfer, so the control the certificate gives (who may hold DFABI) is gone; BI loses the gate.
- (c) `CertificateValidation.None` with the allowlist off. Pros: no online party at all. Cons: an open token, anyone may receive DFABI; no investor gate. Why not: removes the purpose of the certificate (KYC gate).

## Consequences
- (a): no change; R2 is reported as GAP with citation, not as ACCEPTED, until the user records an exemption.
- (b): S13 adds `addCertificateSigner` per bank and a policy outside the chain; analyst re-scores R2.
- (c): a validator reconfiguration and a legal review; not reversible for tokens already moved.
