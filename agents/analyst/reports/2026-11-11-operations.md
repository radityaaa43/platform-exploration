REVIEW: operations @ besu@927f572 fabric-x@3f7caeb iroha3@e2a1794 frontend@aa6e09b   VERDICT: GAPS
Reviewer: analyst subagent (sonnet), read-only, live reads 2026-11-11 via `KUBECONFIG=alibaba.yaml kubectl get ...`.

FINDING: fabricx ns runs 34 containers with no requests/limits   SEVERITY: major   KIND: deviation
  PROJECT:  live ns fabricx (committer-*, orderer-*, fca-*, 5 postgres, block-explorer); fabric-x/NOTES.md:27-28 says committers and orderers are unmodified images. No manifest tracked in git; no LimitRange in ns fabricx.
  UPSTREAM: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ (set requests and limits). Ansible 0.8.26 resource defaults not read: unverified.
  EVIDENCE: `kubectl get pods -n fabricx -o json | jq '[.items[].spec.containers[]|select(.resources.limits==null)]|length'` -> 34. `kubectl get limitrange -A` lists only <foreign-ns> and paladin.
  FIX:      LimitRange in ns fabricx + resources in the (untracked) Ansible vars. Cluster write: user approval.   OWNER: fabric

FINDING: <foreign-ns> / <foreign-ns> / <foreign-ns> undocumented and unpinned by version   SEVERITY: major   KIND: drift
  PROJECT:  Three namespaces, 8 days old, 24 pods, label `fabricx-multiregion`. Images `ghcr.io/hyperledger/fabric-x-committer@sha256:4eb210e6...`, `fabric-x-orderer@sha256:de767c3f...`. fabric-x/NOTES.md:9-10 pins 1.0.4 and covers only ns fabricx. Only repo mention: fabric-x/opa/DESIGN.md:18.
  UPSTREAM: fabric-x/NOTES.md:9 (hyperledger/fabric-x-committer v1.0.4, 08a469d2).
  EVIDENCE: committer digest in fabricx is `sha256:b5bc4c6c...` (tag 1.0.4); in <foreign-ns> it is `sha256:4eb210e6...`, version unknown.
  FIX:      Record owner, version, purpose of the three namespaces in NOTES.md, or confirm they belong to another team.   OWNER: fabric

FINDING: Fabric-X liveness/readiness gaps   SEVERITY: major   KIND: deviation
  PROJECT:  ns fabricx: rdbi-bank2/3/4 (8 containers each) and rdbi-bi (FSC node, endorser, committer-*, db) have no probes. fx-gw-1..4 envoy and fxapi have no liveness probe. <foreign-ns>/bank-a/bank-b committer and orderer: readiness only.
  UPSTREAM: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/. committer/orderer health endpoint defaults not read: unverified.
  EVIDENCE: `kubectl get pods -n fabricx -o json | jq ...` -> `committer-verifier|lim=true|live=false|ready=false`; same live=false for committer and orderer in <foreign-ns>.
  FIX:      TCP or gRPC health probe on rdbi-* containers; liveness on multiregion committers and orderers.   OWNER: fabric

FINDING: Backups and monitoring are thin   SEVERITY: major   KIND: deviation
  PROJECT:  Backups cover CRs only (besu/zeto/ops/backup-pld-node1..4-*.yaml, besu/noto+pente/ops/resources/backup-node1..4-*.yaml, Fabric-X rollout backups). No data backup, no restore procedure (TEAM.md:216-231 states the gate only). No Prometheus/ServiceMonitor. agents/ops/post-reboot-check.sh exists; TEAM.md §10 marks it PLANNED. The 2Gi PVC shrink is undocumented in git.
  UPSTREAM: https://kubernetes.io/docs/concepts/storage/volume-snapshots/ (generic practice, not a project requirement).
  EVIDENCE: `kubectl get cronjob,volumesnapshot -A` -> "No resources found". `kubectl get servicemonitor,prometheusrule -A` -> "the server doesn't have a resource type". `grep -rnE '2Gi|shrunk|monitoring' fabric-x/NOTES.md agents/TEAM.md` -> no hit.
  FIX:      Short "Backup/Monitoring: absent by decision" note in TEAM.md. alicloud-essd and fabricx-essd have allowVolumeExpansion=true.   OWNER: lead

FINDING: Manual `kubectl set image` is the Fabric-X rollout path; images mixed digest and tag   SEVERITY: minor   KIND: accepted
  PROJECT:  fabric-x/NOTES.md:44 `kubectl -n fabricx set image deploy/rdbi-bankN ...`. Backups in besu/zeto/out/fabricx-award-rollout-20261103T045711Z/. Deployments use `strategy: Recreate` (NOTES.md:52).
  UPSTREAM: Ansible collection 0.8.26 (playbook apply). Not diffed: unverified.
  EVIDENCE: live `bank2` = `rdbi-node@sha256:71e3b678...`; `endorser-2` = `rdbi-node:ebbb28f1d552`; matches NOTES.md:38-41.
  FIX:      State in NOTES that `set image` is an approved deviation; fold digests into manifest source.   OWNER: fabric

FINDING: Paladin: CM image = STS image; probes are operator defaults   SEVERITY: minor   KIND: accepted
  PROJECT:  CM `paladin-operator` config.json `paladin.image = ghcr.io/radityaaa43/paladin@sha256:6f113f38...`; all 4 STS same digest; operator `lfdecentralizedtrust/paladin-operator:v1.0.0`. Liveness `pidof java` (period 2s, timeout 1s), readiness tcp 8548. Postgres tcp liveness, no readiness. Limits come from LimitRange `paladin-defaults` (cpu 3, mem 4Gi); STS `resources: {}`.
  UPSTREAM: local clone operator-1.0.0-rc.12-322-g4ab578f3a `operator/internal/controller/paladin_controller.go:434-440` (`pidof java` probe). Not the v1.0.0 tag: unverified vs tag.
  EVIDENCE: `kubectl get sts -n paladin ... image` -> `sha256:6f113f3829fe` on all 4. Restarts last 24h: 0 in paladin, besu, fabricx*, iroha3. Memory's exit-137 crash loop not reproduced today.
  FIX:      None for images. Keep the LimitRange dependency documented.   OWNER: besu

FINDING: Besu: `busybox` initContainer untagged; validators lack readiness probe   SEVERITY: minor   KIND: deviation
  PROJECT:  live ns besu: init `volume-permission-besu` image `busybox` (resolves to latest), no limits. `hyperledger/besu:26.8.1` pinned. Liveness `/liveness:8545` initialDelay 180s period 60s; no readinessProbe. Chart not tracked in git (`git grep busybox` in besu hits only opa/README.md).
  UPSTREAM: https://kubernetes.io/docs/concepts/containers/images/ (avoid `:latest`). qgt-0.2.20 chart defaults not read: unverified.
  EVIDENCE: `kubectl get pods -n besu -o json | jq ...` -> `besu-node-validator-1-0|volume-permission-besu|busybox|lim=false|req=false|live=false|ready=false`.
  FIX:      Pin busybox tag in Helm values; readiness probe on the besu port.   OWNER: besu

FINDING: Secrets hygiene clean in git; two caveats   SEVERITY: minor   KIND: accepted
  PROJECT:  `git log --all -p -S 'PRIVATE KEY'` empty in root, besu, fabric-x, frontend, iroha3. `git grep BEGIN ... PRIVATE KEY` empty in all five. `alibaba.yaml`, `.env` ignored everywhere. Caveat 1: besu/stealth-address/ts/stealth.test.ts:13 literal privateKey (`0x32074def70...`), looks like a fixture. Caveat 2: backup-pld-*.yaml tracked, contain secretName references only; values not checked.
  UPSTREAM: TEAM.md:218 ("Secrets never enter Git").
  EVIDENCE: `git -C besu grep -nIiE 'private[_-]?key...' HEAD` -> `HEAD:stealth-address/ts/stealth.test.ts:13: privateKey: '0x32074def70`.
  FIX:      Confirm the stealth test key is a throwaway.   OWNER: besu

No finding:
- Iroha 3 manifests match live: `iroha3-rd-node:071e281e-stark` in deploy/k8s/base/statefulset.yaml:40 and on the live STS. Live probes are /livez and /readyz, timeoutSeconds 3 (memory says /health: memory is stale).
- Iroha 3 resources cpu 250m/2, mem 1Gi/3Gi; PVCs 5Gi. /storage usage vs 80%: unverified (no exec).
- Besu PVCs 40Gi; Paladin pgdata 20Gi.
- kaleido ns out of scope: 5 pods > 18,000 restarts, last 26-27 days ago, 0 in last 24h.

SOURCES:
- Live: `KUBECONFIG=alibaba.yaml kubectl get pods|sts|pvc|cm|limitrange|sc|cronjob|pdb -A`, `kubectl top`, 2026-11-11.
- iroha3@e2a1794:deploy/k8s/base/statefulset.yaml:36-100
- fabric-x/NOTES.md:9-11, 14, 27-29, 38-52
- agents/TEAM.md:216-231, 313-340
- /home/ecs-user/eksplorasi-paladin/paladin (operator-1.0.0-rc.12-322-g4ab578f3a) operator/internal/controller/paladin_controller.go:434-440
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- https://kubernetes.io/docs/concepts/containers/images/
- https://kubernetes.io/docs/concepts/storage/volume-snapshots/

UNVERIFIED:
- Upstream v1.0.0 operator probe defaults (clone is rc.12-322, not the tag).
- Ansible 0.8.26 and committer/orderer 1.0.4 resource and health-endpoint defaults.
- <foreign-ns>/bank-a/bank-b image version (digest unlabelled).
- Iroha /storage usage.
- "PVCs shrunk to 2Gi on 2026-10-21": live shows 2Gi on fabricx PVCs, no doc in git.
- qgt-0.2.20 chart defaults; backup-pld-*.yaml secret values.
- ghcr.io/radityaaa43/* image provenance (digest/tag vs stated commit not checked).
