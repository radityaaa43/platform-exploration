# stealth: plan CURRENT -> AFTER
Skills used (applied by the drafter as checklists, not loaded as tool calls): superpowers:writing-plans, ecc:architecture-decision-records (adr/0001-0004), ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), ecc:evm-token-decimals (S6, CONTRACTS), solidity-auditor (inventory only, no audit run), ecc:deployment-patterns (S20 cutover and rollback), ecc:code-explorer (path:line reads, by hand), web3-testing (S8 test list, checklist only).
Target: agents/analyst/design/ARCHITECTURE-stealth.md (AFTER) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/stealth/CURRENT.md @ 2026-11-11 (file carries no time).
Namespaces: rd-stealth-bi, rd-stealth-bank-a, rd-stealth-bank-b (cluster 1), rd-stealth-bank-c (cluster 2, new only). Old: `besu` (4 QBFT validators, PVs Retain) and `paladin` (gateways, Postgres PVs Delete), both shared with zeto and noto-pente.
Pins: `besu@9890701` (CURRENT; ARCHITECTURE cites 927f572), `frontend@28c8bdb` (local HEAD; CURRENT cites aa6e09b, so `stealth.ts` lines below are re-read and sit 1-4 lines below ARCHITECTURE's), EIP-5564 and EIP-6538 (ethereum/ERCs master, Final), Besu image 26.8.1 (docs unversioned: version match not proven).
Preserve (every step): chain 1337 and every address in CONTRACTS.md (no new genesis, no token redeploy); the contract code as it is (AFTER rule: only role holders move); no custom Paladin (none here, stealth has no Paladin node); balances on stealth addresses (they depend on each bank's current spend and view keys).
Shared with zeto (referenced by zeto S id, not repeated): validators and chain data S3-S5; namespace and credential pattern S1-S2; gateway manifest, per-party mTLS CA and bundle server S16-S17; Lensa forwards, Publisher and Besu network view S19-S20; decommission S22.

## Order and dependencies
1. S1 after zeto S1  2. S2 after zeto S2  3. S3 after zeto S5  4. S4 after S1,S3  5. S5 after S2,S4 and zeto S4  6. S6 after S4
7. S7 after S1,S2 (user product choice)  8. S8 after S7  9. S9 after S5,S7,S8  10. S10 after S4,S7,S8  11. S11 after S9,S10,S18
12. S12 after ADR 0001  13. S13 after ADR 0002 and S12  14. S14 after ADR 0003,S20,S21
15. S17 after S4,S5,S9,S10 and zeto S16,S17  16. S18 after S8  17. S19 after S17,S18 and zeto S19,S20  18. S20 after S9,S10,S11,S17,S19 (+ S12/S13 if their ADR changes the flow)
19. S21 after S20  20. S15 after S21,S12 and the zeto registrant confirmation (+S13,S14 if decided)  21. S16 after S4 (optional)  22. S22 after S20 and the zeto and noto-pente cutovers (LAST)

## Steps
### S1: Per-party namespaces on cluster 1
- DELTA: 7 -> AFTER row: "One admin domain per org: per-bank kubeconfig, per-bank credentials"
- Owner: besu  Size: S
- Prerequisites: zeto S1 (same pattern and the same user credential issue)
- Flags: CLUSTER-OP, user-only (credential issue)
- Role note (lead approval 2026-11-11, applied in rd-besu #14): `party-admin` also holds `batch` jobs/cronjobs verbs from S1 so that S11's CronJob and event-watch Job need no Role change; no other widening.
- Does: create ns `rd-stealth-bi`, `rd-stealth-bank-a`, `rd-stealth-bank-b` (labels `part-of=rd-stealth`, `party=<bi|bank-a|bank-b>`); NetworkPolicy `default-deny-ingress`, `allow-dns-egress`, `allow-same-namespace`; ServiceAccount `party-admin` + namespace-scoped Role/RoleBinding. Egress stays open (Besu p2p, JWT RPC reads, cert requests need it).
- RED proof: `kubectl get ns rd-stealth-bank-a` before `NotFound`, after `Active`; `kubectl -n rd-stealth-bank-a auth can-i get pods -n rd-stealth-bank-b --as system:serviceaccount:rd-stealth-bank-a:party-admin` -> `no`; `kubectl -n rd-stealth-bank-a get netpol -o name | wc -l` -> `3`.
- Rollback: `kubectl delete ns rd-stealth-<x>` (empty at this point).
- Sources: https://kubernetes.io/docs/concepts/services-networking/network-policies/ (as ARCHITECTURE 2a); zeto PLAN S1; CURRENT section 11 (old ns have no per-party RBAC).

### S2: Namespace on cluster 2 (first stealth write there)
- DELTA: 10, 7 -> AFTER row: "Cluster 2 holds ns-bank-c" (2a topology)
- Owner: besu  Size: S
- Prerequisites: zeto S2 done (credential proven to resolve to cluster 2 by its region RED proof)
- Flags: CLUSTER-OP, user-only
- Does: create ONLY ns `rd-stealth-bank-c` with the same three NetworkPolicies and `party-admin` objects as S1. No read of any existing cluster-2 namespace; no cluster-scoped object (stealth needs none).
- RED proof: `kubectl get ns rd-stealth-bank-c` -> `Active`; `kubectl -n rd-stealth-bank-c auth can-i list namespaces --as system:serviceaccount:rd-stealth-bank-c:party-admin` -> `no` (own namespace only; no read of any other cluster-2 namespace).
- Rollback: `kubectl delete ns rd-stealth-bank-c` (empty). Cluster 2: nothing else is ever deleted.
- Sources: ARCHITECTURE 2a "Capacity on cluster 2" (new namespaces only).

### S3: Validator per bank (done by zeto S3-S5): stealth-side proof and ownership record
- DELTA: 5 -> AFTER row: "Each bank runs its own Besu validator with a node key it generated"
- Owner: besu  Size: S
- Prerequisites: zeto S5 (this plan adds no validator pod: one validator per bank, shared by zeto, noto-pente and stealth)
- Flags: user-only (the vote-out of the old validators is zeto S5b: user-only, waits for VERIFY); the RED port-forwards to `rd-zeto-<party>` pods run outside the flock, read-only (admin RPC query only)
- Does: nothing is deployed. After zeto S5 record in CURRENT.md the validator-to-party mapping by namespace (`rd-zeto-<party>` pod `besu-validator-0`): it replaces the ARCHITECTURE inference "1=BI 2=A 3=B 4=C" (netpol guess, UNVERIFIED) with a fact. Old `besu` validators stay running until S22 (stealth still reads through them until S20).
- RED proof: through port-forward to each `besu-validator-0` (admin RPC is denied through the OPA door, CURRENT section 1): `qbft_getValidatorsByBlockNumber latest` before = `0xe89105d4…25d0 0x712f8366…69fd 0x95197d60…a715 0xd27cb197…38d9f3`, after = 4 addresses none of them old, each equal to `besu-node-address` of one party ns.
- Rollback: none needed (read-only); zeto S5 rollback governs.
- Sources: ARCHITECTURE 2 row "Bank validator" (Besu qbft "Add and remove validators", poa "Liveness"); CURRENT section 1.

### S4: Besu RPC node per party on cluster 1 (non-validator, JWT)
- DELTA: 6 -> AFTER row: "Separate non-validator node per org; JWT permissions eth/net/web3"
- Owner: besu  Size: M
- Prerequisites: S1, S3 (needs the zeto `besu-p2p` addresses, S3 of zeto); read-only capacity check first (free disk-attach slots and node memory on cluster 1, as zeto S1)
- Flags: CLUSTER-OP, spend, user-only (40Gi PVC per party)
- Does: in each of the three ns: ConfigMap `besu-genesis` byte-identical to live `besu-genesis`; ConfigMap `besu-rpc-config` copied from live `besu-node-validator-1-besu-config` with `rpc-http-api=["ETH","NET","WEB3"]`, `rpc-http-authentication-enabled=true`, `rpc-http-authentication-jwt-public-key-file=/jwt/public.pem`, `host-allowlist=["st-gw","besu-rpc"]` names of this ns's gateway and signer Services, `rpc-http-cors-origins` removed, `rpc-ws-enabled=false`, `metrics-host="127.0.0.1"`, `sync-mode="FULL"`, `static-nodes-file` = the 4 zeto `besu-p2p` addresses (this node is not in the validator set; its own node key is generated in the ns). StatefulSet `besu-rpc` image `hyperledger/besu:26.8.1`, PVC 40Gi `alicloud-essd` (re-syncable, Delete is acceptable); the JWT keypair (RS256 or ES256, Besu docs) is generated inside this step into Secret `stealth-rpc-jwt` (names only; public key mounted into `besu-rpc`, private key readable only by the token minter). Tokens carry `exp`, so a minting helper is a runtime dependency: project code inside the signer (S9); for the S4 and S6 proofs the operator mints a one-off token from the Secret inside the window. NetworkPolicy: 8545 only from pods `app=st-gw` and `app=stealth-signer` of this ns; cross-plan line: zeto S3 policy: allow 30303 from `rd-stealth-<party>` rpc node (new node dials the validator; today 30303 is allowed only from validators). Why a separate node: Besu JWT `permissions` are per token (`eth:*`, `*:*`) but `rpc-http-authentication-enabled` is endpoint-wide, so a token-protected validator would force tokens on zeto's Paladin `baseLedgerEndpoint` and on zeto S5 `qbft_proposeValidatorVote` calls, and whole-history `eth_getLogs` view-tag scans would load a consensus node (1 pod + 40Gi per party).
- RED proof: before `kubectl -n rd-stealth-bank-a get sts besu-rpc` -> `NotFound`; after, by port-forward: `eth_chainId` with a valid JWT (one-off token minted from `stealth-rpc-jwt`) -> `0x539`, `eth_blockNumber` within 2 blocks of `rd-zeto-bi` validator; no token -> HTTP `401`; `admin_peers`, `debug_traceTransaction`, `perm_getNodesAllowlist` with a valid `eth:*,net:*,web3:*` token -> error (API not enabled); `net_peerCount` >= `0x3`. Exact 401 body [unverified].
- Rollback: delete sts, pvc, ConfigMaps, Secret `stealth-rpc-jwt` in `rd-stealth-<x>`; remove the added 30303 rule in zeto's ns.
- Sources: ARCHITECTURE 2 rows "RPC auth + API surface", "Bank RPC node" (Besu `public-networks/how-to/use-besu-api/authenticate`, `reference/options` `rpc-http-authentication-jwt-public-key-file`, `host-allowlist`; quickstart "four validators, one non-validator RPC node"); CURRENT section 1 (live config keys to copy).

### S5: Besu RPC node for bank C on cluster 2
- DELTA: 10, 6 -> AFTER row: "Cross-cluster limits: p2p across clusters via static nodes"
- Owner: besu  Size: M
- Prerequisites: S2, S4; zeto S4 (cluster-1 p2p addresses reachable from cluster 2; the network path is [unverified], the RED proof decides); read-only capacity check first (cluster-2 node memory and disk slots)
- Flags: CLUSTER-OP, spend, user-only (40Gi PVC on cluster 2)
- Does: in `rd-stealth-bank-c` the same objects as S4; `static-nodes-file` = zeto `besu-p2p` addresses of cluster 1 plus bank C's own validator in `rd-zeto-bank-c`; requests set on every container (cluster-2 memory is tight, ARCHITECTURE 2a); no LoadBalancer (outbound dial only; adding the 30303 rule in `rd-zeto-bank-c` as in S4).
- RED proof: `eth_chainId` with JWT -> `0x539`; `net_peerCount` >= `0x3`; `eth_blockNumber` within 2 blocks of cluster 1; before: no pod in `rd-stealth-bank-c`.
- Rollback: delete sts, pvc in `rd-stealth-bank-c`.
- Sources: ARCHITECTURE 2a "Cross-cluster limits" 1-2 (latency 15-30 ms vs 2 s / 4 s, no tunable changes); Besu `public-networks/how-to/connect/static-nodes`, `specify-nat`.
- Peering (user decision 2026-11-11 "stealth RPC connects to each bank's own validator"; analyst-checked at besu-eth/besu@26.8.1 d97cbd61): at head, each party's `besu-rpc` keeps exactly ONE static peer = that party's own zeto validator (stable in-cluster address, not a pod IP), `discovery-enabled=false`; the zeto `besu-validator-ingress` admits 30303 from `rd-stealth-<same party>` only. `sync-min-peers` is ignored in FULL sync (BesuCommand.java:1996-1998) and is not a lever. Runbook, S4 and S5 alike: the INITIAL sync and any resync after a long outage use TEMPORARY multi-peer static-nodes (the 3 cluster-1 zeto nodes; for bank C its own zeto node plus the 3 cluster-1 `besu-p2p` LB addresses, admitted by the ACL for bank C's egress), switched to the single own-party peer once within 2 blocks of head. Reason: one peer offers 5 request slots (EthPeer.java:67) while the download pipeline wants up to 16 with no failover, so a single-peer bulk download ends in `NO_PEER_AVAILABLE` ("Chain download failed. Restarting after short delay", observed 2026-11-11 on rd-stealth-bi at block 1965409). Trigger for the temporary multi-peer file: a "Chain download failed" loop, or a gap of more than a few thousand blocks. Documented alternative: seed the data dir from a backup of a synced node (Besu `private-networks/how-to/backup`, the validator key left out of the copy). Each switch of the live ConfigMaps is its own user request.

### S6: Record the DFABI scale evidence (no code change)
- DELTA: none (correctness record, analyst adds the addendum) -> AFTER row preserved: "No new contract design; only role holders move." (ARCHITECTURE-stealth.md:66; units untouched)
- Owner: qa  Size: S
- Prerequisites: S4 (read through the new RPC node with a read-only `eth:*` token minted from Secret `stealth-rpc-jwt` as in S4; the earlier check failed at the old mTLS door, LENSA.md section 3)
- Flags: read-only (the proof token is minted by the S4 operator from Secret `stealth-rpc-jwt` inside the S4 window and handed over; S6 itself reads no cluster Secret)
- Does: read `decimals()`, `granularity()`, `totalSupply()` of RD and DfabiBond and one holder `balanceOfByPartition(TRANCHE_A, …)`; write the result as the CONTRACTS.md units cells, and one line "whole units; wallets honouring `decimals()` show 1e-18" in `besu/stealth-address/docs` only if the user asks. Lensa constants stay `PRICE_PER_UNIT = 1_000_000n`, `MAX_AMOUNT = 10n ** 15n` (`frontend@28c8bdb:server/src/domain.ts:14-15`).
- RED proof: DFABI `decimals()` -> `0x…12` (18), `granularity()` -> `0x…01`, `totalSupply()` -> `3007139` raw, equal to the whole-unit supply Lensa shows (CURRENT section 2 gives the same numbers); RD `decimals()` -> `0x…00`. Mismatch (supply scaled by 1e18) would turn this step into a defect for `lead`.
- Rollback: none (read-only).
- Sources: `besu@9890701:stealth-address/src/vendor/universal-token/ERC1400.sol:679` (`decimals()`), `src/RupiahDigital.sol:29`; ecc:evm-token-decimals; CURRENT sections 2-3.

### S7: Per-party key store (Vault or KMS-wrapped)
- USER DECISION 2026-11-12 ~01:35 CST ("stealth A", via orchestrator): option A = one Kubernetes Secret `stealth-keys` per bank namespace now, no Vault, no spend; recorded as a GAP vs README row 28 (Vault) and the AFTER "keys in bank Vault/KMS". Hardening candidates, not analyzed, none chosen: Vault (row 28), Alibaba Cloud KMS envelope, OpenBao, ACK etcd encryption with a cloud key. Copy channel per bank = besu operator session, /dev/shm (700/600), `shred -u`, names and sizes read back, no rotation, no chain call. Trust reset acknowledged by the user: keys that sat in the Lensa host state file cannot be proven private; rotation stays README decision 12. Known limit of Secrets (RED below, GAP): any pod a party operator creates in the namespace can mount `stealth-keys`, so "denied from st-gw" holds only by render (only the signer Deployment mounts it) and by RBAC (`party-admin` has no `get secrets`), not by the store. NOT covered by this word: the S12 chain calls (old deployer key) and the S9/S10 key moves; each gets its own text and user word. BI store (`issuerKey` = copy of `deployerKey`, `biMeta`) is created at S10 with its own text, not in this step.
- DELTA: 1 -> AFTER row: "Bank keys ... spend, view, identity keys in bank Vault/KMS"
- Owner: besu  Size: M
- Prerequisites: S1, S2; user chooses the key-store product (Vault, or cloud KMS envelope on Secrets: AFTER names both, picks neither)
- Flags: CLUSTER-OP, spend, user-only (product choice)
- Does: per ns one store reachable only from pods `app=stealth-signer`: path/Secret `stealth-keys` holding names `spendKey`, `viewKey`, `identityKey` (bank) or `issuerKey`, `custodianKey` placeholder, `registryKey` placeholder (the S15 InstrumentRegistry holder, DELTA 8a), `biMeta` (BI). Hard limit 6: the signer needs the spending key in memory (EIP-5564 "Private key derivation"), so an HSM-only signing mode is not planned. NetworkPolicy: store ingress only from `stealth-signer`. Backup/seal policy named by the product.
- RED proof: from `stealth-signer` (S9) read of `stealth-keys` -> ok; same read from a pod `app=st-gw` in the same ns and from another ns -> denied/timeout; `kubectl -n rd-stealth-bank-a get secret -o name` lists no key outside `stealth-keys`.
- Rollback: delete the store (empty before S9).
- Sources: ARCHITECTURE 2 row "Bank keys" and hard limit 6 (inference from the EIP formula, not tested); EIP-5564 "Private key derivation"; Besu use-besu-api "Account management".

### S8: stealth-signer service (code): intents in, signed tx out, own-key scan
- USER DECISION 2026-11-11 ~23:20 CST host clock ("stealth setuju usulan", via orchestrator; analyst verdict binding): custodian = BI (ADR 0001 accepted); raw-in-memory spend key = accepted limit. Analyst verdict on the S8 SPEC (rd-besu #37): custodian reads nonce + domain separator from chain; inline ABIs pinned by test; every scan match listed incl. balance 0; one covering holding (422 insufficient_holdings, recorded limit); mTLS via stdlib node:https behind the injectable fetch port (no undici); cert issuance rule = (a) mTLS client cert must be a registered bank signer else 403 + log, (b) token == bond else 422, (c) expiry <= chain now + 600, (d) payload selector allowlist (transferByPartitionStealth, or transferByPartition to a DvPFactory escrow), banks never hold the cert key; gas price 0, estimateGas only after the real cert is inserted; 403 role_forbidden for role bank until S12; /intent returns {kind, from, txHash, rawTx}, from = party id, the signer picks the stealth address. PLACEMENT: one signer per party namespace holding only its own spend + view keys (BI signer = issuer key + view-key copies, never spend keys); the cert signer is a separate key + role in the custodian namespace; a single signer with all banks' spend keys is forbidden (DELTA 1). GATE: refund tracking for DvP escrows (src/DvPEscrow.sol:124-142) must exist before S17. Vault key-store spend and the S7 key-store custody step stay user-only.
- GATE SCOPING 2026-11-12 (lead's interpretation, for the analyst's final evaluation; the analyst's wording is only: "GATE: refund tracking for DvP escrows (`src/DvPEscrow.sol:124-142`) must exist before S17."): implemented as (1) on-chain tracking state `bondRefunded`, cumulative `rdRefunded` and view `refundStatus()` (bondHeld, bondRefunded, rdRefunded, bondStuck) in place of log scans, and (2) a retry path `refundBond(bytes freshCert)` (anyone, after expiry, bond held, not settled/refunded, destination fixed to the seller by the terms, certificate bound to the escrow and payload by the validator); no off-chain index. Proposal PR rd-besu #50 (forge 91 tests, no deploy). The new bytecode changes the CREATE2 escrow addresses and needs a NEW `DvPFactory` at the S15 trust reset, not an upgrade of deployed escrows. S17 text waits for #50 to be reviewed and merged.
- DELTA: 1, 2, 4 -> AFTER row: "Bank client signs and submits; Lensa builds unsigned intents" (DELTA 1), "Bank scanner with own viewing key" (DELTA 2), bank client sends cert request (sender, payload, expiry) to the custodian (ARCHITECTURE-stealth.md:106,178)
- Owner: besu  Size: L
- Prerequisites: S7
- Flags: none (image build only, no cluster)
- Does: new dir `besu@9890701:stealth-address/signer/` reusing `ts/stealth.ts` (`deriveStealth`, `scan`, `scanView`), `ts/chain.ts`, `ts/bond.ts` (`signCertificate`:71): HTTP API `POST /intent` (kind rd-transfer, bond-transfer, dvp-leg; Lensa sends public meta-address + amount, never a key), `GET /holdings`, `GET /history` (own-key scan of `Announcement` logs from own RPC with JWT, view tag first), `POST /cert` (role `custodian` only, enabled by S12). Keys read from S7; submits `eth_sendRawTransaction` to the own RPC node; per-party config rejects an intent whose `from` party is not the configured party. Port of the pool and `sent`/`escrowed` records of ONE party into the service's own volume. Bank-side cert-request client (project code in the signer/gateway): for DFABI transfers, bond funding and DvP legs it sends (sender, payload, expiry) over mTLS to BI's (custodian's) `/cert` and attaches the returned certificate to the raw tx.
- RED proof: `cd besu/stealth-address && npx vitest run signer` before: `No test files found` (exit 1); after: all pass, including (1) rd-transfer intent -> signed raw tx whose recovered `from` equals the derived stealth address, (2) intent naming another party -> rejected, (3) `GET /holdings` equals `scan()` on the same fixture, (4) no response body or log line contains a key value (grep of the test log), (5) cert-request client: against a stub `/cert` server the request carries (sender, payload, expiry) and the returned cert is attached; the S17 call exercises it live. `tsc --noEmit` clean (the package `test` script runs it).
- Rollback: `git revert` (new dir only; Lensa still holds keys until S21).
- Sources: `besu@9890701:stealth-address/ts/stealth.ts:58-80`, `ts/chain.ts:46-49`, `docs/architecture-brief.md:119-123` (key table), `:461`; `frontend@28c8bdb:server/src/adapters/stealth.ts:117-122,195-198,382-386,411`; Besu "Account management" (no `eth_sendTransaction`).

### S9: Bank signer + scanner per bank, key move A, B, C
- USER DECISION 2026-11-12 ~02:35 CST (supersedes "rotasi stealth ya" of ~02:20): NO key rotation (one key, one meta-address registration per ERC-5564/6538 practice). The S7 Secrets `stealth-keys` (keys copied from the Lensa host file) are the PERMANENT bank keys; no registerKeys re-registration and no sweeps in S9. Accepted risk: the origin file (Lensa host state/stealth.json) cannot be proven private; it is destroyed at the Lensa S9 shred list. Reversible later: ERC-6538 `registerKeys` can overwrite the meta-address; old-key balances would then need a sweep. Order unchanged: signers (S8/S9) and the S10 BI signer code before the S12 role move; the DvPFactory redeploy at S15 stays user-only.
- DELTA: 1, 2, 10 -> AFTER row: "Signer/scanner service holds this org's spending + viewing (+ identity) keys only"
- Owner: besu  Size: L
- Prerequisites: S5, S7, S8
- Flags: CLUSTER-OP, user-only (the copy is a trust reset: keys that sat in the Lensa state file cannot be proven private; rotation is not planned here and stays the user-only key-reset decision, final-design README decision 12, at the cost in Key bindings)
- Party credential (user decision via orchestrator 2026-11-11, aligned to the design: own account per institution, cluster-admin operator only, Lensa holds no kubeconfig): until this step the party operator gets short `kubectl create token party-admin` tokens re-issued per window (API-server cap 12 h); inside THIS step's CLUSTER-OP one bound token Secret `party-admin-token` (type `kubernetes.io/service-account-token`, annotation `kubernetes.io/service-account.name: party-admin`) is created per party namespace, delivered to that party's operator only (never the Lensa host, never chat), revocable by deleting the Secret. RED: `kubectl -n <ns> get secret party-admin-token -o name` NotFound before, present after; `auth can-i get secrets --as=system:serviceaccount:<ns>:party-admin` stays `no`.
- Does: Deployment `stealth-signer` (+ Service) in `rd-stealth-bank-a/-b` and `-bank-c`, requests set; keys `banks.<X>.{spendKey,viewKey,identityKey}` (state also holds `deployerKey`, `banks.<X>.metaAddress`, `biMeta.{spendKey,viewKey,metaAddress}`, `pool.<pair>[].{stealthAddress,privateKey,used}` 1030 entries, records `sent`, `escrowed`: CURRENT section 4) and the `pool.<pair>` entries of the pairs this bank pays (a pair's entries belong to the paying bank, the bank whose spend key derives them; BI keeps none: [unverified], CURRENT section 4 does not say) enter the ns store through a channel the bank operator chooses (no value in chat, git, logs); `sent`/`escrowed` entries of that bank move to the signer volume. This is a copy, not a rotation: it needs NO contract call. Lensa still holds its copy until S21. Bank scanner = same pod, own view key, reads the own RPC node (S4, S5).
- RED proof: with Lensa frozen, `GET /holdings` of each bank signer equals Lensa's `/api/history?model=stealth&party=<P>` holdings total for that bank (same value); `meta-address` derived inside the signer equals `banks.<X>.metaAddress` of `state/stealth.json` and `ERC6538Registry.stealthMetaAddressOf(address(identityKey), 1)` on the registry (keyed by the identity-key account, not by "<bank>"); before: no `stealth-signer` pod.
- Rollback: delete Deployment and the store entries in `rd-stealth-<x>`; Lensa unchanged.
- Key bindings (what a later rotation must call): (i) `deployerKey` address = RD `issuer` (immutable, `RupiahDigital.sol:21`: no rotation without redeploy, ADR 0003), bond owner, controller, minter, validator certificate signer and allowlist (`chain.ts:49-50`), `DvPFactory.custodian` (immutable, `:14`), `InstrumentRegistry` owner and registrar (`chain.ts:51`): rotation = S12/S15 calls, factory = new instance. (ii) bank `spendKey`+`viewKey` = the meta-address registered by `registerKeys` from the bank's `identityKey` account (`frontend@28c8bdb:server/src/cli/bootstrap-stealth.ts:36-40`; `ERC6538Registry.sol:36-38` overwrites `stealthMetaAddressOf[msg.sender][1]`): rotation = a new `registerKeys` by the identity key; funds on old-derived stealth addresses stay spendable only with the OLD spend key. (iii) `identityKey` address is bound only off-chain (BI onboarding list, `ts/memo.ts:11`, `stealth.ts:122`). (iv) `pool` entries and `biMeta`: no binding found; BI's own meta-address registration [unverified].
- Sources: `frontend@28c8bdb:server/src/adapters/stealth.ts:22-24,164,193` (key and pool shapes, `unusedOf`); ARCHITECTURE 2a row "Signer/scanner service"; CURRENT section 4.

### S10: BI signer + BI scanner in rd-stealth-bi
- Analyst audit 2026-11-12: DELTA 3 (BI scanner holding per-bank view-key copies + the S11 registry-compare job) is UNBUILT and part of this plan; the BI signer code (role `bi`) does not exist yet and must exist before S12.
- DELTA: 1, 3, 8 -> AFTER row: "BI scanner holds a copy of each bank's viewing key (not spend keys)"
- Owner: besu  Size: M
- Prerequisites: S4, S7, S8
- Flags: CLUSTER-OP, user-only (same trust reset as S9 for BI keys)
- Does: Deployment `stealth-signer` role `bi` and `stealth-bi-scanner` in `rd-stealth-bi`: BI keys `deployerKey` -> `issuerKey` role copy (DELTA 8; the key still holds every role until S15) (mint, DFABI issue, DvP RD leg), `biMeta` (BI stealth receive keys), `registryKey` placeholder (filled at S15, DELTA 8a); scanner uses `scanView`/`scanAll` with per-bank `viewKey` copies (S11 fills them), never a spend key; BI's store also holds the list of bank identity addresses (the S11 registry lookup key, Key bindings (iii)). Signing role `custodianKey` stays empty until S12 decides the party.
- RED proof: `GET /holdings` of the BI signer for a BI stealth balance equals Lensa's BI history; a bank `viewKey` loaded without its meta-address is refused (`view key does not match meta-address of <id>`, `ts/stealth.ts:74`); before: no pod in `rd-stealth-bi`.
- Rollback: delete the Deployments and store entries in `rd-stealth-bi`.
- Sources: `besu@9890701:stealth-address/ts/stealth.ts:69-81`; `frontend@28c8bdb:server/src/adapters/stealth.ts:117,120-122` (BI wallet and view-key holders); ARCHITECTURE 2 row "BI see all", hard limit 2.

### S11: View-key handover and registry compare job
- DELTA: 3 -> AFTER row: "BI compares the viewing public key inside each bank's registered meta-address"
- Owner: besu  Size: M
- Prerequisites: S9, S10, S18 (Lensa health field `stealth.scanLag`)
- Flags: CLUSTER-OP (CronJob and event-watch Job in `rd-stealth-bi`), user-only (each bank operator hands its own view key; no on-chain forcing: hard limit 2)
- Does: each bank operator copies its `viewKey` (not spend key) into the BI store `stealth-keys/viewcopy-<bank>` by an off-chain channel; CronJob `stealth-viewkey-compare` in `rd-stealth-bi` reads `ERC6538Registry.stealthMetaAddressOf(address(identityKey of <bank>), 1)` (identity list from S10) through the BI RPC node and compares its viewing pubkey with the held copy; a second job watches `StealthMetaAddressSet` events and emits an alert (log line + Lensa `/api/health` field `stealth.scanLag`, S18) on any change. R1 "BI sees all" is detective only: it holds for banks whose current key BI holds.
- RED proof: unit test in `besu/stealth-address` (vitest, fixture with two registered key pairs): matching copy -> `match`, registry key replaced -> `MISMATCH bank-a` (fails before the job exists); live read-only: three banks `match`.
- Rollback: delete the CronJob and the copies in `rd-stealth-bi`.
- Sources: EIP-6538 Specification (`stealthMetaAddressOf`, `registerKeys`, event `StealthMetaAddressSet`); EIP-5564 "Stealth meta-address format"; `besu@9890701:stealth-address/src/ERC6538Registry.sol`; ARCHITECTURE 2 row "BI detective check" (layout assumption not executed: UNVERIFIED there).

### S12: Custodian party and DFABI roles
- DELTA: 4, 4a -> AFTER row: "Custodian role: not required to be BI; roles that move: owner, minter, controllers, certificate signer, DvPFactory"
- Owner: besu  Size: M
- Prerequisites: ADR 0001 decided, S10
- Flags: BLOCKED(Stealth custodian party), CLUSTER-OP (live tx in the RED proof, under flock), user-only; BLOCKED(bond controllability, ADR 0004) only for the `renounceControl` option, the move of controllers below stays
- Does: only after the user picks the party (BI or another). New `custodianKey` in that party's store (S7); with the old signer: `validator.addCertificateSigner(bond, new)`; `validator.addAllowlisted(bond, new)` (`chain.ts:50`, `AllowlistedRole.sol:36`; the allowlist moves with the custodian role, DELTA 4a); `bond.transferOwnership(new)`, from the new owner `bond.setControllers([new])` (`ERC1400.sol:745`; keep controllable: `isControllable` is set true in the constructor `:193`, `renounceControl()` is owner-only, irreversible and not a role move (DELTA 4a) `:710-713`, controller power = `_isControllable && _isController[op]` `:1150`, and `DvPEscrow.sol:131` says a failed bond refund waits for the controller, so removing controllers or renouncing strands refunds: ADR 0004), `bond.addMinter(new)` (`MinterRole.sol:35`); deploy `DvPFactory(new)` and write `deployed.dvpFactory`; old factory and its escrows stay valid. Old deployer roles are removed in S15, not here. `stealth-signer` role `custodian` (S8 `POST /cert`) starts in that party's ns.
- RED proof: `bond.owner()`, `controllers()`, `isMinter(new)`, `validator.isCertificateSigner(bond, new)` and the allowlist read for new -> new address / true; `DvPFactory(new).custodian()` -> new address; a DFABI transfer with a cert from the new signer settles (qa on a test account); before: all equal `0x4de0…9472`.
- Rollback: while the old key still holds roles (before S15) the same calls move them back; after S15 none.
- Sources: `besu@9890701:stealth-address/src/DvPFactory.sol:14-18,30-31`; `src/vendor/universal-token/roles/CertificateSignerRole.sol:33,37`; `ERC1400.sol:31,745`; ARCHITECTURE 2 row "Custodian role", hard limits 3-4.

### S13: DFABI certificate model (R2)
- DELTA: 4 -> AFTER row: "Moving the signer off BI moves the mandatory third party, it does not remove it" (hard limit 4)
- Owner: besu  Size: S (single signer, no change) / M (several signers)
- Prerequisites: ADR 0002 decided, S12
- Flags: BLOCKED(DFABI certificate model), CLUSTER-OP, user-only (the RED proof is an outage experiment on a live path)
- Does: the AFTER leaves R2 as a GAP for DFABI (matrix: "GAP (DFABI certificate)"; RD, `settle()`, `cancel()` need no signer: hard limit 4). The default plan keeps one online certificate signer. Only if the user picks several signers: `addCertificateSigner` per extra signer (each bank signer pod, S8 role `custodian` configured in each ns); `registerTokenSetup(..., None)` needs the allowlist change and is not planned unless chosen.
- RED proof: only after ADR 0002 is decided and inside its CLUSTER-OP window: with the certificate signer pod scaled to 0, a DFABI transfer fails (single signer: the documented R2 GAP) and settles under several signers when another signer certifies it.
- Rollback: `removeCertificateSigner(bond, extra)` per added signer.
- Sources: `besu@9890701:stealth-address/docs/architecture-brief.md:12,461`; ARCHITECTURE hard limit 4 (`ERC1400TokensValidator.sol:394-432`, via ARCHITECTURE).

### S14: RD issuer address
- DELTA: 8 -> AFTER row: "RD: issuer stays BI (immutable)"
- Owner: besu  Size: L (redeploy) / none (keep)
- Prerequisites: ADR 0003 decided AND S20 PASS + S21 (RD redeploy only after the cutover proof)
- Flags: BLOCKED(RD issuer redeploy), user-only
- Does: default AFTER = no change, the issuer key moves into the BI store (S10, S15). Only if the user wants a different issuer address: deploy a new `RupiahDigital(issuer_, announcer)` and migrate balances by ordinary stealth transfers (RD has no migration function); not planned further.
- RED proof: `RupiahDigital.issuer()` -> the BI issuer address from the BI store (default) / the new address (redeploy).
- Rollback: none after a redeploy (old balances not carried); default plan: none needed.
- Sources: `besu@9890701:stealth-address/src/RupiahDigital.sol:21,24-25,33-35`; ARCHITECTURE hard limit 5.

### S15: Retire deployerKey as a shared key
- DELTA: 8, 8a -> AFTER row: "keeps only the RD issuer role, strip every other role from it"
- Owner: besu  Size: S
- Prerequisites: S21 (Lensa no longer holds it), S12 (roles already moved); no open DvP escrow (a stored certificate from the removed signer would be invalid: `DvPEscrow.sol:131-136`); zeto registrant: confirm the Zeto instrument entries and the zeto registrar key before S15 (zeto CONTRACTS.md row; the registry is shared: `InstrumentRegistry.sol:7`, `besu@9890701:zeto/spike-zeto-instrument.ts:9`); S15 waits for that confirmation
- Flags: CLUSTER-OP (live txs from the old key; flock, lead GO), user-only (destructive for the old holder)
- Does: from the old key: `validator.removeCertificateSigner(bond, old)`, `bond.renounceMinter()` (`MinterRole.sol:43`), and in this order for the registry (DELTA 8a): `InstrumentRegistry.setRegistrar(new,true)` FIRST (`register`/`registerVersion` are `onlyRegistrar`, `InstrumentRegistry.sol:82,96`; only the deployer is registrar today, `ts/chain.ts:51`), then `transferOwnership(new)` (`:68`), new = a BI-party key in the BI party's store, separate from the issuer key; then from the new owner `setRegistrar(old,false)` and the allowlist removal of the old key (allowlisted by `chain.ts:50`); after that the key is the BI issuer key only (RD `issuer`, immutable).
- RED proof: before the transfer `isRegistrar(new)` true; after: `isCertificateSigner(bond, old)` false, `isMinter(old)` false, `bond.owner()` and `controllers()` not old, `InstrumentRegistry.owner()` not old, `isRegistrar(old)` false, the allowlist read for old false, `RupiahDigital.issuer()` unchanged; before: all old = `0x4de0…9472` (CURRENT section 2).
- Rollback: the bond owner re-adds a minter (`addMinter`: `onlyMinter` admits the owner, `ERC1400.sol:155-157`, `MinterRole.sol:35`); `setRegistrar(old,true)` by the registry owner restores the old registrar; a removed signer is re-added by a remaining signer.
- Sources: `besu@9890701:stealth-address/src/vendor/universal-token/roles/{CertificateSignerRole,MinterRole}.sol`; ARCHITECTURE DELTA 8, 8a; CURRENT section 10.

### S16: Node allowlist (optional hardening)
- DELTA: 9 -> AFTER row: "Optional local nodes allowlist; no accounts allowlist"
- Owner: besu  Size: S
- Prerequisites: S4 (and zeto S5 so the enodes are final)
- Flags: CLUSTER-OP
- Does: `permissions_config.toml` with `nodes-allowlist` listing the 4 validator and 4 RPC enodes, config key `permissions-nodes-config-file-enabled=true`; no `accounts-allowlist` (stealth senders are fresh addresses: hard limit 7, inference not tested).
- RED proof: a throwaway Besu pod with a foreign node key and the same static nodes: `net_peerCount` -> `0x0` after 60 s; before the allowlist the same pod reaches `>= 0x1`.
- Rollback: remove the key from config.toml and restart one node at a time.
- Sources: Besu `private-networks/how-to/use-local-permissioning`, `tutorials/permissioning` (via ARCHITECTURE row "Permissioning"); CURRENT section 1 (no `permissions-*` keys today).

### S17: Stealth gateway and OPA per party
- DELTA: 6, 7 -> AFTER row: "Gateway + NetworkPolicy: envoy+opa is the only ingress from Lensa"
- Owner: besu  Size: M
- Prerequisites: S4, S5, S9, S10; zeto S16, S17 (manifest, per-party mTLS CA, bundle server); read-only: the custodian's gateway address: the cert path runs bank-C signer (cluster 2) -> custodian `/cert` (cluster 1), so the LoadBalancer (spend, user-only) sits on the custodian's gateway Service on cluster 1 (`st-gw-1` while the custodian is BI; whichever gateway ADR 0001 picks); `st-gw-4` stays inbound-only (NodePort/ClusterIP, no LoadBalancer); the address is read after creation and quoted in CURRENT.md before the bank-C `/cert` route is configured
- Flags: CLUSTER-OP, spend (LoadBalancer for the custodian cert path)
- Does: Deployment and Service `st-gw-<N>` (N: 1 BI, 2 A, 3 B, 4 C; the name fits the Publisher guard `^[a-z0-9]+-gw-[1-4]$`, `frontend@28c8bdb:server/src/policy/kube.ts:22`) in each `rd-stealth-<party>` from `besu@9890701:opa/k8s/bank-gw-1.yaml` (namespace lines become the ns); envoy fronts the signer API and the read door of the RPC node (rego `bi.besu` method allowlist unchanged for reads; new package `bank.stealth` for `/intent`, `/holdings`, `/history`, `/cert`: new rego file, not in CURRENT); bundles pulled from zeto S17's `bundle-server` in `rd-zeto-<party>` (cross-ns rule added there). Service for the BI custodian path reachable from cluster 2 (LB address quoted from that prerequisite). NetworkPolicy: signer API ingress only from `st-gw`.
- RED proof: party B's Lensa client cert on `st-gw-2` -> TLS handshake failure, A's cert -> `GET /holdings` 200; a method outside the allowlist on the read door (`debug_traceTransaction`) -> denied; `/cert` from the bank C signer pod to BI's gateway answers (qa; exercises the custodian key, so it runs only inside this step's CLUSTER-OP window).
- Rollback: delete the Deployment, Service, Secret in `rd-stealth-<x>`; Lensa still points at the old door until S19.
- Sources: `besu@9890701:opa/k8s/bank-gw-1.yaml`; `besu@9890701:opa/bundles/bi/bi/besu/besu.rego`; zeto PLAN S16-S17; ARCHITECTURE 2a row "Gateway + NetworkPolicy"; LENSA.md section 1.1.
- S17 IMPLEMENTATION RECORD 2026-11-12 (lead's decisions; implementation in rd-besu PRs #51-#55, repo only, nothing applied; deviations listed for the analyst's final evaluation):
  - /cert = TLS PASSTHROUGH, not an OPA-checked gateway route (deviation vs "route for `/cert`" above). The S8 verdict rule (a) needs the bank's mTLS client cert on the custodian signer's own `node:https` socket, so Envoy must not terminate it: `st-gw-1` listener `tls_inspector` + filter chain `server_names: [custodian-1]` -> `tcp_proxy` to Service `stealth-custodian` :9443, no `transport_socket`; the default chain stays the Lensa mTLS + OPA door. Bank signers dial with `CERT_SERVERNAME=custodian-1` (SNI and verification name). `/cert` is never allowed by the rego target `stealth`; its control is the signer's four cert rules (a-d). `st-gw-<N>` not-bi parties get no passthrough chain. (rd-besu #54, `stealth-address/k8s/gateway/render.sh`)
  - R1 (orchestrator pick, replaces the LoadBalancer on "the custodian's gateway Service" with a defined object): bank-c (cluster 2) reaches `st-gw-1` only through ONE new CLB Service `st-gw-1-ext` (same class and spec as the CLBs already approved, EXISTING ACL ids only, ACL annotations in the first apply, `externalTrafficPolicy: Cluster`, no `loadbalancer-id`; the second-Service-on-shared-CLB option R2 is rejected). Cluster-1 nodes have no external IP, so a NodePort cannot serve bank-c. Order: apply -> ACL read-back on the listener -> controls before traffic (positive from bank-c, hosted-runner negative). The extra CLB cost is noted to the user. Quote the LB address after creation; it is bank-c's `CERT_URL`. bank-a/bank-b use `st-gw-1.rd-stealth-bi.svc` with the same servername.
  - NO Besu read door on `st-gw` (deviation vs "read door of the RPC node" above): the S4 RPC node requires an RS256 JWT and a gateway cannot mint one. Lensa reads stealth data through the signer routes (`/holdings`, `/history`); public chain reads already come through the zeto gateways' Besu door on the same chain 1337. Rego target `stealth` (`bi.platform.stealth`, `bank.platform.stealth`): Lensa certs only, `POST /intent`, `GET /holdings`, `GET /history`, `GET /health`, exact paths. Bundles come from `bundle-server.rd-zeto-<party>` (NetworkPolicy `bundle-server-from-stealth`, :8080 only); the st-gw OPA has no sink token, no status/decision-log service. (rd-besu #55)
  - Per-request RPC JWT (S8/S9 follow-up): the signer mints the node's RS256 token per request from `RPC_JWT_KEY_FILE` (`private.pem` of Secret `stealth-rpc-jwt`), `exp` <= now+900, permissions `eth|net|web3`, reused until 60 s before expiry, key never logged; the static `RPC_JWT_FILE` is gone. The signer pod therefore mounts the node's JWT private key, by design. (rd-besu #53)
  - S17 WINDOW LINE (field change on approved objects, own line, not applied): re-apply `allow-same-namespace` in `rd-stealth-bi`, `-bank-a`, `-bank-b`, `-bank-c` with the extra expression `{key: app, operator: NotIn, values: [stealth-signer]}` BEFORE the signer pods exist (the old key `app.kubernetes.io/name` did not match the signer label, so any pod in the ns could have reached the signer). Read back with `kubectl -n <ns> get netpol allow-same-namespace -o yaml`.
  - Other S17 inputs recorded in `besu/stealth-address/k8s/S17.md` (rd-besu): Kubernetes Secrets for keys (limit: `party-admin` can mount them, so the S7 "denied from a pod" RED does not cover an operator-created pod; a Vault agent sidecar into tmpfs is a later hardening row), `certKey` = the S12 custodian key only (never a copy of `deployerKey`), S17 waits for S12 and the S7 custody step (user-only), new rego reaches the gateways only after a new signed bundle upload.

### S18: Lensa relay adapter (fe): intent builder, no keys
- DELTA: 1, 2 -> AFTER row: "Lensa: relay and read model; holds no spending, viewing, identity, certificate or deployer key"
- Owner: fe  Size: L
- Prerequisites: S8
- Flags: none (merge and deploy happen in S19 and S20)
- Does: split `frontend@28c8bdb:server/src/adapters/stealth.ts` (44 KB): keep intent building from public meta-addresses, relay to `st-gw-N`, read model assembled from each party's `/history`; delete the `Wallet(state.deployerKey)` path (`:117`), view-key holders (`:120-122`), `scanOwned` of bank keys (`:164,204,211,284`), `pool` (`:193`), `cert()` calls (`:382-386,411`), `StealthState` key fields (`:22-27`). BI view = BI scanner `/history`; a bank's outsider view comes from that bank's own scanner, not a Lensa key. Sub-step (S11 alert): `/api/health` gains a stealth field `stealth.scanLag` (or equivalent) read from the BI scanner.
- RED proof: node test with no key fields in `state/stealth.json`: `createStealthAdapter` serves rd-transfer A to B through a stub `st-gw` (fails before: `state.deployerKey` is undefined); `grep -nE "deployerKey|spendKey|viewKey|identityKey|privateKey" frontend/server/src/adapters/stealth.ts` -> 0 hits after (46 lines / 69 occurrences at frontend@28c8bdb before); unit test: `/api/health` carries `stealth.scanLag`, fails before.
- Rollback: `git revert` (client change only).
- Sources: `frontend@28c8bdb:server/src/adapters/stealth.ts:22-27,117-122,164,193,382-411`; LENSA.md sections 1.2, 1.4, 1.5; ARCHITECTURE section 2 row "Lensa".

### S19: Lensa pointers: forwards and gateway client per party (fe)
- DELTA: 1, 7 -> AFTER row: "Lensa must reach four gateways in two clusters" (2a limit 5)
- Owner: fe  Size: M
- Prerequisites: S17, S18; zeto S19 and S20 (they change the shared `forwards.conf` header, `pf.sh` kubeconfig column, `kube.ts`, `besu-network.ts`; not repeated here)
- Flags: none (host unit change belongs to the S20 cutover window)
- Does: `frontend@28c8bdb:deploy/forwards.conf` lines `besu` (`paladin bank-gw-1 38545:8545`) and `besu-bank-a/b/c` (`paladin bank-gw-2..4 38546-38548:8545`) become four lines `stealth-gw-<N> rd-stealth-<party> st-gw-<N> 3864<N>:8443` (local ports 38641-38644, free in the current file: 38545-38548, 38080-38090, 39441-39444 are taken); `lensa.env` `LENSA_BESU_RPC` and `LENSA_BESU_RPC_BANKS` stop pointing at `bank-gw-N`; `gwAgent` client cert per party (zeto S19). Publisher: `PLATFORMS` (`platforms.ts:9`) gains `stealth` with gateways `st-gw-1..4` (enforced: false until the rego is published).
- RED proof: `grep -nE "^(besu|besu-bank-[abc])\s+paladin\s" frontend/deploy/forwards.conf` -> 0 lines after (4 before); Publisher unit test lists `st-gw-1..4` for platform `stealth`.
- Rollback: `git revert` and restore the previous `forwards.conf`; units restart.
- Sources: LENSA.md sections 4.2, 6 (rows `paladin`, `besu`); `frontend@28c8bdb:deploy/forwards.conf`, `server/src/policy/platforms.ts:9,25-29`.

### S20: Cutover party by party and qa proof
- DELTA: 1, 2, 3, 5, 6 -> AFTER row: "Lensa relay and read model; bank signs with its own key and sends to its own RPC node"
- Owner: qa (steps by besu, fe)  Size: L
- Prerequisites: S9, S10, S11, S17, S19 (+ S12, S13 if their ADR changes the flow)
- Flags: CLUSTER-OP, user-only (maintenance window)
- Does: order bank-a, bank-b, bank-c, bi (BI last: it holds the issuer key and scans everyone). Per party: freeze Lensa stealth writes; compare signer holdings with Lensa (S9 proof); flip that party's forward and env to `st-gw-N`; unfreeze. After all four: qa runs F1 RD transfer, F2 DFABI transfer with certificate, F3 DvP create/fund/settle, F4 scan, a stress run of the pooled addresses, outsider C view, and the BI-balance proof: per bank, BI scanner holdings (view-key copy) equal the bank scanner holdings. Transactions made after the last restart (TEAM.md section 10 rule 3).
- RED proof: `GET /api/history?model=stealth&party=P` shows the old tx `0x7fcad8f3d95c…` and a NEW tx made after cutover; R1 views = BI `viewkey`, A `clear`, B `clear`, C `partial` (amount public, counterparty null: ACCEPTED, hard limit 1); `lensa.service` environment shows no key fields read.
- Rollback: before the first new tx per party flip the forward and env back (Lensa still holds its keys until S21); after it, new announcements exist on chain and only the new signer can spend them, so roll forward.
- Sources: CURRENT sections 5, 9; LENSA.md section 4.1; ecc:deployment-patterns.

### S21: Remove key fields from Lensa
- DELTA: 1 -> AFTER row: "holds no spending, viewing, identity, certificate or deployer key"
- Owner: fe  Size: S
- Prerequisites: S20 PASS for all four parties; each operator confirms its store copy (S9, S10)
- Flags: user-only, destructive (the Lensa copy is the only other copy)
- Does: delete `deployerKey`, `banks.*.{spendKey,viewKey,identityKey}`, `biMeta.{spendKey,viewKey}`, `pool` from `state/stealth.json` on the Lensa host (field names, `state.ts` 0600 file); keep `deployed.*`, `chainId`, public `metaAddress`. No backup of the removed fields stays on the Lensa host.
- RED proof: `python3 -c "import json;d=json.load(open('state/stealth.json'));print(sorted(k for k in d if k in ('deployerKey','pool','biMeta')))"` -> `[]`, and `banks.A` has only `metaAddress`; before: the three keys exist (CURRENT section 4).
- Rollback: none after delete; the keys are exported from the owning signer store (S9, S10) back if ever needed.
- Sources: CURRENT section 4; LENSA.md section 1.2 (stealth row).

### S22: Decommission `besu`, `paladin` (and `dfabi`)
- DELTA: 7, 7a -> AFTER row: "One admin domain per org ... no shared cluster-admin kubeconfig" (old shared ns removed)
- Owner: lead  Size: M
- Prerequisites: SHARED with zeto and noto-pente; executes once, after all three cutovers (zeto S21, noto-pente cutover, S20). Cutover proven (qa PASS on the new namespaces for every flow + the BI-balance proof). Nothing points at the old ns: LENSA.md "Namespace references" rows `paladin`, `besu`, `dfabi` clean (`forwards.conf` 0 lines, no `lensa-pf@*` unit, `kube.ts:3` and `besu-network.ts:20` updated, OPA bundle server and CI: `ci.yml` names no ns); `dfabi` bank backends repointed or retired (user decides). Surviving data copied BEFORE any delete: Besu chain DB `data-besu-node-validator-1..4-0` 4 x 40Gi (PV Retain: kept as is, not a backup) with Secrets `besu-node-validator-N-keys` and CM `besu-genesis`; Postgres of `paladin-node1..4-pgdata` (PV reclaim = Delete, 4 x 20Gi) dumped by the zeto plan as `zeto-decom-pgdump-<date>`; Lensa state files; `~/.opa-keys`, `~/.opa-mtls`; `dfabi` PVs `data-postgres-0`, `runner-state` (Delete, 2 x 5Gi). Stealth adds: `state/stealth.json` `deployed` block saved as named backup `stealth-deployed-<date>` (addresses only, no keys, after S21).
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: inventory = CURRENT.md section 11 "Decommission inventory": `besu` 4 STS, 4 PVC 40Gi; `paladin` 6 Deployments incl. `bank-gw-1..4`, 4 STS, 4 PVC 20Gi, 43 `smartcontractdeployment`, 3 `paladindomain`, 4 `paladinregistration`, 1 `paladinregistry`; `dfabi` 9 Deployments, 2 PVC. PVC total: 160 Gi Besu + 80 Gi Paladin (+10 Gi dfabi). Stealth deletes nothing alone: the zeto plan re-sets the 4 `paladin` PVs to Retain or copies them first. The `dfabi` namespace is decommissioned only if the user confirms its ownership (TEAM.md §4, DELTA 7a); otherwise it stays. Cluster-scoped CRDs stay. Cluster 2: nothing is ever deleted.
- RED proof: `kubectl get ns besu paladin` -> `NotFound`; qa re-runs S20 read-only checks on the new namespaces (PASS); the zeto dump restores into a scratch DB (row counts equal) before the delete.
- Rollback: none after delete; restore `zeto-decom-pgdump-<date>` and the retained Besu PVs / node-key Secrets from the named backup, `stealth-deployed-<date>` for the addresses.
- Sources: CURRENT.md section 11; LENSA.md section 6; zeto PLAN S22.

## DEVIATION REQUEST (draft for lead)
None for the AFTER rows. Two points go to `analyst` with the plan: (1) closed by analyst DELTA 8a: the `InstrumentRegistry` holder is a BI-party key separate from the issuer key (S15); (2) the lead brief lists "retire multiregion stack" as an open stealth decision, but ARCHITECTURE-stealth has no such item (it exists only in ARCHITECTURE-fabricx 2.4), so no stealth ADR was written for it.
