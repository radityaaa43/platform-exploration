# 0001. Registry root owner: rootless registry or BI-signed registrations
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
The Paladin registry `evm-registry` (`0x99f3326e...7874`) is an `IdentityRegistry` whose root identity owner is `0xf404...A11b`, the key `registry.operator` held by BI's node1 (CURRENT.md section 4). A `rootless` registry lets any sender register a root child; otherwise only the root owner can (`paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,67-72`). A `PaladinRegistration` CR resolves `registryAdminNode`, `node` and the `PaladinRegistry` CR in its own namespace (`operator/internal/controller/paladinregistration_controller.go:107,137,238,256`), and the operator is namespace-scoped (`operator/cmd/main.go:98,108,211-221`). With one namespace per bank, a bank namespace cannot publish or update its own node entry without BI's registry key (ARCHITECTURE-noto-pente.md 2a "Cross-cluster limits"; an upstream split flow was not found). Every certificate or hostname change forces a registry update (`doc-site/docs/administration/certificate_management.md:27-35,99`), so this affects objectives (b) self-submit and (c) third-party. The same decision applies to the zeto plan (same number and slug there).

## Decision
Left to the user. PLAN.md step S5 stays BLOCKED(registry rootless) until one option is chosen.

## Alternatives Considered
- A. Deploy a rootless registry and re-register the four nodes. Pros: each bank signs its own entry with its own key; no BI key in bank namespaces. Cons: new contract address in every `PaladinRegistry` CR; four re-registrations; any sender can register a root name (name squatting, mitigated only by node-level mTLS and `directCertVerification`); whether a deployed registry can be switched to rootless is [unverified]. Why not default: changes a shared trust root during the move.
- B. Keep the non-rootless `evm-registry`; BI's key signs every bank registration and update. Pros: no new contract, root names stay under BI control. Cons: BI is in the path of every bank endpoint or certificate change, which weakens (b) and (c); BI's registry key must reach a flow outside the bank namespace; no documented cross-namespace procedure. Why not default: leaves a third-party dependency for every bank change.
- C. Keep non-rootless and move root ownership to a different BI-held key (outside node1). Pros: separates the registry key from node1's HD seed. Cons: still one owner, banks still cannot self-register; transfer function in `IdentityRegistry` [unverified]. Why not default: does not reach the self-submit goal alone.

## Consequences
- Option A: S5 deploys the registry (CLUSTER-OP), all four nodes re-register, bank C's registration on cluster 2 needs no BI key. Noto/Pente factories and tokens are untouched.
- Option B or C: bank registrations and cert renewals queue behind BI; the zeto plan's transport steps carry the same dependency.
- Steps S5 and the registration part of Z-TRANSPORT stay BLOCKED until this is decided; S7 needs the registry to be usable.
