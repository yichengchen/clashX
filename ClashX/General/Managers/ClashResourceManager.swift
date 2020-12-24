
import Alamofire
import AppKit
import Foundation
import Gzip

class ClashResourceManager {
    static func check() -> Bool {
        checkConfigDir()
        checkMMDB()
        return true
    }

    static func checkConfigDir() {
        var isDir: ObjCBool = true

        if !FileManager.default.fileExists(atPath: kConfigFolderPath, isDirectory: &isDir) {
            do {
                try FileManager.default.createDirectory(atPath: kConfigFolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                Logger.log("\(err.localizedDescription) \(kConfigFolderPath)")
                showCreateConfigDirFailAlert(err: err.localizedDescription)
            }
        }
    }

    static func checkMMDB() {
        let fileManage = FileManager.default
        let destMMDBPath = "\(kConfigFolderPath)/Country.mmdb"

        // Remove old mmdb file after version update.
        if fileManage.fileExists(atPath: destMMDBPath) {
            let vaild = verifyGEOIPDataBase().toBool()
            let versionChange = AppVersionUtil.hasVersionChanged || AppVersionUtil.isFirstLaunch
            let customMMDBSet = !Settings.mmdbDownloadUrl.isEmpty
            if !vaild || (versionChange && customMMDBSet) {
                try? fileManage.removeItem(atPath: destMMDBPath)
            }
        }

        if !fileManage.fileExists(atPath: destMMDBPath) {
            if let mmdbUrl = Bundle.main.url(forResource: "Country.mmdb", withExtension: "gz") {
                do {
                    let data = try Data(contentsOf: mmdbUrl).gunzipped()
                    try data.write(to: URL(fileURLWithPath: destMMDBPath))
                } catch let err {
                    Logger.log("add mmdb fail:\(err)", level: .error)
                }
            }
        }
    }

    static func showCreateConfigDirFailAlert(err: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ClashX fail to create ~/.config/clash folder. Please check privileges or manually create folder and restart ClashX." + err, comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}

extension ClashResourceManager {
    static func addUpdateMMDBMenuItem(_ menu: inout NSMenu) {
        let item = NSMenuItem(title: NSLocalizedString("Update GEOIP Database", comment: ""), action: #selector(updateGeoIP), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private static func updateGeoIP() {
        guard let url = showCustomAlert() else { return }
        AF.download(url, to:  { (_, _) in
            let path = kConfigFolderPath.appending("/Country.mmdb")
            return (URL(fileURLWithPath: path), .removePreviousFile)
        }).response { res in
            var info: String
            switch res.result {
            case .success:
                info = NSLocalizedString("Success!", comment: "")
                Logger.log("update success")
            case let .failure(err):
                info = NSLocalizedString("Fail:", comment: "") + err.localizedDescription
                Logger.log("update fail \(err)")
            }
            if !verifyGEOIPDataBase().toBool() {
                info = "Database verify fail"
                checkMMDB()
            }
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Update GEOIP Database", comment: "")
            alert.informativeText = info
            alert.runModal()
        }
    }
    
    private static func showCustomAlert() -> String? {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Custom your GEOIP MMDB download address.", comment: "")
        let inputView = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        inputView.placeholderString =  "https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb"
        inputView.stringValue = Settings.mmdbDownloadUrl
        alert.accessoryView = inputView
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            if inputView.stringValue.isEmpty {
                return inputView.placeholderString
            }
            Settings.mmdbDownloadUrl = inputView.stringValue
            return inputView.stringValue
        }
        return nil
    }
}
