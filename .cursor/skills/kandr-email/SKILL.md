---
name: kandr-email
description: AgentMail, the email service for all Kandr apps — the org ID, which API key belongs to which projects and what rotating one affects, configured domains and inboxes, the SDK send pattern for Cloud Functions, and the Firestore-trigger contact form pattern. Use when sending email from an app, adding an inbox or sending domain, wiring a contact form, or debugging email delivery.
---

# AgentMail

[AgentMail](https://agentmail.to) is the email service for all Kandr apps.

- **Org ID**: `f9485f71-6cfd-4bc4-9570-d26412e4e045`

## API keys

Every key lives in GCP Secret Manager as `AGENTMAIL_API_KEY` on the owning project. There is no
single org-wide key — four distinct keys are in use, so always read the one belonging to the
project you are working in:

| Key | Projects sharing it |
|---|---|
| kandr.io / parent | `rlibbey-pocs`, `kandr-crm-app`, `waypoint-kandr-app`, `greenlight-drive` |
| Faith Music family | `streamingapp-32dcb`, `kandr-radio-app`, `pizzeria-pfiff-kandr`, `sunny-slope-haus-kandr`, `bill-agentic` |
| Hunter Book Club | `hunter-book-club-kandr` |
| Yard Seller | `yard-sale-3a062` |

Because keys are shared across several projects, **rotating one affects every project in its row**.
Check the row before rotating.

## Configured domains and inboxes

### kandr.io (parent company)
- **Inbox**: `info@kandr.io`
- **Firebase project**: `rlibbey-pocs`

### faithmusic.kandr.io (Faith Music Streaming)
- **Inboxes**: `support@faithmusic.kandr.io`, `noreply@faithmusic.kandr.io`,
  `info@faithmusic.kandr.io` (CRM allowlist for envelope From; create additional inboxes in
  AgentMail before adding to the allowlist in code)
- **Firebase project**: `streamingapp-32dcb`
- **DNS**: MX, SPF, DKIM, DMARC all configured in Route 53

## SDK usage (Cloud Functions)

Install: `npm install agentmail`

```typescript
import { AgentMailClient } from "agentmail";

const client = new AgentMailClient({ apiKey: process.env.AGENTMAIL_API_KEY });

await client.inboxes.messages.send("info@kandr.io", {
  to: ["recipient@example.com"],
  subject: "Subject line",
  text: "Plain text body",
  html: "<p>HTML body</p>",
});
```

## Pattern: contact form via Firestore trigger

The proven pattern (used in streaming-app):

1. Client writes to a Firestore collection (e.g. `contactSubmissions`)
2. Cloud Function triggers on `onDocumentCreated`
3. Function sends email via the AgentMail SDK
4. Function updates the doc with `processed: true`, `emailSent: true/false`

Reference implementation: `streaming-app/functions/src/email.ts` and
`streaming-app/functions/src/contactForm.ts`
