import AppKit
import SwiftUI

struct Accent: Identifiable {
    let id: Int
    let name: String
    let rgb: UInt32

    var isNeo: Bool { id >= 15 }
    var hex: String { String(format: "#%06X", rgb) }
    var color: Color {
        Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    static let all: [Self] = [
        .init(id: 3, name: "Golden Yellow", rgb: 0xF3B036),
        .init(id: 4, name: "Teal", rgb: 0x427E82),
        .init(id: 5, name: "Slate Blue", rgb: 0x507791),
        .init(id: 6, name: "Coral Pink", rgb: 0xCD565A),
        .init(id: 7, name: "Dusty Purple", rgb: 0x5D6291),
        .init(id: 8, name: "Orange", rgb: 0xEF8056),
        .init(id: 15, name: "Indigo", rgb: 0x98A8D9),
        .init(id: 16, name: "Citrus", rgb: 0xB5D65A),
        .init(id: 17, name: "Blush", rgb: 0xFF7F99)
    ]

    static func supportedIDs(executable: URL) -> Set<Int> {
        // AppKit caches the hardware color. Probe each number in a fresh process
        // using argument-domain overrides, which never write to global defaults.
        guard let blue = resolvedRGB(executable, ["-AppleAccentColor", "4"]) else { return [] }
        let os = ProcessInfo.processInfo
        return Set(all.compactMap { accent in
            if accent.isNeo && !os.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 26, minorVersion: 3, patchVersion: 1)
            ) { return nil }
            let args = ["-AppleAccentColor", "8", "-NSColorSimulateHardwareAccent", "YES",
                        "-NSColorSimulatedHardwareEnclosureNumber", String(accent.id)]
            guard let color = resolvedRGB(executable, args), color != blue else { return nil }
            return accent.id
        })
    }

    private static func resolvedRGB(_ executable: URL, _ args: [String]) -> String? {
        let task = Process()
        let output = Pipe()
        task.executableURL = executable
        task.arguments = ["--accent-probe"] + args
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let rgb = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return rgb.count == 6 && UInt32(rgb, radix: 16) != nil ? rgb : nil
    }

    static func resolvedRGB() -> String? {
        let appearance = NSAppearance(named: .aqua)
        var rgb: String?
        appearance?.performAsCurrentDrawingAppearance {
            guard let color = NSColor.controlAccentColor.usingColorSpace(.sRGB) else { return }
            rgb = [color.redComponent, color.greenComponent, color.blueComponent]
                .map { String(format: "%02X", Int((max(0, min(1, $0)) * 255).rounded())) }.joined()
        }
        return rgb
    }
}
