# 0002. Retire the multiregion namespaces (fabricx-bi, fabricx-bank-a/b/c)
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
Namespaces `fabricx-bi`, `fabricx-bank-a`, `fabricx-bank-b`, `fabricx-bank-c` exist (CURRENT.md section 1; not read inside by the study). The analyst read them live: label `part-of=fabricx-multiregion`, PSS `restricted`, `default-deny-all` plus `token-*-access-v2` netpols, per org a committer pod and an orderer pod, `token-endorser-v2`, `token-owner-v2`, BI also `token-issuer-v2`, `token-auditor-v2`, `console-web`; bank-c has Services and `default-deny-all` only (ARCHITECTURE 2.4). Lensa does not use them (LENSA.md section 6; `opa/DESIGN.md:18-20` is stale, see CURRENT.md section 12). No repo manifests exist; digests are unpinned; the `*-v2` token app has an auditor, which contradicts the R2 choice. CURRENT.md lists all four on cluster 1; the lead's brief names `fabricx-bank-c` as a cluster-2 namespace: [unverified] which cluster holds it. Cluster-2 namespaces are foreign and are never touched by this project.

## Decision
Left to the user.

## Alternatives Considered
- Retire the stack, keep it as pattern source (analyst recommendation). Pros: frees pods, PVC slots and memory on cluster 1; removes a stack with an auditor that contradicts R2. Cons: destructive; no manifests, so it cannot be recreated; its creator and purpose are unknown [unverified].
- Keep as is. Pros: nothing destroyed. Cons: capacity held (disk-attach slots are the cluster-1 limit, CURRENT section 6); an unpinned, unowned stack beside the target; confuses "which Fabric-X is the system".
- Keep only part (for example `fabricx-bank-c` placeholder removed, rest kept). Pros: smaller delete. Cons: half a stack serves nothing; the hanging bank-c is an incomplete deployment.
- Snapshot first, then retire. Pros: partial rollback via PVC/export. Cons: needs inventory by names of 4 namespaces first; PV reclaim policy unknown [unverified].

## Consequences
- PLAN S21 runs only after S20 (qa cutover) and this decision; it is not part of S22 (Decommission `fabricx`).
- Decided "retire": deletion is irreversible without a snapshot; the user names who may approve it (CLUSTER-OP).
- Decided "keep": capacity assumptions of PLAN S11/S18 must be re-checked.
