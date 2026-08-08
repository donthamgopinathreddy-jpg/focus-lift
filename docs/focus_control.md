# Focus Lift Focus Control Research

## Executive Summary

Focus Lift addresses a widespread problem during physical training: **loss of focus caused by smartphone distractions**. The product promise is *"Train Without Distractions"*.

To ensure Focus Lift can be published and maintained on **Google Play** and the **Apple App Store**, this document analyzes the current official technical capabilities, platform policies, entitlement requirements, and user experience constraints of both Android and iOS.

**Critical Platform Finding:**
Android and iOS operate on fundamentally different security and privacy architectures. Consequently, **Android and iOS will NOT provide identical app-blocking behavior**:
- **iOS:** Supports official, native OS-level application shielding via Apple's **Screen Time APIs** (`FamilyControls`, `ManagedSettings`), subject to Apple's distribution entitlement review.
- **Android:** Does not provide a dedicated consumer app-shielding API. Android will implement a **Compliant Distraction Detection and Reminder Model** (via optional Usage Access and actionable notifications/reminders), avoiding high-risk policy practices.

---

## Product Requirement & Focus Modes

Focus Lift defines three focus modes:
1. **FOCUS MODE:** Restricts major algorithmic distractions (social media, short-form video, games) during active sets and rest periods. Phone calls, emergency functionality, and permitted music playback remain accessible.
2. **BALANCED MODE:** Restricts high-friction entertainment apps while allowing essential communication tools (calls, messaging) and music.
3. **CUSTOM MODE:** The user configures specific applications or categories according to their training preferences.

### Core Safety Rules
- **No Trapping:** The app must fail open if terminated, crashed, or rebooted.
- **Emergency Protection:** Focus Lift will not intentionally shield or interfere with system emergency functionality (e.g., 911/112), and the respective operating systems govern emergency override behaviors.
- **Privacy First:** 100% on-device operation with zero remote databases, zero analytics tracking, and no external servers.

---

## Android Platform Analysis

### UsageStatsManager (`PACKAGE_USAGE_STATS`)

- **Capabilities:**
  - Queries system usage logs to inspect timestamped foreground transitions (`UsageEvents.Event.ACTIVITY_RESUMED` or `MOVE_TO_FOREGROUND`).
  - Allows detecting when a user has navigated away from Focus Lift to another application during an active workout session.
- **Permissions & User Flow:**
  - Requires `android.permission.PACKAGE_USAGE_STATS`.
  - Cannot be granted through a standard runtime dialog. Focus Lift must direct the user to the system settings screen (`Settings.ACTION_USAGE_ACCESS_SETTINGS`) with clear explanatory context.
- **Technical Limitations:**
  - **Read-Only Detection:** `UsageStatsManager` provides observation only; it cannot intercept, close, or prevent an application from opening.
  - Background event querying is subject to OEM battery management and Android Doze modes.
- **Google Play Policy Considerations:**
  - Google Play permits Usage Access when directly relevant to user-facing digital wellbeing, focus, or productivity features.
  - Prominent in-app disclosure and explicit user consent are mandatory prior to launching the system settings intent.
- **Verdict:** **Recommended for Distraction Detection & Workout Return Nudges (Read-Only).**

---

### AccessibilityService (`BIND_ACCESSIBILITY_SERVICE`)

- **Technical Capabilities:**
  - Receives real-time window state change events (`AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED`) containing the package name of the active foreground window.
  - Can programmatically trigger `performGlobalAction(GLOBAL_ACTION_HOME)` or launch an intent to redirect the user back to Focus Lift when a restricted app is opened.
- **Google Play Policy Considerations:**
  - Google Play's **Accessibility API Policy** regulates the use of accessibility services. While Google does permit AccessibilityService for non-disability use cases under specific conditions, the app must:
    1. Complete a dedicated Play Console declaration justifying why no alternative Android API can fulfill the core feature.
    2. Provide a prominent in-app disclosure explaining exactly what data is collected and how the service is used.
    3. Obtain explicit user consent prior to requesting the permission.
    4. Adhere strictly to Google Play User Data policies (no keystroke logging, no unauthorized data transmission).
  - Google Play heavily scrutinizes apps using accessibility services for app-locking or restriction, and policy updates frequently narrow permitted usage.
- **Verdict:** **NOT RECOMMENDED for Focus Lift V1.** Narrower, safer APIs (UsageStats and actionable notifications) are preferred to ensure long-term stability and minimize store review friction.

---

### Overlays (`SYSTEM_ALERT_WINDOW`)

- **Capabilities:**
  - Displays a floating window or "Workout in Progress" reminder banner over other running applications using `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`.
- **Permissions & Technical Constraints:**
  - Requires `android.permission.SYSTEM_ALERT_WINDOW`, requiring user authorization via `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`.
  - Android 10+ restricts starting activities directly from background services.
  - Android 12+ restricts touch pass-through (`FLAG_NOT_TOUCHABLE`) to safeguard against tapjacking.
  - OEM variations (e.g., MIUI, One UI, ColorOS) often impose custom background overlay restrictions that can prevent reliable presentation unless explicitly enabled in device-specific settings.
- **Google Play Policy Considerations:**
  - Google Play's **Deceptive Behavior** and **Device and Network Abuse** policies prohibit intrusive overlays that trap users, obscure navigation buttons, or prevent closing the overlay.
  - An overlay is only acceptable if it is clearly branded, non-deceptive, dismissible, and provides immediate navigation back to the app or exit options (`[RETURN TO WORKOUT]`, `[DISMISS]`).
- **Verdict:** **Possible as an Optional Secondary Feature with Caution.** For V1, Focus Lift will prioritize in-app reminders and high-priority notifications, treating full-screen overlays as optional and strictly non-blocking.

---

### DevicePolicyManager & Kiosk Mode

- **Capabilities & Limitations:**
  - Lock Task Mode (`startLockTask()`) without Device Owner privileges allows standard screen pinning, which any user can easily exit by holding Back + Overview.
  - Full, inescapable kiosk mode requires the app to be provisioned as a **Device Owner** or **Profile Owner** via MDM (Mobile Device Management) or factory provisioning.
- **Policy & Practicality:**
  - Device Owner provisioning is designed for enterprise-managed corporate fleets, not standard consumer apps distributed via Google Play.
- **Verdict:** **NOT VIABLE for consumer Google Play distribution.**

---

### Digital Wellbeing & Public APIs

- **Capabilities & Limitations:**
  - Android's native Digital Wellbeing and Focus Mode features operate under system-level permissions (`CONTROL_KEYGUARD`, system-signed firmware).
  - Google provides no public third-party SDK or intent interface permitting consumer applications to pause, hide, or restrict arbitrary packages through the OS Focus Mode.
- **Verdict:** **NOT VIABLE (No public third-party API exists).**

---

### Other Approaches (VPN, Custom Launcher)

- **Local VPN (`VpnService`):** Intercepts network packets to block social feed data, but does not stop offline apps or cached media, increases battery drain, and triggers strict Google Play VpnService policies.
- **Custom Launcher:** Overly intrusive and completely unsuitable for a simple workout utility.
- **Verdict:** **NOT VIABLE.**

---

### Android Package Visibility (`QUERY_ALL_PACKAGES` vs Narrower Alternatives)

- **Google Play Policy on `QUERY_ALL_PACKAGES`:**
  - Google Play restricts `QUERY_ALL_PACKAGES` to apps with broad inventory search requirements (e.g., file managers, device search, antivirus). Apps failing to justify broad inventory access face rejection.
- **Narrower Compliant Alternatives for Focus Lift:**
  1. **Launcher Activity Query:** Query only applications that declare `Intent.ACTION_MAIN` and `Intent.CATEGORY_LAUNCHER`.
  2. **Targeted `<queries>` Elements:** Declare specific package intents in `AndroidManifest.xml` for well-known distraction categories.
  3. **Usage Access Discovery:** Identify foreground package events via `UsageStatsManager` without scanning entire device inventories.
- **Decision:** Focus Lift will **avoid `QUERY_ALL_PACKAGES`** and rely on launcher-resolvable queries or user-selected app configurations.

---

### Recommended Android Architecture (V1)

Focus Lift on Android will adopt a **Compliant Distraction Detection and Reminder Model**:
1. **No Hard Blocking:** Focus Lift will not forcefully close or hijack third-party apps.
2. **Optional Usage Access (`PACKAGE_USAGE_STATS`):** Detects when a user navigates away from Focus Lift during an active workout session.
3. **Actionable Workout Notifications:** Displays a persistent high-priority notification during active workouts (`"Workout Active • Set 3 • Tap to return"`).
4. **In-App Accountability:** Prompts the user to return when Focus Lift is resumed.
5. **No Dangerous Permissions:** Does not use `AccessibilityService`, `DeviceAdminReceiver`, or `QUERY_ALL_PACKAGES`.
6. **Hard Allowlist:** Phone dialer, emergency calls, and audio apps (Spotify, YouTube Music, Apple Music) are never flagged.

---

## iOS Platform Analysis

### Apple Screen Time API Suite

Starting in iOS 15/16, Apple provides the official **Screen Time Frameworks**:
1. `FamilyControls`
2. `ManagedSettings`
3. `DeviceActivity`
4. `ManagedSettingsUI`

---

### FamilyControls & Authorization

- **Capabilities:**
  - In iOS 16+, `AuthorizationCenter.shared.requestAuthorization(for: .individual)` supports individual self-control and personal focus use cases without requiring a parental Family Sharing group.
  - Presents Apple's official system authentication dialog (Face ID / Touch ID / Passcode).

---

### FamilyActivityPicker

- **Capabilities & Privacy:**
  - Presents Apple's native SwiftUI picker sheet allowing the user to select specific apps, entire categories (e.g., Social, Games, Entertainment), and web domains.
  - **Zero Knowledge Privacy:** Focus Lift never receives bundle identifiers, application names, or icons. The OS returns opaque `ApplicationToken` and `ActivityCategoryToken` structures.
  - Tokens are persisted securely on-device (via `UserDefaults` or App Group).

---

### ManagedSettings (`ManagedSettingsStore`)

- **Capabilities:**
  - Enables direct, programmatic application and category shielding during active workouts:
    ```swift
    let store = ManagedSettingsStore(named: .workoutFocus)
    store.shield.applications = selectedAppTokens
    store.shield.applicationCategories = .specific(selectedCategoryTokens)
    ```
  - When shielded, opening a restricted app immediately displays Apple's native **Screen Time Shield UI**.
  - Clearing shields on workout finish (`store.clearAllSettings()` or `store.shield.applications = nil`) instantly restores access.
- **System Emergency Behavior:**
  - Phone calls and system emergency services are managed by Apple's operating system and will not be blocked by Focus Lift.
  - Permitted audio applications (Spotify, Apple Music) are left unshielded by excluding their tokens from the store selection.

---

### DeviceActivity & Usage Analytics Separation

- **Immediate Session Control vs Scheduled Monitoring:**
  - Direct workout sessions (Start Workout ➔ End Workout) are controlled immediately via `ManagedSettingsStore` without requiring complex background `DeviceActivitySchedule` timers.
- **Opaque Tokens vs Detailed Bundle Analytics:**
  - `FamilyControls` tokens allow **shielding** apps, but do not provide raw bundle IDs or real-time tap event logs to the parent app.
  - Accessing detailed app-and-website activity reports requires separate reporting extensions (`DeviceActivityReportExtension`) and specialized entitlements (`com.apple.developer.family-controls.app-and-website-activity`).

---

### Entitlements & App Store Review

- **Entitlement Key:** `com.apple.developer.family-controls`.
- **Development vs App Store Distribution:**
  - **Local Development / Simulator / Ad-Hoc:** Supported with standard Apple Developer account provisioning.
  - **TestFlight / App Store Distribution:** Requires submitting an official **Family Controls Distribution Request** to Apple Developer Relations.
- **App Store Review Guidelines (Guideline 5.4):**
  - Apple permits individual focus and wellbeing applications using `.individual` authorization, provided the app clearly communicates its purpose and does not mislead users.

---

### Recommended iOS Architecture (V1)

1. **Native Swift Plugin (`FocusControlPlugin.swift`):** Communicates with Flutter via `MethodChannel('com.cotrainr.focuslift/focus_control')`.
2. **`FamilyControls` Authorization:** Manages `.individual` Screen Time permission.
3. **`FamilyActivityPicker`:** Modal presentation for user selection of opaque application/category tokens.
4. **`ManagedSettingsStore`:** Applies OS shields on `startWorkout()` and unconditionally clears shields on `finishWorkout()`, `skipRest()`, discard, or crash recovery.

---

## Platform Comparison

| Capability | Android | iOS |
| :--- | :--- | :--- |
| **Official OS Shield/Block API** | ❌ No consumer shielding API | ✅ Yes (`ManagedSettingsStore`) |
| **Official System App Picker** | ❌ None (Custom launcher query / list) | ✅ Yes (`FamilyActivityPicker`) |
| **Shield Selected Apps at OS Level** | ❌ Not supported without policy risk | ✅ Supported natively |
| **Permit Background Audio (Spotify/Music)** | ✅ Yes (Hard allowlist) | ✅ Yes (Unshielded token) |
| **Emergency Functionality & Calls** | ✅ Normal device calls accessible | ✅ Managed by OS; unshielded |
| **Detect Distraction Attempts Legitimate Count** | ⚠️ Only with `PACKAGE_USAGE_STATS` | ❌ Opaque tokens (Privacy restriction) |
| **Requires Special Distribution Entitlement Approval** | ❌ No (Standard Android permissions) | ✅ Yes (`Family Controls Distribution`) |
| **Store Policy Compliance Risk** | 🟢 Low (with Reminder Model) | 🟢 Low (with approved entitlement) |
| **100% Offline / Zero Backend Required** | ✅ Yes | ✅ Yes |

---

## Focus Score Feasibility

- **iOS:** Apple's Screen Time architecture deliberately does not notify third-party apps when a user attempts to open a shielded app.
- **Android:** While `UsageStatsManager` can detect foreground switches if permission is granted, it cannot be measured if the permission is withheld.
- **Decision:** **Focus Score and Distraction Attempts MUST REMAIN HIDDEN on the Summary Screen** in V1. Focus Lift will never display fabricated or estimated behavioral statistics.

---

## Recommended Product Behavior

### iOS
- **FOCUS MODE:** Restricts selected distracting apps and entertainment categories via `ManagedSettingsStore`. Music streaming apps and phone calls remain accessible.
- **BALANCED MODE:** Restricts social/video categories; messaging tools and music remain unshielded.
- **CUSTOM MODE:** The user opens `FamilyActivityPicker` to select specific app and category tokens.

### Android
- **FOCUS MODE:** Focus Lift monitors foreground app usage (if Usage Access is granted) and presents an actionable high-priority focus reminder notification. Permitted music and dialer apps are ignored.
- **BALANCED MODE:** Monitors only selected entertainment packages; communication tools are excluded.
- **CUSTOM MODE:** The user selects apps from a list of installed launcher applications.

---

## V1 Launch Recommendation

1. **Dual-Platform Architecture with Platform-Tailored Focus Controls:**
   - Both platforms share the same clean Flutter UI and timer engine.
   - iOS implements native **Screen Time shielding** (`ManagedSettingsStore`).
   - Android implements a **Compliant Distraction Reminder Model** (`UsageStatsManager` + high-priority notification), avoiding dangerous AccessibilityService exploits.
2. **Transparent User Communication:**
   - Focus Lift will clearly explain its capabilities on each platform so users understand what the OS natively supports.

---

## Implementation Plan & Implemented Architecture (Phase 5)

1. **Common Dart Abstraction (`lib/services/focus_control/`):**
   - `FocusAuthorizationStatus`: Strong enum (`notDetermined`, `authorized`, `denied`, `restricted`, `unsupported`) with user-facing labels.
   - `FocusControlResult`: Immutable result object returning status, mode, and explanatory messages.
   - `AppInfo`: Model representing launcher-resolvable applications on Android.
   - `FocusControlService`: Service managing `MethodChannel('com.cotrainr.focuslift/focus_control')`, on-device distraction persistence, focus activation, and unconditional fail-safe cleanup.
2. **Android Native Implementation (`MainActivity.kt`):**
   - `getAuthorizationStatus`: Inspects `AppOpsManager.OPSTR_GET_USAGE_STATS` without throwing.
   - `requestAuthorization`: Launches system `Settings.ACTION_USAGE_ACCESS_SETTINGS`.
   - `getLauncherApps`: Queries `Intent.ACTION_MAIN` with `Intent.CATEGORY_LAUNCHER` to discover user applications safely without `QUERY_ALL_PACKAGES`.
   - `startFocusSession` / `stopFocusSession`: Manages focus session state.
   - `restoreNormalAccess`: Ensures all monitoring state is cleared.
3. **iOS Native Implementation (`FocusControlPlugin.swift` & `AppDelegate.swift`):**
   - Integrates `FamilyControls.AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
   - Manages `ManagedSettingsStore(named: .init("com.cotrainr.focuslift.workout"))`.
   - `restoreNormalAccess` / `stopFocusSession`: Unconditionally calls `store.clearAllSettings()`.
4. **Manual Apple Developer Steps for Distribution:**
   - **Step 1:** Add `com.apple.developer.family-controls` entitlement in `Runner.entitlements` (completed for development).
   - **Step 2:** Log in to the Apple Developer Portal (developer.apple.com) ➔ Certificates, Identifiers & Profiles ➔ App IDs ➔ `com.cotrainr.focuslift` ➔ Enable "Family Controls".
   - **Step 3:** Request the official **Family Controls Distribution Entitlement** from Apple Developer Relations via the online submission form before publishing to TestFlight external groups or App Store review.
5. **Fail-Safe Startup & Discard Guarantees:**
   - On application startup (`main.dart`), if no valid active workout is recovered, `focusControlService.restoreNormalAccess()` is called immediately.
   - Discarding a recovered workout on the Home screen unconditionally clears all shields and focus states.
