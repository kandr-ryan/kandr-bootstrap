---
name: kandr-ios-release
description: iOS release workflow shared across every Kandr app — Homebrew Ruby setup, XcodeGen, Match signing, the two-step TestFlight-then-submit process, certificate and keychain safety policy, versioning, and the common error table. Use when the request mentions iOS, Fastlane, TestFlight, App Store Connect, match, deliver, pilot, signing, provisioning profiles, certificates, build numbers, marketing versions, or XcodeGen.
---

# iOS release

Shared workflow for every Kandr iOS app. Per-app values — bundle ID, scheme, Match repo,
ASC key ID and app ID, lane names, project path — live in that repo's `kandr-overlay.mdc`.

**Do not build unless the user asked for a build.** Editing Swift source is not a request to
ship to TestFlight. See `kandr-deploy`.

---

## 1. Shared identifiers

| Setting | Value |
|---|---|
| Apple Team ID | `KNDYLHQ94J` |
| Team name | Kandr Media, LLC |
| ASC API issuer ID | `69a6de80-f231-47e3-e053-5b8c7c11a4d1` |

The **ASC API key ID differs by project** and lives in the project overlay. Some apps use
`6LF5PQ5KPG`; radio-app uses `9C4UN5HNPV`. Do not assume.

---

## 2. Environment setup — do this first, every time

System Ruby at `/usr/bin/ruby` is too old and lacks write permissions:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
```

Verify before proceeding:

```bash
ruby --version    # expect 4.x
which bundle      # expect /opt/homebrew/opt/ruby/bin/bundle
```

If `bundle exec fastlane` fails with a bundler version mismatch, call the gem binary directly
instead of fighting `Gemfile.lock`:

```bash
/opt/homebrew/lib/ruby/gems/4.0.0/bin/fastlane beta
```

If the gems path has moved, check with `ls /opt/homebrew/lib/ruby/gems/`.

---

## 3. Keychain policy

**Never run `security unlock-keychain` without `-p`.** It opens an interactive prompt that
hangs the agent session indefinitely.

**Never put a keychain password in a rule, skill, or any tracked file.** That is what made
this a problem in the first place.

The keychain is normally already unlocked from the user's macOS login session, so no unlock
should be needed. If signing fails because it is locked, the default is to **say so and ask
the user to unlock it in their own terminal**.

### Opt-in automatic unlock

Some projects build several apps back to back, and the keychain relocks between sequential
Fastlane runs — producing `errSecInternalComponent` partway through. Those projects may opt in
by declaring `KEYCHAIN_PASSWORD` in their `.kandr-secrets` manifest under `[fastlane]`. When
present, resolve it at build time and never echo it:

```bash
security unlock-keychain -p "$(kandr-secrets get KEYCHAIN_PASSWORD)" ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$(kandr-secrets get KEYCHAIN_PASSWORD)" ~/Library/Keychains/login.keychain-db
```

If the project has **not** declared it, do not go looking for a password — ask the user.

> A login-keychain password unlocks the user's whole macOS account, so this trades real blast
> radius for convenience. The safer end state is a dedicated codesigning keychain with a random
> password, created by Fastlane's `create_keychain` and referenced through match's
> `keychain_name` / `keychain_password`. Recommend that upgrade when touching a Fastfile;
> do not perform it mid-release.

---

## 4. Certificate safety

**Never revoke, disable, or delete a signing certificate in the Apple Developer Portal or the
Match certs repo.** Revoking a distribution certificate invalidates every provisioning profile
that references it, breaking all builds for the entire team immediately. Never run `match nuke`.

If a revocation truly seems necessary, explain the blast radius to the user and let them decide.

### Duplicate certificates in the local keychain

Symptom: the archive fails with "Provisioning profile doesn't include signing certificate"
even though match completed successfully. The keychain has two or more "Apple Distribution"
certificates with the same name and xcodebuild picked the wrong one.

Diagnose (read-only, safe to run):

```bash
security find-identity -v -p codesigning | grep "Apple Distribution"
```

Two or more identically named certs confirms the diagnosis. To find which one the Match
profiles actually reference, decode each profile and print the SHA1 of its embedded certificate:

```bash
for p in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"/*.mobileprovision; do
  name=$(security cms -D -i "$p" 2>/dev/null | plutil -extract Name raw -)
  case "$name" in
    *"match AppStore"*)
      echo "=== $name ==="
      python3 -c "
import plistlib, subprocess, hashlib, sys
data = subprocess.run(['security','cms','-D','-i',sys.argv[1]], capture_output=True).stdout
for cert in plistlib.loads(data).get('DeveloperCertificates', []):
    print(hashlib.sha1(cert).hexdigest().upper())
" "$p"
      ;;
  esac
done
```

The cert whose SHA appears in the output is the correct one; the others are stale.

**Then stop and ask the user before deleting anything.** `local-toolchain.mdc` prohibits the
agent from running `security delete-certificate`. Present the stale SHA and the exact command
so the user can run it themselves:

```bash
security delete-certificate -Z <STALE_SHA1> ~/Library/Keychains/login.keychain-db
```

---

## 5. Project generation

- Projects are generated by **XcodeGen** from `project.yml`
- **Never hand-edit `.xcodeproj`** — the next `xcodegen generate` discards the change
- `project.yml` is the source of truth for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- Run `xcodegen generate` before archiving; most `beta` lanes do this automatically
- If the app has a Watch target or an App Clip, bump the version in **every** target, not just
  base settings

---

## 6. Signing with Match

- Each app has its own git-backed certs repo (named in the project overlay)
- `MATCH_PASSWORD` lives in GCP Secret Manager on the app's project, and reaches Fastlane
  through a gitignored `fastlane/.env` that is **generated, never hand-written**:

```bash
kandr-secrets env ios/fastlane/.env --group fastlane
```

**The filename matters, and it differs by project.** Fastlane auto-loads only `.env` and
`.env.default`; a `.env.local` is read solely when a lane runs with `--env local`. Writing
secrets to the wrong file fails silently — no error, just an unset variable that surfaces
later as a wrong-password error. Never use `.env.default` at all; it is not gitignored in any
Kandr repo.

| Project | Target file | Why |
|---|---|---|
| streaming-app, radio-app, Fish On! | `ios/fastlane/.env` | Fastlane auto-load |
| yard-sale, garagesale-legacy | `fastlane/.env.local` | Fastfile hand-rolls a `.env.local` reader at the top |

Check the top of the project's `Fastfile` before choosing. If it has no explicit loader, use
`.env`.

- If a lane fails on signing, run `kandr-secrets doctor` before touching anything else —
  a missing or newline-corrupted `MATCH_PASSWORD` reports as a wrong-password error
- Debug builds use automatic signing; Release uses Match manual signing
- Never write a Match password into a tracked file, and never paste one into a lane invocation

See `kandr-secrets` for the manifest format and the rest of the commands.

Regenerating `api_key.json` for `deliver` (substitute the project's key ID):

```bash
ruby -e "require 'json'; k=File.read('./fastlane/AuthKey_KEYID.p8'); \
File.write('./fastlane/api_key.json', JSON.pretty_generate({ \
  key_id: 'KEYID', \
  issuer_id: '69a6de80-f231-47e3-e053-5b8c7c11a4d1', \
  key: k, in_house: false }))"
```

---

## 7. Versioning

**Marketing version** (`MARKETING_VERSION` in `project.yml`) — bump before every build that
contains changes since the last release. Never ship two different feature sets under the same
marketing version. It must exceed the live App Store version.

**Build number** (`CFBundleVersion`) — scoped to the current marketing version; Apple resets
the sequence when the marketing version changes. Fastlane auto-increments from the latest
TestFlight build. Do not hand-edit it in `Info.plist`.

When the marketing version is bumped, most projects set `FORCE_BUILD_NUMBER=1` to restart the
sequence at 1. Check the project overlay.

Query App Store Connect for the live version before building rather than trusting a version
table in a file — tables go stale.

### Build number conflicts

When a build fails with "This build already exists" or a duplicate build number error,
**do not silently retry or auto-bump.** A previous build may still be processing, or the
build-number query returned a stale value. Stop and ask the user which they want.

### Stale archives

An old archive with the previous build number baked in causes xcodebuild to skip the rebuild
and the upload to reject a correct build number as "already been used." Delete it before
building a new version:

```bash
rm -rf ~/Library/Developer/Xcode/Archives/<AppName>.xcarchive
```

---

## 8. The two-step release

"Release" is two distinct actions. Conflating them causes the most common failure in this
workflow.

**Step 1 — build and upload to TestFlight:**

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
bundle exec fastlane beta
```

**Step 2 — submit that build for App Store review:**

```bash
bundle exec fastlane run deliver \
  api_key_path:"./fastlane/api_key.json" \
  submit_for_review:true \
  automatic_release:false \
  force:true \
  skip_binary_upload:true \
  app_version:"X.Y.Z" \
  build_number:"N" \
  precheck_include_in_app_purchases:false
```

Why each flag matters:

- **`skip_binary_upload:true`** — `beta` already uploaded the IPA. Without this, `deliver`
  tries to upload again and fails with **409 Redundant Binary Upload**. Never run a combined
  `release` lane that does both in one pass.
- **`app_version` and `build_number`** — always pass them explicitly. Without them `deliver`
  cannot create the new App Store version and fails with "Cannot find edit app store version"
  after retrying for 20+ minutes.
- **`precheck_include_in_app_purchases:false`** — ASC API key auth cannot validate in-app
  purchases, so precheck fails without this.

---

## 9. Common errors

| Error | Cause | Fix |
|---|---|---|
| `Could not find 'bundler'` / `bundler: command not found: fastlane` | System Ruby, or `Gemfile.lock` pins an uninstalled bundler | Set the Homebrew Ruby PATH, or call the gem binary directly |
| Redundant Binary Upload (409) | `deliver` re-uploading what `beta` already sent | Run them separately with `skip_binary_upload:true` |
| "Cannot find edit app store version" | `deliver` called without version and build number | Pass `app_version` and `build_number` explicitly |
| "Precheck cannot check IAP with API Key" | API key auth cannot validate IAP | `precheck_include_in_app_purchases:false` |
| "This build already exists" | Stale build-number query or a build still processing | Stop and ask the user — do not auto-bump |
| "already been used" on a correct build number | Stale local archive | Delete the archive, rebuild |
| Train / version closed | Marketing version already released | Bump `MARKETING_VERSION`, re-run |
| "Provisioning profile doesn't include signing certificate" | Duplicate certs in keychain | Diagnose per section 4, then ask the user to delete the stale one |
| Preflight hangs indefinitely | `security unlock-keychain` run without `-p` | Never run it bare; use the opt-in form in section 3 or ask the user |
| `errSecInternalComponent` during export/codesign | Keychain relocked between sequential builds | If the project declares `KEYCHAIN_PASSWORD`, unlock per section 3; otherwise ask the user |
| ITMS-90683 missing purpose string | `Info.plist` missing an `NS*UsageDescription` key | Add the key. Check `git diff` on Info.plist — large commits revert these |
| `CI=true` breaks match | Cursor sets `CI=true`, putting match in readonly mode | `export CI=false` |

---

## 10. Reporting a release

Always report:

- **Version** — marketing version and build number
- **Archive** — succeeded or failed, with the error class
- **Upload** — TestFlight status
- **Submission** — App Store review status, if applicable
- **Next step** — what to watch: processing time, review status, whether manual release is needed

Never report a build as uploaded without the command output proving it.

---

## Related skills

- `kandr-deploy` — why native builds are gated differently from backend deploys
- `kandr-qa` — the regression gate before any release
- `kandr-worklog` — recording the release
- `local-toolchain.mdc` — the machine safety rules this skill defers to
