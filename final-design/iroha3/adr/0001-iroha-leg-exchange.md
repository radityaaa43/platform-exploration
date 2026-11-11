# 0001. Iroha 3 leg exchange for per-bank proving

Date: 2026-11-11
Status: proposed
Deciders: user

## Context
Objective (b), self-submit per bank, needs each bank to prove its own leg of a two-leg DvP with its own keys. Upstream routes allow different authorities to upload legs (spec `:547-548`), but the library takes all legs in one call and rejects a differing manifest (`iroha@071e281e crates/iroha/src/client/private_settlement.rs:2527-2557`). A prepared leg is "a native client-side construction value rather than wire object" (`crates/iroha_core/src/privacy_engines/atomic_private_settlement/wallet.rs:139-148,222-228`). The witness stays in an owner-only wallet file (`wallet.rs:1-8`). The spec has no protocol for passing legs or authorizations between clients (`specs/private_settlement.md:444-447`; grep for witness, multi-party, exchange, interactive, assemble: not found). Our driver does everything in one process (`iroha3-rd-node-build@ceccc4d driver/src/aps.rs:1283-1289`). Even `pay` is two-party today: the companion leg is BI to BI (`NOTES.md:44`). Plan step: S17 (also limits S9 and S10).

## Decision
Left to the user. Not decided by the drafter.

## Alternatives Considered
1. Build a leg-exchange transport (skeleton manifest out; recipient view-key authorization and sponsor authorization in; the four prepared-leg fields to an assembler).
   - Pros: full self-submit; no bank key leaves its namespace.
   - Cons: not in upstream; new custom code (size L); assembler needs the prepared-leg fields that upstream does not expose as wire objects.
   - Why not (default): the team rule is no custom code beyond what exists; needs the user to lift it for this item.
2. Accept the limit: BI keeps the companion and settlement leg; banks self-submit only what one key can sign.
   - Pros: no code; matches upstream today.
   - Cons: objective (b) is GAP for DvP; BI stays on the path.
   - Why not (default): leaves objective (b) open; acceptable only if the user records it as an accepted limit.

## Consequences
- Option 1 adds a custom component to maintain and audit, and moves S9/S10 from partial to complete.
- Option 2 leaves other parties' seeds in the initiating process (the single-driver design); S9 and S10 deliver only the partial outcome of DELTA 1b and 4.
- Until decided, S17 stays BLOCKED and the analyst matrix keeps self-submit as GAP (blocker) for Iroha 3.
