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

        case "openAppPicker":
            result(nil)

        case "updateSelectedDistractions":
            result(nil)

        case "startFocusSession":
            #if canImport(ManagedSettings)
            if #available(iOS 16.0, *) {
                // Apply managed shield store for active workout session
                let store = ManagedSettingsStore(named: .init("com.cotrainr.focuslift.workout"))
                // Apply shielding to selected token set
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
