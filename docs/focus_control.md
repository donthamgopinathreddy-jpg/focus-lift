# Focus Lift Focus Control Research

## Executive Summary

Focus Lift aims to solve one primary problem: **eliminating phone distractions during physical workouts**. To deliver on the brand promise of *"Train Without Distractions"*, the application must provide effective focus modes (Focus, Balanced, Custom) while remaining **100% compliant with Google Play Policies and Apple App Store Review Guidelines**.

This document analyzes all official platform mechanisms on Android and iOS, evaluates store rejection risks, establishes feasibility for focus statistics, and outlines a compliant, robust native architecture for Phase 5.

---

## Product Requirement

Focus Lift defines three workout focus tiers:
1. **FOCUS MODE:** Maximum restriction on distracting apps (social media, short-form video, games, algorithmic feeds). Normal phone calls, emergency services, and audio/music streaming applications remain fully permitted.
2. **BALANCED MODE:** Restricts primary algorithmic distractions while allowing essential communication tools (calls, messaging) and music.
3. **CUSTOM MODE:** The user explicitly selects which specific applications to restrict or allow.

**Core Safety Requirement:** Focus Lift must **never trap the user**, never interfere with emergency 911/112 services, never block phone calls, fail open on crash/reboot, and maintain 100% on-device privacy with zero external backend servers.

---

## Android Platform Analysis

### UsageStatsManager (`PACKAGE_USAGE_STATS`)

- **Capabilities:**
  - Queries system usage logs to inspect timestamped foreground transitions (`UsageEvents.Event.ACTIVITY_RESUMED` / `MOVE_TO_FOREGROUND`).
  - Provides empirical data on when and how long third-party applications were in the foreground.
- **Permissions & User Flow:**
  - Requires `android.permission.PACKAGE_USAGE_STATS`.
  - Cannot be granted via a simple in-app runtime dialog; the user must be deep-linked to the system settings screen (`Settings.ACTION_USAGE_ACCESS_SETTINGS`).
- **Technical Limitations:**
  - **Read-Only Detection:** `UsageStatsManager` provides observation only. It **cannot** intercept, block, or prevent an app from launching.
  - Event polling in the background is subject to Android battery optimizations (Doze mode, OEM process killing).
- **Google Play Policy Considerations:**
  - Permitted for digital wellbeing and fitness utilities, provided a clear in-app prominent disclosure is presented before redirecting to system settings.
  - `QUERY_ALL_PACKAGES` is heavily restricted on Google Play; apps should use targeted `<queries>` or user-directed package selection rather than requesting broad inventory access without justification.
- **Verdict:** **Recommended for Detection & Focus Metrics** (read-only monitoring; cannot perform hard blocking).

---

### AccessibilityService (`BIND_ACCESSIBILITY_SERVICE`)

- **Capabilities:**
  - Receives real-time `AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED` events whenever any application is opened.
  - Can programmatically invoke `GLOBAL_ACTION_HOME` or launch an intent immediately upon detecting a restricted package, forcefully redirecting the user back to Focus Lift.
- **Google Play Policy (CRITICAL RISK):**
  - Google Play's **Accessibility API Policy** explicitly restricts the use of `AccessibilityService` to applications designed to assist users with disabilities or explicitly approved enterprise tools.
  - Google's developer policy states: *"The Accessibility API is not designed and cannot be requested for call recording or broad app-blocking without meeting strict disability assistance criteria."*
  - Consumer fitness or productivity apps using AccessibilityService to block apps face an estimated **>90% rejection rate** or subsequent permanent removal from the Google Play Store.
- **Verdict:** **NOT RECOMMENDED / HIGH REJECTION RISK.** Must be avoided for production store releases.

---

### SYSTEM_ALERT_WINDOW / Overlays

- **Capabilities:**
  - Displays a floating window or "Workout in Progress" shield on top of other running applications using `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`.
- **Permissions & Technical Limitations:**
  - Requires `android.permission.SYSTEM_ALERT_WINDOW` granted via `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`.
  - Android 10+ background activity launch restrictions prevent background services from launching overlays without user interaction or a high-priority notification trampoline.
  - Android 12+ enforces untrusted touch blocking to prevent tapjacking.
- **Google Play Policy Considerations:**
  - Overlays that trap the user, obscure system navigation, or simulate malicious lockouts violate the **Deceptive Behavior** and **Device Abuse** policies.
  - Non-deceptive, dismissible workout reminder banners with clear `[RETURN TO WORKOUT]` and `[DISMISS]` buttons are permitted if accompanied by prominent disclosure.
- **Verdict:** **Possible With Limitations (Gentle Non-Blocking Reminder Shield).**

---

### DevicePolicyManager / Lock Task Mode / Kiosk

- **Capabilities:**
  - `startLockTask()` locks the device screen strictly to the active application.
- **Technical Limitations:**
  - Without Device Owner / Profile Owner provisioning (MDM/Enterprise enrollment via QR code or adb during factory setup), `startLockTask()` displays a system pinning prompt that any user can exit by holding Back + Overview.
  - Genuine unescapable Lock Task mode requires Device Owner provisioning, which is completely unavailable for ordinary consumer apps distributed through Google Play.
- **Verdict:** **NOT VIABLE for consumer Google Play distribution.**

---

### Android Digital Wellbeing & Focus Mode APIs

- **Capabilities & Limitations:**
  - Android's native Digital Wellbeing / Focus Mode features are system-level privileges (`android.permission.CONTROL_KEYGUARD`, system-signed apps).
  - Google provides **no public third-party SDK or Intent API** allowing standard Play Store applications to pause, hide, or restrict arbitrary installed apps through Digital Wellbeing.
- **Verdict:** **NOT VIABLE (No public API exists).**

---

### Other Approaches (VPN, Custom Launcher, Local DNS)

- **Local VPN (`VpnService`):** Can intercept and sinkhole network traffic (blocking social feeds), but cannot prevent offline games, downloaded media, or local app usage. Violates Google Play's strict `VpnService` policy unless the app's primary purpose is a VPN or Antivirus tool.
- **Custom Launcher:** Requires the user to replace their entire home screen launcher. Excessively invasive and impractical for a workout utility.
- **Verdict:** **NOT VIABLE.**

---

### Recommended Android Architecture

Because Android does not offer a public third-party app-shielding API without violating Google Play policies, Focus Lift will employ a **Compliant Accountability & Shield Model**:
1. **Usage Access Monitoring (`UsageStatsManager`):** Tracks when distracting apps are opened during an active workout session.
2. **Persistent High-Priority Focus Notification:** While a workout is active, Focus Lift maintains an actionable notification (`"Workout Active • Set 3 • Tap to Return"`).
3. **Optional Non-Intrusive Workout Shield (`SYSTEM_ALERT_WINDOW`):** If the user grants overlay permission, Focus Lift displays a clean, branded reminder overlay when a restricted app is brought to the foreground, providing a one-tap `[RETURN TO WORKOUT]` button and an immediate `[DISMISS]` escape hatch.
4. **Emergency & Audio Hard-Allowlist:** `com.android.server.telecom`, default dialers, SMS, Spotify, YouTube Music, and Apple Music are permanently exempted from alerts.

---

## iOS Platform Analysis

### Apple Screen Time API Suite

Starting with iOS 15/16, Apple introduced the modern, privacy-first **Screen Time API Suite** comprising:
1. `FamilyControls`
2. `ManagedSettings`
3. `DeviceActivity`
4. `ManagedSettingsUI`

---

### FamilyControls & Authorization

- **Capabilities:**
  - Grants the app access to Screen Time controls.
  - Supports `AuthorizationCenter.shared.requestAuthorization(for: .individual)` for self-control and personal focus utilities (iOS 16+).
- **User Experience:**
  - When invoked, iOS displays an official Apple system prompt: *"Focus Lift would like to access Screen Time to manage app restrictions during workouts."*
  - Requires Face ID / Touch ID / Device Passcode to authorize.

---

### FamilyActivityPicker

- **Capabilities:**
  - Apple's official system picker sheet allows users to select individual apps, entire categories (e.g., Social, Games, Entertainment), and web domains.
- **Privacy Architecture:**
  - Focus Lift **never receives bundle identifiers, app names, or package strings**.
  - Selections are returned as opaque, encrypted `ApplicationToken` and `ActivityCategoryToken` objects stored securely in local `AppGroup` or `UserDefaults`.

---

### ManagedSettings (`ManagedSettingsStore`)

- **Capabilities:**
  - `ManagedSettingsStore()` allows instant, programmatic shielding of selected applications and categories during an active workout:
    ```swift
    let store = ManagedSettingsStore(named: .workoutFocus)
    store.shield.applications = selectedAppTokens
    store.shield.applicationCategories = .specific(selectedCategoryTokens)
    ```
  - When shielded, opening a restricted app immediately displays Apple's native **Screen Time Shield UI**.
  - Calling `store.clearAllSettings()` or setting `store.shield.applications = nil` instantly restores full access when the workout ends.
- **Emergency & Communication Safety:**
  - Phone calls (Phone.app), Messages (if unshielded), and system emergency features (SOS) are protected at the kernel level and cannot be locked out.
  - Music streaming apps (Spotify, Apple Music) are left unselected in `FamilyActivityPicker`, ensuring continuous background audio playback during workouts.

---

### DeviceActivity

- **Role:**
  - `DeviceActivity` is designed for scheduled recurring time windows and total duration monitoring.
  - For Focus Lift's on-demand workout sessions (Start Workout ➔ End Workout), direct control via `ManagedSettingsStore` is faster, simpler, and does not require complex background schedule extensions.

---

### Entitlements & App Store Distribution

- **Entitlement Key:** `com.apple.developer.family-controls`
- **Development vs. Distribution:**
  - **Local Development / Simulator / Ad-Hoc:** Works out-of-the-box with a standard paid Apple Developer account.
  - **App Store / TestFlight Distribution:** Requires submitting an **Apple Family Controls Distribution Request** form via the Apple Developer portal.
- **App Store Review Guidelines:**
  - Under Section 5.4 (Screen Time APIs), Apple explicitly permits individual self-focus and productivity applications that use `.individual` authorization and provide clear user disclosures.

---

### Recommended iOS Architecture

1. **Native Swift Plugin (`FocusControlPlugin.swift`):**
   - Communicates with Flutter via `MethodChannel('com.cotrainr.focuslift/focus_control')`.
2. **`FamilyControls.AuthorizationCenter`:** Manages `.individual` permission requests.
3. **`FamilyActivityPicker`:** Modal presentation for selecting distracting app tokens.
4. **`ManagedSettingsStore`:** Instantly applies shields on `startWorkout()` and completely clears shields on `finishWorkout()`.

---

## Platform Comparison

| Capability | Android | iOS |
| :--- | :--- | :--- |
| **Official OS Shield/Block Support** | ❌ No public third-party blocking API | ✅ Yes (`ManagedSettingsStore`) |
| **Official App Picker** | ⚠️ Custom app list / Intent picker | ✅ Yes (`FamilyActivityPicker`) |
| **Shield Selected Apps at OS Level** | ❌ Not supported without policy violation | ✅ Supported natively |
| **Permit Background Music (Spotify/Apple Music)** | ✅ Yes (Hard allowlist) | ✅ Yes (Unshielded token) |
| **Allow Normal & Emergency Calls** | ✅ Yes (Never blocked) | ✅ Yes (Protected at OS level) |
| **Custom In-Workout Return Shield** | ⚠️ Non-intrusive Overlay (`SYSTEM_ALERT_WINDOW`) | ✅ Native Screen Time Shield UI |
| **Detect Distraction Attempts Legitimate Count** | ⚠️ Only with `PACKAGE_USAGE_STATS` | ❌ Opaque tokens (Privacy restriction) |
| **Special Store Entitlement Request Required** | ❌ No (Standard Android permissions) | ✅ Yes (`Family Controls Distribution`) |
| **Store Rejection Risk if Hard-Blocking Forced** | 🚨 **EXTREME** (if AccessibilityService is used) | 🟢 **LOW** (Standard Screen Time compliance) |
| **100% Offline / No Backend Required** | ✅ Yes | ✅ Yes |

---

## Focus Score Feasibility

- **Android:** With `PACKAGE_USAGE_STATS`, Focus Lift can calculate foreground switch counts. However, without this optional permission, data cannot be gathered.
- **iOS:** Apple deliberately obscures real-time shield touch events for privacy. The parent application is **not** notified when a user attempts to open a shielded app.
- **Conclusion:** **Focus Score and Distraction Attempts MUST REMAIN HIDDEN on the Summary Screen** in V1. Fabricating or estimating these metrics violates Focus Lift’s integrity principles.

---

## Recommended Product Behavior

| Focus Mode | Android Implementation | iOS Implementation |
| :--- | :--- | :--- |
| **FOCUS** | High-priority active workout notification + optional overlay reminder for non-whitelisted apps. Calls, emergency, and music permitted. | Strict `ManagedSettingsStore` shield on user's distracting apps & social categories. Music and calls unshielded. |
| **BALANCED** | Reminder notifications for heavy social/video apps; communication apps excluded. | `ManagedSettingsStore` shields algorithmic feeds; messaging and music unshielded. |
| **CUSTOM** | User configures specific apps to monitor. | User opens `FamilyActivityPicker` to choose specific tokens. |

---

## V1/V2 Launch & Platform Strategy

1. **Dual-Platform Architecture:**
   - Both Android and iOS will share a unified `FocusControlService` Flutter interface.
   - iOS implements full native **Screen Time / ManagedSettings** shielding.
   - Android implements a **Compliant Focus Assistant** (Notification + Optional Non-Intrusive Overlay + UsageStats monitoring), avoiding any dangerous AccessibilityService exploits that would risk account termination.
2. **Honest Platform Transparency:**
   - Settings will clearly explain platform differences to the user: iOS uses Apple Screen Time shields; Android uses Focus Nudges & Overlays.

---

## Implementation Plan for Phase 5

1. **Native MethodChannel Interface (`FocusControlService` in Dart):**
   - `requestAuthorization()`
   - `getAuthorizationStatus()`
   - `selectApps()`
   - `startFocusSession()`
   - `stopFocusSession()`
   - `restoreNormalAccess()`
2. **iOS Native Implementation:**
   - Implement `FocusControlPlugin.swift` using `FamilyControls`, `FamilyActivityPicker`, and `ManagedSettingsStore`.
   - Setup App Groups and Xcode configuration for Family Controls entitlement.
3. **Android Native Implementation:**
   - Implement `FocusControlPlugin.kt` handling `UsageStatsManager` deep linking and safe, non-intrusive workout reminder notifications/overlays.
4. **Safety & Fail-Safe Cleanup:**
   - Ensure app termination, reboot, or workout completion unconditionally clears any active shields or overlays.
