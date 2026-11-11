#!/bin/bash
# Post-reboot check (TEAM.md §10 item 1). READ-ONLY: no restart, no enable, no write.
# One line per item: "PASS|FAIL <item> <detail>". Exit 1 if any FAIL.
# Env (all optional): FORWARDS (forwards.conf path), NAMESPACES, HEALTH_URL, PLATFORMS. KUBECONFIG comes from the env and is never printed.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
FORWARDS=${FORWARDS:-$root/frontend/deploy/forwards.conf}
NAMESPACES=${NAMESPACES:-paladin iroha3 fabricx}
HEALTH_URL=${HEALTH_URL:-http://127.0.0.1:${PORT:-8790}/api/health}
PLATFORMS=${PLATFORMS:-zeto noto stealth fabricx iroha3}
rc=0
res() { echo "$1 $2 $3"; [ "$1" = PASS ] || rc=1; }

# 1. lensa.service
if [ "$(systemctl --user is-active lensa.service 2>/dev/null)" = active ]; then res PASS lensa.service active; else res FAIL lensa.service "not active"; fi

# 2. every lensa-pf@ in lensa.service Wants=: unit active and local port listening
units=$(systemctl --user show lensa.service -p Wants --value 2>/dev/null | tr ' ' '\n' | grep '^lensa-pf@')
n=0; bad=0
for u in $units; do
  n=$((n + 1)); name=${u#lensa-pf@}; name=${name%.service}
  port=$(awk -v n="$name" '$1 == n {split($4, a, ":"); print a[1]}' "$FORWARDS")
  if [ -z "$port" ]; then res FAIL "forward $u" "no entry in forwards.conf"; bad=$((bad + 1)); continue; fi
  if [ "$(systemctl --user is-active "$u" 2>/dev/null)" != active ]; then res FAIL "forward $u" "unit not active (port $port)"; bad=$((bad + 1)); continue; fi
  if [ -z "$(ss -Hltn "sport = :$port" 2>/dev/null)" ]; then res FAIL "forward $u" "port $port not listening"; bad=$((bad + 1)); continue; fi
  res PASS "forward $u" "port $port"
done
if [ "$n" -eq 0 ]; then res FAIL forwards "no lensa-pf@ in lensa.service Wants="
elif [ "$bad" -eq 0 ]; then res PASS forwards "$n/$n"
else res FAIL forwards "$((n - bad))/$n"; fi

# 3. Lensa /api/health: every platform ready
out=$(python3 -I - "$HEALTH_URL" $PLATFORMS <<'P' 2>&1
import json, sys, urllib.request
try:
    m = json.load(urllib.request.urlopen(sys.argv[1], timeout=10))["models"]
except Exception as e:
    print("unreachable: " + type(e).__name__); sys.exit(1)
bad = [p for p in sys.argv[2:] if not m.get(p, {}).get("ready")]
print("not ready: " + " ".join(bad) if bad else "all ready: " + " ".join(sys.argv[2:])); sys.exit(1 if bad else 0)
P
) && res PASS health "$out" || res FAIL health "$out"

# 4. no pod NotReady (skipped: Succeeded pods and Failed pods of a finished Job)
for ns in $NAMESPACES; do
  out=$(kubectl get pods -n "$ns" -o json 2>&1 | python3 -I -c '
import json, sys
try:
    items = json.load(sys.stdin)["items"]
except Exception:
    print("kubectl error"); sys.exit(1)
done = lambda i: i["status"].get("phase") == "Succeeded" or (i["status"].get("phase") == "Failed"
       and any(o.get("kind") == "Job" for o in i["metadata"].get("ownerReferences", [])))
bad = [i["metadata"]["name"] for i in items if not done(i)
       and not any(c["type"] == "Ready" and c["status"] == "True" for c in i["status"].get("conditions", []))]
print("NotReady: " + " ".join(bad) if bad else str(len(items)) + " pods ok"); sys.exit(1 if bad else 0)
') && res PASS "pods $ns" "$out" || res FAIL "pods $ns" "$out"
done
exit $rc
