# fabricx: plan CURRENT -> AFTER
Skills used (loaded by `lead` with the Skill tool before the review; the drafter applied them as checklists): superpowers:writing-plans, ecc:plan, ecc:architecture-decision-records, ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), ecc:deployment-patterns (Lensa cutover/rollback). Not applicable: solidity-auditor, ecc:evm-token-decimals, web3-testing (no EVM; unit discipline applied in CONTRACTS.md).
Target: agents/analyst/design/ARCHITECTURE-fabricx.md (AFTER) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/fabricx/CURRENT.md @ 2026-11-11 08:20 UTC.
Namespaces: rd-fabricx-bi, rd-fabricx-bank-a, rd-fabricx-bank-b (cluster 1), rd-fabricx-bank-c (cluster 2, new only). Old: `fabricx` (+ host-side committer, `~/.fabricx-token`).
Pins: repo cites are `fabric-x@713fd0c` (local HEAD read now; CURRENT read 7bef424, line numbers re-checked only where marked), `frontend@28c8bdb` (local HEAD; analyst pin aa6e09b), others as in ARCHITECTURE-fabricx.md header.
Preserve (current behaviour, every step): Envoy route timeout 300 s (`fabric-x@713fd0c:panurus-itest/scripts/k8s.py:299`), ext_authz 3 s (:294), Lensa `GW_CALL_MS = 305_000`, `TX_DEADLINE_MS = 340_000` (`frontend@28c8bdb:server/src/adapters/fabricx.ts:27-28`), Lensa fabricx `txDeadlineMs` 745 s (`fabricx.ts:416`), `rdbi-driver` stays 0 replicas (never created in new namespaces).
Key fact for the order: any change of an Arma party address or any new CA/MSP means a new genesis (ARCHITECTURE 2a.2 item 1, DELTA 3), i.e. a NEW channel and ledger side by side with `fabricx`; balances are not carried (ADR 0001 Consequences).

## Order and dependencies
1. S1 (none)  2. S2 after S1  3. S3 (none)  4. S4 (none)  5. S6 after S1,S2  6. S7 after S2 (no cluster)  7. S8 after ADR 0003
8. S9 after S1,S2,S8,ADR 0001  9. S10 after S6,S8,S9  10. S11 after S10  11. S12 after S11  12. S13 after S12  13. S16 after S13 (+ zeto S17)
14. S14 after S13,S16  15. S15 after S6,S14  16. S17 after S16  17. S18 after S10,S13,S16  18. S19 after S4,S16,S18  19. S20 after S15,S17,S19
20. S21 after S20 and ADR 0002  21. S5 after S4,S20 (executes beside S22)  22. S22 after S5,S20,S21 (LAST)

## Steps
### S1: Per-org namespaces on cluster 1
- DELTA: 2 -> AFTER row: "Own namespace per org ... own kubeconfig and RBAC; template from multiregion patterns"
- Owner: fabric  Size: S
- Prerequisites: cluster-1 admin kubeconfig (exists, operator host); lead naming (rd-fabricx-*). The per-org kubeconfigs are an output of this step (ServiceAccount token per namespace), not an input. Cluster-2 sub-step needs the user-supplied <cluster-2 kubeconfig>.
- Flags: CLUSTER-OP
- Does: create ns `rd-fabricx-bi`, `-bank-a`, `-bank-b`; label `pod-security.kubernetes.io/enforce=restricted`; NetworkPolicy `default-deny-ingress` + `allow-dns-egress` + `allow-same-namespace`; ServiceAccount + namespace-scoped Role/RoleBinding per org. Pattern source: multiregion `default-deny-all`, PSS restricted, identity Secrets (ARCHITECTURE 2.4); whether multiregion also denies egress: [unverified], so egress stays open until S13. Cluster-2 sub-step: create ns `rd-fabricx-bank-c` ONLY (no workloads).
- RED proof: `kubectl get ns rd-fabricx-bi -o jsonpath='{.metadata.labels}'` before: NotFound; after: contains `"pod-security.kubernetes.io/enforce":"restricted"`; qa probe pod from `rd-fabricx-bank-a` to a test Service in `rd-fabricx-bi` times out (the probe pod is part of this CLUSTER-OP and is deleted at its end; the per-namespace ServiceAccount token is created inside the same CLUSTER-OP); cluster 2: `get ns rd-fabricx-bank-c` NotFound before, Active after.
- Rollback: `kubectl delete ns rd-fabricx-<x>` (empty at this point; user-only).
- Sources: CURRENT.md section 5 (CNI Terway ebpf enforces policy); https://kubernetes.io/docs/concepts/security/pod-security-standards/ [not opened]

### S2: Per-org manifest renderer (requests, digests, anti-affinity)
- DELTA: 2, 11 -> AFTER row: "template from multiregion patterns"; "images pinned at 1.0.4 by digest"
- Owner: fabric  Size: L
- Prerequisites: S1
- Flags: none
- Does: `panurus-itest/scripts/k8s.py:30` `NS = "fabricx"` and global `PODS` (:35-36) become per-org parameters; today usage is only `apply [replicas]`, `seed`, `gw render|apply N` (:17-23), so add a subcommand `render --org <party> --ns rd-fabricx-<party>` (render one org's objects into its own namespace); keep `resources.requests` on every container (:148-149); pin every image by digest (CURRENT section 3: three different rdbi-node builds today, unify node/endorser/gateway to one digest); add podAntiAffinity (`topologyKey kubernetes.io/hostname`) between pods of different orgs on cluster 1 and between the 4 roles of one party where nodes allow.
- RED proof: `python3 -I scripts/k8s.py render --org bank-a --ns rd-fabricx-bank-a | kubectl apply --dry-run=client -f -` exits 0; before: `k8s.py: error: unrecognized arguments`. Also `grep -c 'namespace: fabricx$'` on the render = `0`, `grep -c 'image:.*@sha256'` equals image count, a pytest asserts every container has requests.
- Rollback: `git revert` of the rd-fabric-x PR; nothing applied to a cluster.
- Sources: CURRENT.md sections 2-3, k8s.py:30,148-149; ARCHITECTURE 2a.3 (requests on every container)

### S3: Document namespace-policy rule k = N - F
- DELTA: 7 -> AFTER row: "OutOf(3, Org1..4MSP.member). Rule k = N - F = 2F+1"
- Owner: fabric  Size: S
- Prerequisites: none
- Flags: none
- Does: add the rule and its derivation (liveness k <= N-1, safety 2k-N >= F+1) to `panurus-itest/README.md` next to line 19; `panurus-itest/rdbi/topology.go:84` stays `OutOf(3, ...)`.
- RED proof: `grep -n 'k = N - F' panurus-itest/README.md` before: no hit; after: 1 hit; `grep -n 'OutOf(3' panurus-itest/rdbi/topology.go` still 1 hit.
- Rollback: `git revert` the docs commit.
- Sources: committer@08a469d:docs/namespace-policy.md:160-161,254-264; orderer@dd296e3:docs/architecture.md:182 (derivation is ours, labelled so in ARCHITECTURE 2.1)

### S4: Lensa Fabric-X adapter without kubectl/psql
- DELTA: 1 -> AFTER row: "Own client / kubeconfig ... no `kubectl exec`, no psql through another org's cluster"
- Owner: fe  Size: L (multi-day)
- Prerequisites: none (runs against the old namespace; gateway ops exist today)
- Flags: none
- Does: remove `kubectl` Exec path (`frontend@28c8bdb:server/src/adapters/fabricx.ts:86-102`), psql reads (:189, :321; :436 is only a description string), pod status (:399) and `FABRICX_KUBECONFIG` (:486); replace per-party reads with gateway ops `history`, `records`, `finality`, `balance` of each bank's `fx-gw-N`; replace the public-ledger lens (psql, :189) with a client of BI's committer query service (the AFTER row names it; `committer@08a469d:docs/query-service.md` [not opened, port/API unverified]; BI sees every row per R1, so the lens keeps its content); pod health (:399) becomes the gateway `usage` op or is dropped from the lens; keep :27-28 deadlines. `state/fabricx.json` loses `kubeconfig`, `namespace`. Lensa has no gRPC client for the committer query service, so the tx_status SQL at :189,:321 must be re-designed; whether the query service exposes tx history is [unverified]; if not: history via the `history` op of BI's own gateway. Lensa adapter code only; no Fabric-X, Panurus or Paladin change.
- RED proof: `grep -nE "kubectl|psql|FABRICX_KUBECONFIG" server/src/adapters/fabricx.ts` before: hits; after: 0 hits; fe tests for fabricx adapter pass; qa `records` lens shows the R1 views of CURRENT section 11 unchanged.
- Rollback: `git revert` PR, restart `lensa.service` (previous dist, deploy/update.sh rollback per LENSA.md 4.1).
- Sources: LENSA.md sections 1.4-1.5, 4.1; ARCHITECTURE DELTA 1; opa/DESIGN.md:43-45 (allowed ops)

### S5: Delete rdbi-driver and rdbi-driver-files in `fabricx`
- DELTA: 1 -> AFTER row: "no `rdbi-driver-files`-style Secret with all party keys"
- Owner: fabric  Size: S
- Prerequisites: S4 merged and live (Lensa no longer execs into `rdbi-driver`); S20 (executes beside S22, after the cutover proof; no new-stack check exists before it)
- Flags: user-only, CLUSTER-OP, destructive
- Does: first export Deployment `rdbi-driver` (0/0) to `<backup>/rdbi-driver.yaml`; then delete it and Secret `rdbi-driver-files` (view-client keys of every node) in ns `fabricx`. The Secret is unrecoverable unless exported first (export = read of Secret data = user-only).
- RED proof: `kubectl -n fabricx get secret rdbi-driver-files` before: found; after: `NotFound`; qa runs `balance` through Lensa for all four banks: all 200.
- Rollback: `kubectl apply -f <backup>/rdbi-driver.yaml` (not `k8s.py apply`, which re-applies all four institution pods, :244-251, and needs env `IMAGE`); the Secret only if exported before.
- Sources: CURRENT.md section 7, 10; opa/DESIGN.md:148-150

### S6: Scratch channel: Idemix MSP + known_certs
- DELTA: 5 -> AFTER row: "Channel config gains an Idemix MSP ... drops `ids/anon`" (UNVERIFIED live)
- Owner: fabric  Size: M
- Prerequisites: S1, S2; scratch namespace `rd-fabricx-scratch` on cluster 1 (needs orderer + committer + FSC pods)
- Flags: CLUSTER-OP
- Does: channel `"arma"` is hard-coded in `multiorg/cfgupdate/main.go:50`, `rdbi/cmd/driver/main.go:366` (SetupPublicParams) and `scripts/assemble.py:26`: make it a parameter in those 3 files (small project-code change). Then in `rd-fabricx-scratch` (created for this step, deleted at its end) build a minimal scratch channel (own genesis, NOT `arma`) with an Idemix MSP (configtx `MSPType: idemix`) and `FabricMSPConfig.known_certs`; run one transfer without `ids/anon` and without `patches/fsc-full-certificate.patch`. Outcome PASS/FAIL recorded in CURRENT.md; a FAIL is a DEVIATION REQUEST to analyst (ids/anon and the FSC patch stay until it is answered).
- RED proof: scratch transfer with certificate-ID, no patch: before `unknown certificate id` [expected text unverified]; after tx status `confirmed` in the scratch committer DB.
- Rollback: `kubectl delete ns rd-fabricx-scratch` (user-only).
- Sources: hyperledger.fabricx 0.8.26 roles/configtxgen/templates/configtx.yaml.j2:84-86; committer@08a469d:docs/namespace-policy.md:320-331, docs/verification-service.md:198-215,234; panurus@5f3c49e2:integration/token/fungible/topology/topology.go:51-53

### S7: Upstream PRs for accepted patches
- DELTA: 13 -> AFTER row: "Upstream PRs for accepted patches, no new code"
- Owner: fabric  Size: M
- Prerequisites: S2 (patch files stay in `panurus-itest/patches/`)
- Flags: user-only (posting to external repos)
- Does: prepare PR branches (not posted) for panurus-endorser-failover, panurus-sequential-remote-signatures, panurus-issuer-keeps-audit-tokens; fsc-full-certificate stays until S15; auditor-limits dropped. User posts.
- RED proof: `git apply --check` of each patch against upstream `main` of LFDT-Panurus/panurus: expect exit 0 (before the rebase: conflicts [unverified]).
- Rollback: close the PRs; patches in the repo unchanged.
- Sources: ARCHITECTURE DELTA 13; panurus-itest/README.md:113-141

### S8: Admin keys per org and lifecycle policy
- DELTA: 6 -> AFTER row: "Each org holds its own admin key; channel changes need a MAJORITY of org admins"
- Owner: fabric  Size: M
- Prerequisites: ADR 0003 (user)
- Flags: BLOCKED(lifecycle policy 4-of-4 vs MAJORITY), CLUSTER-OP (admin key Secrets per org)
- Does: per org admin key created in its namespace (S9); `multiorg/cfgupdate/main.go:123` `SignedByNOutOfGivenRole(len(allMSPIDs), ...)` set to the user's choice; `check-genesis` run with the 4 org admin MSPs separately.
- RED proof: `go run . check-genesis -block <new> -msp <org1-admin>` alone: `FAIL ... not satisfied by Org1 admin alone`; with a majority: `PASS`.
- Rollback: discard the unpublished genesis inputs.
- Sources: fabric-x@713fd0c:multiorg/cfgupdate/main.go:123,204-209; orderer@dd296e3:testutil/fabric/sampleconfig/configtx.yaml:227-229

### S9: Per-org CA, MSP, Arma and TLS keys in own namespace
- DELTA: 3a, 3 (and 2) -> AFTER row: "Own Arma party per org: org-generated keys, public material exchange"
- Owner: fabric  Size: L
- Prerequisites: S1, S2, S8, ADR 0001
- Flags: BLOCKED(orderer party placement X/Y), CLUSTER-OP
- Does: in each of `rd-fabricx-bi/-bank-a/-bank-b`: `fca-org<N>` (+db), Secrets `orderer-{router,batcher,consenter,assembler}-<N>-secret`, `fca-*`. Each org generates its own MSP tree in its namespace (`orderer@dd296e3:cmd/armageddon/README.md:284-285`; analyst DELTA 3a); the genesis assembler receives only public material. `generate` makes all parties' crypto in one run (README.md:32-51, :91), so if a tool step still needs BI to touch private material, that material is destroyed after handover and the step records it.
- RED proof: `kubectl -n rd-fabricx-bank-a get secret -o name` lists only Org2 names; `kubectl -n rd-fabricx-bank-a auth can-i get secret -n rd-fabricx-bi --as <bank-a SA>` = `no` (posts a SubjectAccessReview: inside the S9 CLUSTER-OP window); the record of any BI-touched private material shows it destroyed.
- Rollback: delete the new Secrets/CA objects in the new namespaces; `fabricx` untouched.
- Sources: orderer@dd296e3:cmd/armageddon/README.md:27-91,237-281; hyperledger.fabricx 0.8.26 examples/playbooks/20-generate-crypto.yaml (central)

### S10: New genesis block (channel config)
- DELTA: 3, 5 -> AFTER row: "Same genesis everywhere"; "Capabilities Channel V3_0, Orderer V2_0, Application V2_5"
- Owner: fabric  Size: M
- Prerequisites: S6 outcome (PASS, or FAIL with the analyst DEVIATION REQUEST answered), S8, S9 (its public-material exchange done by hand, out of band), ADR 0001
- Flags: BLOCKED(orderer party placement X/Y), user-only (new ledger), CLUSTER-OP (ConfigMaps)
- Does: build genesis from the public material: hosts/ports per ADR 0001, `V3_0/V2_0/V2_5`, Idemix MSP + `known_certs` if S6 PASS, lifecycle policy per S8, `UseTLSRouter/UseTLSAssembler` TLS; `check-genesis` PASS; `sha256` published to all orgs; create ConfigMap `genesis-block` in each namespace from the host-side block. Merging the per-org MSP trees into one baseDir for the assembler (DELTA 3a) is [unverified] on this tool version.
- RED proof: `go run . check-genesis -block <new> -msp <majority admins>` -> `PASS ValidateNewConfig LifecycleEndorsement`, `MSP 4`; `sha256sum` of the host-side genesis file (CURRENT section 8 method) equals the value published to all orgs, and the `genesis-block` ConfigMap content in each namespace hashes to the same value (no Secret data read).
- Rollback: discard; old genesis `b9c342d7...02769ab` still runs in `fabricx`.
- Sources: orderer@dd296e3:config/party_shared_config.go:11-68, docs/architecture.md:148-153,187; fabric-x multiorg/cfgupdate/main.go:132; CURRENT.md section 8

### S11: Arma party per org (cluster 1: parties 1-3)
- DELTA: 3 -> AFTER row: "One party (router, batcher, consenter, assembler) per org"
- Owner: fabric  Size: L
- Prerequisites: S10; free disk-attach slot read per node (`kubectl describe node | grep -c attached` or the CURRENT section 6 method) before apply, otherwise a node pool change = spend, user-only
- Flags: BLOCKED(orderer party placement X/Y), CLUSTER-OP
- Does: per org STS `orderer-{router,batcher,consenter,assembler}-<N>` (images `fabric-x-orderer:1.0.4` by digest, 2Gi PVC each, `alicloud-essd-wffc`, zone `ap-southeast-5b`), Services; cross-party ports open via NetworkPolicy (consenter BFT, batcher, router mTLS). Party 4 follows in S18. Disk-attach slots on cluster 1 are the risk (CURRENT section 6: 5/5 on one node).
- RED proof: `kubectl -n rd-fabricx-bi get sts -o wide` all `1/1`; orderer logs of party 1 show a leader with 3 parties up (N=4, F=1) [log line unverified].
- Rollback: `kubectl delete sts,cm,netpol -l app.kubernetes.io/part-of=rd-fabricx -n rd-fabricx-<x>` and the 4 PVCs by name (objects carry `app.kubernetes.io/part-of: rd-fabricx`, rd-fabric-x #23 5e103a7; Services belong to the S16 LB render) (new, empty ledger; user-only).
- Sources: orderer@dd296e3:docs/architecture.md:178-185; deployment/README.md:44-61

### S12: Committer per org
- DELTA: 4 -> AFTER row: "Own sidecar, coordinator, verifier, vc, query + DB ... reads blocks from the assembler of its own party"
- Owner: fabric  Size: M
- Prerequisites: S11
- Flags: CLUSTER-OP
- Does: per org namespace committer (sidecar `tls.mode: mtls`, `fault-tolerance-level: BFT`, own assembler, `latest-known-config-block-path`), Postgres `tls.mode: tls` + `ca-cert-path` (replaces `multiorg/committer/config/vc.yaml:19` no-TLS); BI committer-* stays shared-DB form only inside `rd-fabricx-bi`.
- RED proof: committer-vc log line reporting a TLS DB connection [log text unverified] or a committer query-service read (no `exec`; any `exec` check only inside the S12 CLUSTER-OP window); sidecar log block height equals the assembler height of party 2.
- Rollback: delete the committer objects in the new namespace (user-only).
- Sources: committer@08a469d:docs/tls-configurations.md:81-95,129-136, cmd/config/samples/sidecar.yaml:9-21,66-76, vc.yaml:62-67

### S13: FSC node + endorser per org, static P2P routing, key custody
- DELTA: 10, 1 -> AFTER row: "static P2P routing table lists the other orgs' addresses"; "keys only in this namespace's Secrets"
- Owner: fabric  Size: L
- Prerequisites: S12; free disk-attach slot per node (same check as S11: each `rdbi-<node>-state` PVC is one more attach)
- Flags: CLUSTER-OP
- Party credential (user decision via orchestrator 2026-11-11, aligned to the design: own account per institution, cluster-admin operator only, Lensa holds no kubeconfig): until this step the party operator gets short `kubectl create token party-admin` tokens re-issued per window (API-server cap 12 h); inside THIS step's CLUSTER-OP one bound token Secret `party-admin-token` (type `kubernetes.io/service-account-token`, annotation `kubernetes.io/service-account.name: party-admin`) is created per party namespace, delivered to that party's operator only (never the Lensa host, never chat), revocable by deleting the Secret. RED: `kubectl -n <ns> get secret party-admin-token -o name` NotFound before, present after; `auth can-i get secrets --as=system:serviceaccount:<ns>:party-admin` stays `no`.
- Does: Deployments `rdbi-bi`, `rdbi-bank2/3` forms in their org namespaces (Recreate, node + endorser + committer containers as `k8s.py:200-207`), Secret `rdbi-<node>-files` per org only; `k8s.py:74-75` rewrite of P2P to in-cluster names replaced by public per-org addresses (NodePort/LB); NetworkPolicy: FSC P2P ports ingress from the other orgs, FSC API ingress only from own `fx-gw`; egress default-deny now with explicit allows. No `rdbi-driver-files`. Interim custody: until S15 the shared `ids/anon` submitter key stays as it is today in each party's endorser Secret (`README.md:118-121`: one Org1MSP key held by every rdbi node), recorded here as the known shared-key gap; S15 (Idemix MSP) replaces it and every copy is destroyed and the destruction recorded.
- RED proof: `kubectl -n rd-fabricx-bank-a get secret -o name | grep -c driver-files` = `0`; the shared `ids/anon` key is still inside each org's `rdbi-<node>-files` Secret until S15 (key names inside a Secret are not read; the absence check `grep -c anon` moves to S15 RED); FSC logs show P2P links to the other 3 endorsers [log text unverified]; the 3-of-4 endorsement proof is in S14 RED (BI's gateway exists after S16).
- Rollback: delete the org's Deployments/Secrets in the new namespace.
- Sources: panurus@5f3c49e2:integration/token/fungible/topology/topology.go:164-186; fabric-x k8s.py:74-75,200-207; CURRENT.md section 9. FSC routing docs: not opened

### S14: Token namespace `rd_dfabi_v2`, public params, issuance
- DELTA: 7 -> AFTER row: "OutOf(3, Org1..4MSP.member)"; "Public params: issuer BI, no auditors"
- Owner: fabric  Size: M
- Prerequisites: S13, S16
- Flags: CLUSTER-OP (live ledger write under flock; new channel only)
- Does: create the namespace with policy `OutOf(3, Org1..4MSP)` (`topology.go:84` form, 64-bit amounts via `rdbi/cmd/ppgen`, auditor list empty `ppgen/main.go:45`); BI issues RD and DFABI-2027A through BI's own gateway `issue` op with BI's client cert (no `rdbi-driver` anywhere).
- RED proof: committer query-service client reads namespace policy: `OutOf(3,...)` (live name/MSPs not yet read in CURRENT section 13 item 1); `balance` RD through BI's gateway = issued total (the issue collected 3 of 4 endorsements).
- Rollback: none after issuance on the new channel; discard the channel (S10 rollback).
- Sources: committer@08a469d:docs/namespace-policy.md:160-161; panurus@5f3c49e2:token/core/zkatdlog/nogh/v1/setup/setup.go:254-260,293-296; panurus-itest/README.md:19-24

### S15: Remove `ids/anon` and the FSC full-certificate patch
- DELTA: 5 -> AFTER row: "FSC `idemix` label then maps to it, dropping `ids/anon`"
- Owner: fabric  Size: M
- Prerequisites: S6 PASS, S14 (an S6 FAIL is a DEVIATION REQUEST to analyst; S15 does not run until it is answered; if the answer is "keep ids/anon", S15 becomes a decision record, the shared submitter key stays as an accepted gap against DELTA 5, and S20/S22 proceed)
- Flags: CLUSTER-OP (redeploys node pods)
- Does: remove `ids/anon` (README.md:118-121) from node configs and `patches/fsc-full-certificate.patch`; nodes use certificate-ID resolved from `known_certs`.
- RED proof: `ls ids/anon` in each pod: absent; `kubectl -n <ns> get secret rdbi-<node>-files -o json | jq -r '.data|keys[]' | grep -c anon` = 0 in every namespace incl. `rd-fabricx-bank-c` on cluster 2 (names only, inside the S15 window); the destruction record (date, namespace, operator) is in CURRENT.md; transfer confirmed; before: the patch applies in the image build and the key name is present.
- Rollback: redeploy previous digest (S2 pin list).
- Sources: panurus-itest/README.md:115-121; committer@08a469d:docs/namespace-policy.md:320-331

### S16: Gateway + OPA + bundles per org
- DELTA: 9 -> AFTER row: "Own envoy + OPA + fxapi in the org's cluster; trusts only the org's client CA"
- Owner: fabric  Size: M
- Prerequisites: S13; zeto S17 (OPA bundles per party, per-org signed bundles)
- Flags: CLUSTER-OP
- Does: `fx-gw-<N>` (envoy `0.0.0.0:8443`, ext_authz 3 s `failure_mode_allow=False`, route 300 s) in each org namespace; per-org client CA Secret `fx-gw-<N>-mtls` (split from the single Lensa cert); OPA bundles `bundles.bi/bank.resource`, per-org signing key held by its owner (not Lensa host); netpol covers orderer/committer pods too; Service NodePort (cluster 1) or LoadBalancer (cluster 2), reachable only with a client cert.
- RED proof: read-only qa: `op balance` through `fx-gw-2` with Lensa cert: 200; with a cert of bank B: 403; `{"op":"records"}` returns 200 (R1 views are proven in S20).
- Rollback: delete `fx-gw-*` in the new namespace; Lensa still on old `fabricx` gateways.
- Sources: fabric-x opa/DESIGN.md:29-45,96-103; k8s.py:287-320; CURRENT.md section 10

### S17: Scheduled report per bank
- DELTA: 8 -> AFTER row: "scheduled `op: report` (empty TxID) per bank + reconcile"
- Owner: fabric  Size: S
- Prerequisites: S16
- Flags: CLUSTER-OP (CronJobs; the BI-down part is a user-only window)
- Does: CronJob `fx-report` in each bank namespace calling its own gateway `{"op":"report","txid":""}` (`report.go:36-48`, `serve.go:254-259` `deliver("")`; it answers `{"report":""}` with no per-tx outcomes, so the job cannot see BI refusals); `scripts/reconcile.py:15,22` replaced by per-org form (no cross-namespace `kubectl exec`); Lensa text "dikirim ulang nanti" (`fabricx.ts:290` region) matches the CronJob period.
- RED proof: not the empty-txid call: with BI down, send a real transfer, bring BI up, read the fxapi redelivery log line [text unverified] on bank A's `fx-gw` and BI `records` contains that txid.
- Rollback: delete the CronJob.
- Sources: ARCHITECTURE 2.3; iroha3-driver-fabricx-bi-down.md finding 1; fabric-x@713fd0c:panurus-itest/rdbi/cmd/driver `serve.go:254-259` (empty txid accepted)

### S18: Bank C Fabric-X on cluster 2 (new namespace)
- DELTA: 14 -> AFTER row: "ns-bank-c on cluster 2: party 4 move, committer, FSC node with public P2P routing, fx-gw, bundle source"
- Owner: fabric  Size: L
- Prerequisites: S10, S13, S16, ADR 0001, user-supplied cluster-2 kubeconfig
- Flags: BLOCKED(orderer party placement X/Y), CLUSTER-OP, spend (new pods)
- Does: ns `rd-fabricx-bank-c` already exists (S1 cluster-2 sub-step); these workloads are a second GO: party 4, committer, FSC + endorser-4, `fx-gw-4` (LoadBalancer behind mTLS), requests on every container; images 1.0.4 by digest; public endpoints for P2P/Arma. Never read or touch another cluster-2 namespace, incl. `fabricx-bank-c`. Schedule last (memory risk, ARCHITECTURE 2a.3).
- RED proof: read-only: `kubectl -n rd-fabricx-bank-c get pods` all Running; qa transfer bank A to C confirmed; BI-offline transfer still settles.
- Rollback: `kubectl delete ns rd-fabricx-bank-c` (only our namespace; user-only).
- Sources: ARCHITECTURE 2a.1-2a.4; orderer@dd296e3:config/reconfig.go:68,96; committer@08a469d:docs/sidecar.md:482-486

### S19: Lensa reaches the org gateways directly
- DELTA: 1, 9 -> AFTER row: "Lensa relay calls only the bank's gateway endpoint with that bank's client cert"
- Owner: fe  Size: M
- Prerequisites: S4, S16, S18
- Flags: CLUSTER-OP (host step; `lensa.service` restart is not covered by the lensa-pf standing approval)
- Does: Lensa calls each org's gateway at `https://<ip>:<port>` (NodePort on cluster 1 as today's router NodePorts, LoadBalancer on cluster 2, behind mTLS) with its per-org client cert from S16; remove `frontend/deploy/forwards.conf:20-23` (`fabricx-gw-N`), the `lensa-pf@fabricx-gw-*` entries in `lensa.service:3-4`, and `state/fabricx.json` `kubeconfig`/`namespace`; `besu-network.ts:20` no longer reuses the Fabric-X kubeconfig (Besu team item); no kubeconfig of any org on the Lensa host for Fabric-X.
- RED proof: `systemctl --user list-units 'lensa-pf@fabricx-*'` empty; `grep -c kubeconfig server/state/fabricx.json` = `0`; `/api/health` fabricx ok.
- Rollback: restore forwards.conf, `lensa.service`, state file from git/backup, `lensa.service` restart; old `fabricx` still running.
- Sources: LENSA.md sections 4.2, 6; ARCHITECTURE 2a.1 row "Lensa relay"

### S20: qa cutover proof
- DELTA: 1, 7, 10, 12 (acceptance) -> AFTER row: "R1, R2, R3 ALIGNED"
- Owner: qa  Size: M
- Prerequisites: S15, S17, S19
- Flags: CLUSTER-OP (test transfers are live ledger writes under flock; the rest read-only)
- Does: every flow (issue, award, transfer, swap DvP, redeem, balance, history, records, finality, report) via Lensa; R1 views as CURRENT section 11 (BI/sender/receiver see, outsider `{"records":[]}`); R2 with each single other party down and with BI down (latency within Envoy 300 s / `GW_CALL_MS` 305 s); R3 one tx two actions; BI-balance proof: sum of all four `balance` = BI issued total (new ledger, issued in S14).
- RED proof: qa script exits 0 on all flows; on `fabricx` the same script is the baseline (PASS today per CURRENT section 11).
- Rollback: Lensa pointers back (S19 rollback).
- Sources: CURRENT.md section 11; ARCHITECTURE 2.2

### S21: Retire multiregion namespaces
- DECIDED (2026-11-11 ~23:45 CST, user-delegated decision via the analyst (pins besu 26.8.1 d97cbd61, paladin v1.0.0 6d4b913)): `fabricx-bi`, `fabricx-bank-a`, `fabricx-bank-b`, `fabricx-bank-c` on cluster 1 are OUT OF SCOPE: another team's stack (KPID-poc / Rupiah-Digital-Eksplorasi platforms/fabric-x). No workload reads, no delete, removed from every list. This step is VOID. Old `fabricx` (ours): mode "bertahap": its 28 PVs patched to Retain 2026-11-11 (list in rd-fabric-x operator notes); named backup + restore test; delete only after the new stack passes VERIFY for Lensa (S22).
- DELTA: 12 -> AFTER row: "RETIRE as a stack, KEEP as pattern source"
- Owner: lead  Size: S
- Prerequisites: S20, ADR 0002 (user)
- Flags: BLOCKED(retire multiregion stack), user-only, CLUSTER-OP, destructive
- Does: cluster 1 only: ns `fabricx-bi`, `fabricx-bank-a`, `fabricx-bank-b`, `fabricx-bank-c` as listed by CURRENT section 1 on cluster 1 (creation history [unverified]; the user confirms in ADR 0002 that they are this project's). The cluster-2 namespace of the same name `fabricx-bank-c` is foreign and is never read, used or touched. Before any delete: inventory with read-only `kubectl get` (same kinds as S22) added to CURRENT.md, export `kubectl get all,secret,configmap,pvc,networkpolicy -n <ns> -o yaml` (Secrets by name only in the file) to the named backup, PV reclaimPolicy read and patched to Retain or snapshotted if Delete.
- RED proof: `kubectl get ns | grep -c '^fabricx-'` before: 4; after: 0 (cluster 1).
- Rollback: none after delete; restore = the named backup `fabricx-multiregion-final-2026-11-<dd>` (manifests export + PV snapshots) into new namespaces.
- Sources: ARCHITECTURE 2.4

### S22: Decommission `fabricx`
- DELTA: 2a (decommission addendum, analyst PR #40) -> AFTER row: "Own namespace per org ... move Secrets to the owning org"
- Owner: fabric  Size: M
- Prerequisites: S20 qa PASS on rd-fabricx-* for every flow + BI-balance proof; no pointer left (LENSA.md section 6 checks: forwards.conf 0 lines for `fabricx`, `lensa.service:3-4`, `state/fabricx.json`, `lensa.env`, `fabricx.ts:486`, `besu-network.ts:20`, `forwards.conf:20-23`, bundle-server NetworkPolicy namespaceSelector `fabricx` from rd-besu #9, `agents/ops/post-reboot-check.sh:8`, host-side committer `compose.yaml:38-41`, `scripts/assemble.py`, `reconcile.py:15,22`, `netshim.go:16-18`; CI none); named backup taken first; restore of one snapshot into a scratch PVC verified
- Flags: user-only, CLUSTER-OP (own approval then), destructive
- Does: (1) inventory = CURRENT.md section 14: deployments=20 statefulsets=24 pods=42 services=60 networkpolicies=4 persistentvolumeclaims=28 configmaps=41 secrets=51; PVC total 28 x 2Gi = 56Gi. (2) PV reclaimPolicy is `Delete` for all 28 (`alicloud-essd-wffc reclaim=Delete`): FIRST patch the 28 PVs to `Retain`, or copy; (3) backup `fabricx-final-2026-11-<dd>`: snapshot or export of the 16 `data-orderer-*-0`, `data-committer-sidecar-0`, `data-committer-db-0`, `rdbi-{bi,bank2,bank3,bank4}-state`, 5 `data-fca-*-db-0`, plus `~/.fabricx-token` (201M) archive. VolumeSnapshot is supported on cluster 1 (`kubectl get volumesnapshotclass` -> `alibabacloud-disk-snapshot diskplugin.csi.alibabacloud.com Delete 433d`) but its deletionPolicy is Delete: a surviving backup needs a Retain VolumeSnapshotClass (new cluster-scoped object = write, part of this CLUSTER-OP). (4) then `kubectl delete ns fabricx`. Scope cluster 1 only; cluster 2: nothing is ever deleted. Nothing executes now.
- RED proof: `kubectl get ns fabricx` -> `NotFound`; `kubectl get pv | grep -c fabricx` = backup PVs only; `/api/health` all models ok; `systemctl --user list-units 'lensa-pf@fabricx-*' --no-legend` -> empty (units removed in S19).
- Rollback: none after delete; restore from `fabricx-final-2026-11-<dd>` into a new namespace with the PVs set to Retain.
- Sources: CURRENT.md sections 6, 14; LENSA.md section 6

## Open items
None. DELTA 3a (per-org MSP trees, armageddon limit) and DELTA 2a (decommission `fabricx`) were added by `analyst` in PR #40, merged to master as 7df112a; this plan cites them.

## DEVIATION REQUEST
None. (The drafter raised the public-ledger lens of S4; `lead` resolved it inside the AFTER row "ledger reads via the org's committer query service", see S4.)
