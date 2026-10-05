---
name: kandr-aws
description: AWS access for Kandr — resolving credentials from GCP Secret Manager, configuring or inlining them for the AWS CLI, SES inbound, leftover EC2, and S3. Use when running an AWS CLI command or debugging SES / leftover AWS compute. Do not use for kandr.io DNS — that is kandr-dns (Cloudflare).
---

# AWS

AWS credentials are stored in **GCP Secret Manager** under the `streamingapp-32dcb` project. Never
inline the key values anywhere.

DNS for `kandr.io` is **not** here. Authoritative DNS is Cloudflare — see `kandr-dns`. Route 53
hosted zone `Z5Q853FSJIIQT` is **retired for writes** (rollback-only). Do not
`change-resource-record-sets` against it.

## Retrieving credentials

```bash
AWS_KEY=$(gcloud secrets versions access latest --secret=aws-access-key --project=streamingapp-32dcb)
AWS_SECRET=$(gcloud secrets versions access latest --secret=aws-secret-key --project=streamingapp-32dcb)
```

In a repo with a `.kandr-secrets` manifest, prefer the helper — it caches and needs no project
argument:

```bash
eval "$(kandr-secrets load)"
```

## Configuring the AWS CLI (if `~/.aws/credentials` is missing)

```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $AWS_KEY
aws_secret_access_key = $AWS_SECRET
EOF
cat > ~/.aws/config << EOF
[default]
region = us-east-1
output = json
EOF
```

Writing these files is the one sanctioned exception to the standing rule against touching AWS
config, and only when the files are absent. Never overwrite existing credentials.

## Quick inline auth (for one-off commands)

```bash
export AWS_ACCESS_KEY_ID="$AWS_KEY"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET"
export AWS_DEFAULT_REGION="us-east-1"
```

## Account details

| Setting | Value |
|---|---|
| Account ID | `295976325903` |
| Principal | account **root** (see warning below) |
| Credentials | `aws-access-key` / `aws-secret-key` on `streamingapp-32dcb` |
| Region | `us-east-1` |

> **Known issue — root access keys.** The stored credentials belong to the account root user, not
> an IAM user, which AWS explicitly advises against. Rotating them touches every script that reads
> these secrets, so it is tracked as its own task rather than done incidentally.
> Do not create new root keys, and do not widen where these credentials are used until rotation
> lands.

## Retired Route 53 hosted zone

| Setting | Value |
|---|---|
| Hosted zone ID | `Z5Q853FSJIIQT` |
| Domain | `kandr.io` |
| Status | **Do not write.** Rollback copy only. |

Registrar (nameservers / transfer) is Route 53 **Registered domains** in this same account, not
the hosted zone. Do not change NS, unlock transfer, or delete the zone unless Ryan asks. New
`*.kandr.io` records go to Cloudflare via `kandr-dns`.

## SES (still AWS)

Apex, `faithmusic.kandr.io`, and `radio.kandr.io` still have MX →
`inbound-smtp.us-east-1.amazonaws.com`. Bounce/feedback names `mail.*` point at
`feedback-smtp.us-east-1.amazonses.com`. Those **records** live on Cloudflare (DNS-only); the
mailboxes/queues are still SES. Do not move inbound to Cloudflare Email Routing. See
`kandr-email`.

## Leftover EC2

`streaming.kandr.io` and `streaming-dev.kandr.io` are A records to `3.19.159.96`. Origin is
unconfirmed. Do not proxy them. Do not assume they can be deleted. DNS edits for those names
still go through `kandr-dns`.
