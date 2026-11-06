import AppKit

@MainActor
enum SystemAppRestart {
    static func run() async -> [String] {
        let apps = [
            ("com.apple.dock", "Dock"),
            ("com.apple.systempreferences", "System Settings"),
            ("com.apple.finder", "Finder")
        ]
        var failed: [String] = []
        for (id, name) in apps {
            if !(await restart(bundleIdentifier: id)) {
                failed.append(NSLocalizedString(name, comment: "System app name"))
            }
        }
        return failed
    }

    static func restart(bundleIdentifier: String) async -> Bool {
        let workspace = NSWorkspace.shared
        let original = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
        let originalPIDs = Set(original.map(\.processIdentifier))
        let url = original.first?.bundleURL ?? workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)

        for app in original {
            // forceTerminate can report failure if the process already exited.
            _ = app.forceTerminate()
        }
        for _ in 0..<30 {
            if original.allSatisfy(\.isTerminated) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard original.allSatisfy(\.isTerminated) else { return false }

        // Dock and Finder can relaunch on their own. Reuse that new process.
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).contains(where: {
            !$0.isTerminated && !originalPIDs.contains($0.processIdentifier)
        }) { return true }

        guard let url else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        guard let relaunched = try? await workspace.openApplication(at: url, configuration: configuration) else {
            return false
        }
        return !relaunched.isTerminated && !originalPIDs.contains(relaunched.processIdentifier)
    }
}
