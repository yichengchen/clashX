//
//  SystemProxyManager.swift
//  ClashX
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

import AppKit
import ServiceManagement

class SystemProxyManager: NSObject {
    static let shared = SystemProxyManager()

    private var savedProxyInfo: [String: Any] {
        get {
            return UserDefaults.standard.dictionary(forKey: "kSavedProxyInfo") ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kSavedProxyInfo")
        }
    }

    private var disableRestoreProxy: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "kDisableRestoreProxy")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kDisableRestoreProxy")
        }
    }

    private var helper: ProxyConfigRemoteProcessProtocol? {
        PrivilegedHelperManager.shared.helper()
    }

    func saveProxy() {
        guard !disableRestoreProxy else { return }
        Logger.log("saveProxy", level: .debug)
        helper?.getCurrentProxySetting({ [weak self] info in
            Logger.log("saveProxy done", level: .debug)
            if let info = info as? [String: Any] {
                self?.savedProxyInfo = info
            }
        })
    }

    func enableProxy() {
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        enableProxy(port: port, socksPort: socketPort)
    }

    func enableProxy(port: Int, socksPort: Int) {
        guard port > 0 && socksPort > 0 else {
            Logger.log("enableProxy fail: \(port) \(socksPort)", level: .error)
            return
        }
        Logger.log("enableProxy", level: .debug)
        helper?.enableProxy(withPort: Int32(port),
                            socksPort: Int32(socksPort),
                            pac: nil,
                            filterInterface: Settings.filterInterface,
                            error: { error in
            if let error = error {
                Logger.log("enableProxy \(error)", level: .error)
            }
        })
    }

    func disableProxy(complete: (() -> Void)? = nil) {
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort, complete: complete)
    }

    func disableProxy(port: Int, socksPort: Int, forceDisable: Bool = false, complete: (() -> Void)? = nil) {
        Logger.log("disableProxy", level: .debug)

        if disableRestoreProxy || forceDisable {
            helper?.disableProxy(withFilterInterface: Settings.filterInterface) { error in
                if let error = error {
                    Logger.log("disableProxy \(error)", level: .error)
                }
                complete?()
            }
            return
        }

        helper?.restoreProxy(withCurrentPort: Int32(port), socksPort: Int32(socksPort), info: savedProxyInfo, filterInterface: Settings.filterInterface, error: { error in
            if let error = error {
                Logger.log("restoreProxy \(error)", level: .error)
            }
            complete?()
        })
    }

    // MARK: - Expriment Menu Items

    func addDisableRestoreProxyMenuItem(_ menu: inout NSMenu) {
        let item = NSMenuItem(title: NSLocalizedString("Disable Restore Proxy Setting", comment: ""), action: #selector(optionMenuItemTap(sender:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        updateMenuItemStatus(item)
    }

    func updateMenuItemStatus(_ item: NSMenuItem) {
        item.state = disableRestoreProxy ? .on : .off
    }

    @objc func optionMenuItemTap(sender: NSMenuItem) {
        disableRestoreProxy = !disableRestoreProxy
        updateMenuItemStatus(sender)
    }
}
