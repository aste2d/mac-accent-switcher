import Foundation
import CoreFoundation

struct AccentStore {
    static let simulate = "NSColorSimulateHardwareAccent"
    static let enclosure = "NSColorSimulatedHardwareEnclosureNumber"
    static let appleAccent = "AppleAccentColor"
    static let keys = [simulate, enclosure, appleAccent]
    static let notifications = ["AppleAquaColorVariantChanged", "AppleColorPreferencesChangedNotification"]

    let backupURL: URL
    var domain = kCFPreferencesAnyApplication
    var announce = true

    var canRestore: Bool { FileManager.default.fileExists(atPath: backupURL.path) }

    enum Failure: LocalizedError {
        case preferences, rollback, invalidBackup
        var errorDescription: String? {
            switch self {
            case .preferences: return NSLocalizedString("Could not save the macOS accent preferences.", comment: "")
            case .rollback: return NSLocalizedString("The change could not be verified. The saved backup is still available.", comment: "")
            case .invalidBackup: return NSLocalizedString("The saved backup could not be read.", comment: "")
            }
        }
    }

    func read() throws -> [String: Any] {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw Failure.preferences
        }
        return CFPreferencesCopyMultiple(Self.keys as CFArray, domain,
                                         kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
    }

    func apply(_ number: Int) throws {
        let before = try read()
        if canRestore {
            _ = try readBackup()
        } else {
            try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: before, format: .binary, options: 0)
            try data.write(to: backupURL, options: .atomic)
        }
        try change(to: [Self.simulate: true, Self.enclosure: number], revertingTo: before)
    }

    func restore() throws {
        let saved = try readBackup()
        try change(to: saved, revertingTo: read())
        try FileManager.default.removeItem(at: backupURL)
    }

    private func readBackup() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: backupURL),
              let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let saved = value as? [String: Any],
              Set(saved.keys).isSubset(of: Self.keys) else { throw Failure.invalidBackup }
        return saved
    }

    private func change(to newValues: [String: Any], revertingTo previous: [String: Any]) throws {
        do {
            try write(newValues)
        } catch {
            do { try write(previous) } catch { throw Failure.rollback }
            throw error
        }
        if announce {
            for name in Self.notifications {
                DistributedNotificationCenter.default().postNotificationName(
                    Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true
                )
            }
        }
    }

    private func write(_ values: [String: Any]) throws {
        let removals = Self.keys.filter { values[$0] == nil }
        CFPreferencesSetMultiple(values as CFDictionary, removals as CFArray, domain,
                                 kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let saved = try read()
        guard NSDictionary(dictionary: values).isEqual(to: saved) else { throw Failure.preferences }
    }
}
