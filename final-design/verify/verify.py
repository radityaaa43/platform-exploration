#!/usr/bin/env python3
"""qa read-only verify harness: S1 (namespaces + RBAC + netpol) of one track on cluster 1.

usage: verify.py <zeto|stealth|fabricx|iroha3> S1 [--pre] [--kubeconfig FILE]
  --pre   expect the namespaces (and iroha3's PriorityClass) NOT to exist yet; otherwise expect the GREEN state.
Prints one block to paste into the GO report: UTC time, every check with the quoted output, PASS/FAIL.
Exit 0 = all checks passed, 1 = at least one failed. Only get / auth can-i; never prints Secret data.
"""
import json, os, subprocess, sys, time

PARTIES = ("bi", "bank-a", "bank-b")
LAB = "app.kubernetes.io/part-of"
TRACKS = {  # prefix, ns label selector key for "part of", netpols, extra labels per party, extra ns label
    "zeto": dict(part=("part-of", "rd-zeto"), party_key="party", netpols={"allow-dns-egress", "allow-same-namespace", "default-deny-ingress", "rehearsal-no-9000-egress"}),
    "stealth": dict(part=("part-of", "rd-stealth"), party_key="party", netpols={"allow-dns-egress", "allow-same-namespace", "default-deny-ingress"}),
    "fabricx": dict(part=("part-of", "rd-fabricx"), party_key="party", netpols={"allow-dns-egress", "allow-same-namespace", "default-deny-ingress"},
                    extra_ns={"pod-security.kubernetes.io/enforce": "restricted"}),
    "iroha3": dict(part=(LAB, "rd-iroha3"), party_key="rd-iroha3/party", netpols={"default-deny-ingress"}, priorityclass=("rd-iroha3-peer", 10000)),
}
results = []


def kubectl(*args):
    p = subprocess.run(["kubectl", *args], capture_output=True, text=True, timeout=60)
    return (p.stdout + p.stderr).strip(), p.returncode


def check(name, ok, got):
    results.append(ok)
    print(f"  {'PASS' if ok else 'FAIL'} {name}: {got}")


def get_json(*args):
    out, rc = kubectl(*args, "-o", "json")
    return (json.loads(out) if rc == 0 else None), out


def can_i(ns, sa_ns, verb, resource, *extra):
    out, _ = kubectl("-n", ns, "auth", "can-i", verb, resource, *extra, "--as", f"system:serviceaccount:{sa_ns}:party-admin")
    return out.splitlines()[-1] if out else ""


def main():
    a = [x for x in sys.argv[1:]]
    pre = "--pre" in a
    if "--kubeconfig" in a:
        os.environ["KUBECONFIG"] = a[a.index("--kubeconfig") + 1]
    pos = [x for x in a if not x.startswith("--") and x != os.environ.get("KUBECONFIG")]
    if len(pos) != 2 or pos[0] not in TRACKS or pos[1] != "S1":
        sys.exit(__doc__)
    track = pos[0]
    t = TRACKS[track]
    prefix = f"rd-{track}-"
    print(f"{'PRE' if pre else 'VERIFY'} {track} S1 {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}")
    pk, pv = t["part"]
    for p in PARTIES:
        ns = prefix + p
        d, out = get_json("get", "ns", ns)
        if pre:
            check(f"{ns} absent", d is None and "NotFound" in out, out.splitlines()[-1])
            continue
        if d is None:
            check(f"{ns} Active", False, out.splitlines()[-1])
            continue
        lab = d["metadata"].get("labels", {})
        want = {pk: pv, t["party_key"]: p, **t.get("extra_ns", {})}
        check(f"{ns} Active + labels", d["status"]["phase"] == "Active" and all(lab.get(k) == v for k, v in want.items()),
              f"{d['status']['phase']} " + " ".join(f"{k}={lab.get(k)}" for k in want))
        np_, _ = get_json("-n", ns, "get", "netpol")
        names = {i["metadata"]["name"] for i in np_["items"]}
        check(f"{ns} netpol count {len(t['netpols'])}", names == t["netpols"], f"{len(names)}: {' '.join(sorted(names))}")
        sa, _ = get_json("-n", ns, "get", "sa")
        sas = {i["metadata"]["name"] for i in sa["items"]} - {"default"}
        wsa = {"party-admin"} | ({"lensa-publisher"} if track == "zeto" and p == "bi" else set())
        check(f"{ns} service accounts", sas == wsa, " ".join(sorted(sas)))
        left = 0
        for kind in ("deploy", "sts", "pod", "pvc", "svc"):
            o, _ = get_json("-n", ns, "get", kind)
            left += len(o["items"]) if o else 0
        check(f"{ns} leftovers (deploy/sts/pod/pvc/svc)", left == 0, str(left))
        # names only, never data. The aliyun-acr-credential-helper addon adds 2 acr-credential-* dockerconfigjson Secrets per new ns (not ours).
        out, _ = kubectl("-n", ns, "get", "secret", "-o", "name")
        secs = [s.split("/", 1)[-1] for s in out.splitlines() if s]
        extra = [s for s in secs if not s.startswith("acr-credential-")]
        check(f"{ns} secrets (names; acr-credential-* are the addon's)", not extra, " ".join(secs) or "none")
    if track == "iroha3":
        name, val = t["priorityclass"]
        d, out = get_json("get", "priorityclass", name)
        if pre:
            check(f"priorityclass {name} absent", d is None and "NotFound" in out, out.splitlines()[-1])
        else:
            check(f"priorityclass {name}", bool(d) and d.get("value") == val and not d.get("globalDefault"),
                  f"value={d and d.get('value')} globalDefault={d and d.get('globalDefault')}")
    if pre:
        return
    A, B, BI = prefix + "bank-a", prefix + "bank-b", prefix + "bi"
    for desc, ns2, verb, res, extra, want in [
        ("get pods in another party ns", B, "get", "pods", [], "no"),
        ("get secrets in own ns", A, "get", "secrets", [], "no"),
        ("get secrets in bi ns", BI, "get", "secrets", [], "no"),
        ("create secrets in own ns", A, "create", "secrets", [], "yes"),
        ("create pods --subresource=exec", A, "create", "pods", ["--subresource=exec"], "no"),
    ]:
        got = can_i(A, A, verb, res, "-n", ns2, *extra)
        check(f"can-i as {A} party-admin: {desc}", got == want, got)
    role, _ = get_json("-n", A, "get", "role", "party-admin")
    sec = [r["verbs"] for r in role["rules"] if "secrets" in r["resources"]] if role else []
    check("Role secrets verbs", len(sec) == 1 and sorted(sec[0]) == ["create", "patch", "update"], str(sec))
    if track == "zeto":
        np_, _ = get_json("-n", A, "get", "netpol", "allow-dns-egress")
        sel = np_["spec"]["podSelector"] if np_ else None
        ok = sel == {"matchExpressions": [{"key": "app", "operator": "NotIn", "values": ["paladin"]}]}
        check("allow-dns-egress selects app NotIn (paladin)", ok, json.dumps(sel))
        out, _ = kubectl("-n", BI, "auth", "can-i", "get", "services/bundle-server", "--subresource=proxy", "-n", BI,
                         "--as", f"system:serviceaccount:{BI}:lensa-publisher")
        check("can-i as lensa-publisher: get services/bundle-server --subresource=proxy", out.splitlines()[-1] == "yes", out.splitlines()[-1])
    cs, _ = kubectl("get", "clusterrole,clusterrolebinding", "-l", f"{pk}={pv}", "--no-headers")
    check("cluster-scoped RBAC objects by label", cs == "No resources found", cs or "none")
    print("RESULT", "PASS" if all(results) else "FAIL")


if __name__ == "__main__":
    main()
    sys.exit(0 if all(results) else 1)
