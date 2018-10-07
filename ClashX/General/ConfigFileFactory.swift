//
//  ConfigFileFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/5.
//  Copyright © 2018年 yichengchen. All rights reserved.
//
import Foundation
import AppKit
import SwiftyJSON

class ConfigFileFactory {
    static let shared = ConfigFileFactory()
    var witness:Witness?
    func watchConfigFile() {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/config.ini")
        witness = Witness(paths: [path], flags: .FileEvents, latency: 0.3) { events in
            for event in events {
                print(event.flags)
                if event.flags.contains(.ItemModified) || event.flags.contains(.ItemCreated){
                    NSUserNotificationCenter.default.postConfigFileChangeDetectionNotice()
                    NotificationCenter.default.post(Notification(name: kConfigFileChange))
                    break
                }
            }
        }
    }
    
    static func proxyConfigStr(proxy:ProxyServerModel) -> String {
        let targetStr:String
        switch proxy.proxyType {
        case .shadowsocks:
            targetStr = "\(proxy.remark) = ss, \(proxy.serverHost), \(proxy.serverPort), \(proxy.method), \(proxy.password) \(proxy.pluginStr) \n"
        case .socks5:
            //socks = socks5, server1, port
            targetStr = "\(proxy.remark) = socks5, \(proxy.serverHost), \(proxy.serverPort)\n"
        }
        return targetStr
    }
    
    static func configFile(proxies:[ProxyServerModel]) -> String {
        var proxyStr = ""
        var proxyGroupStr = ""
        for proxy in proxies {
            let targetStr = self.proxyConfigStr(proxy: proxy)
            proxyStr.append(targetStr)
            proxyGroupStr.append("\(proxy.remark),")
        }
        let sampleConfig = NSData(contentsOfFile: Bundle.main.path(forResource: "sampleConfig", ofType: "ini")!)
        var sampleConfigStr = String(data: sampleConfig! as Data, encoding: .utf8)
        proxyGroupStr = String(proxyGroupStr.dropLast())

        if proxies.count > 1 {
            let autoGroupStr = "ProxyAuto = url-test, \(proxyGroupStr), http://www.google.com/generate_204, 300"
            sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyAutoGroupPlaceHolder}}", with: autoGroupStr)
            proxyGroupStr.append(",ProxyAuto")
        } else {
            sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyAutoGroupPlaceHolder}}", with: "")
        }

        sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyPlaceHolder}}", with: proxyStr)
        sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyGroupPlaceHolder}}", with: proxyGroupStr)

        return sampleConfigStr!
    }
    
    static func saveToClashConfigFile(str:String) {
        // save to ~/.config/clash/config.ini
        _ = self.backupAndRemoveConfigFile(showAlert: false)
        try? str.write(to: URL(fileURLWithPath: kConfigFilePath), atomically: true, encoding: .utf8)
    }
    
    @discardableResult
    static func backupAndRemoveConfigFile(showAlert:Bool = false) -> Bool {
        let path = kConfigFilePath
        if (showAlert) {
            if (!self.showReplacingConfigFileAlert()) {
                return false;
            }
        }
        if (FileManager.default.fileExists(atPath: path)) {
            let newPath = "\(kConfigFolderPath)config_\(Date().timeIntervalSince1970).ini"
            try? FileManager.default.moveItem(atPath: path, toPath: newPath)
        }
        return true
    }
    
    static func copySimpleConfigFile() -> Bool {
        if (!backupAndRemoveConfigFile(showAlert: true)) {
            return false
        }
        let path = Bundle.main.path(forResource: "initConfig", ofType: "ini")!
        try? FileManager.default.copyItem(atPath: path, toPath: kConfigFilePath)
        NSUserNotificationCenter.default.postGenerateSimpleConfigNotice()
        return true
    }
    
    
    static func importConfigFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Config Json File"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.becomeKey()
        let result = openPanel.runModal()
        guard (result.rawValue == NSFileHandlingPanelOKButton && (openPanel.url) != nil) else {
            NSUserNotificationCenter.default
                .post(title: "Import Server Profile failed!",
                      info: "Invalid config file!")
            return
        }
        let fileManager = FileManager.default
        let filePath:String = (openPanel.url?.path)!
        var profiles = [ProxyServerModel]()
        
        
        if fileManager.fileExists(atPath: filePath) &&
            filePath.hasSuffix("json") {
            if let data = fileManager.contents(atPath: filePath),
                let json = try? JSON(data: data) {
                let remarkSet = Set<String>()
                for item in json["configs"].arrayValue{
                    if let host = item["server"].string,
                        let method = item["method"].string,
                        let password = item["password"].string{
                        
                        let profile = ProxyServerModel()
                        profile.serverHost = host
                        profile.serverPort = String(item["server_port"].intValue)
                        profile.method = method
                        profile.password = password
                        profile.remark = item["remarks"].stringValue
                        profile.pluginStr = item["plugin_opts"].stringValue
                        if remarkSet.contains(profile.remark) {
                            profile.remark.append("Dup")
                        }
                        
                        if (profile.isValid()) {
                            profiles.append(profile)
                        }
                    }
                }
                
                if (profiles.count > 0) {
                    let configStr = self.configFile(proxies: profiles)
                    self.saveToClashConfigFile(str: configStr)
                    NSUserNotificationCenter
                        .default
                        .post(title: "Import Server Profile succeed!",
                              info: "Successful import \(profiles.count) items")
                    NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
                } else {
                    NSUserNotificationCenter
                        .default
                        .post(title: "Import Server Profile Fail!",
                              info: "No proxies are imported")
                }
                

            }
        }
        
    }
    
    static func addProxyToConfig(proxy:ProxyServerModel) {
        let targetStr = self.proxyConfigStr(proxy: proxy)
        guard let ini = parseConfig(kConfigFilePath),
            let currentProxys = ini["Proxy"],
            let proxyGroup = ini["Proxy Group"]
        else {
            self.saveToClashConfigFile(str: self.configFile(proxies: [proxy]))
            NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
            return
        }
        
        if currentProxys.keys.contains(proxy.remark) {
            NSUserNotificationCenter.default.postProxyRemarkDupNotice(name: proxy.remark)
            return
        }
        
        if self.shared.witness != nil {
            // not watch config file change now.
            self.shared.witness = nil
            defer {
                self.shared.watchConfigFile()
            }
        }
        
        let configData = NSData(contentsOfFile: kConfigFilePath)
        var configStr = String(data: configData! as Data, encoding: .utf8)!
        let spilts = configStr.components(separatedBy: "[Proxy Group]")
        configStr = spilts[0] + targetStr + "[Proxy Group]\n" + spilts[1]
        
        if let selectGroup = proxyGroup["Proxy"] {
            let newSelectGroup = "\(selectGroup),\(proxy.remark)"
            configStr = configStr.replacingOccurrences(of: selectGroup, with: newSelectGroup)
        }
        
        if let autoGroup = proxyGroup["ProxyAuto"] {
            let autoGroupProxys = autoGroup.components(separatedBy: ",").dropLast(2).joined(separator:",")
            let newAutoGroupProxys = "\(autoGroupProxys),\(proxy.remark)"
            configStr = configStr.replacingOccurrences(of: autoGroupProxys, with: newAutoGroupProxys)
        }
        
        self.saveToClashConfigFile(str: configStr)
        NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
    }
    
    static func showReplacingConfigFileAlert() -> Bool{
        let alert = NSAlert()
        alert.messageText = """
        Can't recognize your config file. We will backup and replace your config file in your config folder.
        
        Otherwise the functions of ClashX will not work properly. You may need to restart ClashX or reload Config manually.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
