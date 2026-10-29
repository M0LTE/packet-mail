#!/bin/bash
# Builds and starts the demo BBS container on 127.0.0.1:18111 for local tests.
# Pass extra docker options (for example -e DEMO_BBS_MAX_PER_IP=10) as arguments.
set -e
here=$(cd "$(dirname "$0")" && pwd)
docker build -q -t packet-mail-demo-bbs "$here" >/dev/null
docker rm -f packet-mail-demo-bbs >/dev/null 2>&1 || true
docker run -d --name packet-mail-demo-bbs \
  --read-only --cap-drop ALL --security-opt no-new-privileges --memory 128m --pids-limit 64 \
  -p 127.0.0.1:18111:8011 "$@" packet-mail-demo-bbs >/dev/null
for _ in $(seq 1 30); do
  if (echo > /dev/tcp/127.0.0.1/18111) 2>/dev/null; then echo "demo BBS up on 127.0.0.1:18111"; exit 0; fi
  sleep 1
done
docker logs packet-mail-demo-bbs
exit 1
