# 0003. Atom.cancel has no access control: which mitigation
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
`Atom.cancel()` has no access control (paladin@v1.0.0:solidity/contracts/shared/Atom.sol:102-107): any account can cancel an Atom before it executes. Any party may call `execute()` once approvals exist (doc-site/docs/architecture/atomic_interop.md:105-110). Today the Zeto DvP runs create, delegateLock and execute in one client process (besu@9890701:zeto/src/flows.ts:118-131), so the window is short. A bank-side client (ADR 0005) puts two actors between create and execute and widens the window. `RestrictedAtom` exists as a project contract (besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224); whether it works with Zeto `delegateLock` is not verified [unverified].

## Decision
Left to the user. PLAN S13 stays BLOCKED(Atom.cancel mitigation).

## Alternatives Considered
- Keep create, delegateLock, execute in one client step plus a fail-closed test (cost S). Pros: no new contract, no change on chain. Cons: a griefer can still cancel inside the window; the window grows with bank-side flows.
- `RestrictedAtom` for Zeto DvP (cost M). Pros: cancel restricted to the parties. Cons: a project contract, not upstream Paladin; needs a new factory address and Zeto compatibility proof [unverified].
- Accept the upstream limit and document it. Pros: no work. Cons: R3 holds for atomicity but not against a third party aborting a swap.

## Consequences
- The first option is the baseline for S21; the others change `AtomFactory` in CONTRACTS.md.
- If ADR 0005 picks bank-side clients, this ADR is re-read first.
