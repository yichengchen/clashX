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
            if URL(string: txt.stringValue) != nil {
                configUrl = txt.stringValue
                updateConfigIfNeed()
            }else {
                alert(with: "Url Error")
            }
        }
    }
    
    static func getRemoteConfigString(handler:@escaping (String?)->()) {
        guard let url = configUrl else {alert(with: "Not config url set!");return}
        request(url, method: .get).responseString(encoding: .utf8) { (res) in
            if let s = res.result.value {
                handler(s)
            } else {
                handler(nil)
            }
        }
    }
    
    static func updateConfigIfNeed() {
        getRemoteConfigString { (string) in
            guard let newConfigString = string else {alert(with: "Download fail"); return}
            
            var replaceSuccess = false
            if FileManager.default.fileExists(atPath: kDefaultConfigFilePath) {
                do {
                    let currentConfigStr = try String(contentsOfFile: kDefaultConfigFilePath)
                    if currentConfigStr == newConfigString {
                        self.alert(with: "Config not updated")
                    } else {
                        guard var originConfig = (try Yams.load(yaml: currentConfigStr)) as? [String:Any] else { throw "Can not parse current config"}
                        guard let newConfig = try Yams.load(yaml: newConfigString) as? [String:Any] else { throw "Can not parse new config"}
                        
                        originConfig["Proxy"] = newConfig["Proxy"]
                        originConfig["Proxy Group"] = newConfig["Proxy Group"]
                        originConfig["Rule"] = newConfig["Rule"]
                        
                        for (k,v) in originConfig {
                            if v is NSNull {
                                originConfig[k] = nil
                            }
                        }
                        
                        try FileManager.default.removeItem(atPath: kDefaultConfigFilePath)
                        try newConfigString.write(toFile: kDefaultConfigFilePath, atomically: true, encoding: .utf8)
                        NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
                        self.alert(with: "Success!")
                        replaceSuccess = true
                    }
                } catch _{
                    
                }
            }
            
            if !replaceSuccess {
                try? FileManager.default.removeItem(atPath: kDefaultConfigFilePath)
                do {
                    try string?.write(toFile: kDefaultConfigFilePath, atomically: true, encoding: .utf8)
                    NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
                    self.alert(with: "Success!")
                } catch let err {
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
