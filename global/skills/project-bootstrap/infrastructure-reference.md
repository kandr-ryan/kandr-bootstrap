
<!-- SECRET-AUDIT: the Match password registry below duplicates values that now live in
     GCP Secret Manager as MATCH_PASSWORD on each app's own project:
       streamingapp-32dcb, kandr-radio-app, fishon-kandr-app, yard-sale-3a062
     Keep the naming convention here; the values are redundant and should be dropped.
     Keychain/login passwords are NOT stored anywhere — remove those examples entirely.
     Full workflow: ~/.cursor/skills/kandr-secrets/SKILL.md
-->
# Infrastructure Reference — Config Templates

Copy-paste-ready templates extracted from working Kandr projects. Replace `{placeholders}` with actual values from Phase 1.

---

## XcodeGen — project.yml

```yaml
name: {AppName}
options:
  bundleIdPrefix: com.{codename}
  xcodeVersion: "26.0"
  deploymentTarget:
    iOS: "17.0"
  generateEmptyDirectories: true
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: KNDYLHQ94J
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
  configs:
    Debug:
      CODE_SIGN_IDENTITY: "Apple Development"
      CODE_SIGN_STYLE: Automatic
    Release:
      CODE_SIGN_IDENTITY: "Apple Distribution: Kandr Media, LLC (KNDYLHQ94J)"
      CODE_SIGN_STYLE: Manual
      PROVISIONING_PROFILE_SPECIFIER: "match AppStore {bundleId}"

configFiles:
  Debug: Configs/Base.xcconfig
  Release: Configs/Base.xcconfig

packages:
  FirebaseSDK:
    url: https://github.com/firebase/firebase-ios-sdk
    majorVersion: 11.0.0
  GoogleSignInSDK:
    url: https://github.com/google/GoogleSignIn-iOS
    majorVersion: 8.0.0

targets:
  {AppName}:
    type: application
    platform: iOS
    sources:
      - path: {AppName}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {bundleId}
        PRODUCT_NAME: {Display Name}
        INFOPLIST_FILE: {AppName}/Resources/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      configs:
        Debug:
          CODE_SIGN_IDENTITY: "Apple Development"
          CODE_SIGN_STYLE: Automatic
        Release:
          CODE_SIGN_IDENTITY: "Apple Distribution"
          CODE_SIGN_STYLE: Manual
          PROVISIONING_PROFILE_SPECIFIER: "match AppStore {bundleId}"
    dependencies:
      - package: FirebaseSDK
        product: FirebaseAuth
      - package: FirebaseSDK
        product: FirebaseFirestore
      - package: FirebaseSDK
        product: FirebaseStorage
      - package: FirebaseSDK
        product: FirebaseAnalytics
      - package: FirebaseSDK
        product: FirebaseCrashlytics
      - package: FirebaseSDK
        product: FirebaseFunctions
      - package: FirebaseSDK
        product: FirebaseMessaging
      - package: GoogleSignInSDK
        product: GoogleSignIn
      - package: GoogleSignInSDK
        product: GoogleSignInSwift
    entitlements:
      path: {AppName}/Resources/{AppName}.entitlements
      properties:
        com.apple.developer.applesignin:
          - Default
        aps-environment: production
```

---

## Fastlane — Fastfile

Two lanes serve two distinct purposes:
- **`beta`** — builds, archives, and uploads a NEW binary to TestFlight
- **`release`** — promotes an EXISTING TestFlight build to App Store review (no new binary)

```ruby
default_platform(:ios)

platform :ios do
  def load_api_key
    key_filepath = File.expand_path("AuthKey_6LF5PQ5KPG.p8", __dir__)
    app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"] || "6LF5PQ5KPG",
      issuer_id: ENV["ASC_ISSUER_ID"] || "69a6de80-f231-47e3-e053-5b8c7c11a4d1",
      key_filepath: key_filepath,
      in_house: false
    )
  end

  lane :setup_certs do
    api_key = load_api_key
    match(
      type: "appstore",
      api_key: api_key,
      readonly: false,
      force: true
    )
  end

  # BUILD + UPLOAD TO TESTFLIGHT
  # This is the ONLY lane that produces a new binary.
  # The deployment agent must run pre-build verification before invoking this.
  lane :beta do
    api_key = load_api_key

    # 1. Regenerate Xcode project from project.yml
    sh("cd .. && xcodegen generate")

    # 2. Install signing certs/profiles from the certs repo
    match(
      type: "appstore",
      api_key: api_key,
      readonly: true
    )

    # 3. Query TestFlight for latest build number, increment by 1
    latest = latest_testflight_build_number(
      api_key: api_key,
      app_identifier: "{bundleId}",
      initial_build_number: 0
    )
    new_build = (latest + 1).to_s
    new_build = ENV["FORCE_BUILD_NUMBER"] if ENV["FORCE_BUILD_NUMBER"]
    increment_build_number(
      build_number: new_build,
      xcodeproj: "{AppName}.xcodeproj"
    )

    # 4. Archive the app
    build_app(
      scheme: "{AppName}",
      export_method: "app-store",
      export_options: {
        provisioningProfiles: {
          "{bundleId}" => "match AppStore {bundleId}"
        }
      }
    )

    # 5. Upload IPA to TestFlight
    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: true
    )
  end

  # PROMOTE TESTFLIGHT BUILD TO APP STORE REVIEW
  # Does NOT build or upload a new binary — uses skip_binary_upload.
  # The build must already exist on TestFlight from a prior `beta` run.
  lane :release do
    api_key = load_api_key
    deliver(
      api_key: api_key,
      submit_for_review: true,
      automatic_release: false,
      force: true,
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: true
    )
  end
end
```

## Fastlane — Appfile

```ruby
app_identifier("{bundleId}")
apple_id("rlibbey@gmail.com")
team_id("KNDYLHQ94J")
```

## Fastlane — Matchfile

```ruby
git_url("https://github.com/kandr-ryan/{codename}-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["{bundleId}"])
team_id("KNDYLHQ94J")
```

---

## firebase.json

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": ["node_modules", ".git", "firebase-debug.log", "firebase-debug.*.log", "*.local"],
      "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
    }
  ],
  "hosting": [
    {
      "target": "admin",
      "public": "hosting-dist",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        { "source": "/admin/**", "destination": "/admin/index.html" },
        { "source": "/admin", "destination": "/admin/index.html" }
      ],
      "headers": [
        {
          "source": "/admin/**/*.@(js|css)",
          "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
        },
        {
          "source": "index.html",
          "headers": [{ "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }]
        },
        {
          "source": "**",
          "headers": [
            { "key": "X-Frame-Options", "value": "DENY" },
            { "key": "X-Content-Type-Options", "value": "nosniff" },
            { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
            { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" }
          ]
        }
      ]
    }
  ],
  "storage": {
    "rules": "storage.rules"
  }
}
```

For web-only projects without an admin sub-path, simplify hosting to:

```json
"hosting": {
  "public": "dist",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
}
```

## .firebaserc

```json
{
  "projects": {
    "default": "{projectId}"
  },
  "targets": {
    "{projectId}": {
      "hosting": {
        "admin": ["{projectId}"]
      }
    }
  }
}
```

---

## Firestore Rules

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isAuthenticated() {
      return request.auth != null
        && request.auth.token.firebase.sign_in_provider != "anonymous";
    }

    function isAdmin() {
      return request.auth != null
        && (request.auth.token.role == "admin"
            || request.auth.token.role == "superAdmin");
    }

    function isOwner(userId) {
      return request.auth != null
        && request.auth.uid == userId;
    }

    // User profiles — owner read/write, admin read
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isAuthenticated() && isOwner(userId);
      allow update: if isOwner(userId) || isAdmin();
      allow delete: if isAdmin();
    }

    // App config — any signed-in user can read, admin write
    match /config/{document} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // Private config — Cloud Functions only
    match /privateConfig/{document} {
      allow read, write: if false;
    }

    // Admin users — Cloud Functions only
    match /adminUsers/{email} {
      allow read, write: if false;
    }
  }
}
```

## Storage Rules

```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {

    function isAuthenticated() {
      return request.auth != null
        && request.auth.token.firebase.sign_in_provider != "anonymous";
    }

    function isValidImage() {
      return request.resource.contentType.matches('image/.*')
        && request.resource.size < 10 * 1024 * 1024;
    }

    // User uploads — owner write, authenticated read
    match /uploads/{userId}/{allPaths=**} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
        && request.auth.uid == userId
        && isValidImage();
    }

    // Default deny
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## firestore.indexes.json

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

---

## Cloud Functions — functions/package.json

```json
{
  "name": "functions",
  "version": "1.0.0",
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "lint": "tsc --noEmit"
  },
  "engines": {
    "node": "22"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.0.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "typescript": "^5.7.0"
  }
}
```

### Optional dependencies (add based on features)

| Feature | Package | Install |
|---------|---------|---------|
| Gemini AI | `@google/genai` | `npm i @google/genai` |
| Geohash queries | `geofire-common` | `npm i geofire-common` |
| Stripe payments | `stripe` | `npm i stripe` |
| AgentMail email | `agentmail` | `npm i agentmail` |

## Cloud Functions — functions/tsconfig.json

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2022",
    "skipLibCheck": true
  },
  "compileOnSave": true,
  "include": ["src"]
}
```

## Cloud Functions — functions/src/index.ts

```typescript
import * as admin from "firebase-admin";

admin.initializeApp();

// Export functions as they are created:
// export { functionName } from "./moduleName";
```

### Common Cloud Function patterns

**Callable function (with secrets):**

```typescript
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export const myFunction = onCall(
  { secrets: ["MY_SECRET"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const secret = process.env.MY_SECRET;
    // ...
  }
);
```

**HTTP webhook handler:**

```typescript
import { onRequest } from "firebase-functions/v2/https";

export const handleWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }
  // verify signature, process payload
  res.status(200).send("OK");
});
```

**Firestore trigger:**

```typescript
import { onDocumentCreated } from "firebase-functions/v2/firestore";

export const onDocCreated = onDocumentCreated(
  "collection/{docId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    // process document
  }
);
```

**Scheduled function:**

```typescript
import { onSchedule } from "firebase-functions/v2/scheduler";

export const scheduledTask = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/New_York" },
  async () => {
    // daily task
  }
);
```

---

## Admin Console — package.json

```json
{
  "name": "{codename}-admin",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "deploy": "vite build && firebase deploy --only hosting:admin --project {projectId}"
  },
  "dependencies": {
    "firebase": "^11.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "~5.7.0",
    "vite": "^7.0.0"
  }
}
```

## Admin Console — vite.config.ts

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  base: "/admin/",
  plugins: [react(), tailwindcss()],
  build: {
    outDir: "dist/admin",
    rollupOptions: {
      output: {
        manualChunks: {
          firebase: ["firebase/app", "firebase/auth", "firebase/firestore"],
          vendor: ["react", "react-dom", "react-router-dom"],
        },
      },
    },
  },
});
```

## Admin Console — tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true
  },
  "include": ["src"]
}
```

## Admin Console — src/lib/firebase.ts

```typescript
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app);
export default app;
```

## Admin Console — src/hooks/useAuth.tsx

```tsx
import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  GoogleAuthProvider,
  type User,
} from "firebase/auth";
import { auth } from "../lib/firebase";

interface AuthContextValue {
  user: User | null;
  claims: Record<string, unknown> | null;
  loading: boolean;
  isAdmin: boolean;
  loginWithEmail: (email: string, password: string) => Promise<void>;
  loginWithGoogle: () => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [claims, setClaims] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    return onAuthStateChanged(auth, async (firebaseUser) => {
      setUser(firebaseUser);
      if (firebaseUser) {
        const token = await firebaseUser.getIdTokenResult();
        setClaims(token.claims as Record<string, unknown>);
      } else {
        setClaims(null);
      }
      setLoading(false);
    });
  }, []);

  const isAdmin = claims?.role === "admin" || claims?.role === "superAdmin";

  const loginWithEmail = async (email: string, password: string) => {
    await signInWithEmailAndPassword(auth, email, password);
  };

  const loginWithGoogle = async () => {
    await signInWithPopup(auth, new GoogleAuthProvider());
  };

  const logout = async () => {
    await signOut(auth);
  };

  return (
    <AuthContext.Provider
      value={{ user, claims, loading, isAdmin, loginWithEmail, loginWithGoogle, logout }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
```

## Admin Console — src/components/AuthGate.tsx

```tsx
import { type ReactNode } from "react";
import { useAuth } from "../hooks/useAuth";
import LoginPage from "../pages/LoginPage";

export default function AuthGate({ children }: { children: ReactNode }) {
  const { user, loading, isAdmin, logout } = useAuth();

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-500 border-t-transparent" />
      </div>
    );
  }

  if (!user) return <LoginPage />;

  if (!isAdmin) {
    return (
      <div className="flex h-screen flex-col items-center justify-center gap-4">
        <h1 className="text-2xl font-bold text-red-600">Access Denied</h1>
        <p className="text-gray-600">
          You do not have admin permissions. Contact your administrator.
        </p>
        <button onClick={logout} className="rounded bg-gray-200 px-4 py-2 hover:bg-gray-300">
          Sign Out
        </button>
      </div>
    );
  }

  return <>{children}</>;
}
```

---

## .gitignore

```gitignore
# Dependencies
node_modules/
.pnp.*
.yarn/

# Build output
dist/
lib/
build/
*.js.map

# Firebase
.firebase/
firebase-debug.log
firestore-debug.log
ui-debug.log

# Environment
.env
.env.local
.env.*.local

# iOS
*.xcodeproj
*.xcworkspace
xcuserdata/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM
Pods/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
*.moved-aside
*.hmap
*.xccheckout
*.xcscmblueprint

# iOS sensitive
GoogleService-Info.plist
ios/fastlane/api_key.json
ios/fastlane/AuthKey_*.p8

# Fastlane
ios/fastlane/report.xml
ios/fastlane/Preview.html
ios/fastlane/screenshots/
ios/fastlane/test_output/
ios/vendor/

# macOS
.DS_Store
*.swp
*~
.Spotlight-V100
.Trashes

# IDE
.idea/
*.sublime-workspace
.vscode/
```

---

## Stripe Integration — Cloud Functions pattern

```typescript
import Stripe from "stripe";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

function getStripe(): Stripe {
  return new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: "2024-12-18.acacia",
  });
}

export const createCheckoutSession = onCall(
  { secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const stripe = getStripe();
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: request.data.priceId, quantity: 1 }],
      success_url: `${request.data.returnUrl}?success=true`,
      cancel_url: `${request.data.returnUrl}?canceled=true`,
      metadata: { userId: request.auth.uid },
    });
    return { sessionId: session.id, url: session.url };
  }
);

export const handleStripeWebhook = onRequest(
  { secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"] },
  async (req, res) => {
    const stripe = getStripe();
    const sig = req.headers["stripe-signature"];
    if (!sig) { res.status(400).send("Missing signature"); return; }

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!
      );
    } catch (err) {
      res.status(400).send("Invalid signature");
      return;
    }

    switch (event.type) {
      case "checkout.session.completed":
        // provision access
        break;
      case "customer.subscription.updated":
      case "customer.subscription.deleted":
        // sync entitlements
        break;
      case "invoice.payment_failed":
        // handle failed payment
        break;
    }

    res.status(200).json({ received: true });
  }
);
```

### Admin console Stripe client

```typescript
import { loadStripe } from "@stripe/stripe-js";

export const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY);
```

---

## AgentMail — Cloud Functions pattern

```typescript
import { AgentMailClient } from "agentmail";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

export const onContactFormWrite = onDocumentCreated(
  { document: "contactSubmissions/{docId}", secrets: ["AGENTMAIL_API_KEY"] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const client = new AgentMailClient({ apiKey: process.env.AGENTMAIL_API_KEY! });

    await client.inboxes.messages.send("support@{subdomain}.kandr.io", {
      to: [data.email],
      subject: `Re: ${data.subject}`,
      text: `Thank you for contacting us. We received your message and will respond shortly.`,
      html: `<p>Thank you for contacting us. We received your message and will respond shortly.</p>`,
    });

    await event.data?.ref.update({ processed: true, emailSent: true });
  }
);
```

---

## DNS — Route 53 Commands

### Add CNAME record for Firebase Hosting

```bash
# Load AWS credentials (see ~/.cursor/rules/aws-credentials.mdc)
AWS_KEY=$(gcloud secrets versions access latest --secret=aws-access-key --project=streamingapp-32dcb)
AWS_SECRET=$(gcloud secrets versions access latest --secret=aws-secret-key --project=streamingapp-32dcb)
export AWS_ACCESS_KEY_ID="$AWS_KEY"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET"
export AWS_DEFAULT_REGION="us-east-1"

# Add CNAME: {subdomain}.kandr.io → {siteId}.web.app
aws route53 change-resource-record-sets \
  --hosted-zone-id Z5Q853FSJIIQT \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "{subdomain}.kandr.io",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "{siteId}.web.app"}]
      }
    }]
  }'
```

### Add Firebase Hosting custom domain

```bash
ACCESS_TOKEN=$(gcloud auth print-access-token)
curl -X POST \
  "https://firebasehosting.googleapis.com/v1beta1/projects/{projectId}/sites/{siteId}/customDomains?customDomainId={subdomain}.kandr.io" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-goog-user-project: {projectId}" \
  -H "Content-Type: application/json" -d '{}'
```

---

## Marketing Site — Static HTML Pattern (radio-app style)

Simple landing page using static HTML and Tailwind CDN. No build step needed.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{App Name} — {tagline}</title>
  <meta name="description" content="{App description for SEO}">

  <!-- Open Graph -->
  <meta property="og:title" content="{App Name}">
  <meta property="og:description" content="{App description}">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://{subdomain}.kandr.io">
  <meta property="og:image" content="https://{subdomain}.kandr.io/og-image.png">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{App Name}">
  <meta name="twitter:description" content="{App description}">

  <!-- App Store Smart Banner (iOS apps) -->
  <meta name="apple-itunes-app" content="app-id={appleAppId}">

  <!-- Tailwind CDN -->
  <script src="https://cdn.tailwindcss.com"></script>

  <!-- JSON-LD Structured Data -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "{App Name}",
    "operatingSystem": "iOS",
    "applicationCategory": "{category}",
    "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" }
  }
  </script>
</head>
<body class="font-sans antialiased text-gray-900">
  <!-- Hero, Features, CTA, Footer -->
</body>
</html>
```

### Directory structure (static)

```
marketing-site/
├── index.html           # Home page
├── features.html        # Features page
├── privacy.html         # Privacy policy (required for App Store)
├── terms.html           # Terms of service
├── contact.html         # Contact form (optional)
├── assets/
│   ├── images/
│   └── favicon.ico
└── styles.css           # Optional custom CSS beyond Tailwind
```

## Marketing Site — React SPA Pattern (kandr.io / yard-sale style)

Full React app with routing, built with Vite + Tailwind — same stack as the admin console.

### package.json

```json
{
  "name": "{codename}-site",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "~5.7.0",
    "vite": "^7.0.0"
  }
}
```

### vite.config.ts

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    outDir: "dist",
  },
});
```

### Standard pages

```
marketing-site/src/pages/
├── HomePage.tsx          # Hero, features overview, CTA
├── FeaturesPage.tsx      # Detailed feature list
├── PrivacyPage.tsx       # Privacy policy (required for App Store)
├── TermsPage.tsx         # Terms of service
├── ContactPage.tsx       # Contact form (writes to Firestore contactSubmissions)
└── FaqPage.tsx           # FAQ (optional)
```

### SEO pattern (add to each page's `<head>` or use react-helmet-async)

Every page must include: `<title>`, `<meta name="description">`, Open Graph tags,
Twitter Card tags, and JSON-LD structured data. The App Store Smart Banner meta tag
should be on every page for iOS apps:
```html
<meta name="apple-itunes-app" content="app-id={appleAppId}">
```

## Marketing Site — Build Script (shared hosting)

When marketing site and admin console share one Firebase Hosting target, use a build
script to merge their outputs into a single `dist/` directory.

```bash
#!/bin/bash
# scripts/build.sh — Merge marketing site + admin console into dist/
set -e

echo "Cleaning dist/..."
rm -rf dist

echo "Building marketing site..."
cd marketing-site && npm run build && cd ..
cp -r marketing-site/dist/ dist/

echo "Building admin console..."
cd admin-console && npm run build && cd ..
cp -r admin-console/dist/admin/ dist/admin/

echo "Build complete. Output in dist/"
```

### firebase.json hosting config (shared)

When both share the same hosting target, configure rewrites to route admin traffic
to the admin SPA and everything else to the marketing site:

```json
"hosting": {
  "public": "dist",
  "rewrites": [
    { "source": "/admin/**", "destination": "/admin/index.html" },
    { "source": "/admin", "destination": "/admin/index.html" },
    { "source": "**", "destination": "/index.html" }
  ]
}
```

---

## iOS — Base.xcconfig

```
// Base configuration shared across Debug and Release
// Project-specific overrides go here
```

## Admin Console — .env template

```
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN={projectId}.firebaseapp.com
VITE_FIREBASE_PROJECT_ID={projectId}
VITE_FIREBASE_STORAGE_BUCKET={projectId}.firebasestorage.app
VITE_FIREBASE_MESSAGING_SENDER_ID=
VITE_FIREBASE_APP_ID=
VITE_STRIPE_PUBLISHABLE_KEY=
```

---

## Cloud Run — Dockerfile template

```dockerfile
FROM node:22-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 8080
CMD ["node", "dist/index.js"]
```

## Cloud Run — deploy.sh template

```bash
#!/bin/bash
set -e
PROJECT_ID="{gcpProjectId}"
SERVICE_NAME="{codename}-api"
REGION="us-central1"

gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME --project $PROJECT_ID
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --project $PROJECT_ID
```

---

## Cursor Rule Templates

### project-context.mdc

```markdown
---
description: Core project context, architecture, and identifiers for {App Name}
alwaysApply: true
---

# {App Name} — Project Context

## Identifiers

- **Bundle ID**: `{bundleId}`
- **Apple Team ID**: `KNDYLHQ94J`
- **Firebase Project**: `{projectId}`
- **Firebase iOS App ID**: `{firebaseIosAppId}`
- **Firebase Web App ID**: `{firebaseWebAppId}`

## Architecture

- **iOS App**: SwiftUI, minimum iOS 17.0, Swift 5.9
- **Admin Console**: React 19 + Vite 7 + TypeScript + Tailwind 4, at `admin-console/`
- **Backend**: Firebase (Auth, Firestore, Storage, Functions)
- **Project generation**: XcodeGen (`ios/project.yml`)

## Authentication

- **Anonymous-first**: Users auto-sign in anonymously on launch
- **Account creation**: Required for {gated features}
- **Providers**: {providers list}

## Firestore Structure

- `users/{userId}` — user profile
- `config/appConfig` — feature flags, app settings
{additional collections as needed}

## Firebase Auth Roles

Admin users have custom claims: `{ role: "admin" }` or `{ role: "superAdmin" }`
Super admin emails: `ryan@kandr.io` / `rlibbey@gmail.com`

## Git Repository

- **Code**: `https://github.com/kandr-ryan/{codename}.git`
- **Certs**: `https://github.com/kandr-ryan/{codename}-certs.git`
```

### fastlane-deployment.mdc

```markdown
---
description: Fastlane and deployment conventions for {App Name}
globs: ios/fastlane/**
alwaysApply: false
---

# Fastlane & Deployment

## Code Signing

- **Debug**: Automatic signing, Apple Development identity
- **Release**: Manual signing via Fastlane Match, Apple Distribution identity
- **Provisioning profile**: `match AppStore {bundleId}`
- **Certs repo**: `https://github.com/kandr-ryan/{codename}-certs.git`
- **Match password**: `{matchPassword}`

## App Store Connect API Key

- **Key ID**: `6LF5PQ5KPG`
- **Issuer ID**: `69a6de80-f231-47e3-e053-5b8c7c11a4d1`
- **Key file**: `ios/fastlane/AuthKey_6LF5PQ5KPG.p8` (gitignored)

## Fastlane Commands — Two Distinct Operations

### `fastlane beta` — Build + Upload to TestFlight

This is the ONLY command that builds a new binary. It runs XcodeGen, Match,
increments the build number, archives, and uploads to TestFlight.

\`\`\`bash
cd ios
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
export MATCH_PASSWORD="{matchPassword}"
export CI=false
security unlock-keychain -p "{keychainPassword}" ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "{keychainPassword}" ~/Library/Keychains/login.keychain-db
bundle exec fastlane beta
\`\`\`

### `deliver` — Promote TestFlight Build to App Store Review

This does NOT build or upload anything. It takes an EXISTING TestFlight build
and submits it for App Store review. The `skip_binary_upload:true` flag is
mandatory — without it, deliver tries to re-upload and fails with a 409 conflict.

\`\`\`bash
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
\`\`\`

## Pre-Build Verification (MANDATORY before every `fastlane beta`)

Do NOT skip any step. Run in order before every build.

1. **Disk space**: `df -h / | tail -1` — need >= 4 GB free
2. **ASC version check**: query App Store Connect for the live version
   The version in project.yml MUST be strictly higher than the live version
3. **Version train**: verify the marketing version is not in a closed train
4. **Stale archive**: `rm -rf ~/Library/Developer/Xcode/Archives/{AppName}.xcarchive`
5. **API key**: verify `ios/fastlane/AuthKey_6LF5PQ5KPG.p8` exists
6. **Keychain**: unlock + set partition list (MANDATORY, not just on error)
7. **Environment**: PATH has Homebrew Ruby, MATCH_PASSWORD set, CI=false

## Admin Console Deployment

\`\`\`bash
cd admin-console && npm run deploy
\`\`\`

## Firebase Backend

\`\`\`bash
firebase deploy --only functions --project {projectId}
firebase deploy --only firestore:rules,storage --project {projectId}
\`\`\`

## Common Errors

| Error | Fix |
|-------|-----|
| `errSecInternalComponent` | Run BOTH unlock-keychain AND set-key-partition-list before every build |
| `No code signing identity... readonly` | `export CI=false` (Cursor sets CI=true) |
| `Could not find 'bundler'` | Use Homebrew Ruby: `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` |
| `Invalid Pre-Release Train` | Version train closed — bump marketing version in project.yml |
| `Redundant Binary Upload` / 409 conflict | Using `deliver` without `skip_binary_upload:true` — the binary already exists from `beta` |
| `already been used` upload error | Stale archive — delete `~/Library/Developer/Xcode/Archives/{AppName}.xcarchive` |
| `Couldn't decrypt the repo` | Wrong MATCH_PASSWORD — check the Match Password Registry in the bootstrap skill |
```

### ios-development.mdc

```markdown
---
description: iOS development conventions for {App Name}
globs: ios/**/*.swift
alwaysApply: false
---

# iOS Development Rules

## Project Generation

- Always run `xcodegen generate` after modifying `ios/project.yml`
- Never edit `{AppName}.xcodeproj` directly — it is regenerated from `project.yml`
- New source files must go under `ios/{AppName}/` to be picked up

## Directory Structure

- `App/` — Entry point, AppDelegate, ContentView
- `Core/` — Singleton managers (AuthManager, FirestoreService, etc.)
- `Features/` — Feature modules organized by screen/flow
- `Shared/Models/` — Codable Firestore data models
- `Shared/Views/` — Reusable SwiftUI components
- `Shared/Extensions/` — Swift extensions
- `Resources/` — Assets.xcassets, Info.plist, entitlements, GoogleService-Info.plist

## Data Models

- All Firestore models use `@DocumentID` for the document ID
- Use `CodingKeys` with snake_case mapping to match Firestore field names
- Optional fields decode with defaults — never crash on missing data

## Authentication

- Anonymous-first: `Auth.auth().signInAnonymously()` on first launch
- Account linking: `currentUser.link(with: credential)` to upgrade from anonymous
- Gated features check `authManager.isAuthenticated` (non-anonymous)
```

### ios-build-safety.mdc

```markdown
---
description: Prevents iOS builds, TestFlight uploads, and App Store submissions unless explicitly requested
alwaysApply: true
---

# iOS Build Safety

iOS builds are expensive (3-5 min), upload to a live distribution channel, and may trigger App Store review. **Never** initiate a build unless the user explicitly asks.

## Rules

1. **Explicit consent required** — Do not run `fastlane beta`, `xcodebuild archive`, or any build command unless the user says: "build", "push to TestFlight", "upload to TestFlight", "submit to App Store", "ship it", or equivalent.
2. **"build" means TestFlight only** — Unless the user explicitly mentions App Store, a "build" request means archive + upload to TestFlight only.
3. **Stop after code changes** — When you finish implementing a feature or fix, report what was done and wait. Do not auto-build.
4. **No silent resubmission** — If a build fails and you fix the issue, tell the user and ask before retrying.
5. **Deployments are separate** — Cloud Functions, Firestore rules, and web hosting deploys do not require extra confirmation.
```

### cloud-functions-agent.mdc

```markdown
---
description: Review gate for Cloud Function creation — check before adding new functions
alwaysApply: true
---

# Cloud Functions Review Gate

Before creating a new Cloud Function:

1. Check `functions/src/index.ts` for existing exports
2. Search for functions in the same domain
3. If an existing function can be extended (via parameter or flag), recommend that
4. If a new function is genuinely needed:
   - State why no existing function covers it
   - Propose name, trigger type, and source file
   - Confirm with user before writing code

## Naming Conventions

- `onX` for Firestore/Auth triggers (e.g. `onUserCreated`)
- `handleX` for HTTP webhooks (e.g. `handleStripeWebhook`)
- `verbNoun` for callable functions (e.g. `createCheckoutSession`)
- `scheduledX` for cron functions (e.g. `scheduledBackup`)
```
