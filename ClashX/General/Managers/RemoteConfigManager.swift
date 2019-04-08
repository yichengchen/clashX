//
//  RemoteConfigManager.swift
//  ClashX
//
//  Created by CYC on 2018/11/6.
//  Copyright © 2018 west2online. All rights reserved.
//

import Cocoa
import Alamofire
import Yams

class RemoteConfigManager: NSObject {
    static var configUrl:String? {
        get {
            return UserDefaults.standard.string(forKey: "kRemoteConfigUrl")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "kRemoteConfigUrl")
        }
    }
    
    static var configFileName:String? {
        guard let configUrl = configUrl else {return nil}
        return URL(string: configUrl)?.host
    }
    
    static var lastAutoCheckTime:Date? {
        get {
            return UserDefaults.standard.object(forKey: "kLastAutoCheckTime") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kLastAutoCheckTime")
        }
    }
    
    static var autoUpdateEnable:Bool {
        get {
            return UserDefaults.standard.object(forKey: "kAutoUpdateEnable") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kAutoUpdateEnable")
        }
    }
    
    static func showUrlInputAlert() {
        let msg = NSAlert()
        msg.addButton(withTitle: "OK")
        msg.addButton(withTitle: "Cancel")  // 2nd button
        msg.messageText = "Remote config"
        msg.informativeText = "url:"
        
        let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        txt.cell?.usesSingleLineMode = true
        txt.stringValue = configUrl ?? ""
        msg.accessoryView = txt
        let response = msg.runModal()
        
        if response == .alertFirstButtonReturn {
            if txt.stringValue.count == 0 {
                configUrl = nil
                return
            }
            
            if URL(string: txt.stringValue) != nil{
                configUrl = txt.stringValue
                updateConfigIfNeed()
            } else {
                alert(with: "Url Error")
            }
        }
    }
    
    
    static func updateCheckAtLaunch() {
        guard autoUpdateEnable else {return}
        let currentConfig = ConfigManager.selectConfigName
        
        if RemoteConfigManager.configUrl != nil, configFileName == currentConfig {
            
            if Date().timeIntervalSince(lastAutoCheckTime ?? Date(timeIntervalSince1970: 0)) < 60 * 60 * 12 {
                // 12hour
                return;
            }
            
            lastAutoCheckTime = Date()
            
            RemoteConfigManager.updateConfigIfNeed { err in
                if let err = err {
                    NSUserNotificationCenter.default.post(title: "Remote Config Update Fail", info: err)
                } else {
                    NSUserNotificationCenter.default.post(title: "Remote Config Update", info: "Succeed!")
                }
            }
        }
    }
    
    static func getRemoteConfigString(handler:@escaping (String, String?)->()) {
        guard let urlString = configUrl,
            let fileName = configFileName
            else {alert(with: "Not config url set!");return}
        
        request(urlString, method: .get).responseString(encoding: .utf8) { (res) in
            if let s = res.result.value {
                handler(fileName,s)
            } else {
                handler(fileName,nil)
            }
        }
    }
    
    static func updateConfigIfNeed(complete:((String?)->())?=nil) {
        getRemoteConfigString { (configName,string) in
            guard let newConfigString = string else {
                if let complete = complete {
                    complete("Download fail")
                } else {
                    alert(with: "Download fail")
                }
                return
            }
            
            let savePath = kConfigFolderPath.appending(configName).appending(".yml")
            let fm = FileManager.default
            do {
                if fm.fileExists(atPath: savePath) {
                    let current = try String(contentsOfFile: savePath)
                    if current == newConfigString {
                        if let complete = complete {
                            complete(nil)
                        } else {
                            self.alert(with: "No Update needed!")
                        }
                        return
                    }
                    try fm.removeItem(atPath: savePath)
                }
                try newConfigString.write(toFile: savePath, atomically: true, encoding: .utf8)
                ConfigManager.selectConfigName = configName
                NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
                if let complete = complete {
                    complete(nil)
                } else {
                    self.alert(with: "Update Success!")
                }
            } catch let err {
                if let complete = complete {
                    complete(err.localizedDescription)
                } else {
                    self.alert(with: err.localizedDescription)
                }
            }
        }
    }
    
    static func alert(with text:String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}


extension String: Error {}
