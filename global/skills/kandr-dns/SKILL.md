---
name: kandr-dns
description: Authoritative DNS for kandr.io on Cloudflare (full setup, Free). Use when adding or changing a DNS record, pointing a new *.kandr.io hostname at Firebase Hosting or Cloud Run, debugging kandr.io DNS, or deciding proxy vs DNS-only. Do not use for AWS CLI, SES, or leftover EC2 — that is kandr-aws.
---

# kandr-dns

Authoritative DNS for `kandr.io` is **Cloudflare** (full setup, Free). Public NS are
`rafe.ns.cloudflare.com` / `yisroel.ns.cloudflare.com`.

Do **not** write the Route 53 hosted zone `Z5Q853FSJIIQT`. That zone is rollback-only. The
registrar is still **Route 53 Registered domains** (`rlibbey@gmail.com`) — do not change
nameservers, transfer, or unlock from here.

## Zone

| Setting | Value |
|---|---|
| Zone | `kandr.io` (full setup, Free) |
| Zone ID | `6586a47fb64386dd05f01baa20b30892` |
| Plan | Free Website |
| Flatten all CNAMEs | **off** |
| DNSSEC | **off** — do not enable |
| Email Routing | **off** — never enable (conflicts with Google MX) |
| Email Sending | Onboarded with selector `cf-bounce` / return-path `cf-bounce.kandr.io` only |

## Tokens

| Name | Used for |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Zone DNS (`GET`/`POST`/`PATCH` `/zones/:id/dns_records`) |
| `CLOUDFLARE_ACCOUNT_ID` | Account-scoped APIs only (e.g. Email Sending limits). Not required to add a record. |

Cursor Runtime Secrets inject these names on **Cursor-hosted cloud VMs only**. They do **not**
inject on My Machines or self-hosted workers. On a laptop, use the dashboard or a local export —
never commit the values.

Never print token values. Never overwrite `CLOUDFLARE_API_TOKEN`.

```bash
# Confirm the token is present without printing it
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] && echo "CLOUDFLARE_API_TOKEN is set"

ZONE_ID=6586a47fb64386dd05f01baa20b30892
# or: curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
#   "https://api.cloudflare.com/client/v4/zones?name=kandr.io"
```

## Proxy (grey-cloud default)

Start every new record **DNS-only** (`proxied: false`). Orange-cloud only if Ryan asks.

| Record class | Proxy | Why |
|---|---|---|
| MX (all) | DNS-only (forced) | SMTP is not proxied. Email Routing must stay off. |
| TXT (SPF, DMARC, DKIM, `hosting-site=`, Google verify, ACME) | DNS-only (forced) | Verification and mail auth |
| DKIM / SendGrid CNAMEs | DNS-only | Must return the CNAME, not a flattened A |
| Firebase A / CNAME | DNS-only | Firebase/Google cert checks see the real origin |
| Cloud Run (`restore` → `ghs.googlehosted.com`) | DNS-only | Mapped domain |
| Unknown A (`streaming`, `streaming-dev`, Fastly pair) | DNS-only | Do not proxy until the origin is identified |

Firebase hostnames: CNAME `{name}` → `{site}.web.app`, or A `199.36.158.100`, plus
`hosting-site=` / ACME TXT as Firebase returns. See `kandr-firebase` for the custom-domain API.

## Never on this zone

- Enable **Email Routing** (would replace apex Google MX and break `ryan@` / `info@`)
- Put Email Sending MX/SPF/DKIM on the **apex** — Sending stays on `cf-bounce` only
- Write Route 53 hosted zone `Z5Q853FSJIIQT`
- Change registrar nameservers
- Enable DNSSEC or flatten-all CNAMEs
- Orange-cloud mail or verify records

Mail policy: `kandr-email`. AgentMail stays the app sender.

## Add a subdomain

Check the hostname table below before creating anything. Then add Firebase's custom domain
(`kandr-firebase`) **and** one grey record here. No AWS.

### API

```bash
# CNAME → Firebase Hosting (typical)
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/6586a47fb64386dd05f01baa20b30892/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "{subdomain}",
    "content": "{siteId}.web.app",
    "ttl": 300,
    "proxied": false
  }'

# Apex-style A (Firebase IPv4)
# "type": "A", "name": "{subdomain}", "content": "199.36.158.100", "ttl": 300, "proxied": false
```

`proxied` must be `false` unless Ryan asks to proxy.

### Dashboard

Cloudflare → **kandr.io** → **DNS** → **Records** → **Add record**. Type CNAME (or A), name
`{subdomain}`, target `{siteId}.web.app` (or `199.36.158.100`), proxy status **DNS only**
(grey cloud). Save. Do not use the Email Routing wizard.

## Hostnames already on this zone

Do not modify these without checking live records first.

| Hostname | Type | Target / notes |
|---|---|---|
| `kandr.io` | A | `199.36.158.100` (Firebase `kandr-io`) |
| `www.kandr.io` | CNAME | `kandr-io.web.app` |
| `faithmusic.kandr.io` | A | `199.36.158.100` |
| `admin.faithmusic.kandr.io` | CNAME | `streamingapp-32dcb-e9588.web.app` |
| `radio.kandr.io` | A | `199.36.158.100` |
| `restore.kandr.io` | CNAME | `ghs.googlehosted.com` (Cloud Run) |
| `myfish.kandr.io` | CNAME | `fishon-kandr-app.web.app` |
| `yardsale.kandr.io` | CNAME | `yard-sale-marketing.web.app` |
| `waypoint.kandr.io` | CNAME | `waypoint-marketing.web.app` |
| `admin.waypoint.kandr.io` | CNAME | `waypoint-kandr-app.web.app` |
| `superadmin.waypoint.kandr.io` | CNAME | `waypoint-superadmin.web.app` |
| `beacon.kandr.io` | CNAME | `beacon-portal.web.app` |
| `relay.kandr.io` | CNAME | `relay-kandr-app.web.app` |
| `blueprint.kandr.io` | CNAME | `blueprint-kandr.web.app` |
| `greenlight.kandr.io` / `app` / `apex` / `btw` | CNAME | `greenlight-drive.web.app` |
| `plan.kandr.io` | CNAME | `capplan-v2.web.app` |
| `reach.kandr.io` | CNAME | `kandr-crm-app.web.app` (this is Kandr CRM — there is no `crm.kandr.io`) |
| `altbau.kandr.io` | CNAME | `altbau-kandr.web.app` |
| `trips.kandr.io` | CNAME | `libbey-europe-trip-2026.web.app` |
| `streaming.kandr.io` / `streaming-dev.kandr.io` | A | `3.19.159.96` (AWS; origin unconfirmed — do not proxy) |
| `faithmusicmissions.kandr.io` | A | Fastly-style pair — confirm origin before any proxy |

Apex also has Google MX 1/5/10 + SES inbound MX 15, `_dmarc`, AgentMail/SendGrid DKIM, and
Firebase `hosting-site=` / ACME TXT. Copy mail/verify values from live Cloudflare records, not
from memory.

**Not on this zone** (do not invent): `crm.kandr.io`, `phoenix.kandr.io`, `admin.kandr.io`,
`portal.kandr.io`, `share.kandr.io`, `clawd.kandr.io`. Shares are paths on the apex
(`/share/<slug>`). Phoenix is `usa-ak.com`. Optional later: `mercury.kandr.io` →
`34.172.139.191` DNS-only (replaces the `sslip.io` workaround) — ask Ryan before adding.

AWS leftovers (SES inbound, `streaming` IPv4): `kandr-aws`. Mail send/receive: `kandr-email`.
