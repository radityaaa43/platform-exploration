# 0001. Stealth custodian party: BI or another party
Date: 2026-11-11
Status: accepted (user decision 2026-11-11, via orchestrator)
Deciders: user

## Context
One account today is issuer, DFABI owner, controller and minter, certificate signer, `DvPFactory` custodian and `InstrumentRegistry` owner (CURRENT.md sections 2 and 10). The AFTER says the custodian is not required to be BI; the roles that move are bond `owner`, minter, controllers, certificate signer and `DvPFactory.custodian_` (immutable, so a new factory instance; ARCHITECTURE-stealth.md section 2, DELTA 4; `besu@9890701:stealth-address/src/DvPFactory.sol:14-18,30-31`). The project brief gives the custodian every bank's view key (`docs/architecture-brief.md:59`). R1 says only BI, sender and receiver see a transaction, so a custodian that is not BI is a fourth viewer (hard limit 3). The custodian is also the online certificate signer for every DFABI transfer (hard limit 4, `architecture-brief.md:461`).

## Decision
The DFABI cert-issuer custodian = BI (DELTA 4 decided). Accepted limit: the stealth spend key sits raw in the signer process memory (spend key + h), so Vault/HSM transit cannot hold it; Vault protects it at rest only (ARCHITECTURE-stealth :137, hard limit 6). PLAN S12 unblocked; S15 may follow.

## Alternatives Considered
- (a) Custodian = BI party, with its own key separate from the RD issuer key. Pros: no fourth viewer, R1 unchanged, no new namespace; the third party stays BI, as in R2's current GAP. Cons: BI keeps force-transfer power (`isControllable` true) and certificate control; DFABI stays unavailable while the BI certificate signer is down. Why not: only if the user wants the custodian independent of BI.
- (b) Custodian = another party with the bank view keys. Pros: separates BI (regulator, RD issuer) from the DFABI custodian; matches the brief's custodian actor. Cons: a fourth viewer of every bank's receipts (R1 breach per hard limit 3); one more namespace (`rd-stealth-<custodian>`) and cross-party certificate path; a new mandatory third party that is not BI. Why not: needs an R1 exemption from the user.
- (c) Custodian without view keys. Pros: no extra viewer. Cons: it sees only public data and the certificate request; checking the receiver's KYC then needs the sender to disclose the ephemeral key, which is a new protocol not in project code and not in EIP-5564. Why not: blocked by the no-custom-code rule unless the user accepts new code.

## Consequences
- Any option: chain objects keep their addresses except `DvPFactory` (new instance); RD is untouched.
- (a): S12 is a key split inside BI's store; the custodian signer runs in `rd-stealth-bi`.
- (b): a new namespace and gateway for the custodian party; the plan gains a namespace step and a view-key handover per bank to a second holder.
- (c): S12 plus a design for sender disclosure; goes to `analyst` first.
