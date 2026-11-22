// Phantom Remote – App-Einstieg (Dock-App mit Fenster + Menüleisten-Symbol)
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        Hotkeys.register()
        _ = Phantom.shared
    }
    // Fenster schließen beendet die App nicht – Tastenkürzel & Menüleiste bleiben aktiv
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { Phantom.shared.shutdown() }
}

@main
struct PhantomRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject var p = Phantom.shared

    var body: some Scene {
        Window("Phantom Remote", id: "main") {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Wiedergabe") {
                Button("Lauter") { Task { await p.step(3) } }.keyboardShortcut(.upArrow, modifiers: .command).disabled(!p.canControl)
                Button("Leiser") { Task { await p.step(-3) } }.keyboardShortcut(.downArrow, modifiers: .command).disabled(!p.canControl)
                Button("Stumm umschalten") { Task { await p.toggleMute() } }.keyboardShortcut("m", modifiers: [.command, .shift]).disabled(!p.canControl)
                Divider()
                ForEach(p.selectableSources) { source in
                    Button(p.sourceLabel(source)) { Task { await p.select(source) } }.disabled(!p.canControl)
                }
                Button("Mac per AirPlay verbinden …") { p.openAirPlaySettings() }.keyboardShortcut("2", modifiers: .command)
                Divider()
                Button("Geräte auswählen …") { p.deviceSheet = true; p.rediscover() }
            }
        }

        MenuBarExtra {
            MenuPanel()
        } label: {
            Image(systemName: p.online ? (p.muted ? "speaker.slash" : "hifispeaker.2") : "speaker.badge.exclamationmark")
        }
        .menuBarExtraStyle(.window)
    }
}
