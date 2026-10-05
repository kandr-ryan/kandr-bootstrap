---
name: kandr-aws
description: AWS access for Kandr — resolving credentials from GCP Secret Manager, configuring or inlining them for the AWS CLI, SES, and leftover EC2. Use when running an AWS CLI command, working with SES, or inspecting leftover AWS compute. Do not use this skill to add or change kandr.io DNS — that is kandr-dns (Cloudflare). Hosted zone Z5Q853FSJIIQT is retired for writes.
---

# AWS

AWS credentials are stored in **GCP Secret Manager** under the `streamingapp-32dcb` project. Never
inline the key values anywhere.

DNS for `kandr.io` is **not** this skill. Authoritative DNS is Cloudflare — see `kandr-dns`.
Route 53 hosted zone `Z5Q853FSJIIQT` is **retired for writes** (rollback only). Do not
`change-resource-record-sets` there.

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
> an IAM user, which AWS explicitly advises against. Rotating them touches SES, leftover EC2, and
> every script that reads these secrets, so it is tracked as its own task rather than done
> incidentally. Do not create new root keys, and do not widen where these credentials are used
> until rotation lands.

## What still lives on AWS (not DNS writes)

| Item | Notes |
|---|---|
| SES inbound / bounce | Apex and some product MX still point at `inbound-smtp` / `feedback-smtp` in `us-east-1`. The **records** are on Cloudflare (`kandr-dns`). Do not move mailboxes. |
| Leftover EC2 | `streaming.kandr.io` / `streaming-dev.kandr.io` A `3.19.159.96`. Confirm what this box is before changing it. |
| Route 53 Registered domains | Registrar for `kandr.io` (`rlibbey@gmail.com`). Nameserver / transfer changes only when Ryan asks. Not a DNS write path. |
| Hosted zone `Z5Q853FSJIIQT` | Rollback only. Do not add, change, or delete records here. |

S3 and other AWS CLI work stays here. New `*.kandr.io` hostnames go to `kandr-dns`.
