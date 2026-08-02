---
name: project-bootstrap
description: Guides the full setup of a new Kandr app or project — from Firebase provisioning through Fastlane TestFlight uploads. Produces step-by-step checklists based on app type (iOS, web, Cloud Run). Use when starting a new app, bootstrapping a project, or scaffolding infrastructure.
---

<!-- SECRET-AUDIT: the Match password registry below duplicates values that now live in
     GCP Secret Manager as MATCH_PASSWORD on each app's own project:
       streamingapp-32dcb, kandr-radio-app, fishon-kandr-app, yard-sale-3a062
     Keep the naming convention here; the values are redundant and should be dropped.
     Keychain/login passwords are NOT stored anywhere — remove those examples entirely.
     Full workflow: ~/.cursor/skills/kandr-secrets/SKILL.md
-->

# Project Bootstrap Agent

This skill encodes every pattern, convention, and infrastructure decision across Kandr apps (Fish On!, Faith Music Streaming, Kandr Radio, Yard Seller, and others). It produces a complete, sequenced checklist so nothing gets missed when spinning up a new project.

## How This Works

1. Gather requirements interactively (Phase 1)
2. Produce a tailored infrastructure checklist (Phase 2)
3. Show the project structure (Phase 3)
4. Reference detailed config templates on demand (Phase 4 — in `infrastructure-reference.md`)
5. Produce deployment pipeline commands (Phase 5)
6. Generate `.cursor/rules/` files for the new project (Phase 6)

The agent does NOT auto-execute commands or generate files. It produces checklists and the user decides what to run.

### Environment Awareness

All CLI tools needed for Kandr projects are already installed. See `~/.cursor/rules/local-toolchain.mdc` for the full inventory with versions and paths. Do NOT ask the user to install anything, do NOT run version checks, and do NOT guess whether a tool is available — it is documented.

### Environment Safety

If the agent encounters an environment problem (wrong password, expired cert, keychain locked, auth failure, version mismatch), it MUST:
1. Report the exact error
2. Suggest a fix
3. **Ask the user before taking any action**

The agent must NEVER destructively "fix" issues on its own — no deleting certs, no regenerating profiles, no changing passwords, no nuking Match repos, no modifying shell configs. See `~/.cursor/rules/local-toolchain.mdc` for the full list of prohibited actions.

---

## Phase 1: Requirements Gathering

Use `AskQuestion` to collect these inputs. Ask in batches of 1-2 questions to avoid overwhelming the user.

### Question 1: App Type

```
What type of project?
- iOS + Admin Console + Firebase (full-stack — Fish On!, Faith Music, Radio pattern)
- iOS + Firebase only (no admin console)
- Web app + Firebase (capacity-planner, kandr.io pattern)
- Cloud Run service (photo-restorer pattern)
- POC / Prototype (lightweight, Firebase Hosting only)
```

### Question 2: App Identity

Ask for:
- **App name** (display name, e.g. "Fish On!")
- **Code name** (for directories/repos, e.g. "fishon")
- **Bundle ID** (iOS only, e.g. `com.fishon.kandr`) — suggest `com.{codename}.kandr` as default
- **Firebase project ID** — suggest `{codename}-kandr-app` as default

### Question 3: Features

```
Which features does this app need? (select all that apply)
- Authentication (Anonymous-first + Apple + Google + Email OTP)
- Authentication (Apple + Google only, no anonymous)
- Stripe payments (subscriptions, one-time, or both)
- In-App Purchase (StoreKit 2)
- Push notifications (FCM)
- Email (AgentMail — transactional, contact form, admin inbox)
- AI / Gemini integration
- Maps / Location services
- Cloud Storage (user uploads — photos, files)
- Crashlytics
- Sentry (error monitoring + tracing + optional replay — complements Crashlytics on iOS; see `~/.cursor/skills/kandr-sentry/SKILL.md`)
```

### Question 4: Infrastructure

```
- Custom domain? (subdomain of kandr.io, e.g. myapp.kandr.io)
  → If yes, what subdomain?
- Admin console needed?
```

### Question 5: Marketing Site

Always ask this explicitly for every project:

```
Do you want a marketing / public website for this app?
- No marketing site
- Static HTML + Tailwind CDN (simple landing page — radio-app pattern)
- React SPA + Vite + Tailwind (multi-page with routing — kandr.io, yard-sale pattern)
```

If yes, also ask:
- Will it share the same Firebase Hosting site as the admin console (merged into one `dist/`), or have its own separate hosting target?
- Standard pages needed? (Home, Features, Privacy, Terms, Contact, FAQ)

### After Gathering Requirements

Summarize the choices back to the user in a table:

```
| Setting              | Value                          |
|----------------------|--------------------------------|
| App Type             | iOS + Admin + Firebase         |
| App Name             | {name}                         |
| Bundle ID            | com.{codename}.kandr           |
| Firebase Project     | {codename}-kandr-app           |
| Auth Providers       | Anonymous, Apple, Google, Email |
| Payments             | StoreKit 2 IAP                 |
| Push Notifications   | Yes                            |
| Custom Domain        | {subdomain}.kandr.io           |
| Admin Console        | Yes                            |
| Marketing Site       | React SPA (shared hosting)     |
```

Ask the user to confirm before proceeding.

---

## Phase 2: Infrastructure Checklist

Present this as a markdown checklist. The agent tracks progress and checks items off as the user confirms each step. Items marked (conditional) only apply based on Phase 1 answers.

### 2.1 Firebase Project

```
- [ ] Create Firebase project: `firebase projects:create {projectId} --display-name "{App Name}"`
- [ ] Set default project: `firebase use {projectId}`
- [ ] Upgrade to Blaze (pay-as-you-go) billing plan (required for Functions, Extensions)
- [ ] Enable Firestore: Firebase Console → Build → Firestore Database → Create (production mode)
- [ ] Enable Cloud Storage: Firebase Console → Build → Storage → Get started
- [ ] Enable Cloud Functions: Firebase Console → Build → Functions
- [ ] Enable Crashlytics: Firebase Console → Release & Monitor → Crashlytics (conditional)
- [ ] Enable Cloud Messaging: Firebase Console → Engage → Messaging (conditional)
- [ ] Add an iOS app in Firebase Console → Project Settings → Add app → iOS
      Bundle ID: {bundleId}
      (Do NOT download GoogleService-Info.plist yet — wait until after auth setup)
- [ ] Add a Web app in Firebase Console → Project Settings → Add app → Web
      Note the config object (apiKey, authDomain, projectId, etc.) for admin console
```

### 2.2 Authentication (MUST complete before downloading GoogleService-Info.plist)

**Why this is a separate step**: Enabling Google Sign-In writes the `CLIENT_ID` and
`REVERSED_CLIENT_ID` into `GoogleService-Info.plist`. If you download the plist before
enabling Google auth, those fields will be missing and you'll have to re-download.
The standard Kandr auth stack is: Anonymous + Apple + Google + Email OTP.

```
- [ ] Enable Authentication: Firebase Console → Build → Authentication → Get started
- [ ] Enable Anonymous sign-in:
      Firebase Console → Authentication → Sign-in method → Anonymous → Enable
- [ ] Enable Apple sign-in:
      Firebase Console → Authentication → Sign-in method → Apple → Enable
      For iOS: no extra config needed (uses the bundle ID's Sign in with Apple capability)
      For web/admin: set Services ID to `com.{codename}.web` and configure the
      OAuth redirect URL shown by Firebase in Apple Developer → Identifiers → Services IDs
- [ ] Enable Google sign-in:
      Firebase Console → Authentication → Sign-in method → Google → Enable
      Set support email: rlibbey@gmail.com
      This generates the OAuth client ID that gets written into GoogleService-Info.plist
- [ ] Enable Email link (passwordless OTP):
      Firebase Console → Authentication → Sign-in method → Email/Password → Enable
      Toggle ON "Email link (passwordless sign-in)"
```

### 2.3 Download Firebase Config (AFTER auth providers are configured)

```
- [ ] Download `GoogleService-Info.plist` (iOS):
      Firebase Console → Project Settings → Your apps → iOS app → Download
      Place at: `ios/{AppName}/Resources/GoogleService-Info.plist` (gitignored)
      Verify it contains `CLIENT_ID` and `REVERSED_CLIENT_ID` fields (from Google Sign-In)
- [ ] Add the Reversed Client ID as a URL scheme in project.yml or Info.plist:
      URL scheme value is the `REVERSED_CLIENT_ID` from the plist
      (XcodeGen: add under target → settings or Info.plist URL Types)
- [ ] Note the Firebase Web App config for admin console .env:
      VITE_FIREBASE_API_KEY, VITE_FIREBASE_AUTH_DOMAIN, VITE_FIREBASE_PROJECT_ID,
      VITE_FIREBASE_STORAGE_BUCKET, VITE_FIREBASE_MESSAGING_SENDER_ID, VITE_FIREBASE_APP_ID
- [ ] Note the Google Client ID (from the plist or Firebase Console → Authentication →
      Sign-in method → Google) for the iOS app's Google Sign-In configuration
```

### 2.4 Git Repositories

```
- [ ] Create code repo: `gh repo create kandr-ryan/{codename} --private`
- [ ] Create certs repo (iOS only): `gh repo create kandr-ryan/{codename}-certs --private`
- [ ] Initialize local repo: `git init && git remote add origin https://github.com/kandr-ryan/{codename}.git`
- [ ] Create .gitignore (see infrastructure-reference.md for template)
- [ ] Initial commit and push
```

### 2.5 Apple Developer (iOS only)

```
- [ ] Register Bundle ID: Apple Developer → Identifiers → App IDs → Register
      Bundle ID: {bundleId}
      Capabilities: Push Notifications, Sign in with Apple, In-App Purchase (conditional)
- [ ] Create App Store Connect listing:
      Apple Developer → App Store Connect → My Apps → New App
      Bundle ID: {bundleId}, SKU: {codename}
- [ ] ASC API Key: reuse existing key `6LF5PQ5KPG` (issuer `69a6de80-f231-47e3-e053-5b8c7c11a4d1`)
      Copy `AuthKey_6LF5PQ5KPG.p8` into `ios/fastlane/` (gitignored)
- [ ] Note the Apple App ID (numeric) from App Store Connect for Fastfile
```

### 2.6 Code Signing (iOS only)

```
- [ ] Initialize Fastlane Match:
      cd ios && bundle exec fastlane match init
      → Storage: git
      → URL: https://github.com/kandr-ryan/{codename}-certs.git
- [ ] Generate Match password using naming convention: {AppNamePascalCase}{Year}!
      Example: FishOn2026!!, PetTracker2026!
- [ ] Generate certificates and profiles:
      MATCH_PASSWORD="{generatedPassword}" bundle exec fastlane match appstore
      App identifier: {bundleId}
      Team ID: KNDYLHQ94J
- [ ] Record the password in THREE places:
      1. The project's .cursor/rules/fastlane-deployment.mdc
      2. The Match Password Registry in this skill (update the table)
      3. Tell the user the password so they can store it personally
```

### 2.7 Custom Domain (conditional)

```
- [ ] Create Firebase Hosting site: Firebase Console → Hosting → Add site → site ID: {projectId}
- [ ] Set hosting target: `firebase target:apply hosting {target} {siteId}`
- [ ] Add custom domain via REST API:
      ACCESS_TOKEN=$(gcloud auth print-access-token)
      curl -X POST "https://firebasehosting.googleapis.com/v1beta1/projects/{projectId}/sites/{siteId}/customDomains?customDomainId={subdomain}.kandr.io" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "x-goog-user-project: {projectId}" \
        -H "Content-Type: application/json" -d '{}'
- [ ] Get the required DNS records from the response
- [ ] Add DNS records in Route 53:
      AWS credentials: see ~/.cursor/rules/aws-credentials.mdc
      Hosted Zone: Z5Q853FSJIIQT (kandr.io)
      Add CNAME: {subdomain}.kandr.io → {firebaseHostingTarget}.web.app
- [ ] Verify domain in Firebase Console (may take up to 24h for SSL provisioning)
```

### 2.8 Marketing Site (conditional)

If a marketing site was selected in Phase 1, set up its hosting:

**Option A: Shared hosting (marketing + admin on same site)**
The marketing site serves at the root (`/`) and the admin console at `/admin/`.
Both build into a single `dist/` directory. No additional hosting target needed.

```
- [ ] Set up build script that merges marketing + admin output into one dist/:
      1. Build marketing site → dist/
      2. Build admin console → dist/admin/
- [ ] Configure firebase.json rewrites:
      /admin/** → /admin/index.html (admin SPA)
      Specific marketing routes → /index.html (or individual HTML files)
      ** → /index.html (marketing SPA fallback)
```

**Option B: Separate hosting target**
The marketing site gets its own Firebase Hosting site.

```
- [ ] Create a second hosting site: Firebase Console → Hosting → Add site
      Site ID: {projectId}-marketing (or {codename}-site)
- [ ] Add hosting target: `firebase target:apply hosting marketing {siteId}`
- [ ] If using a custom domain for the marketing site, configure it separately
      (the admin console stays on the main site)
```

**For both options:**
```
- [ ] Include SEO essentials:
      - Meta tags (title, description, Open Graph, Twitter Cards)
      - JSON-LD structured data (SoftwareApplication for apps, Organization for company)
      - App Store Smart Banner meta tag (iOS apps): <meta name="apple-itunes-app" content="app-id={appleAppId}">
      - Privacy policy page (/privacy) — required for App Store
      - Terms of service page (/terms)
- [ ] Include standard pages: Home, Features, Privacy, Terms
      Optional: Contact (with Firestore-backed form), FAQ, About
```

### 2.9 Stripe (conditional)

```
- [ ] Create Stripe product and price(s) in Stripe Dashboard
- [ ] Store secret key in GCP Secret Manager:
      gcloud secrets create STRIPE_SECRET_KEY --project={projectId}
      echo -n "sk_live_..." | gcloud secrets versions add STRIPE_SECRET_KEY --data-file=- --project={projectId}
- [ ] Store webhook secret:
      gcloud secrets create STRIPE_WEBHOOK_SECRET --project={projectId}
      echo -n "whsec_..." | gcloud secrets versions add STRIPE_WEBHOOK_SECRET --data-file=- --project={projectId}
- [ ] Note publishable key for admin-console/.env: VITE_STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### 2.10 AgentMail (conditional)

```
- [ ] Create inbox via AgentMail API or dashboard for {subdomain}.kandr.io
- [ ] Configure DNS (MX, SPF, DKIM, DMARC) in Route 53 for the subdomain
- [ ] Store API key in GCP Secret Manager:
      gcloud secrets create AGENTMAIL_API_KEY --project={projectId}
- [ ] Inboxes: support@{subdomain}.kandr.io, noreply@{subdomain}.kandr.io
```

### 2.11 GCP Secret Manager (conditional — any secrets needed)

```
- [ ] Grant Cloud Functions service account access:
      gcloud projects add-iam-policy-binding {projectId} \
        --member="serviceAccount:{projectId}@appspot.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor"
```

### 2.12 Sentry (conditional — if enabled in Phase 1)

Follow **`~/.cursor/skills/kandr-sentry/SKILL.md`** for org vs project layout and triage. Summary:

```
- [ ] In Sentry (org-level): create one Sentry **project** per deployable surface — typically {codename}-web, {codename}-admin,
      {codename}-functions, {codename}-ios — NOT one project per end customer (use tags like appId for white-label)
- [ ] Copy each Client Keys (DSN) into **`.env.local`** (gitignored) or CI secrets — never commit real values. Tracked templates:
      `web/.env.example`, `admin-console/.env.example`, `functions/.env.example` — see **`~/.cursor/skills/kandr-sentry/SKILL.md`** (“Environment variables — tracked vs local”).
      Keys: `VITE_SENTRY_DSN`, `VITE_APP_VERSION`; build uploads: `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`; Functions: `SENTRY_DSN` (Firebase secrets in prod);
      iOS: `SENTRY_DSN` (+ optional `SENTRY_ENVIRONMENT`) in Xcode scheme or xcconfig for local/TestFlight
- [ ] Web/admin: add instrument.ts first import pattern + React 19 error handlers; optional @sentry/vite-plugin when CI has SENTRY_AUTH_TOKEN
- [ ] Functions: sentry-init imported before firebase-init; create Firebase secret `SENTRY_DSN` before first Functions deploy (see `streaming-app/scripts/setup-sentry-functions-secret.sh` pattern); `setGlobalOptions({ secrets: ["SENTRY_DSN"] })` when using global Gen2 options
- [ ] iOS: SPM sentry-cocoa + conditional SentrySDK.start (can coexist with Crashlytics)
```

---

## Phase 3: Project Structure

Based on the app type from Phase 1, present the file tree and describe each directory's purpose.

### Template A: iOS + Admin Console + Firebase

```
{project}/
├── ios/
│   ├── {AppName}/
│   │   ├── App/                    # FishOnApp.swift, AppDelegate.swift, ContentView.swift
│   │   ├── Core/                   # AuthManager, FirestoreService, LocationManager, etc.
│   │   ├── Features/               # Feature modules (Auth, Home, Profile, etc.)
│   │   │   ├── Auth/
│   │   │   ├── Home/
│   │   │   ├── Profile/
│   │   │   └── {FeatureN}/
│   │   ├── Shared/
│   │   │   ├── Models/             # Codable Firestore data models
│   │   │   ├── Views/              # Reusable SwiftUI components
│   │   │   └── Extensions/         # Swift extensions
│   │   └── Resources/              # Assets.xcassets, Info.plist, entitlements, GoogleService-Info.plist
│   ├── Configs/
│   │   └── Base.xcconfig
│   ├── project.yml                 # XcodeGen — generates .xcodeproj
│   └── fastlane/
│       ├── Fastfile
│       ├── Appfile
│       ├── Matchfile
│       └── AuthKey_6LF5PQ5KPG.p8  # gitignored
├── admin-console/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── index.css
│   │   ├── lib/firebase.ts         # Firebase config + initialization
│   │   ├── hooks/useAuth.ts        # Auth context + admin role check
│   │   ├── components/             # AuthGate, Layout, Toast
│   │   └── pages/                  # Dashboard, Login, Settings, Users
│   ├── index.html
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
├── marketing-site/                  # (conditional — if marketing site selected)
│   ├── src/                         # React SPA variant
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── index.css
│   │   └── pages/                   # Home, Features, Privacy, Terms, Contact
│   ├── index.html                   # Static HTML variant: this IS the site
│   ├── package.json
│   └── vite.config.ts              # React SPA variant only
├── scripts/
│   └── build.sh                     # Merges marketing + admin into dist/ (if shared hosting)
├── functions/
│   ├── src/
│   │   └── index.ts                # Re-exports all Cloud Functions
│   ├── package.json
│   └── tsconfig.json
├── firebase.json
├── .firebaserc
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── .gitignore
└── .cursor/
    └── rules/                      # Generated in Phase 6
```

### Template B: Web-only + Firebase

```
{project}/
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── lib/firebase.ts
│   └── pages/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── functions/                      # Optional
│   ├── src/index.ts
│   └── package.json
├── firebase.json
├── .firebaserc
├── firestore.rules
├── .gitignore
└── .cursor/rules/
```

### Template C: Cloud Run

```
{project}/
├── src/ or api/
│   └── index.ts
├── Dockerfile
├── cloudbuild.yaml
├── deploy.sh
├── package.json
├── tsconfig.json
├── .gitignore
└── .cursor/rules/
```

---

## Phase 4: Configuration Templates

Read [infrastructure-reference.md](infrastructure-reference.md) for detailed, copy-paste-ready templates including:

- XcodeGen `project.yml`
- Fastlane `Fastfile`, `Appfile`, `Matchfile`
- `firebase.json` and `.firebaserc`
- `firestore.rules` and `storage.rules`
- Admin console scaffolding (`firebase.ts`, `useAuth.ts`, `AuthGate.tsx`)
- Cloud Functions boilerplate (`index.ts`, `package.json`, `tsconfig.json`)
- `.gitignore`

When the user is ready for a specific template, read that file and present the relevant section.

---

## Phase 5: Deployment Pipeline

Present the deployment commands tailored to the project.

### iOS — Two Distinct Operations

There are exactly two iOS deployment operations. They are NEVER combined:

1. **`fastlane beta`** — Builds the app, archives it, and uploads the binary to TestFlight. This is the ONLY command that produces a new binary.
2. **`deliver` (App Store submission)** — Takes an EXISTING TestFlight build and promotes it to App Store review. It does NOT build or upload a new binary. The flag `skip_binary_upload:true` is critical — the build already exists on ASC from the `beta` step.

### iOS — Build and Upload to TestFlight (`fastlane beta`)

Before running this, the agent MUST complete the Pre-Build Verification Checklist (see below).

```bash
cd ios
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
export MATCH_PASSWORD="{matchPassword}"
export CI=false  # Cursor sets CI=true which makes Match readonly — override it

# MANDATORY before EVERY build — keychain locks between builds
security unlock-keychain -p "{keychainPassword}" ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "{keychainPassword}" ~/Library/Keychains/login.keychain-db

bundle exec fastlane beta
```

What `fastlane beta` does internally (in sequence):
1. Loads ASC API key
2. Runs `xcodegen generate` to regenerate .xcodeproj from project.yml
3. Runs `match` (readonly) to install signing certs/profiles from the certs repo
4. Queries TestFlight for the latest build number, increments by 1
5. Archives the app (Release config)
6. Uploads the IPA to TestFlight

### iOS — Promote TestFlight Build to App Store Review (`deliver`)

This command promotes an EXISTING TestFlight build to App Store review. It does NOT build or upload anything new. Run this only after a TestFlight build has been tested and approved for release.

```bash
cd ios
bundle exec fastlane run deliver \
  api_key_path:"./fastlane/api_key.json" \
  app_version:"{version}" \
  build_number:"{build}" \
  submit_for_review:true \
  automatic_release:true \
  force:true \
  skip_binary_upload:true \
  skip_screenshots:true \
  precheck_include_in_app_purchases:false \
  run_precheck_before_submit:false
```

Key flags explained:
- `app_version` + `build_number` — identify WHICH TestFlight build to promote (must already exist on ASC)
- `skip_binary_upload:true` — the binary was already uploaded by `beta`; without this, deliver tries to re-upload and fails with a 409 conflict
- `automatic_release:true` — release immediately after Apple approves (set to `false` to hold for manual release)

### Pre-Build Verification Checklist (MANDATORY before `fastlane beta`)

The project's deployment agent must run ALL of these checks before attempting a build. Do NOT skip any.

```
- [ ] Disk space: verify ≥ 4 GB free (`df -h / | tail -1`)
      If low: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- [ ] ASC version check: query App Store Connect for the live production version
      The version in project.yml MUST be strictly higher than the live App Store version
      If not: STOP and ask user what version to set
- [ ] Version train check: verify the marketing version is not in a closed train
      If closed: bump to next version before building
- [ ] Stale archive cleanup: `rm -rf ~/Library/Developer/Xcode/Archives/{AppName}.xcarchive`
      Prevents "already been used" upload errors from previous builds
- [ ] Certificates: verify ASC API key .p8 file exists in ios/fastlane/
- [ ] Keychain: unlock keychain + set key partition list (MANDATORY, not just on error)
- [ ] Environment: verify PATH includes Homebrew Ruby, MATCH_PASSWORD is set, CI=false
```

After a successful TestFlight upload, the deployment agent must:
1. Record the version and build number (e.g. "v1.2.0 build 3")
2. Commit and push any changed files (project.yml version bumps, build tracking)
3. Report the build details to the user

### Admin Console

```bash
cd admin-console && npm run deploy
# deploy script in package.json: "deploy": "vite build && cd .. && firebase deploy --only hosting:{target} --project {projectId}"
```

### Marketing Site (conditional)

**Shared hosting (marketing + admin merged):**
```bash
# Build script merges both into dist/, then deploy the single hosting target
./scripts/build.sh
firebase deploy --only hosting --project {projectId}
```

**Separate hosting target:**
```bash
cd marketing-site && npm run build
firebase deploy --only hosting:marketing --project {projectId}
```

### Cloud Functions

```bash
firebase deploy --only functions --project {projectId}
```

### Firestore / Storage Rules

```bash
firebase deploy --only firestore:rules,storage --project {projectId}
```

### Full Deploy (everything except iOS)

```bash
firebase deploy --project {projectId}
```

### Post-Deployment Git

After any successful deployment, commit and push:
```bash
git add -A && git commit -m "Deploy: {what was deployed} — {brief description}" && git push
```

---

## Phase 6: Cursor Rules Generation

Generate `.cursor/rules/` files for the new project. Populate `{placeholders}` with values from Phase 1. Full templates for each rule are in [infrastructure-reference.md](infrastructure-reference.md) under "Cursor Rule Templates."

### Rules to Generate

| Rule File | Scope | When |
|-----------|-------|------|
| `project-context.mdc` | `alwaysApply: true` | Always — every project |
| `fastlane-deployment.mdc` | `globs: ios/fastlane/**` | iOS projects only |
| `ios-development.mdc` | `globs: ios/**/*.swift` | iOS projects only |
| `ios-build-safety.mdc` | `alwaysApply: true` | iOS projects only |
| `cloud-functions-agent.mdc` | `alwaysApply: true` | Projects with Cloud Functions |

### Key Content per Rule

**project-context.mdc** — Identifiers (bundle ID, Firebase project, app IDs), architecture summary, auth providers, Firestore collection map, admin roles, git repos.

**fastlane-deployment.mdc** — Code signing config (Match profile, certs repo, Match password), ASC API key (`6LF5PQ5KPG`), build commands (beta, release), admin/Firebase deploy commands, common errors table.

**ios-development.mdc** — XcodeGen conventions, directory structure (App/Core/Features/Shared/Resources), data model patterns (`@DocumentID`, `CodingKeys`, snake_case), auth pattern (anonymous-first, link credentials).

**ios-build-safety.mdc** — Prevents accidental builds. Requires explicit user consent for `fastlane beta`, `xcodebuild archive`, or any App Store submission. "build" means TestFlight only unless user says otherwise.

**cloud-functions-agent.mdc** — Review gate: check existing exports before creating new functions. Naming: `onX` (triggers), `handleX` (webhooks), `verbNoun` (callables), `scheduledX` (cron).

**Optional — Sentry** — If Sentry was enabled in Phase 1, ensure operators know to read **`~/.cursor/skills/kandr-sentry/SKILL.md`** (DSN placement, one project per surface per repo, tags for multi-tenant). No separate rule file required unless the team wants a project-local `.cursor/rules/sentry.mdc`.

---

## Fastlane Match Password Registry

Match passwords encrypt the certificates repo. Each project has its own password following a consistent naming pattern.

### Existing Passwords

| Project | Bundle ID | Certs Repo | Match Password |
|---------|-----------|------------|----------------|
| Fish On! | `com.fishon.kandr` | `kandr-ryan/fishon-certs` | `FishOn2026!!` |
| Faith Music | `com.allaccess` | `kandr-ryan/streaming-app-certs` | `faithmusic2026` |
| Kandr Radio | `com.wvfv.radio` / `com.faithtunes.faithbroadcasting` | `kandr-ryan/radio-app-certs` | `WVFVRadio2026!` |
| Yard Seller | (yard-sale bundle) | `kandr-ryan/yard-sale-certs` | `YardSale2026!` |

### Naming Convention for New Projects

Generate a Match password automatically using this pattern: `{AppNamePascalCase}{CurrentYear}!`

Examples: `MyNewApp2026!`, `PetTracker2026!`, `KandrHealth2026!`

After generating the password, the agent MUST:
1. Record it in the project's `fastlane-deployment.mdc` cursor rule
2. Update this registry table above (edit this skill file directly)

The password is NOT stored in git — it lives only in cursor rules and this skill file. It is provided via `MATCH_PASSWORD` environment variable at build time.

---

## Shared Constants

These values are consistent across all Kandr apps:

| Constant | Value |
|----------|-------|
| Apple Team ID | `KNDYLHQ94J` |
| ASC Key ID | `6LF5PQ5KPG` |
| ASC Issuer ID | `69a6de80-f231-47e3-e053-5b8c7c11a4d1` |
| GitHub Org | `kandr-ryan` |
| Route 53 Zone | `Z5Q853FSJIIQT` (kandr.io) |
| Super Admin Emails | `ryan@kandr.io`, `rlibbey@gmail.com` |
| Firebase Functions Runtime | Node 22 |
| iOS Deployment Target | 17.0 |
| Swift Version | 5.9 |
| React Version | 19 |
| Vite Version | 7 |
| Tailwind Version | 4 |
| Firebase SDK (iOS) | 11.x |
| GoogleSignIn SDK (iOS) | 8.x |
| Stripe API Version | `2024-12-18.acacia` |
| AgentMail Org ID | `f9485f71-6cfd-4bc4-9570-d26412e4e045` |
