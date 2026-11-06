import AppKit
import SwiftUI

@MainActor
final class SwitcherModel: ObservableObject {
    private let store = AccentStore(backupURL: URL.applicationSupportDirectory
        .appending(path: "MacAccentSwitcher/original-accent.plist"))
    @Published var supportedIDs: Set<Int>?
    @Published var currentID: Int?
    @Published var canRestore = false
    @Published var status = ""
    @Published var errorMessage: String?

    init() {
        refresh()
        if let executable = Bundle.main.executableURL {
            Task {
                supportedIDs = await Task.detached(priority: .userInitiated) {
                    Accent.supportedIDs(executable: executable)
                }.value
            }
        } else {
            supportedIDs = []
        }
    }

    func refresh() {
        canRestore = store.canRestore
        guard let values = try? store.read(),
              values[AccentStore.appleAccent] == nil,
              (values[AccentStore.simulate] as? NSNumber)?.boolValue == true else {
            currentID = nil
            return
        }
        currentID = (values[AccentStore.enclosure] as? NSNumber)?.intValue
    }

    func apply(_ accent: Accent) {
        guard supportedIDs?.contains(accent.id) == true else { return }
        update("Accent applied. Reopen any apps that still show the old color.") { try store.apply(accent.id) }
    }

    func restore() {
        update("Original accent restored. Reopen any apps that still show the old color.") { try store.restore() }
    }

    private func update(_ message: String, operation: () throws -> Void) {
        defer { refresh() }
        do {
            try operation()
            status = NSLocalizedString(message, comment: "")
        } catch {
            status = ""
            errorMessage = error.localizedDescription
        }
    }
}

struct AccentSwitcherApp: App {
    @StateObject private var model = SwitcherModel()

    var body: some Scene {
        Window("Mac Accent Switcher", id: "palette") {
            PaletteView(model: model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Mac Accent Switcher", systemImage: "paintpalette") {
            PaletteView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PaletteView: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Accent Switcher").font(.title3.bold())
                    Text("Choose a Mac accent color.").foregroundStyle(.secondary)
                }
                Spacer()
            }

            palette("iMac", accents: Accent.all.filter { !$0.isNeo })
            palette("MacBook Neo", accents: Accent.all.filter(\.isNeo))
            if let ids = model.supportedIDs, !ids.isSuperset(of: [15, 16, 17]) {
                Text("MacBook Neo colors require a supported build of macOS 26.3.1 or later.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                Button("Restore Original", action: model.restore)
                    .disabled(!model.canRestore)
                Spacer()
                Button("Open Appearance") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Appearance-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Text("aste2d").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 385)
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name("AppleColorPreferencesChangedNotification")
        )) { _ in model.refresh() }
        .alert("Couldn’t change accent", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func palette(_ title: String, accents: [Accent]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                ForEach(accents) { accent in
                    let selected = model.currentID == accent.id
                    let available = model.supportedIDs?.contains(accent.id) == true
                    let name = NSLocalizedString(accent.name, comment: "")
                    Button { model.apply(accent) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(accent.color)
                                .frame(height: 30)
                                .overlay(alignment: .trailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white, .black.opacity(0.62))
                                            .padding(.trailing, 6)
                                    }
                                }
                            Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text("\(accent.id) · \(accent.hex)").font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(available ? 1 : 0.48)
                    .disabled(!available)
                    .accessibilityLabel(name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
