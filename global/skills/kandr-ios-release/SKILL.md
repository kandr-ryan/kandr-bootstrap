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

**Then stop and ask the user before deleting anything.** `kandr-router.mdc` prohibits the
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

**Check the project overlay for the build path before Step 1.** Some Kandr apps build on Xcode
Cloud rather than this Mac. When one does, Step 1 is a cloud workflow run rather than `fastlane
beta` — see "Xcode Cloud builds" below — and Step 2 is unchanged. The overlay names the product,
the workflow and any trigger helper.

**Every project delta states its build path explicitly; silence is read as "not adopted".** A
delta that names only `fastlane beta` is saying the cloud is not in use, so if that is deliberate
it must say so, and if adoption is planned it must say that too. This is not bookkeeping: the two
paths run separate counters and must never build one marketing version, so a reader has to
distinguish "not adopted" from "not documented" without inferring it from a skill nobody wrote. A
cloud project names its product, workflow and trigger helper; a local project names the lane and
whether its station or scheme argument is required; a project mid-adoption names what is still
unknown.

**Step 1 — build and upload to TestFlight:**

_On a project whose overlay still names the local lane as the path, that lane is `fastlane beta`:_

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

- **`skip_binary_upload:true`** — the build step already uploaded the IPA (`beta` locally, the
  cloud workflow when the project builds there). Without this, `deliver` tries to upload again and
  fails with **409 Redundant Binary Upload**. Never run a combined `release` lane that does both in
  one pass.
- **`app_version` and `build_number`** — always pass them explicitly. Without them `deliver`
  cannot create the new App Store version and fails with "Cannot find edit app store version"
  after retrying for 20+ minutes.
- **`precheck_include_in_app_purchases:false`** — ASC API key auth cannot validate in-app
  purchases, so precheck fails without this.

### Xcode Cloud builds

An Xcode Cloud workflow owns the archive, the IPA export and the TestFlight upload. When a project
uses one, **it is the build path and the local `beta` lane is the documented fallback.** Do not run
both for the same marketing version: Xcode Cloud's counter and `latest_testflight_build_number`
never see each other, so the second upload is rejected as "already been used" minutes after an
archive that looked clean. Confirm the cloud run actually finished — and that its build number is
the one recorded — before concluding a fallback is needed.

**A cloud run is scriptable, and the REST API is the only programmatic path.** Opening the App
Store Connect web UI or the Xcode app is a convenience, not a requirement. `POST /v1/ciBuildRuns`
starts a run:

```json
{ "data": { "type": "ciBuildRuns",
            "attributes": { "clean": true },
            "relationships": {
              "workflow": { "data": { "type": "ciWorkflows", "id": "<workflow id>" } },
              "sourceBranchOrTag": { "data": { "type": "scmGitReferences", "id": "<ref id>" } } } } }
```

`GET /v1/ciProducts` lists the products and `GET /v1/ciProducts/{id}/workflows` the workflows, so
the ids never have to be copied out of the UI. Two responses mislead if you have not seen them
before: `GET /v1/ciBuildRuns` is refused **403** with the body *"Allowed operations are: CREATE,
GET_INSTANCE"* — creation is the permitted operation and listing is not, so that body is not a
denial of the endpoint — and a `POST` with no `workflow` relationship **409s** with *"You must
provide a value for the relationship 'workflow'"*, which is how you know the rest of the shape was
accepted. The API targets a **branch or tag, never a raw commit SHA** — `sourceBranchOrTag` is the
only ref selector — so "build this exact commit" means "push a branch or tag that points at it
first".

The two tools people reach for on the assumption they can do this **cannot**: Spaceship has no
Xcode Cloud surface at all (no `ci_build_run`, `ciWorkflow` or `xcodecloud` anywhere in the gem),
and the Xcode CLI ships no cloud or CI tool — `altool` and `notarytool` only upload and notarize.
Do not spend a session looking for a caller; there is only the REST API. Environment variables are
the part that genuinely has **no** API surface and must be entered in the web UI or Xcode — do not
read that gap as covering the trigger.

Where the project ships a trigger helper, use it rather than hand-rolling the call: the JWT has one
field that is easy to get wrong — `dsaEncoding: "ieee-p1363"`, because Node signs DER by default
and Apple answers that with `InvalidProviderToken`, an error naming the token rather than the
encoding.

### Reading a finished run's log — the answer to "we could not verify it"

A cloud run's output is not visible in a terminal, but it **is** reachable over the same API, so
"the build log was not read" is not a reason to record a cloud result as unverified. A run has
**build actions** (`GET /v1/ciBuildRuns/{id}/actions`), each action has **artifacts**
(`GET /v1/ciBuildActions/{id}/artifacts`), and one artifact is the **`LOG_BUNDLE`** — the archive
log and the CI scripts' output, packaged at the end of the action. Its `downloadUrl` is signed and
short-lived and must be fetched **without** the bearer token; it is a CDN host, so sending the
token there is a leak with no benefit. Unzip it and the logs are on disk.

**Finding the run.** The refusal in the table above is the collection list `GET /v1/ciBuildRuns`,
which stays 403. The **scoped** lists are not refused: `GET /v1/ciProducts/{id}/buildRuns` returns
every run in the product (sorted by number, so the newest is first) and
`GET /v1/ciWorkflows/{id}/buildRuns` narrows to one workflow. That is how "the most recent run" and
"the run for build N" are reached without the web UI.

**Why it matters.** A claim that depends on the build log — a dSYM or symbol upload, a signing
step, a `ci_post_clone` action, whether a build phase fired — can be either read or guessed, and a
guess recorded as a fact is the failure this prevents. When a run's log has been read, record what
it says; when it has not, say **unverified** and say why. Do not let an unverifiable claim stand as
a verified one, and do not let a proven *script* stand in for a proven *run*: an unchanged
`ci_post_xcodebuild.sh` says nothing about whether the upload happened on the run in question.
Where the project's trigger helper supports it, its log flag wraps this whole path — prefer it to
hand-rolled calls.

### The next build number is not the per-version counter

`fastlane status` and `latest_testflight_build_number` report App Store Connect's **per-version**
counter. Xcode Cloud stamps the build with `CI_BUILD_NUMBER`, which is **product-wide and
monotonic**: every run in the product consumes a number, including the compile-only workflows that
fire on every push to the default branch. On the release where this surfaced, `fastlane status`
predicted **11** and the build uploaded as **17**, because CI runs #11–#16 had already consumed the
intervening numbers; App Store Connect accepted the jump.

So **confirm the next number from Xcode Cloud / App Store Connect** (Settings → Xcode Cloud →
Build Number → Next Build Number) rather than predicting it, and treat any per-version figure as
advisory. Never present it as "the next build number", and never hand-edit a number to close the
gap — numbers no longer restart at 1 when the marketing version bumps; the counter is across
versions.

### A cloud upload does not attach the build to a testing group

**"Uploaded successfully" is not "testers can install it", and the two build paths differ on
exactly that point.** The local lane's `upload_to_testflight` assigns the build to a beta testing
group as part of the upload; an Xcode Cloud `Archive` action uploads the build and stops, the
group relationship being no part of that upload. The build then reaches `VALID` with App Store
Connect holding it and **in no group at all**, which puts it in nobody's TestFlight app.

The symptom is what makes this expensive: a `VALID` build in zero groups is invisible, and it
presents exactly like Apple's propagation delay — so the natural response, wait and then
re-upload, burns a day and a build number without touching the cause. **The check that settles it
is the build's `betaGroups` relationship** (`GET /v1/builds/{id}?include=betaGroups`); empty is
the defect rather than a timing artefact, and it is readable as soon as the build is `VALID`. The
corroborating transition is `buildBetaDetail.internalBuildState`: a build in no group sits at
`READY_FOR_BETA_TESTING`, and attaching it to one moves it to `IN_BETA_TESTING` and turns
`autoNotifyEnabled` on. Attaching is a **reversible relationship write** — not a re-upload — so a
build stranded this way is repaired rather than rebuilt. Read `betaGroups` before reporting any
TestFlight build as available, and say "uploaded but in no group" when that is what the API shows.

**The remedy is to make the attach part of the trigger, not a checklist item — a step a human
remembers is the step that gets skipped.** Where the project ships a cloud trigger helper, its run
path should wait for the build to process and attach it before it returns, with a separate
attach-only path for repairing a build that already uploaded. Select the group by
`isInternalGroup` and assert it internal before writing, so an external group can never be
targeted; then **read the relationship back** (`betaGroups`, and the `internalBuildState`
transition) — an attach that is not read back is not evidence it landed.

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
| `403` `"Allowed operations are: CREATE, GET_INSTANCE"` on `GET /v1/ciBuildRuns` | Listing cloud build runs is not permitted; only create and instance-read are | Not a denial of the endpoint — `POST /v1/ciBuildRuns` starts a run. See "Xcode Cloud builds" |
| Cloud build number is well ahead of `latest_testflight_build_number` / `fastlane status` | The Xcode Cloud counter is product-wide, and push-triggered compile-only runs consumed the intervening numbers | Expected — read the next number from App Store Connect, not from the per-version prediction |

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
- `kandr-router.mdc` — the machine safety rules this skill defers to; `kandr-machine` for tool versions and paths
