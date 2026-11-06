import AppKit
import Foundation
import SwiftUI

if CommandLine.arguments.contains("--accent-probe") {
    guard let rgb = Accent.resolvedRGB() else { exit(1) }
    print(rgb)
} else if CommandLine.arguments.contains("--check-palette") {
    guard let executable = Bundle.main.executableURL else { exit(1) }
    let ids = Accent.supportedIDs(executable: executable)
    print(ids.sorted().map(String.init).joined(separator: " "))
    guard Set([3, 4, 5, 6, 7, 8]).isSubset(of: ids) else { exit(1) }
} else {
    AccentSwitcherApp.main()
}
