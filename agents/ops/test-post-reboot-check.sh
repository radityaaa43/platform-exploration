#!/bin/bash
# Test for post-reboot-check.sh: fake systemctl/ss/kubectl on PATH, real local HTTP server for /api/health.
set -u
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d); trap 'kill $srv 2>/dev/null; rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/www/api" "$t/pods"
cat > "$t/forwards.conf" <<'C'
# name ns svc local:remote
alpha ns1 svc1 31001:80
beta  ns1 svc2 31002:80
C
cat > "$t/bin/systemctl" <<'C'
#!/bin/bash
case "$*" in
  *"show lensa.service"*) echo "$FAKE_WANTS" ;;
  *"is-active"*) u=${@: -1}; case " $FAKE_INACTIVE " in *" $u "*) echo inactive; exit 3;; esac; echo active ;;
esac
C
cat > "$t/bin/ss" <<'C'
#!/bin/bash
p=${@: -1}; p=${p##*:}
case " $FAKE_DOWN_PORTS " in *" $p "*) exit 0;; esac
echo "LISTEN 0 128 127.0.0.1:$p 0.0.0.0:*"
C
cat > "$t/bin/kubectl" <<'C'
#!/bin/bash
ns=$4; f="$FAKE_PODS/$ns.json"; [ -f "$f" ] || { echo "The connection was refused" >&2; exit 1; }; cat "$f"
C
chmod +x "$t/bin/"*
echo '{"items":[{"metadata":{"name":"p1"},"status":{"phase":"Running","conditions":[{"type":"Ready","status":"True"}]}},{"metadata":{"name":"job1"},"status":{"phase":"Succeeded","conditions":[{"type":"Ready","status":"False"}]}}]}' > "$t/pods/ns1.json"
good='{"models":{"zeto":{"ready":true},"noto":{"ready":true},"stealth":{"ready":true},"fabricx":{"ready":true},"iroha3":{"ready":true}}}'
echo "$good" > "$t/www/api/health"
python3 -I -u -m http.server 0 --bind 127.0.0.1 -d "$t/www" > "$t/srv.log" 2>&1 & srv=$!
for _ in $(seq 50); do port=$(grep -o 'port [0-9]*' "$t/srv.log" | head -1 | cut -d' ' -f2); [ -n "$port" ] && break; sleep 0.1; done

run() { env PATH="$t/bin:$PATH" FORWARDS="$t/forwards.conf" NAMESPACES="ns1" HEALTH_URL="http://127.0.0.1:$port/api/health" \
  FAKE_WANTS="lensa-pf@alpha.service lensa-pf@beta.service other.service" FAKE_PODS="$t/pods" "$@" bash "$here/post-reboot-check.sh"; }
fail=0
check() { # name, expected exit, grep pattern, env...
  local name=$1 want=$2 pat=$3; shift 3
  out=$(run "$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && echo "$out" | grep -qE "$pat"; then echo "ok   $name"; else echo "FAIL $name (rc=$rc want=$want pat=$pat)"; echo "$out" | sed 's/^/     /'; fail=1; fi
}
check all-pass 0 '^PASS forward lensa-pf@alpha' FAKE_INACTIVE= FAKE_DOWN_PORTS=
check wants-only-pf 0 '^PASS forwards 2/2' FAKE_INACTIVE= FAKE_DOWN_PORTS=
check unit-inactive 1 '^FAIL forward lensa-pf@beta' FAKE_INACTIVE=lensa-pf@beta.service FAKE_DOWN_PORTS=
check port-not-listening 1 '^FAIL forward lensa-pf@alpha.*31001' FAKE_INACTIVE= FAKE_DOWN_PORTS=31001
check lensa-inactive 1 '^FAIL lensa.service' FAKE_INACTIVE=lensa.service FAKE_DOWN_PORTS=
echo '{"models":{"zeto":{"ready":true},"noto":{"ready":false},"stealth":{"ready":true},"fabricx":{"ready":true},"iroha3":{"ready":true}}}' > "$t/www/api/health"
check platform-not-ready 1 '^FAIL health.*noto' FAKE_INACTIVE= FAKE_DOWN_PORTS=
echo "$good" > "$t/www/api/health"
echo '{"items":[{"metadata":{"name":"bad-0"},"status":{"phase":"Running","conditions":[{"type":"Ready","status":"False"}]}}]}' > "$t/pods/ns1.json"
check pod-notready 1 '^FAIL pods ns1.*bad-0' FAKE_INACTIVE= FAKE_DOWN_PORTS=
echo '{"items":[{"metadata":{"name":"old-job-x","ownerReferences":[{"kind":"Job"}]},"status":{"phase":"Failed"}},{"metadata":{"name":"ok-0"},"status":{"phase":"Running","conditions":[{"type":"Ready","status":"True"}]}}]}' > "$t/pods/ns1.json"
check failed-job-pod-ignored 0 '^PASS pods ns1' FAKE_INACTIVE= FAKE_DOWN_PORTS=
echo '{"items":[{"metadata":{"name":"dead-0","ownerReferences":[{"kind":"ReplicaSet"}]},"status":{"phase":"Failed"}}]}' > "$t/pods/ns1.json"
check failed-nonjob-pod 1 '^FAIL pods ns1.*dead-0' FAKE_INACTIVE= FAKE_DOWN_PORTS=
rm "$t/pods/ns1.json"
check kubectl-error 1 '^FAIL pods ns1' FAKE_INACTIVE= FAKE_DOWN_PORTS=
exit $fail
