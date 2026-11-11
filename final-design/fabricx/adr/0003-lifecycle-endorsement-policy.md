# 0003. LifecycleEndorsement policy: 4-of-4 or MAJORITY
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
Namespace and config lifecycle uses a channel-level ImplicitMeta policy. Ours is 4-of-4 (`SignedByNOutOfGivenRole(len(allMSPIDs), MEMBER, ...)`, fabric-x@713fd0c:multiorg/cfgupdate/main.go:123); the upstream sample uses `MAJORITY Endorsement` (orderer@dd296e3:testutil/fabric/sampleconfig/configtx.yaml:227-229; committer@08a469d:docs/namespace-policy.md:283-289). With 4-of-4 one org down blocks lifecycle changes (not transfers). `/Channel/Application/Admins` needs 3 of 4 (main.go:204-209). Each org will hold its own admin key (DELTA 6); channel changes need a majority of org admins, checked offline by `check-genesis` (CURRENT.md section 8). Whether org-level `mod_policy` per org works in Fabric-X is UNVERIFIED (ARCHITECTURE 2.1). The policy is written into the new genesis (PLAN S8, S10); changing it later needs a config update, and the official route is re-genesis.

## Decision
Left to the user.

## Alternatives Considered
- Keep 4-of-4. Pros: every org must agree to add or change a namespace; strongest per-org veto; matches today's live genesis. Cons: one org offline blocks lifecycle (a new token namespace), liveness lower than the transfer path (3-of-4).
- MAJORITY Endorsement (upstream sample). Pros: matches upstream sample and the 3-of-4 transfer rule; one org down does not block lifecycle. Cons: three orgs can add a namespace without the fourth; weaker veto for a small bank.
- Explicit N-of-M with M=3 (same as MAJORITY at N=4). Pros: explicit in the config. Cons: must be edited when N changes; derivation is ours, not upstream's.

## Consequences
- PLAN S8 stays BLOCKED until decided; S10 (genesis) cannot be built before.
- The choice changes the offline `check-genesis` expectation (PLAN S8 RED proof).
- Re-opening it after genesis needs a new channel (re-genesis route).
