---
name: release
description: Ship a new Pod version. Use when user says "release", "ship", "publish a new version", "cut a release", or asks to update the website with a new build. Knows the full Sparkle/Developer-ID/notarize pipeline and the hybrid update channel (Sparkle for 1.8+, NSAlert for legacy).
---

# Release Pod

Cut a new Pod release: bump versions, archive, notarize, sign with Sparkle, push to all three repos.

## Repos involved

| Repo | Path | Purpose |
|------|------|---------|
| `pod` | `~/Developer/pod` | App source. `git@github.com:Iskrata/pod.git` |
| `pod-website` | `~/Developer/pod-website` | Vercel site (www.desktopipod.com). Hosts both `.zip` (Sparkle) and `.dmg` (manual download), plus `appcast.xml`, `version.json`. |
| `pod-public` | `~/Developer/pod-public` | Legacy mirror for pre-Sparkle (NSAlert) users polling `version.json`. Mirrors the website's appcast for safety. |

## Update channel architecture

**Two cohorts in the wild:**

1. **Pre-Sparkle (NSAlert) users** — every install ≤ 1.7. They poll `https://raw.githubusercontent.com/Iskrata/pod-public/main/version.json` and show a manual NSAlert. Their app cannot auto-install — they get a popup, click Download, browser opens `download_url`, user manually drag-installs.
2. **Sparkle users** — every install ≥ 1.8. Their `Info.plist` has `SUFeedURL=https://www.desktopipod.com/appcast.xml` and `SUPublicEDKey` matching the EdDSA private key in this Mac's login keychain. They auto-update.

**Cohort 1 → Cohort 2 migration**: when 1.7 users see the NSAlert and reinstall, they land on 1.8+ which has Sparkle baked in. From the next release onwards they're auto-updated.

## Signing & notarization state (current Mac)

- **Developer ID Application** cert: in login keychain. Team `B7949NL6NG`. CN: `ISKREN BOZHIDAROV ALEKSANDROV`.
- **Sparkle EdDSA private key**: in login keychain (item: `Private key for signing Sparkle updates`). Public counterpart `GjgBpBs3vAJI0W4Kv3Vz7qgD4hp2uFqnS/iOElRmn68=` is baked into `Pod/Info.plist`. **If this Mac is ever wiped, all Sparkle users are stranded** — back up the private key (Keychain Access → export `.p12`).
- **Notarytool profile**: `AC_PASSWORD` stored in keychain. Apple ID `iskrenalexandrov@gmail.com`, team `B7949NL6NG`. App-specific password generated at System Settings → Sign-In and Security → App-Specific Passwords.
- **`create-dmg`**: required for the drag-to-Applications dmg. `brew install create-dmg`.
- **Sandbox**: disabled (1.8.2+). Sandboxing in Pod broke Sparkle's installer XPC chain and blocked the Rust bridge binary; for a Developer ID-distributed indie app it's not worth the complexity. If you ever re-enable it, you'll need mach-lookup entitlements for `<bundleid>-spki/spks/spkp` and to manually sign Sparkle's XPC services.
- **Spotify bridge**: `pod-spotify-bridge` (Rust). `release.sh` runs `cargo build --release` and embeds the binary at `Pod.app/Contents/Resources/pod-spotify-bridge`, code-signed with the same Developer ID. `SpotifyBridge.findBridgeBinary()` finds it via `Bundle.main.path(forResource:ofType:)`.

## Steps to ship a new version

1. **Bump versions** in `Pod.xcodeproj/project.pbxproj` (both Debug and Release config blocks):
   - `MARKETING_VERSION` → e.g. `1.9` (user-visible)
   - `CURRENT_PROJECT_VERSION` → next integer (e.g. `9`). **This is what Sparkle compares**, so it must monotonically increase.

2. **Run the release script**:
   ```
   POD_NOTES="<changelog one-liner>" scripts/release.sh
   ```
   It will: archive → export Developer ID → submit zip to notarytool → staple → `sign_update` → build dmg with drag-to-Applications layout → notarize+staple dmg → copy both into `pod-website/public/releases/` → rewrite `appcast.xml` (zip enclosure, for Sparkle) and `version.json` (dmg URL, for humans) in **both** `pod-website/public/` and `pod-public/`.

   **Two artifacts, two purposes**: zip is what Sparkle in-place updates use (faster); dmg is what the website "Get on Mac" button serves and what the legacy NSAlert opens (visual drag-to-Applications install).

3. **Commit + push all three repos**. The script prints the exact commands at the end:
   ```
   cd ~/Developer/pod-website && git add -A && git commit -m "Release Pod <version>" && git push
   cd ~/Developer/pod-public && git add -A && git commit -m "Release <version> (legacy mirror)" && git push
   cd ~/Developer/pod && git tag v<version> && git push --tags
   ```

4. **Verify live**:
   ```
   curl -sLI https://www.desktopipod.com/releases/Pod-<version>.zip
   curl -sL  https://www.desktopipod.com/version.json
   curl -sL  https://www.desktopipod.com/appcast.xml | tail -15
   ```
   Vercel deploys automatically on push to `main`; takes ~30–60s.

## Important rules

- Always bump `CURRENT_PROJECT_VERSION` (the integer build) — Sparkle compares this. If you only bump `MARKETING_VERSION`, existing 1.8 users won't see the update.
- Never commit anything inside `build/release/` (gitignored). The release zip lives in `pod-website/public/releases/` instead.
- Never commit the Sparkle private key or `.p12` exports to git.
- The release script does NOT auto-commit/push — it only writes files. Always inspect the diff in each repo before pushing.
- The `pod-public` mirror keeps existing NSAlert users informed even though no Sparkle user reads it. Drop it once telemetry shows pre-Sparkle installs are gone (`App.launched` no longer reports a missing `feedURL`).

## What the user will tell you vs. what to ask

If they say "ship a new version" or "release":
- If `CURRENT_PROJECT_VERSION`/`MARKETING_VERSION` haven't been bumped from the last release, ask what version + what changelog line.
- Confirm they're on the right Mac (cert lives only here).
- Then run the script and push.

If `release.sh` fails:
- "No Keychain password item found for profile: AC_PASSWORD" → notarytool profile gone, re-run `xcrun notarytool store-credentials`.
- "errSecInternalComponent" during codesign → keychain locked. `security unlock-keychain ~/Library/Keychains/login.keychain-db`.
- Notarization rejected → fetch the log: `xcrun notarytool log <submission-id> --keychain-profile AC_PASSWORD`.

## Files this skill touches

- `Pod.xcodeproj/project.pbxproj` (versions)
- `scripts/release.sh` (the pipeline — modify here, not inline)
- `pod-website/public/{appcast.xml,version.json,releases/Pod-<v>.zip}`
- `pod-public/{appcast.xml,version.json}`
