import AppKit
import SwiftUI

let claudeBundleID = "com.anthropic.claudefordesktop"

struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var color: String
    /// nil = the normal Claude installation without --user-data-dir
    var dataDir: String?
}

let palette: [(String, Color)] = [
    ("blue", .blue), ("orange", .orange), ("green", .green),
    ("purple", .purple), ("pink", .pink), ("gray", .gray),
]

func color(_ name: String) -> Color { palette.first { $0.0 == name }?.1 ?? .gray }

/// Main Claude processes, keyed by data directory ("" = default). Helper processes are ignored.
func runningInstances() -> [String: pid_t] {
    let ps = Process()
    ps.executableURL = URL(fileURLWithPath: "/bin/ps")
    ps.arguments = ["-axww", "-o", "pid=,command="]
    let pipe = Pipe()
    ps.standardOutput = pipe
    do { try ps.run() } catch { return [:] }
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    ps.waitUntilExit()

    var result: [String: pid_t] = [:]
    for line in output.split(separator: "\n") {
        let parts = line.drop { $0 == " " }.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, let pid = pid_t(parts[0]),
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == claudeBundleID
        else { continue }
        let command = String(parts[1])
        guard command.contains("/Contents/MacOS/Claude"), !command.contains("--type=") else { continue }
        var dir = ""
        if let flag = command.range(of: "--user-data-dir=") {
            let rest = command[flag.upperBound...]
            // The path may contain spaces; it ends at the next " --" flag.
            dir = String(rest[..<(rest.range(of: " --")?.lowerBound ?? rest.endIndex)])
        }
        result[dir] = pid
    }
    return result
}

final class Store: ObservableObject {
    @Published var profiles: [Profile] = [] { didSet { save() } }
    @Published var running: [String: pid_t] = [:]
    @Published var error: String?
    /// Process id of the app currently in front.
    @Published var frontPID: pid_t?

    private let file = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ClaudeSwitcher/profiles.json")
    private var timer: Timer?

    init() {
        if let data = try? Data(contentsOf: file) {
            if let saved = try? JSONDecoder().decode([Profile].self, from: data) {
                profiles = saved
            } else {
                // Keep an unreadable file instead of overwriting it with the defaults.
                try? FileManager.default.moveItem(at: file, to: file.appendingPathExtension("broken"))
            }
        }
        if profiles.isEmpty {
            profiles = [
                Profile(name: "Privat", color: "blue", dataDir: nil),
                Profile(name: "Arbeit", color: "orange", dataDir: newDataDir("arbeit")),
            ]
            save()
        }
        refresh()
        frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                self?.refresh()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(profiles).write(to: file, options: .atomic)
        } catch {
            self.error = "Profile konnten nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func refresh() {
        let now = runningInstances()
        if now != running { running = now }
    }

    func pid(_ p: Profile) -> pid_t? { running[p.dataDir ?? ""] }

    private func newDataDir(_ name: String) -> String {
        var slug = name.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? String($0) : "-" }.joined()
        if slug.allSatisfy({ $0 == "-" }) { slug = "profil" }
        let base = NSHomeDirectory() + "/.claude-instances/"
        var candidate = base + slug
        var n = 2
        // Never reuse an existing folder: it may hold another account's login.
        while profiles.contains(where: { $0.dataDir == candidate })
                || (!profiles.isEmpty && FileManager.default.fileExists(atPath: candidate)) {
            candidate = base + "\(slug)-\(n)"
            n += 1
        }
        return candidate
    }

    func isFront(_ p: Profile) -> Bool { pid(p) != nil && pid(p) == frontPID }

    func add(name: String, color: String) {
        profiles.append(Profile(name: name, color: color, dataDir: newDataDir(name)))
    }

    func open(_ p: Profile) {
        refresh()
        if let pid = pid(p), let app = NSRunningApplication(processIdentifier: pid) {
            app.unhide()
            // Reopening the Dock-less window needs an explicit activate of this exact process.
            NSApp.yieldActivation(to: app)
            app.activate(options: [.activateAllWindows])
            return
        }
        guard let claude = NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) else {
            error = "Claude Desktop wurde nicht gefunden."
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        if let dir = p.dataDir {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
            } catch {
                self.error = error.localizedDescription
                return
            }
            config.arguments = ["--user-data-dir=\(dir)"]
        }
        NSWorkspace.shared.openApplication(at: claude, configuration: config) { [weak self] _, err in
            DispatchQueue.main.async {
                if let err { self?.error = err.localizedDescription }
                self?.refresh()
            }
        }
    }

    /// Menu bar click: hide the instance if it is already in front, otherwise show or start it.
    /// Hiding works like Cmd-H, the process keeps running.
    func toggle(_ p: Profile) {
        refresh()
        if let pid = pid(p), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.hide()
        } else {
            open(p)
        }
    }

    func quit(_ p: Profile) {
        guard let pid = pid(p) else { return }
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    func reveal(_ p: Profile) {
        let dir = p.dataDir ?? NSHomeDirectory() + "/Library/Application Support/Claude"
        guard FileManager.default.fileExists(atPath: dir) else {
            error = "Der Datenordner entsteht erst beim ersten Start des Profils."
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: dir))
    }
}

struct ProfileRow: View {
    @ObservedObject var store: Store
    @Binding var profile: Profile
    @State private var confirmQuit = false
    @State private var confirmRemove = false

    var body: some View {
        let isRunning = store.pid(profile) != nil
        HStack(spacing: 10) {
            Menu {
                ForEach(palette, id: \.0) { entry in
                    Button(entry.0) { profile.color = entry.0 }
                }
            } label: {
                Image(systemName: "circle.fill").foregroundStyle(color(profile.color))
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
            .help("Farbe ändern")

            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $profile.name).textFieldStyle(.plain).font(.headline)
                HStack(spacing: 4) {
                    Circle().fill(isRunning ? Color.green : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                    Text(isRunning ? "läuft" : "beendet")
                    if profile.dataDir == nil { Text("· Standard-Installation") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(isRunning ? "Wechseln" : "Starten") { store.open(profile) }
                .buttonStyle(.borderedProminent).tint(color(profile.color))
            Menu {
                Button("Datenordner im Finder zeigen") { store.reveal(profile) }
                Button("Diese Instanz beenden…") { confirmQuit = true }.disabled(!isRunning)
                if profile.dataDir != nil {
                    Button("Aus Liste entfernen…") { confirmRemove = true }.disabled(isRunning)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        }
        .padding(.vertical, 6)
        .confirmationDialog("„\(profile.name)“ beenden?", isPresented: $confirmQuit) {
            Button("Beenden", role: .destructive) { store.quit(profile) }
        } message: {
            Text("Laufende Aufgaben in diesem Claude-Fenster werden abgebrochen.")
        }
        .confirmationDialog("„\(profile.name)“ aus der Liste entfernen?", isPresented: $confirmRemove) {
            Button("Entfernen", role: .destructive) { store.profiles.removeAll { $0.id == profile.id } }
        } message: {
            Text("Der Datenordner mit Login und Chats bleibt erhalten: \(profile.dataDir ?? "")")
        }
    }
}

struct MainView: View {
    @ObservedObject var store: Store
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($store.profiles) { $profile in
                    ProfileRow(store: store, profile: $profile)
                }
            }
            Divider()
            HStack {
                TextField("Neues Profil", text: $newName).onSubmit(add)
                Button("Hinzufügen", action: add).disabled(trimmed.isEmpty)
            }
            .padding(10)
            Text("Erster Login eines Profils: andere Claude-Instanzen vorher beenden und im Browser das richtige Konto verwenden.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding([.horizontal, .bottom], 10)
        }
        .frame(minWidth: 400, minHeight: 280)
        .alert("Fehler", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") {}
        } message: {
            Text(store.error ?? "")
        }
    }

    private var trimmed: String { newName.trimmingCharacters(in: .whitespaces) }

    private func add() {
        guard !trimmed.isEmpty else { return }
        store.add(name: trimmed, color: palette[store.profiles.count % palette.count].0)
        newName = ""
    }
}

struct MenuContent: View {
    @ObservedObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.profiles) { p in
            Toggle(isOn: Binding(get: { store.isFront(p) }, set: { _ in store.toggle(p) })) {
                Text("\(store.pid(p) != nil ? "●" : "○")  \(p.name)")
            }
        }
        Divider()
        Button("Profile verwalten…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Claude Switcher beenden") { NSApp.terminate(nil) }
    }
}

/// Shows only running instances; falls back to an icon when none is running.
struct MenuLabel: View {
    @ObservedObject var store: Store

    var body: some View {
        let badges = store.profiles.filter { store.pid($0) != nil }
            .map { (color: NSColor(color($0.color)), front: store.isFront($0)) }
        if badges.isEmpty {
            Image(systemName: "person.2.circle")
        } else {
            Image(nsImage: badgeImage(badges))
        }
    }
}

struct ClaudeSwitcherApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        Window("Claude Switcher", id: "main") { MainView(store: store) }
            .defaultSize(width: 440, height: 340)
            // Menu bar app: the window only opens through "Profile verwalten…".
            .defaultLaunchBehavior(.suppressed)
            .restorationBehavior(.disabled)
        MenuBarExtra { MenuContent(store: store) } label: { MenuLabel(store: store) }
    }
}

ClaudeSwitcherApp.main()
