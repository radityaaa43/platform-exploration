# Blockchain operational notes

Live state and hazards that the next session must know. Keep each entry dated and short.

## Paladin (ns paladin), updated 2026-11-03 04:10Z

1. **OPEN: paladin-operator must stay at 0 replicas until S8.** All 4 StatefulSets now run the digest
   `ghcr.io/radityaaa43/paladin@sha256:6f113f3829fefd7f954d3377935d7613ab78a90ba89c6af8e79159617b339f71`, but ConfigMap
   `paladin-operator` `paladin.image` still says `ghcr.io/radityaaa43/paladin:main-zeto-v1-rsfix-1d600fc6f`. Scaling the
   operator to 1 makes it rewrite every StatefulSet from that string (operator v1.0.0 copies the image verbatim on each
   reconcile) and rolls all 4 nodes back to rsfix.
   S8 (recommended, not approved yet): (a) drift proof per node: md5(cm/paladin-nodeN data.pldconf.paladin.yaml) ==
   STS annotation core.paladin.io/config-sum, Paladin CR generation 7, svc/pdb/CR spec hashes unchanged (baseline in
   besu/zeto/out/stuck-tx-backup-20261103T040501Z/P0-evidence.txt); (b) back up the CM; (c) patch only
   data.config.json with paladin.image = the digest, byte-identical to the 4 STS strings, and prove that the parsed diff
   is that one path; (d) scale the operator to 1; (e) 5 min: same pod uids and restart counts, STS images unchanged,
   no "Updated Paladin StatefulSet" in the operator log. Rollback: scale the operator to 0 first.
2. RESOLVED 2026-11-03: mixed fleet. node1 moved to the digest at 04:05Z (node2/3/4 earlier), so all 4 nodes run prepfix2.
3. Ceiling with prepfix2: a prepare-only transaction (Zeto prepareSpendLock, any submitMode external) stays in the
   coordinator's memory until the pod restarts. About 500 (`maxInflightTransactions`) per (node, token contract) per pod
   lifetime; after that the node rejects new transactions for that token (PD012642) until a restart. Each Zeto DvP adds one
   on the seller's DFABI coordinator and one on the buyer's RD coordinator. Every restart or image rollout resets it.
4. RESOLVED 2026-11-03: node1's 7 old spike rows (6 external spendLock + createLock 66f4043e, bondCustodian@node1,
   10-21) were backed up to besu/zeto/out/stuck-tx-backup-20261103T040501Z/ (gitignored) and deleted (6/6/7, history
   cascade). Restore only with a new GO.
5. Restart rule: restart a Paladin node only when no node has an in-flight transaction. A node that resumes a transaction
   needing a remote verifier right after start can lose the ResolveVerifier response (PD030015, no retry); the transaction
   then stays `Resolving` and blocks later ones on the same contract.

## Parked ideas

- (none yet)
