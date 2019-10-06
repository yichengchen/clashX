//
//  AppDelegate.swift
//  ClashX
//
//  Created by CYC on 2018/6/10.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import LetsMove
import Alamofire
import RxCocoa
import RxSwift

import Fabric
import Crashlytics

private let statusItemLengthWithSpeed:CGFloat = 70


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proxySettingMenuItem: NSMenuItem!
    @IBOutlet weak var autoStartMenuItem: NSMenuItem!
    
    @IBOutlet weak var proxyModeGlobalMenuItem: NSMenuItem!    
    @IBOutlet weak var proxyModeDirectMenuItem: NSMenuItem!
    @IBOutlet weak var proxyModeRuleMenuItem: NSMenuItem!
    @IBOutlet weak var allowFromLanMenuItem: NSMenuItem!
    
    @IBOutlet weak var proxyModeMenuItem: NSMenuItem!
    @IBOutlet weak var showNetSpeedIndicatorMenuItem: NSMenuItem!
    @IBOutlet weak var dashboardMenuItem: NSMenuItem!
    @IBOutlet weak var separatorLineTop: NSMenuItem!
    @IBOutlet weak var sepatatorLineEndProxySelect: NSMenuItem!
    @IBOutlet weak var switchConfigMenuItem: NSMenuItem!
    
    @IBOutlet weak var logLevelMenuItem: NSMenuItem!
    @IBOutlet weak var httpPortMenuItem: NSMenuItem!
    @IBOutlet weak var socksPortMenuItem: NSMenuItem!
    @IBOutlet weak var apiPortMenuItem: NSMenuItem!
    @IBOutlet weak var remoteConfigAutoupdateMenuItem: NSMenuItem!
    
    var disposeBag = DisposeBag()
    var statusItemView:StatusItemView!
    
    var isSpeedTesting = false

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
                
        // setup menu item first
        statusItem = NSStatusBar.system.statusItem(withLength:statusItemLengthWithSpeed)
        statusItem.menu = statusMenu
        
        statusItemView = StatusItemView.create(statusItem: statusItem)
        statusItemView.frame = CGRect(x: 0, y: 0, width: statusItemLengthWithSpeed, height: 22)
        statusMenu.delegate = self
        // crash recorder
        failLaunchProtect()
        registCrashLogger()
        
        // install proxy helper
        _ = ClashResourceManager.check()
        SystemProxyManager.shared.checkInstall()
        ConfigFileManager.copySampleConfigIfNeed()
        
        PFMoveToApplicationsFolderIfNecessary()
        
        // set system hosts override policy
        if UserDefaults.standard.bool(forKey: "kEnableSystemHostsOverride") {
            clashSetSystemDnsEnable(true.goObject())
            ConfigFileManager.shared.watchHostsFile()
        }
        
        // start proxy
        setupData()
        updateConfig(showNotification: false)
        updateLoggingLevel()
        
        // start watch config file change
        ConfigFileManager.shared.watchConfigFile(configName: ConfigManager.selectConfigName)

        RemoteConfigManager.shared.autoUpdateCheck()
        
        NSAppleEventManager.shared()
            .setEventHandler(self,
                             andSelector: #selector(handleURL(event:reply:)),
                             forEventClass: AEEventClass(kInternetEventClass),
                             andEventID: AEEventID(kAEGetURL))
    }


    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.shared.proxyPortAutoSet {
            let port = ConfigManager.shared.currentConfig?.port ?? 0
            let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
            SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort)
        }
    }

    func setupData() {
        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off
        
        NotificationCenter.default.rx.notification(kShouldUpDateConfig).bind {
            [weak self] (note)  in
            guard let self = self else {return}
            let showNotice = note.userInfo?["notification"] as? Bool ?? true
            self.updateConfig(showNotification: showNotice)
        }.disposed(by: disposeBag)
        
        
        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind {[weak self] (show) in
                guard let self = self else {return}
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                let statusItemLength:CGFloat = (show ?? true) ? statusItemLengthWithSpeed : 25
                self.statusItem.length = statusItemLength
                self.statusItemView.frame.size.width = statusItemLength
                self.statusItemView.showSpeedContainer(show: (show ?? true))
                self.statusItemView.updateStatusItemView()
            }.disposed(by: disposeBag)
        
        ConfigManager.shared
            .proxyPortAutoSetObservable
            .distinctUntilChanged()
            .bind{ [weak self]
                en in
                guard let self = self else {return}
                let enable = en ?? false
                self.proxySettingMenuItem.state = enable ? .on : .off
            }.disposed(by: disposeBag)
        
        let configObservable = ConfigManager.shared
            .currentConfigVariable
            .asObservable()
        Observable.zip(configObservable,configObservable.skip(1))
            .filter{(_, new) in return new != nil}
            .bind {[weak self] (old,config) in
                guard let self = self,let config=config else {return}
                self.proxyModeDirectMenuItem.state = .off
                self.proxyModeGlobalMenuItem.state = .off
                self.proxyModeRuleMenuItem.state = .off
                
                switch config.mode {
                case .direct:self.proxyModeDirectMenuItem.state = .on
                case .global:self.proxyModeGlobalMenuItem.state = .on
                case .rule:self.proxyModeRuleMenuItem.state = .on
                }
                self.allowFromLanMenuItem.state = config.allowLan ? .on : .off
                
                self.proxyModeMenuItem.title = "\(NSLocalizedString("Proxy Mode", comment: "")) (\(config.mode.name))"
                
                self.updateProxyList()
                
                if (old?.port != config.port && ConfigManager.shared.proxyPortAutoSet) {
                    SystemProxyManager.shared.enableProxy(port: config.port, socksPort: config.socketPort)
                }
                
                self.httpPortMenuItem.title  = "Http Port:\(config.port)"
                self.socksPortMenuItem.title = "Socks Port:\(config.socketPort)"
                self.apiPortMenuItem.title = "Api Port:\(ConfigManager.shared.apiPort)"

        }.disposed(by: disposeBag)
        
        ConfigManager
            .shared
            .isRunningVariable
            .asObservable()
            .distinctUntilChanged()
            .bind { [weak self] _ in
                guard let self = self else {return}
                self.updateProxyList()
        }.disposed(by: disposeBag)
        
        LaunchAtLogin.shared
            .isEnableVirable
            .asObservable()
            .subscribe(onNext: { [weak self] enable in
                guard let self = self else {return}
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)
        
  
    }

    
    func updateProxyList() {
        if ConfigManager.shared.isRunning {
            updateProxyList(withMenus: MenuItemFactory.menuItems())
        } else {
            updateProxyList(withMenus: [])
        }
    }
    
    func updateProxyList(withMenus menus:[NSMenuItem]) {
        let startIndex = self.statusMenu.items.firstIndex(of: self.separatorLineTop)!+1
        let endIndex = self.statusMenu.items.firstIndex(of: self.sepatatorLineEndProxySelect)!
        var items = self.statusMenu.items
        
        self.sepatatorLineEndProxySelect.isHidden = menus.count == 0
        items.removeSubrange(Range(uncheckedBounds: (lower: startIndex, upper: endIndex)))
        
        for each in menus {
            items.insert(each, at: startIndex)
        }
        self.statusMenu.removeAllItems()
        for each in items.reversed() {
            self.statusMenu.insertItem(each, at: 0)
        }
    }
    
    func updateConfigFiles() {
        switchConfigMenuItem.submenu = MenuItemFactory.generateSwitchConfigSubMenu()
    }
    
    func updateLoggingLevel() {
        for item in self.logLevelMenuItem.submenu?.items ?? [] {
            item.state = item.title.lowercased() == ConfigManager.selectLoggingApiLevel.rawValue ? .on : .off
        }
    }
        
    func startProxy() {
        if (ConfigManager.shared.isRunning){return}
        
        struct StartProxyResp: Codable {
            let externalController: String
            let secret: String
        }
    
        // setup ui config first
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "dashboard") {
            let uiPath = URL(fileURLWithPath: htmlPath).deletingLastPathComponent().path
            setUIPath(uiPath.goStringBuffer())
        }
        
        Logger.log("Trying start proxy")
        let string = run(ConfigManager.developerMode.goObject())?.toString() ?? ""
        let jsonData = string.data(using: .utf8) ?? Data()
        if let res = try? JSONDecoder().decode(StartProxyResp.self, from:jsonData) {
            let port = res.externalController.components(separatedBy: ":").last ?? "9090"
            ConfigManager.shared.apiPort = port
            ConfigManager.shared.apiSecret = res.secret
            ConfigManager.shared.isRunning = true
            proxyModeMenuItem.isEnabled = true
            dashboardMenuItem.isEnabled = true
        } else {
            ConfigManager.shared.isRunning = false
            proxyModeMenuItem.isEnabled = false
            NSUserNotificationCenter.default.postConfigErrorNotice(msg:string)
        }
    }
    
    func syncConfig(completeHandler:(()->())? = nil){
        ApiRequest.requestConfig{ (config) in
            ConfigManager.shared.currentConfig = config
            completeHandler?()
        }
    }
    
    func resetStreamApi() {
        ApiRequest.shared.delegate = self
        ApiRequest.shared.resetStreamApis()
    }
    
    func updateConfig(showNotification: Bool = true) {
        startProxy()
        guard ConfigManager.shared.isRunning else {return}
        
        if let error = ApiRequest.requestConfigUpdate() {
            if showNotification {
                NSUserNotificationCenter.default
                    .post(title: NSLocalizedString("Reload Config Fail", comment: "")+error,
                          info: error)
            }
        } else {
            syncConfig()
            resetStreamApi()
            selectProxyGroupWithMemory()
            selectOutBoundModeWithMenory()
            selectAllowLanWithMenory()
            ConfigFileManager.checkFinalRuleAndShowAlert()
            if showNotification {
                NSUserNotificationCenter.default
                    .post(title: NSLocalizedString("Reload Config Succeed", comment: ""),
                          info: NSLocalizedString("Succees", comment: ""))
            }
        }
    }
    
}

// MARK: Main actions

extension AppDelegate {
    
    @IBAction func actionAllowFromLan(_ sender: NSMenuItem) {
        ApiRequest.updateAllowLan(allow: !ConfigManager.allowConnectFromLan) {
            [weak self] in
            guard let self = self else {return}
            self.syncConfig()
            ConfigManager.allowConnectFromLan = !ConfigManager.allowConnectFromLan
        }
        
    }
    
    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.shared.isEnabled = !LaunchAtLogin.shared.isEnabled
    }
    
    
    @IBAction func actionSwitchProxyMode(_ sender: NSMenuItem) {
        let mode:ClashProxyMode
        switch sender {
        case proxyModeGlobalMenuItem:
            mode = .global
        case proxyModeDirectMenuItem:
            mode = .direct
        case proxyModeRuleMenuItem:
            mode = .rule
        default:
            return
        }
        let config = ConfigManager.shared.currentConfig?.copy()
        config?.mode = mode
        ApiRequest.updateOutBoundMode(mode: mode) { (success) in
            ConfigManager.shared.currentConfig = config
            ConfigManager.selectOutBoundMode = mode
        }
    }
    
    
    @IBAction func actionShowNetSpeedIndicator(_ sender: NSMenuItem) {
        ConfigManager.shared.showNetSpeedIndicator = !(sender.state == .on)
    }
    
    @IBAction func actionSetSystemProxy(_ sender: Any) {
        ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        let port = ConfigManager.shared.currentConfig?.port ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
        
        if ConfigManager.shared.proxyPortAutoSet {
            SystemProxyManager.shared.saveProxy()
            SystemProxyManager.shared.enableProxy(port: port, socksPort: socketPort)
        } else {
            SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort)
        }
        
    }
    
    @IBAction func actionCopyExportCommand(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let port = ConfigManager.shared.currentConfig?.port ?? 0
        let socksport = ConfigManager.shared.currentConfig?.socketPort ?? 0
        pasteboard.setString("export https_proxy=http://127.0.0.1:\(port);export http_proxy=http://127.0.0.1:\(port);export all_proxy=socks5://127.0.0.1:\(socksport)", forType: .string)
    }
    
    @IBAction func actionSpeedTest(_ sender: Any) {
        if isSpeedTesting {
            NSUserNotificationCenter.default.postSpeedTestingNotice()
            return
        }
        NSUserNotificationCenter.default.postSpeedTestBeginNotice()

        isSpeedTesting = true
        ApiRequest.getAllProxyList { [weak self] proxies in
            let testGroup = DispatchGroup()
            
            for proxyName in proxies {
                testGroup.enter()
                ApiRequest.getProxyDelay(proxyName: proxyName) { delay in
                    testGroup.leave()
                }
            }
            testGroup.notify(queue: DispatchQueue.main, execute: {
                NSUserNotificationCenter.default.postSpeedTestFinishNotice()
                self?.isSpeedTesting = false
            })
        }

        
    }
    
    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
}

// MARK: Streaming Info
extension AppDelegate: ApiRequestStreamDelegate {
    func didUpdateTraffic(up: Int, down: Int) {
        DispatchQueue.main.async {
            self.statusItemView.updateSpeedLabel(up: up, down: down)
        }
    }
    
    func didGetLog(log: String, level: String) {
        Logger.log(log, level: ClashLogLevel(rawValue: level) ?? .unknow)
    }
}

// MARK: Help actions
extension AppDelegate {
    @IBAction func actionShowLog(_ sender: Any) {
        NSWorkspace.shared.openFile(Logger.shared.logFilePath())
    }

}

// MARK: Config actions

extension AppDelegate {
    
    @IBAction func openConfigFolder(_ sender: Any) {
        NSWorkspace.shared.openFile(kConfigFolderPath)
    }
    
    @IBAction func actionUpdateConfig(_ sender: AnyObject) {
        updateConfig()
    }
    
    @IBAction func actionSetLogLevel(_ sender: NSMenuItem) {
        let level = ClashLogLevel(rawValue: sender.title.lowercased()) ?? .unknow
        ConfigManager.selectLoggingApiLevel = level
        updateLoggingLevel()
        resetStreamApi()
    }
    

    @IBAction func actionAutoUpdateRemoteConfig(_ sender: Any) {
        RemoteConfigManager.autoUpdateEnable = !RemoteConfigManager.autoUpdateEnable
        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off
    }
    
    
    @IBAction func actionUpdateRemoteConfig(_ sender: Any) {
        RemoteConfigManager.shared.updateCheck(ignoreTimeLimit: true, showNotification: true)
    }
}

// MARK: crash hanlder
extension AppDelegate {
    func registCrashLogger() {
        Fabric.with([Crashlytics.self])
    }
    
    func failLaunchProtect(){
        let x = UserDefaults.standard
        var launch_fail_times:Int = 0
        if let xx = x.object(forKey: "launch_fail_times") as? Int {launch_fail_times = xx }
        launch_fail_times += 1
        x.set(launch_fail_times, forKey: "launch_fail_times")
        if launch_fail_times > 3 {
            //发生连续崩溃
            ConfigFileManager.backupAndRemoveConfigFile()
            try? FileManager.default.removeItem(atPath: kConfigFolderPath + "Country.mmdb")
            NSUserNotificationCenter.default.post(title: "Fail on launch protect", info: "You origin Config has been renamed")
        }
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            x.set(0, forKey: "launch_fail_times")
        });
    }
    
}

// MARK: Memory
extension AppDelegate {
    
    func selectProxyGroupWithMemory(){
        for item in ConfigManager.selectedProxyMap {
            ApiRequest.updateProxyGroup(group: item.key, selectProxy: item.value) { (success) in
                if (!success) {
                    ConfigManager.selectedProxyMap[item.key] = nil
                }
            }
        }
    }
    
    func selectOutBoundModeWithMenory() {
        ApiRequest.updateOutBoundMode(mode: ConfigManager.selectOutBoundMode){
            [weak self] _ in
            self?.syncConfig()
        }
    }
    
    func selectAllowLanWithMenory() {
        ApiRequest.updateAllowLan(allow: ConfigManager.allowConnectFromLan){
            [weak self] in
            self?.syncConfig()
        }
    }
}

// MARK: NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        syncConfig()
        updateConfigFiles()
    }
}

// MARK: URL Scheme
extension AppDelegate {
    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }
        
        guard let components = URLComponents(string: url),
            let scheme = components.scheme,
            scheme.hasPrefix("clash"),
            let host = components.host
            else {return}
        
        if host == "install-config" {
            guard let url = components.queryItems?.first(where: { item in
                item.name == "url"
            })?.value else {return}
            
            var userInfo = ["url":url]
            if let name = components.queryItems?.first(where: { item in
                item.name == "name"
            })?.value {
                userInfo["name"] = name
            }
            
            remoteConfigAutoupdateMenuItem.menu?.performActionForItem(at: 0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "didGetUrl"), object: nil, userInfo: userInfo)
            }
        }
    }
}

