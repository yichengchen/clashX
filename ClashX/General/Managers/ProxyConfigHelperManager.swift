
import Foundation
import AppKit

class ProxyConfigHelperManager {
    static let kProxyConfigFolder = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash")
    static let kVersion = "0.1.3"

    
    static func vaildHelper() -> Bool {
        let scriptPath = "\(Bundle.main.resourcePath!)/check_proxy_helper.sh"
        let appleScriptStr = "do shell script \"bash \\\"\(scriptPath)\\\" \(kProxyConfigFolder) \(kVersion) \" "
        let appleScript = NSAppleScript(source: appleScriptStr)
        var dict: NSDictionary?
        if let res = appleScript?.executeAndReturnError(&dict) {
            if (res.stringValue?.contains("success")) ?? false {
                return true
            }
        } else {
            Logger.log(msg: "\(String(describing: dict))",level: .error)
        }
        return false
        
    }

    static func install() -> Bool {
        checkConfigDir()
        checkMMDB()
        
        let proxyHelperPath = Bundle.main.path(forResource: "ProxyConfig", ofType: nil)
        let targetPath = "\(kProxyConfigFolder)/ProxyConfig"
        
       
        if !vaildHelper() {
            if (!showInstallHelperAlert()) {
                NSApplication.shared.terminate(nil)
            }
            
            if (FileManager.default.fileExists(atPath: targetPath)) {
                try? FileManager.default.removeItem(atPath: targetPath)
            }
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: proxyHelperPath!), to: URL(fileURLWithPath: targetPath))

            let scriptPath = "\(Bundle.main.resourcePath!)/install_proxy_helper.sh"
            let appleScriptStr = "do shell script \"bash \(scriptPath) \(kProxyConfigFolder) \" with administrator privileges"
            let appleScript = NSAppleScript(source: appleScriptStr)
                        
            var dict: NSDictionary?
            if let _ = appleScript?.executeAndReturnError(&dict) {
                return true
            } else {
                return false
            }
        }
        return true
    }
    
    static func checkConfigDir() {
        var isDir : ObjCBool = true
        
        if !FileManager.default.fileExists(atPath: kProxyConfigFolder, isDirectory:&isDir) {
            do {
                try FileManager.default.createDirectory(atPath: kProxyConfigFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                showCreateConfigDirFailAlert()
            }
        }
    }
    
    static func checkMMDB() {
        let fileManage = FileManager.default
        let destMMDBPath = "\(kProxyConfigFolder)/Country.mmdb"
        
        // Remove old mmdb file after version update.
        if fileManage.fileExists(atPath: destMMDBPath) {
            if AppVersionUtil.hasVersionChanged || AppVersionUtil.isFirstLaunch {
                try? fileManage.removeItem(atPath: destMMDBPath)
            }
        }
        
        
        if !fileManage.fileExists(atPath: destMMDBPath) {
            if let mmdbPath = Bundle.main.path(forResource: "Country", ofType: "mmdb") {
                try? fileManage.copyItem(at: URL(fileURLWithPath: mmdbPath), to: URL(fileURLWithPath: destMMDBPath))
            }
        }
    }
    
    static func setUpSystemProxy(port: Int?,socksPort: Int?) -> Bool {
        let task = Process()
        task.launchPath = "\(kProxyConfigFolder)/ProxyConfig"
        if let port = port,let socksPort = socksPort {
            task.arguments = [String(port),String(socksPort), "enable"]
        } else {
            task.arguments = ["0", "0", "disable"]
        }
        
        task.launch()
        
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            return false
        }
        return true
    }
    
    static func showInstallHelperAlert() -> Bool{
        let alert = NSAlert()
        alert.messageText = """
        ClashX needs to install a small tool to ~/.config/clash with administrator privileges to set system proxy quickly.
        
        Otherwise you need to type in the administrator password every time you change system proxy through ClashX.
        """.localized()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install".localized())
        alert.addButton(withTitle: "Quit".localized())
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    static func showCreateConfigDirFailAlert() {
        let alert = NSAlert()
        alert.messageText = """
        ClashX fail to create ~/.config/clash folder. Please check privileges or manually create folder and restart ClashX.
        """.localized()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit".localized())
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }

}
