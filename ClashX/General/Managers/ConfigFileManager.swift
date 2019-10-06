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

class ConfigFileManager {
    static let shared = ConfigFileManager()
    private var witness:Witness?
    private var pause = false
    private var hostsFileWitness:Witness?
    
    func pauseForNextChange() {
        pause = true
    }
    
    func watchHostsFile() {
        let hostsPath = "/etc/hosts"
        hostsFileWitness = Witness(paths: [hostsPath], flags: .FileEvents, latency: 0.3) {
            events in
            if let _ = events.first(where: {$0.flags.contains(.ItemModified)}){
                clashUpdateHosts()
            }
        }
    }
    
    func watchConfigFile(configName:String) {
        let path = "\(kConfigFolderPath)\(configName).yaml"
        witness = Witness(paths: [path], flags: .FileEvents, latency: 0.3) {
            [weak self] events in
            guard let self = self else {return}
            guard !self.pause else {
                self.pause = false
                return
            }
            for event in events {
                if event.flags.contains(.ItemModified){
                    NSUserNotificationCenter.default
                        .postConfigFileChangeDetectionNotice()
                    NotificationCenter.default
                        .post(Notification(name: kConfigFileChange))
                    break
                }
            }
        }
    }

    
    @discardableResult
    static func backupAndRemoveConfigFile() -> Bool {
        let path = kDefaultConfigFilePath
        if (FileManager.default.fileExists(atPath: path)) {
            let newPath = "\(kConfigFolderPath)config_\(Date().timeIntervalSince1970).yaml"
            try? FileManager.default.moveItem(atPath: path, toPath: newPath)
        }
        return true
    }
    
    static func copySampleConfigIfNeed() {
        if !FileManager.default.fileExists(atPath: kDefaultConfigFilePath) {
            let path = Bundle.main.path(forResource: "sampleConfig", ofType: "yaml")!
            try? FileManager.default.copyItem(atPath: path, toPath: kDefaultConfigFilePath)
        }
    }
    
    
}


extension ConfigFileManager {
    
    static func checkFinalRuleAndShowAlert() {
        ApiRequest.getRules() {
            rules in
            let hasFinal = rules.reversed().contains(){$0.type == "MATCH"}
            if !hasFinal {
                showNoFinalRuleAlert()
            }
        }
    }
}


extension ConfigFileManager {
    
    static func showNoFinalRuleAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("No FINAL rule were found in clash configs,This might caused by incorrect upgradation during earily version of clashX or error setting of FINAL rule.Please check your config file.\n\nNO FINAL rule would cause traffic send to DIRECT which no match any rules.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
}
