#!/bin/bash
# Starts a fresh test XRouter. State lives in a temporary directory, so every run starts clean.
set -e
here=$(cd "$(dirname "$0")" && pwd)
image=${XROUTER_IMAGE:-ghcr.io/packethacking/xrouter:505p-amd64}
data=$(mktemp -d)
cp "$here/XROUTER.CFG" "$here/ACCESS.SYS" "$here/USERPASS.SYS" "$data/"
chmod -R a+rwX "$data"
docker rm -f packet-mail-test-xrouter >/dev/null 2>&1 || true
docker run -d --name packet-mail-test-xrouter -v "$data:/data" \
  -p 127.0.0.1:18023:23 "$image" >/dev/null
for _ in $(seq 1 60); do
  if [ "$(docker inspect -f '{{.State.Running}}' packet-mail-test-xrouter)" != true ]; then break; fi
  if docker logs packet-mail-test-xrouter 2>&1 | grep -q 'version .* started' &&
    (echo > /dev/tcp/127.0.0.1/18023) 2>/dev/null; then
    echo "test XRouter up ($data)"
    exit 0
  fi
  sleep 1
done
docker logs packet-mail-test-xrouter
cat "$data/LOG/BOOTLOG.TXT" 2>/dev/null
exit 1
