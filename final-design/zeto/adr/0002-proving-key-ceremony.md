# 0002. Zeto proving keys: test keys or a ceremony
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
The Paladin fork image ships the zeto v0.5.1 TEST proving keys (`zeto-test-proving-keys.tar.gz`, paladin fork domains/zeto/build.gradle:64-67, CURRENT.md section 3). zeto@v0.5.1 README.md:28 says deployment needs a ceremony or one trusted party. The analyst lists the keys as "from a ceremony" in the AFTER (ARCHITECTURE-zeto.md section 2, SHARED box) and as a hard limit "accept as PoC limit, or ceremony + verifier redeploy" (section 2 Hard limits). No objective in the user's list (validator, self-submit, third-party, R1-R3) depends on it; the risk is trust in Zeto proofs. A ceremony changes verifier contracts, so RD and DFABI must be redeployed (ARCHITECTURE DELTA 10).

## Decision
Left to the user. PLAN S12 stays BLOCKED(proving-key ceremony).

## Alternatives Considered
- Accept the test keys as a PoC limit. Pros: no redeploy, addresses and balances stay (CONTRACTS.md), zero cost. Cons: whoever holds the setup toxic waste could forge proofs; stated limit in every report.
- Multi-party ceremony, redeploy verifiers and tokens (cost L). Pros: removes the single-party trust. Cons: new verifier and token addresses, private balances are not carried (BI re-issues), Lensa `state/zeto.json` and the Zeto flows re-bootstrap, and the new keys must enter the Paladin image: a rebuild of the fork image, which the "no new custom code" rule may exclude [unverified], so it goes to `analyst` as a DEVIATION REQUEST first.

## Consequences
- Accepting keeps S12 closed with no change; the CONTRACTS.md row stays "test keys".
- A ceremony makes S12 the largest Zeto step and invalidates the Zeto parts of every cutover proof (S21) run before it: run S12 before S21 or repeat S21.
