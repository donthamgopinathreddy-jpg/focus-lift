# Focus Lift

**Train Without Distractions**  
*Brand: Cotrainr*

Focus Lift is a simple, 100% offline, privacy-first mobile workout application designed to eliminate smartphone distractions during physical workouts.

---

## Core Features

- **Workout & Rest Timer Engine:** Drift-free timestamp mathematics derived from true device clocks (`workoutStartedAt`, `restEndsAt`).
- **Seamless Workout States:** Rapid transitions between Active Workout, Rest Countdown, and Rest Complete.
- **Workout Alerts:**
  - Single brief audio chime on rest expiration (toggleable).
  - Haptic pulse feedback on rest expiration (toggleable).
  - Scheduled background local notifications when rest completes.
- **Keep Screen Awake:** Optional wakelock preventing display sleep exclusively during active workouts.
- **Unfinished Workout Recovery:** Automatic crash and background recovery with zero timer drift.

---

## Focus Control System

Focus Lift provides three distinct focus tiers:
- **FOCUS MODE:** Maximum restriction on distracting apps during active sets and rest.
- **BALANCED MODE:** Restricts algorithmic entertainment while permitting essential communication tools and music.
- **CUSTOM MODE:** User-defined distraction selections.

### Platform-Specific Focus Implementation

Android and iOS operate on fundamentally different security architectures and provide distinct platform behaviors:

#### 1. iOS Focus Control (Native Screen Time Shielding)
- Uses Apple's official **Screen Time Frameworks** (`FamilyControls`, `FamilyActivityPicker`, and `ManagedSettings`).
- Employs `.individual` authorization for personal focus on the user's own device (iOS 16+).
- Shielding is applied via `ManagedSettingsStore` during active workouts and unconditionally removed upon workout finish, cancel, discard, or app restart.
- *Note for App Store / TestFlight distribution:* Requires submitting an official Apple Family Controls Distribution Entitlement request via the Apple Developer Portal.

#### 2. Android Focus Control (Compliant Usage Nudge & Reminders)
- Uses optional **Usage Access** (`UsageStatsManager`) and launcher-resolvable application queries (`Intent.ACTION_MAIN` / `Intent.CATEGORY_LAUNCHER`).
- When a selected distracting app is opened during an active workout, Focus Lift provides an actionable return notification and in-app workout accountability.
- Avoids high-risk practices: **No** `AccessibilityService` hijacking, **No** `DeviceAdmin`, **No** lock task mode, **No** intrusive overlays, and **No** `QUERY_ALL_PACKAGES`.

---

## Privacy & Safety Principles

- **100% Offline:** Zero remote servers, zero database logins, zero telemetry, and zero analytics SDKs.
- **Fail-Safe Design:** Focus restrictions fail open. Normal device access is unconditionally restored on workout completion, cancellation, app discard, or device reboot.
- **Emergency Protection:** Phone calls, emergency services (911/112), and background audio playback (Spotify, Apple Music) are never intentionally interfered with.

---

## Technical Stack & Architecture

- **Framework:** Flutter (Material 3 Dark Theme).
- **State Management:** Clean Service Pattern with Immutable Session Models.
- **Storage:** `SharedPreferences` for on-device preference and active session caching.
- **Platform Bridges:** Dedicated `MethodChannel` (`com.cotrainr.focuslift/focus_control`).
