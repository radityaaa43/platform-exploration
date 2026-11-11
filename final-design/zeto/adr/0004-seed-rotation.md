# 0004. Seeds moved into party custody: copy or rotate
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
The HD seeds of every Paladin identity sit in Secrets `node1..4.keys` of one namespace under one admin kubeconfig (CURRENT.md section 2). They derive the Zeto owner keys (BabyJubJub, `owners.{BI,A,B,C}`) and BI's token, factory and registry owner keys (CURRENT.md sections 4-6, 11). The AFTER requires keys created and kept only in each bank's namespace (ARCHITECTURE DELTA 1); it states that a seed already in a shared Secret cannot be proven private, so moving it is a trust reset, not a copy, and rotation is optional.

## Decision
Left to the user. PLAN S6 (copy) proceeds under the user's go; S7 stays BLOCKED(Zeto seed rotation).

## Alternatives Considered
- Move the existing seeds (cost M, PLAN S6 only). Pros: identities, token owners and balances stay; no token migration. Cons: the old shared copies stay a possible exposure until deleted at S22; BI owner key history is not provable private.
- Rotate all seeds (cost L, PLAN S7). Pros: clean custody; old copies are worthless. Cons: new owner keys, so every holder moves UTXOs to its new key by Zeto transfers (about 18 TPS ceiling, CPU bound), BI re-owns RD, DFABI and the factory (owner change path [unverified]), registry child owners change (ADR 0001), and a mistake loses funds.
- Rotate only the bank seeds, keep BI's (cost M-L). Pros: BI's contract ownership is untouched. Cons: BI keys stay in the exposed state; half measure.

## Consequences
- Copy: S22 must delete the old Secrets `node1..4.keys`; the exposure window ends only then.
- Rotate: S7 runs before S21; CONTRACTS.md owner rows change; balances are verified party by party.
- Rotation needs NEW Paladin node names: registry entries are owned by the old `registry.nodeN` key, `IdentityRegistry` has no owner transfer and `setIdentityProperty` requires strict owner equality (IdentityRegistry.sol:108), so the old key cannot republish; PLAN S7 inherits this and "node1..4 preserved" breaks.
- Custody (README decision 25): the cluster-1 cluster-admin kubeconfig stays with the platform operator (the user) only, mode 600, never on the Lensa host; per-party credentials are namespace-scoped ServiceAccount tokens (PLAN S1). The cluster operator stays a trusted party for Secrets at rest (Kubernetes limit). Secrets encryption at rest on cluster 1 is an optional user-only cluster-config step; cluster 2 is not ours to configure.
