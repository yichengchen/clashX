//
//  Notification.swift
//  ClashX
//
//  Created by CYC on 2018/8/4.
//  Copyright © 2018年 yichengchen. All rights reserved.
//
import Foundation

extension Notification.Name {
    static let configFileChange = Notification.Name("kConfigFileChange")
    static let speedTestFinishForProxy = Notification.Name("kSpeedTestFinishForProxy")
    static let reloadDashboard = Notification.Name("kReloadDashboard")
    static let systemNetworkStatusIPUpdate = Notification.Name("systemNetworkStatusIPUpdate")
    static let systemNetworkStatusDidChange = Notification.Name("kSystemNetworkStatusDidChange")
    static let proxyMeneViewShowLeftPadding = Notification.Name("kProxyMeneViewShowLeftPadding")

    static func proxyUpdate(for name: ClashProxyName) -> Notification.Name {
        return Notification.Name("kProxyUpdate_\(name)")
    }
    
}
