import Foundation
import CoreFoundation

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}

let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
let domain = "io.github.aste2d.mac-accent-switcher.test." + UUID().uuidString
let store = AccentStore(backupURL: directory.appending(path: "backup.plist"),
                        domain: domain as CFString, announce: false)

func seed(_ values: [String: Any]) {
    CFPreferencesSetMultiple(values as CFDictionary, nil, domain as CFString,
                             kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    check(CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
          "Failed to seed test domain")
}

func run() throws {
    defer {
        CFPreferencesSetMultiple(nil, (AccentStore.keys + ["Unrelated"]) as CFArray,
                                 domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        try? FileManager.default.removeItem(at: directory)
    }

    seed([AccentStore.appleAccent: 0, "Unrelated": "kept"])
    check(!store.canRestore, "A fresh install unexpectedly has a backup")
    try store.apply(16)
    try store.apply(4)
    let applied = try store.read()
    check((applied[AccentStore.enclosure] as? Int) == 4, "Second color was not applied")
    check((applied[AccentStore.simulate] as? Bool) == true, "Simulation was not enabled")
    check(applied[AccentStore.appleAccent] == nil, "Fixed accent was not removed")
    try store.restore()
    let restored = try store.read()
    check((restored[AccentStore.appleAccent] as? Int) == 0, "Original fixed accent was not restored")
    check(restored[AccentStore.simulate] == nil && restored[AccentStore.enclosure] == nil,
          "Originally absent overrides were not removed")
    check(!store.canRestore, "Backup should be cleared after restoring")
    let unrelated = CFPreferencesCopyValue("Unrelated" as CFString, domain as CFString,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    check((unrelated as? String) == "kept", "An unrelated preference changed")

    try store.apply(15)
    try Data("invalid backup".utf8).write(to: store.backupURL, options: .atomic)
    do {
        try store.apply(17)
        check(false, "Expected corrupt backup to block writes")
    } catch AccentStore.Failure.invalidBackup {
        let afterFailure = try store.read()
        check((afterFailure[AccentStore.enclosure] as? Int) == 15, "A failed write changed the accent")
    }
}
try run()
print("Accent backup, switching and restoration passed.")
