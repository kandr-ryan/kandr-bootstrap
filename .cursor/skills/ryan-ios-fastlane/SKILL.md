---
name: ryan-ios-fastlane
description: iOS release workflow using Fastlane (beta/TestFlight + submission), plus XcodeGen/CocoaPods guardrails. Use when the user mentions iOS, TestFlight, App Store Connect, Fastlane, match, deliver, pilot, signing, provisioning profiles, or XcodeGen.
---

# iOS release workflow (Fastlane)

## Operating rules

- “Release” is two distinct actions:
  - **Build/upload to TestFlight** (Fastlane lane like `beta`)
  - **Promote a TestFlight build** to App Store review (deliver with `skip_binary_upload:true`)
- Do not run destructive signing operations without explicit user confirmation.

## Pre-flight checklist

- Keychain unlocked (if needed)
- Correct Xcode selected (`xcode-select`)
- Correct Ruby in PATH (Homebrew Ruby if used)
- `MATCH_PASSWORD` available if match is used
- Marketing version > live App Store version

## Typical commands (illustrative)

```bash
cd ios
bundle exec fastlane beta
```

```bash
cd ios
bundle exec fastlane run deliver \
  skip_binary_upload:true \
  skip_screenshots:true
```

## If something fails

1. Capture the full error output
2. Identify whether it’s:
   - auth (ASC / keychain)
   - signing (match/certs/profiles)
   - build config (XcodeGen/CocoaPods)
3. Suggest the minimal fix and ask before taking any irreversible action

