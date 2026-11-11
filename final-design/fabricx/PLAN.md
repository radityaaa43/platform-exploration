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
- OUTCOME (d) TAKEN 2026-11-12 ~01:40 CST, orchestrator word "fabricx genesis C" (analyst's pre-decided branch, pre-data, found OFFLINE by fabric with the real tools on a throwaway-key block, nothing built or applied): an Idemix org in the genesis is incompatible with Channel capability V3_0 at the pinned versions; channelconfig bundle creation fails with `creating the MSP manager failed: Invalid *IdemixNewOpts. Version not recognized [4]` (fabric-x-common msp/factory.go:70-90 builds an Idemix MSP only for MSP versions 1.1/1.3/1.4.3; V3_0 selects MSPv3_0, common/capabilities/channel.go:88-91). Idemix + channel V2_0 passes the offline checks but was REJECTED (non-sample capability set for a feature with no proven committer acceptance); a newer fabric-x-common = upstream change, not allowed. GENESIS C: no Idemix org, Channel V3_0, explicit Signature policies Endorsement + LifecycleEndorsement `OutOf(3, org1..org4 .member)`, Admins `OutOf(3, org1..org4 .admin)`, majority PASS / single signer FAIL proven, token namespace policy OutOf(3), known_certs = the FSC endorser certs. DEVIATION kept: ids/anon + the FSC full-certificate patch stay; R1 for non-parties ALIGNED; the Idemix self-submit route = GAP. cfgupdate keeps `--idemix-org` off by default, documented as blocked at V3_0. No upstream post; the analyst sees this at the final evaluation.
- DECIDED (2026-11-12 ~00:05 CST, user-delegated decision via the analyst (pins committer v1.0.4 08a469d, Panurus v0.24.0 5f3c49e)): "S6 inline", the scratch channel is NOT run and NOT waived. (a) The S11 genesis carries ONE shared channel Idemix org (`IdemixOrgMSP`, upstream shape) plus each org's endorser certs in `known_certs` (from the B3-SAN final identities); NEVER one Idemix MSP per bank (the creator MSP id would reveal the bank: R1 regression). (b) Offline before bring-up: decode the genesis and assert Idemix MSP + known_certs + MAJORITY; run `cfgupdate check-genesis`. (c) First action after bring-up, before ANY issuance, migration or Lensa traffic: one transfer with no ids/anon and no FSC full-certificate patch. (d) Outcomes: pass = drop ids/anon + the patch (DELTA 5 done); transfer fails but the channel runs = keep ids/anon + patch, deviation recorded with the error quoted; channel will not start = pre-data re-genesis without Idemix on the orchestrator's word (new empty PVCs only). Idemix issuer lives in ns rd-fabricx-bi; the issuer can sign as any creator (inferred); a known_certs rotation has no proven update path.
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
- DECIDED (2026-11-12 ~00:05 CST, user-delegated decision via the analyst (pins committer v1.0.4 08a469d, Panurus v0.24.0 5f3c49e)): ADR 0003 = MAJORITY (3-of-4), accepted; BLOCKED flag lifted. Per-org admin identity `admin-<N>` (cert into the public tree `msp/admincerts/`, key as Secret `orderer-admin-<N>-secret`) and the majority admin keys transiently in /dev/shm for `check-genesis` are custody steps: text to the orchestrator before each write. The real S10 genesis (12cb53bc…, membership-only, never distributed) is superseded by ONE complete rebuild carrying S8 admins + MAJORITY + S6-inline Idemix/known_certs; new heads, new sha.
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
- ROLLOUT NOTE (2026-11-11 ~23:00 CST host clock, from the bi re-apply): a StatefulSet RollingUpdate never replaces a pod that has not become Ready, so a spec fix does not reach a crash-looping pod (currentRevision != updateRevision); the fix step is: apply the corrected spec, then delete the stuck pods by exact name on the orchestrator's word (the controller recreates them at updateRevision; PVCs untouched). First-apply render bugs found and fixed in rd-fabric-x #26 c2f9ad9: consenter CLI command is `consensus` (arma.go:30-58); the node local MSP needs the org's public admin cert mounted at /config/msp/admincerts/ (mspimplsetup.go:211); an offline smoke (multiorg/arma/smoke.py) now runs the pinned arma binaries on the rendered layout before any apply.
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
- Built and run (2026-11-12, rd-fabric-x #30-#34, repo-first, tests first): per-org core.yaml rewriter, `enroll_fsc.py` (24 client identities at the orgs' OWN CAs, Secret `rdbi-<pod>-files` per org, public fsc-exchange trees), render, own-only `import_central.py`; custody runs PASS x4 (enroll_fsc 16:17Z, import 16:34Z). The FSC pods are NOT applied yet.
- KNOWN GAP (accepted interim, orchestrator/user decision 2026-11-12): every bank/issuer pod holds a COPY of the shared `ids/anon` Idemix material (plus its own Idemix owner wallet and, for the issuer, the issuer wallet MSP) imported from the central `~/.fabricx-token` tree. Until S15 this is an accepted decentralization and R1 exposure: any one holder of an `rdbi-<pod>-files` Secret has the shared submitter material. It is recorded in `rdbi-<pod>-files` key names only (`own__<node>__ids__anon__...`); nothing else in any Secret is another org's key.
- Image (PROVENANCE): `ghcr.io/radityaaa43/rdbi-node@sha256:61b473e881b1b5f1bc37c3879bd453807255afcd1efa6d7d13d840b1e5ad6216` (tag ebbb28f1d552), pinned for ALL FSC pods and the init container. Built on the host (`make live-build live-image`, 2026-11-02 15:17), NO CI and NO SBOM/attestation = known gap. Source: LFDT-Panurus/panurus v0.24.0 @5f3c49e + the endorser-failover, sequential-remote-signatures and issuer-keeps-audit-tokens patches (and the dropped auditor-limits patch), fabric-smart-client v0.24.0 + `fsc-full-certificate.patch`, fabric-x-common v0.2.8, go 1.27.2. Live since 2026-11-03 in `fabricx` against committer 1.0.4 and orderer 1.0.4 (the same digests as the new stack). The older digest `sha256:71e3b678...` ran the bank nodes there and is NOT used.
- UNVERIFIED until the first FSC pod start (RUNBOOK-S13): pinned-cert P2P verification; FSC MSP loader without NodeOU config.yaml; the node dials the orderers by the genesis names; real core.yaml keys the template does not show; layout init as uid 10001.
- Rollback: delete the org's Deployments/Secrets in the new namespace.
- Sources: panurus@5f3c49e2:integration/token/fungible/topology/topology.go:164-186; fabric-x k8s.py:74-75,200-207; CURRENT.md section 9. FSC routing docs: not opened

### S14: Token namespace `rd_dfabi_v2`, public params, issuance
- DECIDED (2026-11-12 ~04:45 CST (orchestrator; user statement ~04:30: Lensa is the test UI for every platform)): NO seeded issuance by engineers. Only the namespace + public params step (policy OutOf(3, Org1..4MSP), 64-bit amounts, auditor list empty) runs under the standing GO after S13 + S16, with no amounts and no recipients written by us; issuance happens via Lensa in qa; the old balances do not carry over (README row 13). Seeded balances only if the user asks (amounts then come from the orchestrator).
- DELTA: 7 -> AFTER row: "OutOf(3, Org1..4MSP.member)"; "Public params: issuer BI, no auditors"
- Owner: fabric  Size: M
- Prerequisites: S13, S16
- Flags: CLUSTER-OP (live ledger write under flock; new channel only)
- Does: create the namespace with policy `OutOf(3, Org1..4MSP)` (`topology.go:84` form, 64-bit amounts via `rdbi/cmd/ppgen`, auditor list empty `ppgen/main.go:45`) as in-namespace Jobs under each org's OWN party-admin (state 2026-11-12: three endorse Jobs, one submit Job and read-back Jobs in `rd-fabricx-bi`, setup-pp Job in `rd-fabricx-bi`; every key-holding Job pod carries `rd/egress-locked=true` so its own NetworkPolicy is its only egress, R16/#53). NO issuance by us (DECIDED above): amounts and recipients are written only by Lensa in qa.
- RED proof: committer query-service client reads namespace policy: `OutOf(3,...)` (read back 2026-11-12 21:12Z: version 0, policy bytes = n_out_of 3 over org1..org4 member, no `IdemixOrgMSP`); a 2-of-4 update (BI + bank-c) is REJECTED (`ABORTED_SIGNATURE_INVALID`, 21:14Z); after setup-pp `balance` RD/DFABI through each gateway with the own cert = HTTP 200, balance 0 (nothing issued), another bank's cert rejected at TLS.
- Rollback: none once the namespace is committed on the new channel; discard the channel (S10 rollback).
- Sources: committer@08a469d:docs/namespace-policy.md:160-161; panurus@5f3c49e2:token/core/zkatdlog/nogh/v1/setup/setup.go:254-260,293-296; panurus-itest/README.md:19-24

### S15: Remove `ids/anon` and the FSC full-certificate patch
- DELTA: 5 -> AFTER row: "FSC `idemix` label then maps to it, dropping `ids/anon`"
- Owner: fabric  Size: M
- Prerequisites: S6 PASS, S14 (an S6 FAIL is a DEVIATION REQUEST to analyst; S15 does not run until it is answered; if the answer is "keep ids/anon", S15 becomes a decision record, the shared submitter key stays as an accepted gap against DELTA 5, and S20/S22 proceed)
- Flags: CLUSTER-OP (redeploys node pods)
- Does: remove `ids/anon` (README.md:118-121) from node configs and `patches/fsc-full-certificate.patch`; nodes use certificate-ID resolved from `known_certs`.
- RED proof: `ls ids/anon` in each pod: absent; `kubectl -n <ns> get secret rdbi-<node>-files -o json | jq -r '.data|keys[]' | grep -c anon` = 0 in every namespace incl. `rd-fabricx-bank-c` on cluster 2 (names only, inside the S15 window); the destruction record (date, namespace, operator) is in CURRENT.md; transfer confirmed; before: the patch applies in the image build and the key name is present.
- GATES for "100% done" (2026-11-12): (1) the DESTRUCTION RECORD of every EXTRA copy of the shared `ids/anon` material (the host copy and any copy outside the pods; date, namespace, operator) = a BLOCKER. Analyst audit 2026-11-12: `ids/anon` can never leave this channel, so S15 does NOT remove the one read-only copy each pod (`rdbi-<pod>-files`) must keep to run; the record says exactly that (known gap, see Audit records item 2); (2) the `fsc-full-certificate.patch` image is replaced by a CI rebuild from a pinned source commit: private ghcr, digest-pinned, SBOM + provenance attached in the PR, no key material in the image (the host-built `ebbb28f1d552` has none of that).
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

## Audit records (2026-11-12, analyst audit, binding; fabric's part)

1. **Idemix org at V3_0: ACCEPTED outcome, evidence.** An Idemix org in the genesis is incompatible with Channel capability V3_0 at the pinned versions: `creating the MSP manager failed: Invalid *IdemixNewOpts. Version not recognized [4]` (fabric-x-common `msp/factory.go:70-90`; table in `fabric-x/multiorg/cfgupdate/RUNBOOK-genesis.md:27`). Genesis C (sha256 `c9234227f2c753fee838817043d1ff9952ef95f4a197306436eacdb3d82e754d`, 83037 B) has capabilities Channel V3_0 / Orderer V2_0 / Application V2_5 and no Idemix org. `cfgupdate inspect` quotes the policies and the MSP ids (these are the source for every policy string): MSP names `org1`, `org2`, `org3`, `org4` (Application/org1..4: fabric MSP, admins=1, known_certs=1); `Application/Admins: OutOf(3, org1.admin, org2.admin, org3.admin, org4.admin)`; `Application/Endorsement: OutOf(3, org1.member, org2.member, org3.member, org4.member)`; `Application/LifecycleEndorsement: OutOf(3, org1.member, org2.member, org3.member, org4.member)`. C4 `check-admins` (offline, 3 admin keys read once, shredded): 3 admins `/Channel/Application/Admins ... satisfied=true`, `/Channel/Application/LifecycleEndorsement ... satisfied=true` ("PASS 3 admin(s) satisfy Application/Admins and LifecycleEndorsement"); 1 admin and 2 admins `satisfied=false` ("PASS ... do NOT satisfy the majority policies (as expected)"). Upstream question (Idemix org at V3_0 on committer 1.0.4) is NOTED for the user and NOT posted anywhere.
2. **`ids/anon` stays in the pods (accepted interim gap, S13/S15).** The shared channel-level submitter material cannot leave this channel. Each bank/issuer pod keeps ONE read-only copy; S15 destroys only the host copy and any extra copy outside the pods (destruction record: date, namespace, operator). Wording of S15 GATES (1) is corrected accordingly.
3. **Image pin.** The FSC/fxapi image stays on the host-built `ghcr.io/radityaaa43/rdbi-node@sha256:61b473e8…` (no SBOM, no provenance) until the S15 CI rebuild lands: workflow `rdbi-image.yml` (rd-fabric-x #40, manual run needs lead's word) with SBOM, `provenance: mode=max` and a signed attestation. The driver change D4 (#39) must be in main before that run so the new digest carries `peerFor`.
4. **One operator host knew all four fca admin passwords (B3 CA-interim).** DEVIATION accepted by the user at GO B3 (2026-11-11 ~20:00 CST: "accepted interim shortcut: one operator host, keys transient"). Handover step (before "100% done"): each org rotates its own fca admin/registrar password; the operator-host copy is destroyed with a record (date, org, operator). The identities `admin-<N>`, `endorser-<N>`, `committer-<N>` and every `<node>-fsc/-admin/-id` and the S16 `fx-gw-<N>`, `fx-gw-<N>-peer`, `<node>-gw` identities are PERMANENT at their CA (no CRL can be issued through `cfgupdate`; a rotation does not revoke them).

### S14 inputs read back from genesis C
Pinned images (live pods in rd-fabricx-bi run exactly these digests, read 2026-11-12 21:2xZ; the pull tests must include them): committer 1.0.4 `sha256:b5bc4c6c010f54843dfb023cb1f18f56d4cd9b958565efd243e20a0a35b5a13d`, orderer 1.0.4 `sha256:052ae8e16571d3d4de2e1a0c4e9ed0d979d782d3539d3c8fb1f7f66fe560e265` (both public docker.io, referenced by digest in the committer and arma renders).
Namespace policy string for `rd_dfabi_v2` (the RED check reads exactly this back from the committer query service): `OutOf(3, 'org1.member', 'org2.member', 'org3.member', 'org4.member')`, with `IdemixOrgMSP` absent. (The old `topology.go:84` string with `Org1MSP`... is the previous network's naming.) Negative proof: a namespace update with only 2 org signatures is rejected. Public params go in with `rdbi-driver setup-pp` (no gateway op exists for it, `main.go:363-366`): one-off `kubectl exec` into BI's `fx-gw-1` fxapi container with `public-params.bin` shipped in ConfigMap `fx-gw-1-client` (bi only); record sha256(public-params.bin) and read it back; DEVIATION from "no rdbi-driver anywhere" declared by lead, analyst ALIGNED with: the exec is its own window, ONE call, a failed call gets a new GO. Endorse ceremony: signers bank-c + BI + (A or B); each org signs with its own admin key in its own place; only the partially signed tx travels.

### S16 deviations declared (D1-D4), state 2026-11-12
D1 the gateway client-CA bundle holds the Lensa CA (`bank-gw-ca-<N>`) plus the 4 org TLS roots (rd-fabric-x #37); D2 ingress 8443 has no source list (mTLS + OPA are the control, as zeto `bank-gw-ingress`); D3 cluster-1 Lensa path = NodePort `fx-gw-<N>-ext` (eTP Cluster); D4 peer trust was SAN-only over a 4-root pool: CLOSED by the per-peer root pinning in the driver (`peerFor(M)`, rd-fabric-x #39), effective once the rebuilt image is deployed. Identity binding is in besu's rego (rd-besu #57): `fx-gw-<M>-peer` verified directly against org M's root (all 12 gateway certs verified direct-signed, 2026-11-12 18:05Z).

### S17 decision (user word "A", 2026-11-12)
No CronJob: the fxapi redeliverer (tick 60 s + startup pass, `redeliver.go`) replaces it; `reconcile.py` (rd-fabric-x #38) is the read-only per-org check; the proof (BI down, transfer, restart the bank's fxapi container while BI is still down, BI up, BI `records` has the txid) is a user-word window. Analyst: ALIGNED A. Reconcile credential: it needs `pods/exec` in `rd-fabricx-bi`, which `party-admin` lacks; analyst Q6: a BI Role bound to BI's own credential BEFORE the first run (a run with cluster-admin once = recorded deviation from condition 4). Limit found: RBAC `resourceNames` can name `committer-db-0` (StatefulSet pod, stable) but NOT the FSC pod (Deployment `rdbi-bi`, name changes at each rollout), so "exactly the 2 named pods" is only possible per rollout (re-apply the Role with the current pod name) or with `pods/exec` on the whole BI namespace; decision needed from analyst/lead before the Role is written.

## Open items
None. DELTA 3a (per-org MSP trees, armageddon limit) and DELTA 2a (decommission `fabricx`) were added by `analyst` in PR #40, merged to master as 7df112a; this plan cites them.

## DEVIATION REQUEST
None. (The drafter raised the public-ledger lens of S4; `lead` resolved it inside the AFTER row "ledger reads via the org's committer query service", see S4.)
