#!/bin/bash
# Starts a fresh test XRouter. State lives in a temporary directory, so every run starts clean.
#   ./run.sh       the default mailbox (PMSTYPE 1), telnet on 127.0.0.1:18023
#   ./run.sh bbs   a full BBS (PMSTYPE=4), telnet on 127.0.0.1:18024
set -e
here=$(cd "$(dirname "$0")" && pwd)
image=${XROUTER_IMAGE:-ghcr.io/packethacking/xrouter:505p-amd64}
name=packet-mail-test-xrouter
port=18023
if [ "$1" = bbs ]; then name=packet-mail-test-xrouter-bbs; port=18024; fi
data=$(mktemp -d)
cp "$here/XROUTER.CFG" "$here/ACCESS.SYS" "$here/USERPASS.SYS" "$data/"
if [ "$1" = bbs ]; then sed -i 's/^PMSCALL=/PMSTYPE=4\nPMSCALL=/' "$data/XROUTER.CFG"; fi
chmod -R a+rwX "$data"
docker rm -f $name >/dev/null 2>&1 || true
docker run -d --name $name -v "$data:/data" \
  -p 127.0.0.1:$port:23 "$image" >/dev/null
for _ in $(seq 1 60); do
  if [ "$(docker inspect -f '{{.State.Running}}' $name)" != true ]; then break; fi
  if docker logs $name 2>&1 | grep -q 'version .* started' &&
    (echo > /dev/tcp/127.0.0.1/$port) 2>/dev/null; then
    echo "test XRouter up on port $port ($data)"
    exit 0
  fi
  sleep 1
done
docker logs $name
cat "$data/LOG/BOOTLOG.TXT" 2>/dev/null
exit 1
