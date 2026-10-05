---
name: kandr-dns
description: Authoritative DNS for kandr.io on Cloudflare (full setup, Free). Use when adding or changing a DNS record, pointing a new *.kandr.io hostname at Firebase Hosting or Cloud Run, debugging kandr.io DNS, or creating A/AAAA/CNAME/MX/TXT records. Do not use Route 53 hosted zone Z5Q853FSJIIQT for writes — that zone is rollback-only.
---

# kandr-dns

Authoritative DNS for `kandr.io` is **Cloudflare** (full setup, Free). Do not use Route 53
hosted zone `Z5Q853FSJIIQT` for writes. Registrar stays **Route 53 Registered domains**
(`rlibbey@gmail.com`) — do not change nameservers, transfer lock, or registrar from this
skill.

## Zone

| Setting | Value |
|---|---|
| Zone | `kandr.io` (full setup, Free) |
| Zone ID | `6586a47fb64386dd05f01baa20b30892` |
| Nameservers | `rafe.ns.cloudflare.com`, `yisroel.ns.cloudflare.com` |
| Flatten all CNAMEs | off |
| DNSSEC | off (do not enable) |
| Email Routing | **never** on this zone (conflicts with Google MX) |
| Email Sending | `cf-bounce` selector / `cf-bounce.kandr.io` return-path only |
| Retired Route 53 zone | `Z5Q853FSJIIQT` — rollback only, no writes |

## Auth

Use `CLOUDFLARE_API_TOKEN` (Zone DNS Edit). Use `CLOUDFLARE_ACCOUNT_ID` only when an
account-scoped API needs it (not for `POST /zones/:id/dns_records`).

**Cursor Runtime Secrets inject these on Cursor-hosted cloud VMs only.** They do **not**
inject on My Machines or self-hosted workers. If the token is missing there, stop and say
so — do not invent a value.

Never print token values. Never overwrite `CLOUDFLARE_API_TOKEN`.

```bash
# Token must already be in the environment. Do not echo it.
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
ZONE_ID=6586a47fb64386dd05f01baa20b30892
```

## Grey-cloud (DNS-only) is the default

Add A/AAAA/CNAME as **DNS-only** (`proxied: false`) unless Ryan asks to proxy. MX, TXT, and
DKIM / SendGrid CNAMEs are always DNS-only.

| Record class | Proxy | Why |
|---|---|---|
| MX (all) | DNS-only (forced) | SMTP is not proxied. Email Routing must stay off. |
| TXT (SPF, DMARC, DKIM, `hosting-site=`, Google verify, ACME) | DNS-only (forced) | Verification and mail auth |
| DKIM / SendGrid CNAMEs | DNS-only | Must return the CNAME, not a flattened A |
| Firebase A / CNAME | DNS-only | Lets Firebase keep seeing `199.36.158.100` / `*.web.app` |
| Cloud Run (`restore` → `ghs.googlehosted.com`) | DNS-only | Mapped domain |
| `streaming` / `streaming-dev` A `3.19.159.96` | DNS-only | Unknown AWS origin — do not proxy |
| Future `mercury.kandr.io` | DNS-only unless Ryan wants CF in front of the VM | Replaces the old `sslip.io` workaround |

Do not orange-cloud Firebase or Cloud Run hostnames unless Ryan asks. Do not enable
Cloudflare Email Routing. Do not add Email Sending DNS beyond the existing `cf-bounce`
records.

## Add a subdomain

Firebase custom-domain API first (`kandr-firebase`), then one grey CNAME or A on Cloudflare.
No AWS.

### API

```bash
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
ZONE_ID=6586a47fb64386dd05f01baa20b30892

curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "{subdomain}.kandr.io",
    "content": "{siteId}.web.app",
    "ttl": 300,
    "proxied": false
  }'
```

Apex / IPv4 Firebase hostnames use A `199.36.158.100` plus the `hosting-site=` and ACME TXT
records Firebase returns — still `proxied: false`.

### Dashboard

Cloudflare → `kandr.io` → **DNS** → **Add record**. Type CNAME (or A). Name =
`{subdomain}`. Target = `{siteId}.web.app` (or `199.36.158.100`). Proxy status **DNS only**
(grey cloud). Save.

## Product hostnames (do not invent missing ones)

| Hostname | Type | Target |
|---|---|---|
| `kandr.io` | A | `199.36.158.100` (Firebase `kandr-io` on `rlibbey-pocs`) |
| `www.kandr.io` | CNAME | `kandr-io.web.app` |
| `faithmusic.kandr.io` | A | `199.36.158.100` |
| `admin.faithmusic.kandr.io` | CNAME | `streamingapp-32dcb-e9588.web.app` |
| `radio.kandr.io` | A | `199.36.158.100` |
| `restore.kandr.io` | CNAME | `ghs.googlehosted.com` |
| `myfish.kandr.io` | CNAME | `fishon-kandr-app.web.app` |
| `yardsale.kandr.io` | CNAME | `yard-sale-marketing.web.app` |
| `waypoint.kandr.io` | CNAME | `waypoint-marketing.web.app` |
| `admin.waypoint.kandr.io` | CNAME | `waypoint-kandr-app.web.app` |
| `superadmin.waypoint.kandr.io` | CNAME | `waypoint-superadmin.web.app` |
| `beacon.kandr.io` | CNAME | `beacon-portal.web.app` |
| `relay.kandr.io` | CNAME | `relay-kandr-app.web.app` |
| `blueprint.kandr.io` | CNAME | `blueprint-kandr.web.app` |
| `greenlight.kandr.io` / `apex` / `app` / `btw` | CNAME | `greenlight-drive.web.app` |
| `altbau.kandr.io` | CNAME | `altbau-kandr.web.app` |
| `plan.kandr.io` | CNAME | `capplan-v2.web.app` |
| `reach.kandr.io` | CNAME | `kandr-crm-app.web.app` |
| `trips.kandr.io` | CNAME | `libbey-europe-trip-2026.web.app` |
| `faithmusicmissions.kandr.io` | A | Fastly pair `151.101.1.195`, `151.101.65.195` |
| `streaming.kandr.io` / `streaming-dev.kandr.io` | A | `3.19.159.96` (AWS — confirm before any change) |

**Not on this zone** (do not create unless Ryan asks): `crm.kandr.io`, `phoenix.kandr.io`,
`admin.kandr.io`, `portal.kandr.io`, `share.kandr.io`, `clawd.kandr.io`. Shares are paths on
the apex (`/share/<slug>`), not a hostname.

Apex MX is Google Workspace 1/5/10 plus SES inbound 15. Do **not** touch MX. Mail records
stay DNS-only — see `kandr-email`.

## Related

- AWS CLI / SES / leftover EC2 → `kandr-aws` (not DNS writes)
- Firebase custom domain API → `kandr-firebase`
- App senders / inboxes → `kandr-email`
