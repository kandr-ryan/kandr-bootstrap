---
name: kandr-aws
description: AWS access for Kandr — resolving credentials from GCP Secret Manager, configuring or inlining them for the AWS CLI, the account details, and the Route 53 hosted zone for kandr.io with its existing subdomain records. Use when running an AWS CLI command, adding or changing a DNS record, pointing a subdomain at Firebase Hosting or Cloud Run, or debugging kandr.io DNS.
---

# AWS

AWS credentials are stored in **GCP Secret Manager** under the `streamingapp-32dcb` project. Never
inline the key values anywhere.

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
> an IAM user, which AWS explicitly advises against. Rotating them touches Route 53 and every
> script that reads these secrets, so it is tracked as its own task rather than done incidentally.
> Do not create new root keys, and do not widen where these credentials are used until rotation
> lands.

## Route 53 (kandr.io DNS)

| Setting | Value |
|---|---|
| Hosted Zone ID | `Z5Q853FSJIIQT` |
| Domain | `kandr.io` |

### Existing subdomains (do not modify without checking)

- `faithmusic.kandr.io` — Firebase Hosting (A record)
- `admin.faithmusic.kandr.io` — Firebase Hosting (CNAME)
- `radio.kandr.io` — Firebase Hosting
- `restore.kandr.io` — Cloud Run
- `yardsale.kandr.io` — Firebase Hosting
- `myfish.kandr.io` — Firebase Hosting (CNAME → `fishon-kandr-app.web.app`, admin at `/admin`)
- `kandr.io` — Firebase Hosting (`kandr-io` site on `rlibbey-pocs`)
- MX records — Google Workspace (do NOT touch)
