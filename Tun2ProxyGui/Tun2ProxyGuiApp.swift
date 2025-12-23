//
//  Tun2ProxyGuiApp.swift
//  Tun2ProxyGui
//
//  Created by Mahdi Esbati on 12/22/25.
//

import SwiftUI

@main
struct Tun2ProxyGuiApp: App {
    @StateObject private var vm = Tun2ProxyViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Tun2Proxy", systemImage: vm.isRunning ? "network" : "network.slash") {
            ContentView()
                .environmentObject(vm)
                .onAppear {
                    appDelegate.vm = vm
                }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var vm: Tun2ProxyViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure we stop the proxy before the app actually exits
        vm?.stopSync()
    }
}
