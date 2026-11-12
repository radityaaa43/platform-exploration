# Decommission inventory G1-G11 (cluster 1, old namespaces)

Read-only inventory by `qa`, 2026-11-12 (CST morning; run 23:50Z on 2026-11-11). Namespaces: `dfabi`, `paladin`, `besu`, `iroha3`, `fabricx` (never `fabricx-bi` / `fabricx-bank-*`).
Credential: cluster-admin `get`/`list` only (R19(b)1+3). No Secret read, no log read, no exec. Nothing was changed. Reference counts are plain string hits (grep -F of the Service name), not proof of a live consumer. Env values appear only as host:port; no tokens.
Host at run time: `free -m` available 3166 MB (23:50:56Z).

## Lead notes

- `dfabi` is ABSENT on cluster 1. Decommission order becomes **paladin -> besu**, besu only after S5b (old besu is the only QBFT validator set; S5a handover first).
- Old `iroha3` and `fabricx` stay until their S14 / S15 close and Lensa's forwards move.
- The live-consumer check is NOT re-run until fe changes `forwards.conf` (lead will say when).
- `47.236.100.234` owner and ACL: answered by besu, see G5 blocker 2 (RESOLVED).

## G5 blockers (each needs an owner decision before any delete)

1. `frontend/deploy/forwards.conf` still has 9 forwards into old namespaces (5 into `iroha3`, 4 into `fabricx`; see list below).
2. RESOLVED (besu, relayed by lead 2026-11-12): `47.236.100.234` is `bank-gw-4-ext` in `rd-zeto-bank-c` (cluster 2), Envoy + OPA. ACL `acl-gs5m5o9vb3olr19484tyg`, white list, sourceRanges `['8.215.62.92/32']` only (the cluster-1 egress NAT). The same ACL sits on 6 cluster-2 Services: `bank-gw-4-ext`, `paladin-transport`, `rd-iroha3-bank-c` p2p, `fx-gw-4-lb`, `lb-4`, `rdbi-p2p-bank4`. No-cert TLS from the qa host: `:8545` and `:8548` both answer the alert `certificate required`, no HTTP answer. So Lensa's `LENSA_GW_PALADIN_C` and `LENSA_BESU_RPC_BANKS` use of this address is intended and restricted; it is not a leftover. (Facts are besu's, quoted; qa did not re-run the probe.)
3. Old `besu` is the only QBFT validator set until S5b.
4. `qa` scripts and the besu / fabric-x repos still contain thousands of old service-name string hits (not triaged; most are history).
5. Operators: `paladin-operator` is at 0 replicas in `paladin`, so Paladin CR finalizers are not served there. No operator deployment exists in `besu`, `iroha3`, `fabricx`.

## Disk summary

- Every PV bound to these namespaces has reclaimPolicy `Retain` (44 PVs): deleting a PVC leaves the cloud disk until it is deleted by hand.
- Sum of PVC sizes (Gi): paladin 80, besu 160, iroha3 22, fabricx 56; total 318.
- Host `df -h /`: 295G size, 195G used, 89G avail (69%).
- G3 archive candidates are listed in their own section. Which `fabricx` PVC carries `/data/v2` is UNVERIFIED (no exec).

---

## namespace `dfabi`
ABSENT

## namespace `paladin`
### workloads (kind/name, replicas ready/spec)
| kind/name | spec | ready |
|---|---|---|
| deployment/bank-gw-1 | 1 | 1 |
| deployment/bank-gw-2 | 1 | 1 |
| deployment/bank-gw-3 | 1 | 1 |
| deployment/bank-gw-4 | 1 | 1 |
| deployment/bundle-server | 1 | 1 |
| deployment/paladin-operator | 0 | 0 |
| statefulset/paladin-node1 | 0 | 0 |
| statefulset/paladin-node2 | 0 | 0 |
| statefulset/paladin-node3 | 0 | 0 |
| statefulset/paladin-node4 | 0 | 0 |

pods: 5 total, running 5
operator deployments here: ['paladin-operator']

### PVC -> PV -> disk
| pvc | size | phase | pv | reclaim | pv phase | disk id (csi volumeHandle) | storageClass |
|---|---|---|---|---|---|---|---|
| paladin-node1-pgdata | 20Gi | Bound | d-k1abvsqso8tiw9y3g9yc | Retain | Bound | d-k1abvsqso8tiw9y3g9yc | alicloud-essd |
| paladin-node2-pgdata | 20Gi | Bound | d-k1ahwqof9rvf1dilaldo | Retain | Bound | d-k1ahwqof9rvf1dilaldo | alicloud-essd |
| paladin-node3-pgdata | 20Gi | Bound | d-k1ahwqof9rvf1dilaldq | Retain | Bound | d-k1ahwqof9rvf1dilaldq | alicloud-essd |
| paladin-node4-pgdata | 20Gi | Bound | d-k1abvsqso8tiw9y3g9yb | Retain | Bound | d-k1abvsqso8tiw9y3g9yb | alicloud-essd |

PVC total: 4, 80 Gi requested/bound

### objects with finalizers, and custom resources (names only)
custom resources: orders.acme.cert-manager.io/paladin-node1-tls-1-4269039594, orders.acme.cert-manager.io/paladin-node2-tls-1-851133493, orders.acme.cert-manager.io/paladin-node3-tls-1-2703922760, orders.acme.cert-manager.io/paladin-node4-tls-1-3992833059, certificaterequests.cert-manager.io/paladin-node1-mtls-1, certificaterequests.cert-manager.io/paladin-node1-tls-1, certificaterequests.cert-manager.io/paladin-node2-mtls-1, certificaterequests.cert-manager.io/paladin-node2-tls-1, certificaterequests.cert-manager.io/paladin-node3-mtls-1, certificaterequests.cert-manager.io/paladin-node3-tls-1, certificaterequests.cert-manager.io/paladin-node4-mtls-1, certificaterequests.cert-manager.io/paladin-node4-tls-1, certificates.cert-manager.io/paladin-node1-mtls, certificates.cert-manager.io/paladin-node1-tls, certificates.cert-manager.io/paladin-node2-mtls, certificates.cert-manager.io/paladin-node2-tls, certificates.cert-manager.io/paladin-node3-mtls, certificates.cert-manager.io/paladin-node3-tls, certificates.cert-manager.io/paladin-node4-mtls, certificates.cert-manager.io/paladin-node4-tls, issuers.cert-manager.io/selfsigned-issuer, ciliumendpoints.cilium.io/bank-gw-1-544fcb74c7-pgxxm, ciliumendpoints.cilium.io/bank-gw-2-7cbb98f759-27fmp, ciliumendpoints.cilium.io/bank-gw-3-5c8f9dfb48-cwnh9, ciliumendpoints.cilium.io/bank-gw-4-bb4f4865c-j8gj7, ciliumendpoints.cilium.io/bundle-server-55d44bd57c-p7vnf, paladindomains.core.paladin.io/noto, paladindomains.core.paladin.io/pente, paladindomains.core.paladin.io/zeto, paladinregistrations.core.paladin.io/node1, paladinregistrations.core.paladin.io/node2, paladinregistrations.core.paladin.io/node3, paladinregistrations.core.paladin.io/node4, paladinregistries.core.paladin.io/evm-registry, paladins.core.paladin.io/node1, paladins.core.paladin.io/node2, paladins.core.paladin.io/node3, paladins.core.paladin.io/node4, smartcontractdeployments.core.paladin.io/noto, smartcontractdeployments.core.paladin.io/noto-factory (+47 more)
with finalizers: only `kubernetes.io/pvc-protection` on 4 PVCs

### Services and who still references them (counts: Lensa env file, frontend repo, qa scripts, besu / fabric-x / iroha3 repos)
| service | type | ports | Lensa env | frontend repo (deploy/ + server/src + web/src) | qa scratchpad scripts | besu repo | fabric-x repo | iroha3 repo |
|---|---|---|---|---|---|---|---|---|
| bank-gw-1 | ClusterIP | 8548/TCP,8545/TCP | 0 | 6 | 149 | 563 | 0 | 0 |
| bank-gw-2 | ClusterIP | 8548/TCP,8545/TCP | 0 | 9 | 139 | 339 | 0 | 0 |
| bank-gw-3 | ClusterIP | 8548/TCP,8545/TCP | 0 | 3 | 56 | 247 | 0 | 0 |
| bank-gw-4 | ClusterIP | 8548/TCP,8545/TCP | 0 | 4 | 61 | 302 | 0 | 0 |
| bundle-server | ClusterIP | 80/TCP,8081/TCP | 0 | 6 | 375 | 3201 | 66 | 20 |
| paladin-node1 | ClusterIP | 6100/TCP,8548/TCP,8549/TCP,9000/TCP | 0 | 3 | 201 | 1056 | 0 | 0 |
| paladin-node2 | ClusterIP | 6100/TCP,8548/TCP,8549/TCP,9000/TCP | 0 | 3 | 146 | 868 | 0 | 0 |
| paladin-node3 | ClusterIP | 6100/TCP,8548/TCP,8549/TCP,9000/TCP | 0 | 3 | 129 | 773 | 0 | 0 |
| paladin-node4 | ClusterIP | 6100/TCP,8548/TCP,8549/TCP,9000/TCP | 0 | 0 | 141 | 830 | 0 | 0 |
| paladin-operator | ClusterIP | 80/TCP | 0 | 0 | 72 | 673 | 0 | 0 |

## namespace `besu`
### workloads (kind/name, replicas ready/spec)
| kind/name | spec | ready |
|---|---|---|
| statefulset/besu-node-validator-1 | 1 | 1 |
| statefulset/besu-node-validator-2 | 1 | 1 |
| statefulset/besu-node-validator-3 | 1 | 1 |
| statefulset/besu-node-validator-4 | 1 | 1 |
| job/besu-genesis-init | - | - |
| job/besu-node-validator-1-pre-install-hook | - | - |
| job/besu-node-validator-2-pre-install-hook | - | - |
| job/besu-node-validator-3-pre-install-hook | - | - |
| job/besu-node-validator-4-pre-install-hook | - | - |

pods: 9 total, running 4
operator deployments here: none

### PVC -> PV -> disk
| pvc | size | phase | pv | reclaim | pv phase | disk id (csi volumeHandle) | storageClass |
|---|---|---|---|---|---|---|---|
| data-besu-node-validator-1-0 | 40Gi | Bound | d-k1a3tvwzj4oe9t2iy1pp | Retain | Bound | d-k1a3tvwzj4oe9t2iy1pp | besu-node-validator-1-storage |
| data-besu-node-validator-2-0 | 40Gi | Bound | d-k1abj5hxiusijwnvk1q3 | Retain | Bound | d-k1abj5hxiusijwnvk1q3 | besu-node-validator-2-storage |
| data-besu-node-validator-3-0 | 40Gi | Bound | d-k1admrqwz5xfqb5ky3j5 | Retain | Bound | d-k1admrqwz5xfqb5ky3j5 | besu-node-validator-3-storage |
| data-besu-node-validator-4-0 | 40Gi | Bound | d-k1a9qatmp2tccnr5c2rf | Retain | Bound | d-k1a9qatmp2tccnr5c2rf | besu-node-validator-4-storage |

PVC total: 4, 160 Gi requested/bound

### objects with finalizers, and custom resources (names only)
custom resources: Cilium endpoints (4+ listed) only
with finalizers: only `kubernetes.io/pvc-protection` on 4 PVCs

### Services and who still references them (counts: Lensa env file, frontend repo, qa scripts, besu / fabric-x / iroha3 repos)
| service | type | ports | Lensa env | frontend repo (deploy/ + server/src + web/src) | qa scratchpad scripts | besu repo | fabric-x repo | iroha3 repo |
|---|---|---|---|---|---|---|---|---|
| besu-node-validator-1 | ClusterIP | 8545/TCP,8546/TCP,8547/TCP,30303/TCP,30303/UDP,9545/TCP | 0 | 0 | 97 | 397 | 0 | 0 |
| besu-node-validator-2 | ClusterIP | 8545/TCP,8546/TCP,8547/TCP,30303/TCP,30303/UDP,9545/TCP | 0 | 0 | 35 | 189 | 0 | 0 |
| besu-node-validator-3 | ClusterIP | 8545/TCP,8546/TCP,8547/TCP,30303/TCP,30303/UDP,9545/TCP | 0 | 0 | 27 | 171 | 0 | 0 |
| besu-node-validator-4 | ClusterIP | 8545/TCP,8546/TCP,8547/TCP,30303/TCP,30303/UDP,9545/TCP | 0 | 0 | 30 | 190 | 0 | 0 |

## namespace `iroha3`
### workloads (kind/name, replicas ready/spec)
| kind/name | spec | ready |
|---|---|---|
| deployment/bi-auditor | 1 | 1 |
| statefulset/bank-a | 1 | 1 |
| statefulset/bank-b | 1 | 1 |
| statefulset/bank-c | 1 | 1 |
| statefulset/bi | 1 | 1 |
| statefulset/gha-runner | 1 | 1 |
| job/rd-s1-dvp | - | - |
| job/rd-s2a-insufficient | - | - |
| job/rd-s2b-audit-reject | - | - |
| job/rd-s3-replay | - | - |
| job/rd-s4-redeem | - | - |
| job/rd-selftest | - | - |

pods: 12 total, running 6
operator deployments here: none

### PVC -> PV -> disk
| pvc | size | phase | pv | reclaim | pv phase | disk id (csi volumeHandle) | storageClass |
|---|---|---|---|---|---|---|---|
| bi-audit-store | 1Gi | Bound | d-k1a1kmngclw2b0ngu31z | Retain | Bound | d-k1a1kmngclw2b0ngu31z | alicloud-essd-wffc |
| data-bank-a-0 | 5Gi | Bound | d-k1a7094jzxuwe01bf2m7 | Retain | Bound | d-k1a7094jzxuwe01bf2m7 | alicloud-essd-wffc |
| data-bank-b-0 | 5Gi | Bound | d-k1a7vz34yzdadqejao3w | Retain | Bound | d-k1a7vz34yzdadqejao3w | alicloud-essd-wffc |
| data-bank-c-0 | 5Gi | Bound | d-k1a5bdhgh0tsc7e6b0xc | Retain | Bound | d-k1a5bdhgh0tsc7e6b0xc | alicloud-essd-wffc |
| data-bi-0 | 5Gi | Bound | d-k1a0v25u1ib2no3xqdog | Retain | Bound | d-k1a0v25u1ib2no3xqdog | alicloud-essd-wffc |
| runner-state-gha-runner-0 | 1Gi | Bound | d-k1a47701wm8t96weyp2k | Retain | Bound | d-k1a47701wm8t96weyp2k | alicloud-essd-wffc |

PVC total: 6, 22 Gi requested/bound

### objects with finalizers, and custom resources (names only)
custom resources: Cilium endpoints (6+ listed) only
with finalizers: only `kubernetes.io/pvc-protection` on 6 PVCs

### Services and who still references them (counts: Lensa env file, frontend repo, qa scripts, besu / fabric-x / iroha3 repos)
| service | type | ports | Lensa env | frontend repo (deploy/ + server/src + web/src) | qa scratchpad scripts | besu repo | fabric-x repo | iroha3 repo |
|---|---|---|---|---|---|---|---|---|
| bank-a | ClusterIP | 1337/TCP,8080/TCP | 0 | 29 | 1594 | 6623 | 681 | 547 |
| bank-b | ClusterIP | 1337/TCP,8080/TCP | 0 | 26 | 967 | 4499 | 311 | 471 |
| bank-c | ClusterIP | 1337/TCP,8080/TCP | 0 | 14 | 1183 | 5364 | 500 | 581 |
| bi | ClusterIP | 1337/TCP,8080/TCP | 2 | 812 | 13415 | 66736 | 21169 | 3128 |
| bi-auditor | ClusterIP | 8090/TCP | 0 | 9 | 59 | 0 | 0 | 226 |

## namespace `fabricx`
### workloads (kind/name, replicas ready/spec)
| kind/name | spec | ready |
|---|---|---|
| deployment/block-explorer | 1 | 1 |
| deployment/committer-coordinator | 1 | 1 |
| deployment/committer-query-service | 1 | 1 |
| deployment/committer-validator | 1 | 1 |
| deployment/committer-verifier | 1 | 1 |
| deployment/fca-orderer-org1 | 1 | 1 |
| deployment/fca-orderer-org2 | 1 | 1 |
| deployment/fca-orderer-org3 | 1 | 1 |
| deployment/fca-orderer-org4 | 1 | 1 |
| deployment/fca-org1 | 1 | 1 |
| deployment/fx-gw-1 | 1 | 1 |
| deployment/fx-gw-2 | 1 | 1 |
| deployment/fx-gw-3 | 1 | 1 |
| deployment/fx-gw-4 | 1 | 1 |
| deployment/orderer-loadgen | 0 | 0 |
| deployment/rdbi-bank2 | 1 | 1 |
| deployment/rdbi-bank3 | 1 | 1 |
| deployment/rdbi-bank4 | 1 | 1 |
| deployment/rdbi-bi | 1 | 1 |
| deployment/rdbi-driver | 0 | 0 |
| statefulset/block-explorer-db | 1 | 1 |
| statefulset/committer-db | 1 | 1 |
| statefulset/committer-sidecar | 1 | 1 |
| statefulset/fca-orderer-org1-db | 1 | 1 |
| statefulset/fca-orderer-org2-db | 1 | 1 |
| statefulset/fca-orderer-org3-db | 1 | 1 |
| statefulset/fca-orderer-org4-db | 1 | 1 |
| statefulset/fca-org1-db | 1 | 1 |
| statefulset/orderer-assembler-1 | 1 | 1 |
| statefulset/orderer-assembler-2 | 1 | 1 |
| statefulset/orderer-assembler-3 | 1 | 1 |
| statefulset/orderer-assembler-4 | 1 | 1 |
| statefulset/orderer-batcher-1 | 1 | 1 |
| statefulset/orderer-batcher-2 | 1 | 1 |
| statefulset/orderer-batcher-3 | 1 | 1 |
| statefulset/orderer-batcher-4 | 1 | 1 |
| statefulset/orderer-consenter-1 | 1 | 1 |
| statefulset/orderer-consenter-2 | 1 | 1 |
| statefulset/orderer-consenter-3 | 1 | 1 |
| statefulset/orderer-consenter-4 | 1 | 1 |
| statefulset/orderer-router-1 | 1 | 1 |
| statefulset/orderer-router-2 | 1 | 1 |
| statefulset/orderer-router-3 | 1 | 1 |
| statefulset/orderer-router-4 | 1 | 1 |

pods: 42 total, running 42
operator deployments here: none

### PVC -> PV -> disk
| pvc | size | phase | pv | reclaim | pv phase | disk id (csi volumeHandle) | storageClass |
|---|---|---|---|---|---|---|---|
| data-block-explorer-db-0 | 2Gi | Bound | d-k1a9vurfxzwddtn1p2hu | Retain | Bound | d-k1a9vurfxzwddtn1p2hu | alicloud-essd-wffc |
| data-committer-db-0 | 2Gi | Bound | d-k1a9syy461gvnd65zjee | Retain | Bound | d-k1a9syy461gvnd65zjee | alicloud-essd-wffc |
| data-committer-sidecar-0 | 2Gi | Bound | d-k1a3tvwzj4oea2xoibyv | Retain | Bound | d-k1a3tvwzj4oea2xoibyv | alicloud-essd-wffc |
| data-fca-orderer-org1-db-0 | 2Gi | Bound | d-k1aen3t7wrqx7wn76dhx | Retain | Bound | d-k1aen3t7wrqx7wn76dhx | alicloud-essd-wffc |
| data-fca-orderer-org2-db-0 | 2Gi | Bound | d-k1a9vurfxzwdejag5t2n | Retain | Bound | d-k1a9vurfxzwdejag5t2n | alicloud-essd-wffc |
| data-fca-orderer-org3-db-0 | 2Gi | Bound | d-k1a327antokt6zrlukep | Retain | Bound | d-k1a327antokt6zrlukep | alicloud-essd-wffc |
| data-fca-orderer-org4-db-0 | 2Gi | Bound | d-k1a327antokt6zrlukgc | Retain | Bound | d-k1a327antokt6zrlukgc | alicloud-essd-wffc |
| data-fca-org1-db-0 | 2Gi | Bound | d-k1admrqwz5xfr8p3v27v | Retain | Bound | d-k1admrqwz5xfr8p3v27v | alicloud-essd-wffc |
| data-orderer-assembler-1-0 | 2Gi | Bound | d-k1aarlhphikpxjyx0u9p | Retain | Bound | d-k1aarlhphikpxjyx0u9p | alicloud-essd-wffc |
| data-orderer-assembler-2-0 | 2Gi | Bound | d-k1afs8wedv37t48xvty0 | Retain | Bound | d-k1afs8wedv37t48xvty0 | alicloud-essd-wffc |
| data-orderer-assembler-3-0 | 2Gi | Bound | d-k1ahhlgjlun3452s58ni | Retain | Bound | d-k1ahhlgjlun3452s58ni | alicloud-essd-wffc |
| data-orderer-assembler-4-0 | 2Gi | Bound | d-k1a9vurfxzwddzk518kf | Retain | Bound | d-k1a9vurfxzwddzk518kf | alicloud-essd-wffc |
| data-orderer-batcher-1-0 | 2Gi | Bound | d-k1a6l7r3fv3kr0olqu4t | Retain | Bound | d-k1a6l7r3fv3kr0olqu4t | alicloud-essd-wffc |
| data-orderer-batcher-2-0 | 2Gi | Bound | d-k1ahsbhuxtubfk8agcy5 | Retain | Bound | d-k1ahsbhuxtubfk8agcy5 | alicloud-essd-wffc |
| data-orderer-batcher-3-0 | 2Gi | Bound | d-k1aen3t7wrqx7guy9x2s | Retain | Bound | d-k1aen3t7wrqx7guy9x2s | alicloud-essd-wffc |
| data-orderer-batcher-4-0 | 2Gi | Bound | d-k1agzvylh2nw5hhzoli3 | Retain | Bound | d-k1agzvylh2nw5hhzoli3 | alicloud-essd-wffc |
| data-orderer-consenter-1-0 | 2Gi | Bound | d-k1aismsh93tpl8kuan2k | Retain | Bound | d-k1aismsh93tpl8kuan2k | alicloud-essd-wffc |
| data-orderer-consenter-2-0 | 2Gi | Bound | d-k1a3mmggpxs65qnvdt76 | Retain | Bound | d-k1a3mmggpxs65qnvdt76 | alicloud-essd-wffc |
| data-orderer-consenter-3-0 | 2Gi | Bound | d-k1agzvylh2nw5pe44tlj | Retain | Bound | d-k1agzvylh2nw5pe44tlj | alicloud-essd-wffc |
| data-orderer-consenter-4-0 | 2Gi | Bound | d-k1a70nqju0h8ybgkw44p | Retain | Bound | d-k1a70nqju0h8ybgkw44p | alicloud-essd-wffc |
| data-orderer-router-1-0 | 2Gi | Bound | d-k1a3tvwzj4oeaipxes8x | Retain | Bound | d-k1a3tvwzj4oeaipxes8x | alicloud-essd-wffc |
| data-orderer-router-2-0 | 2Gi | Bound | d-k1abj5hxiusikkc8wq8y | Retain | Bound | d-k1abj5hxiusikkc8wq8y | alicloud-essd-wffc |
| data-orderer-router-3-0 | 2Gi | Bound | d-k1agrktk6cjykel3o8hm | Retain | Bound | d-k1agrktk6cjykel3o8hm | alicloud-essd-wffc |
| data-orderer-router-4-0 | 2Gi | Bound | d-k1a3mmggpxs65smwhvcq | Retain | Bound | d-k1a3mmggpxs65smwhvcq | alicloud-essd-wffc |
| rdbi-bank2-state | 2Gi | Bound | d-k1a58gwg4ljb26hm4ncy | Retain | Bound | d-k1a58gwg4ljb26hm4ncy | alicloud-essd-wffc |
| rdbi-bank3-state | 2Gi | Bound | d-k1a1hcztihtweg5gd58t | Retain | Bound | d-k1a1hcztihtweg5gd58t | alicloud-essd-wffc |
| rdbi-bank4-state | 2Gi | Bound | d-k1a7sja16a31jbij4d2w | Retain | Bound | d-k1a7sja16a31jbij4d2w | alicloud-essd-wffc |
| rdbi-bi-state | 2Gi | Bound | d-k1ablv5sac95ospupvfs | Retain | Bound | d-k1ablv5sac95ospupvfs | alicloud-essd-wffc |

PVC total: 28, 56 Gi requested/bound

### objects with finalizers, and custom resources (names only)
custom resources: Cilium endpoints (40+ listed) only
with finalizers: only `kubernetes.io/pvc-protection` on 28 PVCs

### Services and who still references them (counts: Lensa env file, frontend repo, qa scripts, besu / fabric-x / iroha3 repos)
| service | type | ports | Lensa env | frontend repo (deploy/ + server/src + web/src) | qa scratchpad scripts | besu repo | fabric-x repo | iroha3 repo |
|---|---|---|---|---|---|---|---|---|
| bank2 | ClusterIP | 5103/TCP,5104/TCP,5105/TCP | 0 | 4 | 441 | 1156 | 891 | 0 |
| bank3 | ClusterIP | 5106/TCP,5107/TCP,5108/TCP | 0 | 4 | 311 | 947 | 496 | 0 |
| bank4 | ClusterIP | 5109/TCP,5110/TCP,5111/TCP | 0 | 4 | 175 | 399 | 303 | 0 |
| block-explorer | ClusterIP | 18080/TCP,18000/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| block-explorer-db | ClusterIP | 18432/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| block-explorer-nodeport | NodePort | 18000/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| committer-coordinator | ClusterIP | 5120/TCP,5220/TCP | 0 | 0 | 9 | 0 | 27 | 0 |
| committer-db | ClusterIP | 5150/TCP | 0 | 6 | 60 | 0 | 192 | 0 |
| committer-query-service | ClusterIP | 5140/TCP,5240/TCP | 0 | 0 | 9 | 0 | 44 | 0 |
| committer-query-service-nodeport | NodePort | 5140/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| committer-sidecar | ClusterIP | 5130/TCP,5230/TCP | 0 | 0 | 25 | 0 | 117 | 0 |
| committer-sidecar-nodeport | NodePort | 5130/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| committer-validator | ClusterIP | 5100/TCP,5200/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| committer-verifier | ClusterIP | 5110/TCP,5210/TCP | 0 | 0 | 9 | 0 | 33 | 0 |
| endorser-1 | ClusterIP | 5112/TCP,5113/TCP,5114/TCP | 0 | 0 | 33 | 0 | 126 | 0 |
| endorser-2 | ClusterIP | 5115/TCP,5116/TCP,5117/TCP | 0 | 0 | 19 | 0 | 154 | 0 |
| endorser-3 | ClusterIP | 5118/TCP,5119/TCP,5120/TCP | 0 | 0 | 18 | 0 | 126 | 0 |
| endorser-4 | ClusterIP | 5121/TCP,5122/TCP,5123/TCP | 0 | 0 | 22 | 0 | 67 | 0 |
| fca-orderer-org1 | ClusterIP | 9019/TCP,9020/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| fca-orderer-org1-db | ClusterIP | 9120/TCP | 0 | 0 | 1 | 0 | 0 | 0 |
| fca-orderer-org1-nodeport | NodePort | 9019/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org2 | ClusterIP | 9029/TCP,9030/TCP | 0 | 0 | 7 | 0 | 15 | 0 |
| fca-orderer-org2-db | ClusterIP | 9130/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org2-nodeport | NodePort | 9029/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org3 | ClusterIP | 9039/TCP,9040/TCP | 0 | 0 | 6 | 0 | 12 | 0 |
| fca-orderer-org3-db | ClusterIP | 9140/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org3-nodeport | NodePort | 9039/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org4 | ClusterIP | 9049/TCP,9050/TCP | 0 | 0 | 6 | 0 | 12 | 0 |
| fca-orderer-org4-db | ClusterIP | 9150/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-orderer-org4-nodeport | NodePort | 9049/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-org1 | ClusterIP | 9069/TCP,9070/TCP | 0 | 0 | 17 | 0 | 21 | 0 |
| fca-org1-db | ClusterIP | 9170/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fca-org1-nodeport | NodePort | 9069/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| fx-gw-1 | ClusterIP | 8443/TCP | 1 | 3 | 48 | 183 | 74 | 0 |
| fx-gw-2 | ClusterIP | 8443/TCP | 0 | 2 | 19 | 18 | 58 | 0 |
| fx-gw-3 | ClusterIP | 8443/TCP | 0 | 2 | 9 | 18 | 12 | 0 |
| fx-gw-4 | ClusterIP | 8443/TCP | 0 | 2 | 8 | 0 | 12 | 0 |
| issuer | ClusterIP | 5100/TCP,5101/TCP,5102/TCP | 0 | 69 | 2177 | 11600 | 3016 | 7 |
| orderer-assembler-1 | ClusterIP | 7052/TCP,7062/TCP | 0 | 0 | 5 | 0 | 9 | 0 |
| orderer-assembler-2 | ClusterIP | 7152/TCP,7162/TCP | 0 | 0 | 5 | 0 | 9 | 0 |
| orderer-assembler-3 | ClusterIP | 7252/TCP,7262/TCP | 0 | 0 | 5 | 0 | 9 | 0 |
| orderer-assembler-4 | ClusterIP | 7352/TCP,7362/TCP | 0 | 0 | 5 | 0 | 9 | 0 |
| orderer-batcher-1 | ClusterIP | 7053/TCP,7063/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-batcher-2 | ClusterIP | 7153/TCP,7163/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-batcher-3 | ClusterIP | 7253/TCP,7263/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-batcher-4 | ClusterIP | 7353/TCP,7363/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-consenter-1 | ClusterIP | 7051/TCP,7061/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-consenter-2 | ClusterIP | 7151/TCP,7161/TCP | 0 | 0 | 3 | 0 | 0 | 0 |
| orderer-consenter-3 | ClusterIP | 7251/TCP,7261/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-consenter-4 | ClusterIP | 7351/TCP,7361/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-loadgen | ClusterIP | 12010/TCP,12020/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| orderer-loadgen-nodeport | NodePort | 12010/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| orderer-router-1 | ClusterIP | 7050/TCP,7060/TCP | 0 | 0 | 5 | 0 | 22 | 0 |
| orderer-router-1-nodeport | NodePort | 7050/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| orderer-router-2 | ClusterIP | 7150/TCP,7160/TCP | 0 | 0 | 3 | 0 | 3 | 0 |
| orderer-router-2-nodeport | NodePort | 7150/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| orderer-router-3 | ClusterIP | 7250/TCP,7260/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-router-3-nodeport | NodePort | 7250/TCP | 0 | 0 | 0 | 0 | 0 | 0 |
| orderer-router-4 | ClusterIP | 7350/TCP,7360/TCP | 0 | 0 | 2 | 0 | 0 | 0 |
| orderer-router-4-nodeport | NodePort | 7350/TCP | 0 | 0 | 0 | 0 | 0 | 0 |

## Lensa host forwards that still point INTO old namespaces (frontend/deploy/forwards.conf, names + ports only)
- iroha-bi      iroha3  bi     38080:8080
- iroha-bank-a  iroha3  bank-a 38081:8080
- iroha-bank-b  iroha3  bank-b 38082:8080
- iroha-bank-c  iroha3  bank-c 38083:8080
- iroha-auditor iroha3  bi-auditor 38090:8090
- fabricx-gw-1  fabricx fx-gw-1 39441:8443
- fabricx-gw-2  fabricx fx-gw-2 39442:8443
- fabricx-gw-3  fabricx fx-gw-3 39443:8443
- fabricx-gw-4  fabricx fx-gw-4 39444:8443

## LENSA_* endpoint variables of the running Lensa process (names + host:port only, no tokens)
- LENSA_GW_PALADIN_C -> https://47.236.100.234:8548
- LENSA_BESU_RPC -> http://127.0.0.1:38545
- LENSA_BESU_RPC_BANKS -> http://127.0.0.1:38546,http://127.0.0.1:38547,https://47.236.100.234:8545

## G3 archive candidates (PVCs of the old Iroha chain and the Fabric-X data)
- iroha3/bi-audit-store: 1Gi pv d-k1a1kmngclw2b0ngu31z reclaim Retain disk d-k1a1kmngclw2b0ngu31z
- iroha3/data-bank-a-0: 5Gi pv d-k1a7094jzxuwe01bf2m7 reclaim Retain disk d-k1a7094jzxuwe01bf2m7
- iroha3/data-bank-b-0: 5Gi pv d-k1a7vz34yzdadqejao3w reclaim Retain disk d-k1a7vz34yzdadqejao3w
- iroha3/data-bank-c-0: 5Gi pv d-k1a5bdhgh0tsc7e6b0xc reclaim Retain disk d-k1a5bdhgh0tsc7e6b0xc
- iroha3/data-bi-0: 5Gi pv d-k1a0v25u1ib2no3xqdog reclaim Retain disk d-k1a0v25u1ib2no3xqdog
- iroha3/runner-state-gha-runner-0: 1Gi pv d-k1a47701wm8t96weyp2k reclaim Retain disk d-k1a47701wm8t96weyp2k
- fabricx/data-block-explorer-db-0: 2Gi pv d-k1a9vurfxzwddtn1p2hu reclaim Retain disk d-k1a9vurfxzwddtn1p2hu
- fabricx/data-committer-db-0: 2Gi pv d-k1a9syy461gvnd65zjee reclaim Retain disk d-k1a9syy461gvnd65zjee
- fabricx/data-committer-sidecar-0: 2Gi pv d-k1a3tvwzj4oea2xoibyv reclaim Retain disk d-k1a3tvwzj4oea2xoibyv
- fabricx/data-fca-orderer-org1-db-0: 2Gi pv d-k1aen3t7wrqx7wn76dhx reclaim Retain disk d-k1aen3t7wrqx7wn76dhx
- fabricx/data-fca-orderer-org2-db-0: 2Gi pv d-k1a9vurfxzwdejag5t2n reclaim Retain disk d-k1a9vurfxzwdejag5t2n
- fabricx/data-fca-orderer-org3-db-0: 2Gi pv d-k1a327antokt6zrlukep reclaim Retain disk d-k1a327antokt6zrlukep
- fabricx/data-fca-orderer-org4-db-0: 2Gi pv d-k1a327antokt6zrlukgc reclaim Retain disk d-k1a327antokt6zrlukgc
- fabricx/data-fca-org1-db-0: 2Gi pv d-k1admrqwz5xfr8p3v27v reclaim Retain disk d-k1admrqwz5xfr8p3v27v
- fabricx/data-orderer-assembler-1-0: 2Gi pv d-k1aarlhphikpxjyx0u9p reclaim Retain disk d-k1aarlhphikpxjyx0u9p
- fabricx/data-orderer-assembler-2-0: 2Gi pv d-k1afs8wedv37t48xvty0 reclaim Retain disk d-k1afs8wedv37t48xvty0
- fabricx/data-orderer-assembler-3-0: 2Gi pv d-k1ahhlgjlun3452s58ni reclaim Retain disk d-k1ahhlgjlun3452s58ni
- fabricx/data-orderer-assembler-4-0: 2Gi pv d-k1a9vurfxzwddzk518kf reclaim Retain disk d-k1a9vurfxzwddzk518kf
- fabricx/data-orderer-batcher-1-0: 2Gi pv d-k1a6l7r3fv3kr0olqu4t reclaim Retain disk d-k1a6l7r3fv3kr0olqu4t
- fabricx/data-orderer-batcher-2-0: 2Gi pv d-k1ahsbhuxtubfk8agcy5 reclaim Retain disk d-k1ahsbhuxtubfk8agcy5
- fabricx/data-orderer-batcher-3-0: 2Gi pv d-k1aen3t7wrqx7guy9x2s reclaim Retain disk d-k1aen3t7wrqx7guy9x2s
- fabricx/data-orderer-batcher-4-0: 2Gi pv d-k1agzvylh2nw5hhzoli3 reclaim Retain disk d-k1agzvylh2nw5hhzoli3
- fabricx/data-orderer-consenter-1-0: 2Gi pv d-k1aismsh93tpl8kuan2k reclaim Retain disk d-k1aismsh93tpl8kuan2k
- fabricx/data-orderer-consenter-2-0: 2Gi pv d-k1a3mmggpxs65qnvdt76 reclaim Retain disk d-k1a3mmggpxs65qnvdt76
- fabricx/data-orderer-consenter-3-0: 2Gi pv d-k1agzvylh2nw5pe44tlj reclaim Retain disk d-k1agzvylh2nw5pe44tlj
- fabricx/data-orderer-consenter-4-0: 2Gi pv d-k1a70nqju0h8ybgkw44p reclaim Retain disk d-k1a70nqju0h8ybgkw44p
- fabricx/data-orderer-router-1-0: 2Gi pv d-k1a3tvwzj4oeaipxes8x reclaim Retain disk d-k1a3tvwzj4oeaipxes8x
- fabricx/data-orderer-router-2-0: 2Gi pv d-k1abj5hxiusikkc8wq8y reclaim Retain disk d-k1abj5hxiusikkc8wq8y
- fabricx/data-orderer-router-3-0: 2Gi pv d-k1agrktk6cjykel3o8hm reclaim Retain disk d-k1agrktk6cjykel3o8hm
- fabricx/data-orderer-router-4-0: 2Gi pv d-k1a3mmggpxs65smwhvcq reclaim Retain disk d-k1a3mmggpxs65smwhvcq
- fabricx/rdbi-bank2-state: 2Gi pv d-k1a58gwg4ljb26hm4ncy reclaim Retain disk d-k1a58gwg4ljb26hm4ncy
- fabricx/rdbi-bank3-state: 2Gi pv d-k1a1hcztihtweg5gd58t reclaim Retain disk d-k1a1hcztihtweg5gd58t
- fabricx/rdbi-bank4-state: 2Gi pv d-k1a7sja16a31jbij4d2w reclaim Retain disk d-k1a7sja16a31jbij4d2w
- fabricx/rdbi-bi-state: 2Gi pv d-k1ablv5sac95ospupvfs reclaim Retain disk d-k1ablv5sac95ospupvfs

## free-disk note
host `df -h /` and /home: /           295G  195G   89G  69% | /           295G  195G   89G  69%
sum of old-namespace PVC sizes (Gi): paladin 80, besu 160, iroha3 22, fabricx 56; total 318
reclaim policies of PVs bound to old namespaces: {'Retain': 44} (Delete = the disk is destroyed with the PVC; Retain = the disk survives until deleted by hand)
