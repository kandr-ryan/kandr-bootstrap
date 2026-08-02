---
name: kandr-firebase
description: The Firebase project map for all Kandr apps — which project ID owns which app and hosting sites, the secrets held per project, deploy commands for hosting, functions and rules, hosting targets, adding a custom domain via the REST API, and Cloud Functions runtime settings. Use when deploying, when you need a project ID or hosting target, or when adding a site or custom domain.
---

# Firebase projects

All Kandr apps use Firebase. The CLI is authenticated as `rlibbey@gmail.com`.

## Project map

| Project ID | App | Hosting Sites |
|---|---|---|
| `rlibbey-pocs` | **kandr.io** (parent site), POCs | `kandr-io` → kandr.io, `ai-localization-poc`, `bill-kyc-poc`, `app-automation-poc` |
| `streamingapp-32dcb` | **Faith Music Streaming** | `streamingapp-32dcb` → faithmusic.kandr.io, `streamingapp-32dcb-e9588` → admin.faithmusic.kandr.io |
| `kandr-radio-app` | **Kandr Radio** | `kandr-radio-app` → radio.kandr.io, `fmr-radio-site`, `wvfv-radio-site` |
| `yard-sale-3a062` | **Yard Seller** | `yard-sale-marketing` → yardsale.kandr.io |
| `capacity-planner-app` | **Capacity Planner** | default site |

## Secrets

Secrets live in GCP Secret Manager per project and are bound through the `secrets` field in Cloud
Function config rather than fetched at runtime. See the `kandr-secrets` skill for the manifest and
helper.

**`streamingapp-32dcb`** has: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `AGENTMAIL_API_KEY`,
`aws-access-key`, `aws-secret-key`, `ASC_PRIVATE_KEY`, `ASC_VENDOR_NUMBER`, `SPOTIFY_CLIENT_ID`,
`SPOTIFY_CLIENT_SECRET`, `CRM_UNSUBSCRIBE_SECRET`

## Deployment

```bash
# Hosting only
firebase deploy --only hosting:TARGET --project PROJECT_ID

# Functions only
firebase deploy --only functions --project PROJECT_ID

# Firestore rules
firebase deploy --only firestore:rules --project PROJECT_ID

# Everything
firebase deploy --project PROJECT_ID
```

Whether a given deploy needs the user's permission is decided by the `kandr-deploy` skill, not here.

## Hosting targets

Targets are defined in each project's `.firebaserc`. Use
`firebase target:apply hosting TARGET SITE_ID` to add new ones.

## Custom domains

Added via the Firebase Hosting REST API (there is no CLI command):

```bash
ACCESS_TOKEN=$(gcloud auth print-access-token)
curl -X POST "https://firebasehosting.googleapis.com/v1beta1/projects/PROJECT_ID/sites/SITE_ID/customDomains?customDomainId=DOMAIN" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-goog-user-project: PROJECT_ID" \
  -H "Content-Type: application/json" -d '{}'
```

Then update Route 53 DNS — see the `kandr-aws` skill for the hosted zone and existing records.

## Cloud Functions

- Runtime: **Node 22**, TypeScript
- Deploy: `firebase deploy --only functions --project PROJECT_ID`
- Secrets: declared in function config via `secrets: ["SECRET_NAME"]`
- Logs: `firebase functions:log --project PROJECT_ID`

Conventions for writing the functions themselves are in the `kandr-functions` skill.
