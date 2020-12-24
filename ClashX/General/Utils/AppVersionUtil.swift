//
//  AppVersionUtil.swift
//  ClashX
//
//  Created by CYC on 2019/2/18.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class AppVersionUtil: NSObject {
    private static let shared = AppVersionUtil()

    private static let kLastVersionNumberKey = "com.clashX.lastVersionNumber"

    private let lastVersionNumber: String?

    static var currentVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var currentBuild: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var isBeta: Bool {
        return Bundle.main.object(forInfoDictionaryKey: "BETA") as? Bool ?? false
    }

    override init() {
        lastVersionNumber = UserDefaults.standard.string(forKey: AppVersionUtil.kLastVersionNumberKey)
        UserDefaults.standard.set(AppVersionUtil.currentVersion, forKey: AppVersionUtil.kLastVersionNumberKey)
    }

    static var isFirstLaunch: Bool {
        return shared.lastVersionNumber == nil
    }

    static var hasVersionChanged: Bool {
        return shared.lastVersionNumber != currentVersion
    }
}

extension AppVersionUtil {
    static func showUpgradeAlert() {
        if let lastVersion = shared.lastVersionNumber, hasVersionChanged {
            guard lastVersion.compare("1.30.0", options: .numeric) == .orderedAscending else { return }
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("This version of ClashX contains a break change due to clash core 1.0 released. Check if your config is not working properly.", comment: "")
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Details", comment: ""))
            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://github.com/Dreamacro/clash/wiki/breaking-changes-in-1.0.0")!)
            }
        }
    }
}
