# Blockchain operational notes

Live state and hazards that the next session must know. Keep each entry dated and short.

## Paladin (ns paladin), 2026-11-03

- **paladin-operator must stay at 0 replicas.** ConfigMap `paladin-operator` `paladin.image` still says rsfix
  (`ghcr.io/radityaaa43/paladin:main-zeto-v1-rsfix-1d600fc6f`). Scaling the operator to 1 makes it rewrite every
  StatefulSet from that string (operator v1.0.0 copies the image verbatim on each reconcile) and reverts node2/3/4 to rsfix.
  node1 is deliberately still on rsfix, pending the decision on its 7 old pending rows (10-21 bondCustodian spike, not Lensa).
- Image per node: node2/3/4 = `ghcr.io/radityaaa43/paladin@sha256:6f113f3829fefd7f954d3377935d7613ab78a90ba89c6af8e79159617b339f71`
  (prepfix2: the prepare-only dispatch no longer holds the epoch/step-down flush); node1 = rsfix.
- Ceiling with prepfix2: a prepare-only transaction (Zeto prepareSpendLock, any submitMode external) stays in the
  coordinator's memory until the pod restarts. About 500 (`maxInflightTransactions`) per (node, token contract) per pod
  lifetime; after that the node rejects new transactions for that token (PD012642) until a restart. Each Zeto DvP adds one
  on the seller's DFABI coordinator and one on the buyer's RD coordinator. Every restart or image rollout resets it.
- Restart rule: restart a Paladin node only when no node has an in-flight transaction. A node that resumes a transaction
  needing a remote verifier right after start can lose the ResolveVerifier response (PD030015, no retry); the transaction
  then stays `Resolving` and blocks later ones on the same contract.
