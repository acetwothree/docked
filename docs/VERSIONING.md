# Versioning & bumping builds

iOS has **two** numbers. They do different jobs.

| Setting | Info.plist key | Example | Who sees it | Who bumps it |
|---|---|---|---|---|
| **Marketing version** | `CFBundleShortVersionString` | `1.0`, `1.1`, `2.0` | users, on the App Store | **you**, by hand, when you ship a release |
| **Build number** | `CFBundleVersion` | `1`, `2`, `3`, … | TestFlight, to tell builds apart | **CI**, automatically, every push |

Rule Apple enforces: for a given marketing version, **every upload must have a build number
strictly higher than the last one uploaded**.

---

## Build number — automatic, do nothing

`.github/workflows/testflight.yml` passes `CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER"` to
`xcodebuild archive`. The GitHub Actions run number only ever increases, so every push to
`main` produces a strictly-higher build number. You never touch this.

(The `CURRENT_PROJECT_VERSION = 1;` in `project.pbxproj` is just the local/dev default; CI
overrides it at archive time.)

## Marketing version — bump by hand per release

When you want the next TestFlight/App Store build to read `1.1` instead of `1.0`:

**Edit `Docked.xcodeproj/project.pbxproj`** — there are two `MARKETING_VERSION` lines (Debug
and Release configs). Change both:

```
MARKETING_VERSION = 1.1;
```

One-liner from the repo root:

Git Bash
```bash
sed -i 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = 1.1;/' Docked.xcodeproj/project.pbxproj
```
PowerShell
```powershell
(Get-Content Docked.xcodeproj/project.pbxproj) -replace 'MARKETING_VERSION = [0-9.]+;', 'MARKETING_VERSION = 1.1;' | Set-Content Docked.xcodeproj/project.pbxproj
```

Then commit + push:
```bash
git add -A && git commit -m "Bump version to 1.1" && git push
```

The next CI run archives `1.1 (buildNumber)` and uploads it. In App Store Connect it shows
up as a new version group under **TestFlight**.

> On a Mac you'd normally do this with `xcrun agvtool new-marketing-version 1.1`. Editing
> the pbxproj is the no-Mac equivalent and produces the identical result.

## Typical loop

- **Code change / bug fix, same release:** just `git push`. New build number, same `1.0`.
  Testers get it as "Build 7 of 1.0", etc.
- **New feature milestone / public-facing release:** bump `MARKETING_VERSION`, push.
