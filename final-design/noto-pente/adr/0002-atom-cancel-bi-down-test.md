# 0002. Live test of Atom.cancel while BI's node is down
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
`RestrictedAtom.cancel()` may be called by the executor or by a trade party (`besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224`); `execute()` only by the executor (:150-155). Upstream `Atom.cancel` is open to anyone (`paladin@v1.0.0:solidity/contracts/shared/Atom.sol:102-107`). Locks delegated to an Atom finish without the notary, but preparing and delegating a lock needs the notary (`doc-site/docs/architecture/noto.md:597`). BI's node is the notary of both tokens, so BI offline stops all Noto operations (R2 exempt, `noto.md:569,580`). Whether a party can still cancel an atom whose legs are already delegated while BI's node is down was never tested (ARCHITECTURE-noto-pente.md section 1, row "BI down"; DELTA 7). The test needs a write on the live network: a throwaway atom and a bounded outage of BI's Paladin node, which stops Noto, Pente and also Zeto and Stealth because the node is shared. Decision needed from the user because it is an outage with side effects.

## Decision
Left to the user. PLAN.md step S14 stays BLOCKED(Atom.cancel BI-down test) until one option is chosen.

## Alternatives Considered
- A. Run the test after cutover on the new network: throwaway atom, scale BI's Paladin node to 0 for a fixed window, `cancel()` as a bank, scale back. Pros: real answer on the real stack. Cons: all domains on that node stop during the window (shared node with zeto and stealth); needs an agreed time and the CLUSTER-OP approval. Why not default: outage of other tracks.
- B. Same test but block only traffic to BI's Paladin RPC and gRPC with a temporary NetworkPolicy, leaving the node running. Pros: no restart, shorter rollback. Cons: not identical to a crash (node still holds its DB and keeps its connections to Besu); may overstate or understate the effect. Why not default: weaker evidence.
- C. Do not test; record "cancel with BI down: unknown" and keep R2 exempt for Noto. Pros: no outage. Cons: a stuck delegated lock during a BI outage stays an unquantified risk for DvP.

## Consequences
- A or B: S14 runs once after S13 passes; its report is added to the final-design record and to `architecture-brief.md` section 8.4 of rd-besu.
- C: S14 is closed as "not tested, accepted"; no cluster action.
- Either way the notary stays BI (upstream requirement) and no code is changed.
