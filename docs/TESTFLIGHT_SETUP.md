# TestFlight CI/CD Setup (no Mac required)

Gets `.github/workflows/testflight.yml` deploying **Docked** to TestFlight on every push
to `main`. Same pipeline you used for StepMates, minus HealthKit/CloudKit/Push (Docked has
no special capabilities) and minus XcodeGen (the `.xcodeproj` is committed).

The **certificate, API key, Team ID and keychain password** are *values* you can reuse from
StepMates — a distribution cert and an API key are account-wide, not per-app. But **GitHub
secrets live on each repository**, so you still have to add all 8 secrets to
`acetwothree/docked` (Settings → Secrets and variables → Actions); GitHub never shows you
an existing secret's value, so keep the originals (`distribution.p12` + its password, the
`.p8` file, the two IDs) somewhere you can re-paste from. Only the App ID, the provisioning
profile, and the App Store Connect app record are genuinely new for Docked.

---

## 1. App ID — developer.apple.com

**Certificates, Identifiers & Profiles → Identifiers → +**

- Type: **App**
- Bundle ID: **Explicit** → `com.acetwothree.docked`
  (must match `PRODUCT_BUNDLE_IDENTIFIER` in `Docked.xcodeproj/project.pbxproj` — if you
  want a different reverse-domain, change it in both places and in `ExportOptions.plist`)
- **Capabilities: none.** Leave everything unchecked. Save.

## 2. Distribution certificate (.p12)

**Reuse StepMates' `distribution.p12`** and its password. Skip to step 3.

<details><summary>Only if you don't have one</summary>

1. **Certificates → + → Apple Distribution**.
2. Generate a CSR + key with OpenSSL (ships with Git Bash):
   ```bash
   openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out distribution.csr -subj "/CN=Docked Distribution"
   ```
3. Upload the `.csr`, download `distribution.cer`, then:
   ```bash
   openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
   openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12 -passout pass:YOUR_P12_PASSWORD
   ```
</details>

## 3. Provisioning profile (.mobileprovision) — **new, app-specific**

**Profiles → + → App Store** (under Distribution) → Continue
→ select App ID `com.acetwothree.docked` → Continue
→ select your distribution certificate → Continue
→ name it `Docked AppStore` → Generate → **Download** the `.mobileprovision`.

## 4. App Store Connect record — **new**

**App Store Connect → Apps → +**

- Platform: iOS
- Bundle ID: select `com.acetwothree.docked`
- Name: `Docked`  ·  SKU: `docked-ios`  ·  primary language: English

This must exist before the first upload — `xcodebuild -exportArchive` uploads *to* an
existing app record, it doesn't create one.

## 5. App Store Connect API key (.p8)

**Reuse StepMates' key** (`AuthKey_XXXXXXXXXX.p8`, plus its Key ID and Issuer ID). Skip to
step 6.

<details><summary>Only if you don't have one</summary>

**Users and Access → Integrations → App Store Connect API → +**, role **App Manager**,
download the `.p8` immediately (one download only), note the **Key ID** and **Issuer ID**.
</details>

---

## 6. GitHub Secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**. Add **all
eight to this repo** (they don't carry over from another repo). Six of the values are the
same ones you used for StepMates:

| Secret | Value | Notes |
|---|---|---|
| `DISTRIBUTION_CERTIFICATE_P12_BASE64` | base64 of `distribution.p12` | reuse |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | the `.p12` password | reuse |
| `PROVISIONING_PROFILE_BASE64` | base64 of the **new** `Docked AppStore.mobileprovision` | **new — step 3** |
| `APPLE_TEAM_ID` | your 10-char Team ID | reuse |
| `KEYCHAIN_PASSWORD` | any string | reuse or invent |
| `APP_STORE_CONNECT_API_KEY_P8` | full contents of the `.p8`, pasted as-is (not base64) | reuse |
| `APPLE_KEY_ID` | API Key ID | reuse |
| `APPLE_ISSUER_ID` | API Issuer ID | reuse |

Base64-encode the profile (Git Bash):
```bash
base64 -w 0 "Docked AppStore.mobileprovision" > profile.base64
```
PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Docked AppStore.mobileprovision")) | Set-Content -NoNewline profile.base64
```
Paste its **single unbroken line** as the secret value.

---

## 7. First deploy

Push to `main` (or **Actions → TestFlight Deploy → Run workflow**). Watch the run; every
step is logged in full. First build takes ~8–12 min. When it finishes, the build appears in
**App Store Connect → Docked → TestFlight** after Apple finishes processing (a few more
minutes), then installs to your iPhone via the **TestFlight** app once you've added yourself
as an internal tester.

### If upload fails but archive succeeds

The `.xcarchive` is saved as a workflow artifact (`if: always()`). Download it and open it
in **Xcode → Organizer** on any Mac to retry export/upload from the GUI.

### Common failures

- **"No profiles for 'com.acetwothree.docked' were found"** — bundle ID mismatch between the
  profile and `project.pbxproj` / `ExportOptions.plist`.
- **"bundle version must be higher than the previously uploaded version"** — shouldn't
  happen; CI sets `CURRENT_PROJECT_VERSION` to the run number every build. See VERSIONING.md.
- **App record missing** — do step 4 before pushing.
