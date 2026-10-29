#!/bin/sh
# Copy site/ to the server and swap it into /var/www/packet-mail.
# Usage: ./deploy-site.sh   (needs ssh access as debian@ the server)
set -eu
host=debian@packet-mail-app.m0lte.compute.oarc.uk
cd "$(dirname "$0")/site"
tar -czf - --owner=0 --group=0 . | ssh "$host" '
  set -eu
  sudo rm -rf /var/www/packet-mail.new /var/www/packet-mail.old
  sudo mkdir -p /var/www/packet-mail.new
  sudo tar -xzf - -C /var/www/packet-mail.new --no-same-owner
  sudo chmod -R u=rwX,go=rX /var/www/packet-mail.new
  if [ -d /var/www/packet-mail ]; then sudo mv /var/www/packet-mail /var/www/packet-mail.old; fi
  sudo mv /var/www/packet-mail.new /var/www/packet-mail
  sudo rm -rf /var/www/packet-mail.old
'
echo "Deployed. Check https://packet-mail-app.m0lte.compute.oarc.uk/"
