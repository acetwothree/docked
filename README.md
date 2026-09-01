# Docked

A single-screen iOS app (SwiftUI, iOS 26) that acts as a **second-screen dashboard for
Picture-in-Picture video**. iOS owns the floating video window; Docked reshapes its own
UI around wherever you park it, so no button or canvas ever ends up hidden underneath.

## Run it

1. Open `Docked.xcodeproj` in Xcode 26 (or newer).
2. Select an iPhone simulator (or your device) and press **⌘R**.
3. On first launch the **Video Layout** sheet appears — pick where your PiP window will sit.

> The project uses an Xcode *synchronized folder group*: every file inside `Docked/`
> is part of the target automatically, so just drop new `.swift` files in and build.
> Signing is set to **Automatic**; pick your team under *Signing & Capabilities* if you
> run on a physical device. There's no app-icon art yet (harmless build warning) — add
> one in `Assets.xcassets/AppIcon.appiconset` if you like.

## How it works

### Layout engine — `Model/VideoLayout.swift`

`VideoLayout` enumerates the six exact resting states iOS gives a floating video:

| Small (corner)        | Large (full width) |
|-----------------------|--------------------|
| Top-Left, Top-Right   | Top · Wide         |
| Bottom-Left, Bottom-Right | Bottom · Wide  |

`LayoutSolver` takes the current safe-area size and returns two rectangles:

- **`videoRect`** — where the dashed "television frame" guide is drawn.
- **`contentRect`** — a **full-width band on the opposite side** of the video where the
  dashboard is allowed to live. Corner layouts still reserve the whole band, so nothing
  interactive can ever sit under the window.

`RootView` positions the dashboard into `contentRect` and animates every change with a
single spring (`Theme.layoutAnimation`), so switching layouts glides the whole UI to the
free half of the screen.

### Activity modules — `View/`

- **Doodle** (`DoodlePadView`) — `Canvas` + zero-distance `DragGesture`, quadratic-smoothed
  strokes, colour palette, brush-size slider, undo / clear. Strokes are stored *normalised*
  (0–1) so the drawing keeps its shape across layout changes, and persist to
  `Documents/doodle.json`.
- **Notes** (`NotesView`) — `TextEditor` bound straight to `NotesStore`, autosaved to
  `UserDefaults`, with a word / character count.
- **Runner** (`RunnerGameView` + `RunnerModel`) — a minimalist endless runner in the spirit
  of the offline dinosaur game. Tap to start / jump / retry. A 60 Hz `Timer` drives the
  physics; high score persists.

### Persistence

| Data | Where |
|------|-------|
| Selected layout, guide toggle, active module, runner high score | `UserDefaults` (`AppModel`) |
| Notes text | `UserDefaults` (`NotesStore`) |
| Doodle strokes | `Documents/doodle.json` (`DoodleStore`, debounced + flushed on background) |

## Shipping to TestFlight (no Mac)

Every push to `main` triggers [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml),
which builds, signs and uploads a new build to TestFlight on a GitHub-hosted macOS runner.

- **One-time setup:** [docs/TESTFLIGHT_SETUP.md](docs/TESTFLIGHT_SETUP.md) — App ID,
  provisioning profile, App Store Connect record, 8 GitHub Secrets (most reusable from StepMates).
- **Version bumping:** [docs/VERSIONING.md](docs/VERSIONING.md) — build number is automatic
  (CI run number); bump `MARKETING_VERSION` by hand for a new release.

## Project layout

```
Docked/
├─ DockedApp.swift          # @main, injects the stores
├─ Theme.swift              # accent, paper/ink tones, layout spring, Color(hex:)
├─ Model/
│  ├─ VideoLayout.swift     # 6 layouts + LayoutSolver geometry
│  ├─ AppModel.swift        # app-wide prefs (persisted)
│  ├─ NotesStore.swift
│  ├─ DoodleStore.swift
│  └─ RunnerModel.swift     # pure game simulation
└─ View/
   ├─ RootView.swift        # the single screen
   ├─ DropZoneView.swift    # dashed TV-frame guide
   ├─ ActivityDeckView.swift# pill switcher + module host
   ├─ DoodlePadView.swift
   ├─ NotesView.swift
   ├─ RunnerGameView.swift
   └─ LayoutSettingsView.swift  # phone-diagram layout picker
```

## Tuning knobs

- Guide sizes / margins: `LayoutSolver` in `Model/VideoLayout.swift`.
- Game feel (gravity, jump, speed ramp, spawn cadence): the `// Tuning` block at the top of
  `Model/RunnerModel.swift`.
- Palette / animation: `Theme.swift`.
