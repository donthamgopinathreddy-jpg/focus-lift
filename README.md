# Focus Lift

**Train Without Distractions**  
*Brand: Cotrainr*

Focus Lift is a clean, minimal, 100% offline, privacy-first mobile workout application designed to eliminate smartphone distractions during physical workouts.

---

## Core Philosophy: Allowlist-Style Workout Mode

Unlike complicated productivity apps where users configure hundreds of distracting apps to block, **Focus Lift inverts the mental model**:

1. **User chooses only what is allowed during a workout** (Music, Calls, Messages, Camera).
2. **Focus Lift becomes the main workout screen** during training.
3. **Distracting phone use is restricted as much as the OS legitimately allows**.
4. **Essential/allowed functions remain easy to access via Quick Access buttons** (`[ MUSIC ]`, `[ CALL ]`).
5. **Finishing or discarding a workout unconditionally restores normal phone access**.

---

## Key Screens & User Flow

- **Home Screen:**
  - Branding: Focus Lift • Train Without Distractions
  - Rest Timer selector: `[ 30s ] [ 60s ] [ 90s ] [ 120s ]` + `[ Custom ]`
  - Allowed During Workout summary: Music (Enabled/Disabled), Phone & Calls (Always available), `[ Manage Allowed Apps ]`
  - Dominant CTA: `[ START FOCUS WORKOUT ]`
  - Settings icon in top-right
- **Active Workout Screen:**
  - Main workout interaction surface with live elapsed timer and set counter (`SET 1`, `SET 2`, etc.)
  - Dominant `[ END SET ]` action
  - Quick Access row: `[ MUSIC ]` (launches allowed music app or player) and `[ CALL ]` (opens system dialer)
  - Secondary `Finish Workout`
- **Rest Screen (Integrated in WorkoutScreen):**
  - High-visibility rest countdown timer (`00:59`, `00:58`...)
  - `[ SKIP REST ]` during active rest countdown
  - `[ START NEXT SET ]` when countdown reaches zero
  - Audio chime and haptic feedback alerts on rest completion
- **Allowed Apps Screen:**
  - Essential: Phone & Calls (Always available)
  - Music: User-selected music apps (Spotify, YouTube Music, Apple Music, etc.)
  - Optional: Messages, Camera
- **Settings Screen:**
  - Default Rest Timer
  - Sound Alert (ON/OFF)
  - Vibration (ON/OFF)
  - Keep Screen Awake (ON/OFF)
  - Allowed Apps (Manage >)
  - Privacy Statement: *"Focus Lift stores workout settings and preferences on this device. No account is required."*
- **Workout Summary:**
  - Minimal summary displaying Total Workout Time, Sets Completed, and `[ DONE ]`.
  - Zero fabricated focus scores, zero gamification clutter.

---

## Platform-Specific Architecture

### 1. iOS (Native Screen Time Shielding)
- Employs Apple's `FamilyControls` and `ManagedSettings` frameworks with `.individual` authorization.
- Unshielded access is maintained for permitted audio and system phone calls.
- On workout finish, discard, or app boot with no active session, `ManagedSettingsStore.clearAllSettings()` unconditionally clears all shields (Fail Open).

### 2. Android (Active Workout Hub & Quick Access)
- Android does not permit standard consumer apps to lock down personal devices without dangerous policy violations.
- Focus Lift maintains an active workout interface with screen wakelock (`Keep Screen Awake = ON`).
- Quick Access buttons (`[ MUSIC ]` and `[ CALL ]`) provide one-tap access to music players and standard dialers.
- Maintains ongoing active workout status notification (`"Workout Active • Set X • Tap to return to Focus Lift"`).
- **Zero** `AccessibilityService` hijacking, **Zero** `DeviceAdmin`, **Zero** lock-task traps, **Zero** `SYSTEM_ALERT_WINDOW` overlays, and **Zero** `QUERY_ALL_PACKAGES`.

---

## Privacy & Offline Safety

- **100% On-Device:** Zero backend, zero cloud databases, zero login accounts, zero ads, and zero telemetry.
- **Fail-Safe Design:** Restrictions unconditionally clear on finish, cancel, discard, and app reboot.
- **Emergency Safety:** Phone calls and emergency services (911/112) are never interfered with.
