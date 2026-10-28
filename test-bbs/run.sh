#!/bin/sh
# Starts a fresh test BBS. State lives in a temporary directory, so every run starts clean.
set -e
here=$(cd "$(dirname "$0")" && pwd)
image=${LINBPQ_IMAGE:-m0lte/linbpq:6.0.26.1}
data=$(mktemp -d)
cp "$here/bpq32.cfg" "$here/linmail.cfg" "$data/"
chmod -R a+rwX "$data"
docker rm -f packet-mail-test-bbs >/dev/null 2>&1 || true
docker run -d --name packet-mail-test-bbs -v "$data:/data" \
  -p 127.0.0.1:18008:8008 -p 127.0.0.1:18010:8010 -p 127.0.0.1:18011:8011 \
  "$image" mail >/dev/null
for _ in $(seq 1 90); do
  if (echo > /dev/tcp/127.0.0.1/18011) 2>/dev/null; then echo "test BBS up ($data)"; exit 0; fi
  sleep 1
done
docker logs packet-mail-test-bbs
exit 1
