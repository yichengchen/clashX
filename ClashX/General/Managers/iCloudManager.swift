//
//  iCloudManager.swift
//  ClashX
//
//  Created by yicheng on 2020/5/10.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

class iCloudManager {
    static let shared = iCloudManager()
    private let queue = DispatchQueue(label: "com.clashx.icloud")
    private var metaQuery: NSMetadataQuery?
    private var enableMenuItem: NSMenuItem?
    private var icloudAvailable = false {
        didSet { updateMenuItemStatus() }
    }

    private var userEnableiCloud: Bool = UserDefaults.standard.bool(forKey: "kUserEnableiCloud") {
        didSet { UserDefaults.standard.set(userEnableiCloud, forKey: "kUserEnableiCloud") }
    }

    func setup() {
        addNotification()
        icloudAvailable = isICloudAvailable()
        if isICloudEnable() {
            checkiCloud()
        }
    }

    func isICloudEnable() -> Bool {
        return icloudAvailable && userEnableiCloud
    }

    func getConfigFilesList(configs: @escaping (([String]) -> Void)) {
        getUrl { url in
            guard let url = url,
                let fileURLs = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
                configs([])
                return
            }
            let list = fileURLs
                .filter { String($0.split(separator: ".").last ?? "") == "yaml" }
                .map { $0.split(separator: ".").dropLast().joined(separator: ".") }
            configs(list)
        }
    }

    private func checkiCloud() {
        if isICloudAvailable() {
            icloudAvailable = true
            getUrl { url in
                guard let url = url else {
                    self.icloudAvailable = false
                    return
                }
                let files = try? FileManager.default.contentsOfDirectory(atPath: url.path)
                if let count = files?.count, count == 0 {
                    let path = Bundle.main.path(forResource: "sampleConfig", ofType: "yaml")!
                    try? FileManager.default.copyItem(atPath: path, toPath: kDefaultConfigFilePath)
                    try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "sampleConfig", ofType: "yaml")!, toPath: url.appendingPathComponent("config.yaml").path)
                }
            }
        }
    }

    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    func getUrl(complete: ((URL?) -> Void)? = nil) {
        queue.async {
            guard var url = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                DispatchQueue.main.async {
                    complete?(nil)
                }
                return
            }
            url.appendPathComponent("Documents")
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
                }
                DispatchQueue.main.async {
                    complete?(url)
                }
            } catch let err {
                print(err)
                DispatchQueue.main.async {
                    complete?(nil)
                }
                return
            }
        }
    }

    private func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudAccountAvailabilityChanged), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
    }

    @objc func iCloudAccountAvailabilityChanged() {
        icloudAvailable = isICloudAvailable()
    }
}

extension iCloudManager {
    func addEnableMenuItem(_ menu: inout NSMenu) {
        let item = NSMenuItem(title: NSLocalizedString("Use iCloud", comment: ""), action: #selector(enableMenuItemTap(sender:)), keyEquivalent: "")
        menu.addItem(item)
        enableMenuItem = item
        updateMenuItemStatus()
    }

    @objc func enableMenuItemTap(sender: NSMenuItem) {
        userEnableiCloud = !userEnableiCloud
        updateMenuItemStatus()
        checkiCloud()
    }

    func updateMenuItemStatus() {
        enableMenuItem?.state = isICloudEnable() ? .on : .off
        enableMenuItem?.target = icloudAvailable ? self : nil
    }
}
