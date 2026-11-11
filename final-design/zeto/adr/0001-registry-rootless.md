# 0001. Paladin registry ownership: BI root key or rootless
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
The live registry `evm-registry` (`0x99f3326e…7874`) was deployed with `rootless=false`; its root owner is the BI operator key (CURRENT.md section 4). `registerIdentity` needs the parent owner (root) or the max-address owner of a rootless registry (paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,67-72). The operator `PaladinRegistration` resolves `registryAdminNode` and the `PaladinRegistry` CR in its own namespace (operator/internal/controller/paladinregistration_controller.go:107,137), so with a non-rootless registry a bank namespace cannot register or republish without BI's key in that namespace. The 4 node identities already exist, so re-registration reverts "Name already taken" (IdentityRegistry.sol:67-72); only the node owner can change its own transport property (setIdentityProperty, :105-107). Moving each node to its own namespace and cluster (PLAN S9-S11) changes every published endpoint. Child identity owner is chosen at registration, so each bank can already own its node identity.

## Decision
Left to the user. PLAN S11 stays BLOCKED(registry rootless) until one option is chosen; S10 (endpoints) is not blocked.

## Alternatives Considered
- (a) Keep the registry, BI stays root owner (cost M). Pros: no new contract, no change to Noto/Pente registrations, same address. Cons: BI's registry key is needed once per new node identity; republish of existing identities needs a node-key `setIdentityProperty` call and a way to trigger it without custom code is not found upstream; BI remains a third party for bank onboarding.
- (b) New rootless registry (cost L, constructor arg `true`, a new deployment). Pros: any bank registers under root with its own CR in its own namespace, no BI key outside BI. Cons: new registry address in every `PaladinRegistry` CR, four registrations redone, noto-pente depends on the same registry; names are first come, first served (unique-name check, IdentityRegistry.sol:67-80), so a squatted name is permanent.

## Consequences
- Either option: the Zeto chain objects (tokens, factory) do not change.
- (a): S11 is a republish by node owners; BI stays in the onboarding path for bank C.
- (b): the same decision applies to noto-pente (shared registry); `PaladinRegistration` CRs of all four nodes are re-applied, and a short window exists where peers resolve no endpoint.
