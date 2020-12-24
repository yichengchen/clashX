//
//  ClientOnlyManager.swift
//  ClashX Pro
//
//  Created by 称一称 on 2020/6/16.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

class RemoteControl: Codable {
    let name: String
    let url: String
    let secret: String
    let uuid: String

    init(name: String, url: String, secret: String) {
        self.name = name
        self.url = url
        self.secret = secret
        uuid = UUID().uuidString
    }
}

class RemoteControlManager {
    static let shared = RemoteControlManager()
    static var configs: [RemoteControl] = loadConfig() {
        didSet {
            if let encoded = try? JSONEncoder().encode(configs) {
                UserDefaults.standard.set(encoded, forKey: "kRemoteControls")
            }
            updateMenuItems()
        }
    }

    static var selectConfig: RemoteControl?
    private static var menuSeparator: NSMenuItem?

    static func loadConfig() -> [RemoteControl] {
        if let savedConfigs = UserDefaults.standard.object(forKey: "kRemoteControls") as? Data {
            if let loadedConfig = try? JSONDecoder().decode([RemoteControl].self, from: savedConfigs) {
                return loadedConfig
            } else {
                assertionFailure()
                return []
            }
        }
        return []
    }

    static func setupMenuItem(separator: NSMenuItem) {
        menuSeparator = separator
        updateMenuItems()
        updateDropDownMenuItems()
    }

    static func updateMenuItems() {
        guard let separator = menuSeparator, let menu = separator.menu else { return }
        let idx = menu.index(of: separator)
        for _ in 0..<idx {
            menu.removeItem(at: 0)
        }

        for model in configs.reversed() {
            let item = ExternalControlMenuItem(model: model)
            item.state = (selectConfig?.uuid == model.uuid) ? .on : .off
            item.target = self
            item.action = #selector(didSelectMenuItem(sender:))
            menu.insertItem(item, at: 0)
        }

        let item = ExternalControlMenuItem.createNoneItem()
        item.target = self
        item.action = #selector(didSelectMenuItem(sender:))
        item.state = selectConfig == nil ? .on : .off
        menu.insertItem(item, at: 0)
    }

    @objc static func didSelectMenuItem(sender: ExternalControlMenuItem) {
        selectConfig = sender.model
        updateRemoteControl()
        updateMenuItems()
    }

    static func updateRemoteControl() {
        if let config = selectConfig, let url = URL(string: config.url) {
            ConfigManager.shared.overrideApiURL = url
            ConfigManager.shared.overrideSecret = config.secret
        } else {
            selectConfig = nil
            ConfigManager.shared.overrideApiURL = nil
            ConfigManager.shared.overrideSecret = nil
        }
        ClashProxy.cleanCache()
        AppDelegate.shared.resetStreamApi()
        AppDelegate.shared.syncConfig()
        MenuItemFactory.recreateProxyMenuItems()
        updateDropDownMenuItems()
    }

    static func updateDropDownMenuItems() {
        let d = AppDelegate.shared
        let enable = selectConfig == nil
        d.statusMenu.autoenablesItems = enable
        [d.copyExportCommandMenuItem, d.copyExportCommandExternalMenuItem, d.proxySettingMenuItem].forEach {
            $0?.isEnabled = enable
        }
    }
}

class ExternalControlMenuItem: NSMenuItem {
    var model: RemoteControl?
    init(model: RemoteControl) {
        super.init(title: model.name, action: nil, keyEquivalent: "")
        self.model = model
    }

    private init(title: String) {
        super.init(title: title, action: nil, keyEquivalent: "")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func createNoneItem() -> ExternalControlMenuItem {
        return ExternalControlMenuItem(title: "None")
    }
}
