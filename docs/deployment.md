# Deployment

Both servers run on one OARC container, `packet-mail-app.m0lte.compute.oarc.uk` (Debian 13, amd64). Log in as `debian`, which has sudo.

| What | Public address | Runs as |
|---|---|---|
| Demo BBS (`demo-bbs/`) | TCP `packet-mail-app.m0lte.compute.oarc.uk:8011` | systemd unit `demo-bbs` |
| Feedback receiver (`feedback-receiver/`) | `https://packet-mail-app.m0lte.compute.oarc.uk/v1/report` | systemd unit `feedback-receiver` on `127.0.0.1:8080`, behind nginx |
| Website (`site/`) | `https://packet-mail-app.m0lte.compute.oarc.uk/` | Static files in `/var/www/packet-mail`, served by nginx |

Port 80 only redirects to https. On 443, `/v1/report` goes to the receiver, `/healthz` (and `/health`) answer `ok`, and everything else is the website (404 for a file that isn't there).

There is no Docker on the box. Each service is the static binary from its Dockerfile, run by systemd with the same protections the READMEs ask of Docker: a throwaway unprivileged user (`DynamicUser=yes`), a read-only filesystem (`ProtectSystem=strict`), no capabilities, 128 MB of memory and 64 tasks at most. `Restart=always` brings them back after a crash, and both are enabled, so they start at boot.

## Files on the server

| Path | What |
|---|---|
| `/usr/local/lib/packet-mail/demo-bbs`, `feedback-receiver` | The binaries |
| `/usr/local/lib/packet-mail/REVISION` | The commit they were built from |
| `/etc/systemd/system/demo-bbs.service`, `feedback-receiver.service` | The units |
| `/etc/packet-mail/demo-bbs.env` | Demo BBS limits, written out at the README's defaults |
| `/etc/packet-mail/feedback.env` | The GitHub token. Root only, mode 600 |
| `/etc/nginx/sites-available/packet-mail-feedback` | TLS proxy, the website and the port 80 redirect (Debian's default site is disabled) |
| `/etc/nginx/snippets/packet-mail-site-headers.conf` | Security headers for the website only |
| `/var/www/packet-mail` | The website, a copy of `site/` |
| `/etc/certificates/post-hook.d/50-reload-nginx` | Reloads nginx after a certificate renewal |

## Logs

```sh
journalctl -u demo-bbs -f
journalctl -u feedback-receiver -f
journalctl -u nginx; sudo tail /var/log/nginx/error.log
```

Neither service logs mail, names, passwords or report contents (see the READMEs). nginx keeps no access log for the receiver.

## The certificate

OARC pushes the certificate in with `/usr/local/bin/fetch-certificate`, which writes `/etc/certificates/packet-mail-app.m0lte.compute.oarc.uk.{crt,key}` and runs the hooks in `pre-hook.d` and `post-hook.d` with `run-parts`. Nothing on the box asks for certificates itself, so port 80 isn't needed for renewal.

nginx reads the files directly. The post-hook `50-reload-nginx` checks the nginx configuration and reloads it, so the new certificate is served straight away; if nginx isn't running it does nothing. There is no pre-hook: nginx keeps serving the old certificate from memory until the reload. Hook names must not contain dots, or `run-parts` skips them.

## The GitHub token

The receiver needs a fine-grained GitHub token for `m0lte/packet-mail-feedback` only, with **Contents: read and write** and **Issues: read and write**. Until it has one, `feedback.env` holds a placeholder: the service runs and `/healthz` works, but GitHub refuses each report and the app is told 502, try again later.

To put the real token in:

```sh
sudo nano /etc/packet-mail/feedback.env    # replace PLACEHOLDER_NOT_A_TOKEN with the token
sudo systemctl restart feedback-receiver
journalctl -u feedback-receiver -n 5       # "listening on 127.0.0.1:8080"
```

Keep the file root-owned with mode 600. Never commit the token anywhere.

## The website

`site/` is plain HTML and CSS with no build step. To publish a change, from a checkout of master:

```sh
./deploy-site.sh
```

It copies `site/` to the server and swaps it into `/var/www/packet-mail` in one move. Nothing needs restarting.

nginx serves pages with a 5 minute cache and `/assets/` with a 1 day cache, so a changed stylesheet or picture can take a day to reach a returning visitor; give a changed asset a new file name if that matters. The security headers (a strict Content-Security-Policy with no scripts and nothing from other sites, HSTS, nosniff, no referrer) come from the snippet above and apply only to the website, not to the receiver.

The privacy page is `docs/privacy.md` as HTML. Change both together.

The fonts and pictures in `site/assets/` are made from the app's own:

- Fonts: `assets/fonts/*.ttf`, fixed at one optical size (Source Serif 4 at 20, Inter at 14), weights 400 to 700 only, cut to Latin characters and saved as WOFF2 with fontTools (`fonttools varLib.instancer`, then `pyftsubset --flavor=woff2`). The OFL licences go with them.
- Screenshots: `docs/store/screenshots/1080x1920/*.png` at half size as WebP (`magick in.png -resize 540x960 -strip -quality 82 out.webp`).
- Icons: `assets/icon/icon.png` resized to 32, 180, 192 and 512 pixels.

## Updating to a new version

Build on any amd64 machine with Docker, from the commit you want:

```sh
git fetch origin && git checkout origin/master
for s in demo-bbs feedback-receiver; do
  docker build -t packet-mail-$s $s
  id=$(docker create packet-mail-$s); docker cp $id:/$s ./$s; docker rm $id
done
scp demo-bbs feedback-receiver debian@packet-mail-app.m0lte.compute.oarc.uk:/tmp/
```

Then on the server:

```sh
sudo install -m 755 /tmp/demo-bbs /tmp/feedback-receiver /usr/local/lib/packet-mail/
echo <commit> | sudo tee /usr/local/lib/packet-mail/REVISION
sudo systemctl restart demo-bbs feedback-receiver
rm /tmp/demo-bbs /tmp/feedback-receiver
```

Restarting the demo BBS throws away every visitor's sandbox, which is harmless. Check afterwards with `curl https://packet-mail-app.m0lte.compute.oarc.uk/healthz` and `nc packet-mail-app.m0lte.compute.oarc.uk 8011`.

## Public address

Since 2026-10-29 the web side is reached as https://packet-mail.m0lte.uk through an OARC load balancer, which terminates TLS with its own Let's Encrypt certificate and forwards to this box. The site, privacy policy, support page and the app's report endpoint (`/v1/report`) all use that name. The box's own name, packet-mail-app.m0lte.compute.oarc.uk, still serves everything directly, which keeps older app builds working; the demo BBS (port 8011) is only on the box's own name, since the load balancer carries web traffic only.
