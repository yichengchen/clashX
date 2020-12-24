//
//  NSUserNotificationCenter+Extension.swift
//  ClashX
//
//  Created by CYC on 2018/8/6.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa

extension NSUserNotificationCenter {
    func post(title: String, info: String, identifier: String? = nil) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = info
        if identifier != nil {
            notification.userInfo = ["identifier": identifier!]
        }
        delegate = UserNotificationCenterDelegate.shared
        deliver(notification)
    }

    func postConfigFileChangeDetectionNotice() {
        post(title: NSLocalizedString("Config file have been changed", comment: ""),
             info: NSLocalizedString("Tap to reload config", comment: ""),
             identifier: "postConfigFileChangeDetectionNotice")
    }

    func postStreamApiConnectFail(api: String) {
        post(title: "\(api) api connect error!",
             info: NSLocalizedString("Use reload config to try reconnect.", comment: ""))
    }

    func postConfigErrorNotice(msg: String) {
        let configName = ConfigManager.selectConfigName.count > 0 ?
            Paths.configFileName(for: ConfigManager.selectConfigName) : ""

        let message = "\(configName): \(msg)"
        post(title: NSLocalizedString("Config loading Fail!", comment: ""), info: message)
    }

    func postSpeedTestBeginNotice() {
        post(title: NSLocalizedString("Benchmark", comment: ""),
             info: NSLocalizedString("Benchmark has begun, please wait.", comment: ""))
    }

    func postSpeedTestingNotice() {
        post(title: NSLocalizedString("Benchmark", comment: ""),
             info: NSLocalizedString("Benchmark is processing, please wait.", comment: ""))
    }

    func postSpeedTestFinishNotice() {
        post(title: NSLocalizedString("Benchmark", comment: ""),
             info: NSLocalizedString("Benchmark Finished!", comment: ""))
    }

    func postProxyChangeByOtherAppNotice() {
        post(title: NSLocalizedString("System Proxy Changed", comment: ""),
             info: NSLocalizedString("Proxy settings are changed by another process. ClashX is no longer the default system proxy.", comment: ""))
    }
}

class UserNotificationCenterDelegate: NSObject, NSUserNotificationCenterDelegate {
    static let shared = UserNotificationCenterDelegate()

    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        switch notification.userInfo?["identifier"] as? String {
        case "postConfigFileChangeDetectionNotice":
            AppDelegate.shared.updateConfig()
            center.removeAllDeliveredNotifications()
        default:
            break
        }
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}
