# final-design/verify: qa read-only verify harness

Owner: `qa`. Runs the read-only RED/GREEN rows of a VERIFY.md step and prints one block to paste into the GO report.

    export KUBECONFIG=~/.kube/alibaba.yaml          # cluster 1; the harness never writes
    python3 -I final-design/verify/verify.py <zeto|stealth|fabricx|iroha3> S1 --pre   # before the apply: namespaces absent
    python3 -I final-design/verify/verify.py <zeto|stealth|fabricx|iroha3> S1         # after the apply: GREEN rows
    # exit 0 = every row PASS, 1 = a row FAILED (the block says which)

S1 rows per track (VERIFY.md S1): namespace Active + label keys of that track (iroha3 uses the repo-style
`app.kubernetes.io/part-of`, `rd-iroha3/party`; fabricx also `pod-security.kubernetes.io/enforce=restricted`), exact
NetworkPolicy name set (zeto 4, stealth 3, fabricx 3, iroha3 1), service accounts, no leftovers, `auth can-i` as bank-a
`party-admin` (get pods other ns / get secrets own and bi ns = no, create secrets = yes, `create pods --subresource=exec` = no),
Role secrets verbs `[create, update, patch]`, no cluster-scoped RBAC by label; zeto adds the `allow-dns-egress` selector
`app NotIn (paladin)` and the `lensa-publisher` proxy check (`services/bundle-server --subresource=proxy`); iroha3 adds
PriorityClass `rd-iroha3-peer` = 10000, not default.

Secrets: only names are listed; the aliyun-acr-credential-helper addon puts 2 `acr-credential-*` dockerconfigjson Secrets in every new namespace (not ours),
any other Secret before S9 is a FAIL.

Gotchas learned in the L0 windows:
- `kubectl auth can-i create pods/exec` prints a misleading `yes`; use `create pods --subresource=exec`.
- `can-i get services/proxy` is `no` when the Role is restricted by `resourceNames`; name the service: `services/bundle-server --subresource=proxy`.
- A pod probe of `rehearsal-no-9000-egress` is a cluster write: owners apply it (rd-besu `zeto/k8s/render.sh probe-listeners` then `probe-pods`);
  qa only reads the pod logs. Valid lines: `OPEN` / `BLOCKED` (timeout). `REFUSED`, `ERROR`, `DNS-FAIL` are not results.

Only `S1` exists; add a step by adding a check function and a row in the VERIFY.md of that track.

L6 cutover plans (one end-to-end run per platform after L0-L5, `qa`): `L6-COMMON.md` (rules, Lensa API calls, templates), `zeto.md`, `noto-pente.md`, `stealth.md`, `fabricx.md`, `iroha3.md`. Live proof runs only after `lead` says "platform X ready for qa".
