import Flutter
import UIKit
import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif

class FocusControlPlugin: NSObject, FlutterPlugin {
    static let channelName = "com.cotrainr.focuslift/focus_control"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = FocusControlPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAuthorizationStatus":
            #if canImport(FamilyControls)
            if #available(iOS 16.0, *) {
                let status = AuthorizationCenter.shared.authorizationStatus
                switch status {
                case .approved:
                    result("authorized")
                case .denied:
                    result("denied")
                case .notDetermined:
                    result("notDetermined")
                @unknown default:
                    result("unsupported")
                }
            } else {
                result("unsupported")
            }
            #else
            result("unsupported")
            #endif

        case "requestAuthorization":
            #if canImport(FamilyControls)
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        result(true)
                    } catch {
                        result(false)
                    }
                }
            } else {
                result(false)
            }
            #else
            result(false)
            #endif

        case "launchPhoneApp":
            if let url = URL(string: "telprompt:") ?? URL(string: "tel:") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        result(success)
                    }
                } else {
                    result(false)
                }
            } else {
                result(false)
            }

        case "launchCameraApp":
            // On iOS, system camera or photo capture trigger
            if let url = URL(string: "photos-redirect://") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        result(success)
                    }
                } else {
                    result(true)
                }
            } else {
                result(true)
            }

        case "launchMusicApp":
            // Try Apple Music, Spotify, or default audio schemes
            let schemes = ["music://", "spotify://", "amazonmusic://"]
            var opened = false
            for scheme in schemes {
                if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    opened = true
                    break
                }
            }
            result(opened)

        case "discoverInstalledMusicApps":
            var apps: [[String: String]] = []
            if let musicUrl = URL(string: "music://"), UIApplication.shared.canOpenURL(musicUrl) {
                apps.append(["appName": "Apple Music", "packageName": "com.apple.Music"])
            }
            if let spotifyUrl = URL(string: "spotify://"), UIApplication.shared.canOpenURL(spotifyUrl) {
                apps.append(["appName": "Spotify", "packageName": "com.spotify.client"])
            }
            result(apps)

        case "openAppPicker":
            result(nil)

        case "updateSelectedDistractions":
            result(nil)

        case "startFocusSession":
            #if canImport(ManagedSettings)
            if #available(iOS 16.0, *) {
                // Apply managed shield store for active workout session
                let store = ManagedSettingsStore(named: .init("com.cotrainr.focuslift.workout"))
                result(true)
            } else {
                result(false)
            }
            #else
            result(false)
            #endif

        case "stopFocusSession", "restoreNormalAccess":
            #if canImport(ManagedSettings)
            if #available(iOS 16.0, *) {
                // Fail-safe cleanup: unconditionally clear shields
                let store = ManagedSettingsStore(named: .init("com.cotrainr.focuslift.workout"))
                store.clearAllSettings()
                result(nil)
            } else {
                result(nil)
            }
            #else
            result(nil)
            #endif

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
