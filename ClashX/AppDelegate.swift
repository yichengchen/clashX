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
        statusItem = NSStatusBar.system.statusItem(withLength:65)
        statusItem.menu = statusMenu
        
        statusItemView = StatusItemView.create(statusItem: statusItem)
        statusItemView.frame = CGRect(x: 0, y: 0, width: 65, height: 22)
        statusMenu.delegate = self
        
        // crash recorder
        failLaunchProtect()
        registCrashLogger()
        
        // install proxy helper
        _ = ProxyConfigHelperManager.install()
        ConfigFileManager.copySampleConfigIfNeed()
        ConfigManager.shared.refreshApiInfo()
        
        PFMoveToApplicationsFolderIfNecessary()
        
        // start proxy
        setupData()
        actionUpdateConfig(self)
        updateLoggingLevel()
        hideFunctionIfNeed()
        
        // check config vaild via api
        ConfigFileManager.checkFinalRuleAndShowAlert()
        
        RemoteConfigManager.updateCheckAtLaunch()
        
    }



    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.shared.proxyPortAutoSet {
            _ = ProxyConfigHelperManager.setUpSystemProxy(port: nil,socksPort: nil)
        }
    }

    func setupData() {
        
        // check and refresh api url
        _ = ConfigManager.apiUrl
        
        // start watch config file change
        ConfigFileManager.shared.watchConfigFile(configName: ConfigManager.selectConfigName)
        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off
        
        NotificationCenter.default.rx.notification(kShouldUpDateConfig).bind {
            [weak self] (note)  in
            guard let self = self else {return}
            self.actionUpdateConfig(nil)
        }.disposed(by: disposeBag)
        
        
        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind {[weak self] (show) in
                guard let self = self else {return}
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                let statusItemLength:CGFloat = (show ?? true) ? 65 : 25
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
                self.proxyModeMenuItem.title = "\("Proxy Mode".localized()) (\(config.mode.rawValue.localized()))"
                
                self.updateProxyList()
                
                if (old?.port != config.port && ConfigManager.shared.proxyPortAutoSet) {
                    _ = ProxyConfigHelperManager.setUpSystemProxy(port: config.port,socksPort: config.socketPort)
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
    
    func hideFunctionIfNeed() {
        if #available(OSX 10.11, *) {
            // pass
        } else {
            dashboardMenuItem.isHidden = true
        }
    }


    
    func updateProxyList() {
        if ConfigManager.shared.isRunning {
            MenuItemFactory.menuItems {
                [weak self] menus in
                self?.updateProxyList(withMenus: menus)
            }
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
    
        // setup ui config first
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "dashboard") {
            let uiPath = URL(fileURLWithPath: htmlPath).deletingLastPathComponent().path
            let path = String(uiPath)
            let length = path.count + 1
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: length)
            (path as NSString).getCString(buffer, maxLength: length, encoding: String.Encoding.utf8.rawValue)
            setUIPath(buffer)
        }
        
        print("Trying start proxy")
        if let cstring = run() {
            let error = String(cString: cstring)
            if (error != "success") {
                ConfigManager.shared.isRunning = false
                NSUserNotificationCenter.default.postConfigErrorNotice(msg:error)
            } else {
                ConfigManager.shared.isRunning = true
                self.resetStreamApi()
                self.dashboardMenuItem.isEnabled = true
            }
        }
    }
    
    func syncConfig(completeHandler:(()->())? = nil){
        ApiRequest.requestConfig{ (config) in
            guard config.port > 0 else {return}
            ConfigManager.shared.currentConfig = config
            completeHandler?()
        }
    }
    
    func resetStreamApi() {
        ApiRequest.shared.requestTrafficInfo(){ [weak self] up,down in
            guard let `self` = self else {return}
            DispatchQueue.main.async {
                self.statusItemView.updateSpeedLabel(up: up, down: down)
            }
        }
        
        ApiRequest.shared.requestLog { (type, msg) in
            Logger.log(msg: msg,level: ClashLogLevel(rawValue: type) ?? .unknow)
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
        if ConfigManager.shared.proxyPortAutoSet {
            let port = ConfigManager.shared.currentConfig?.port ?? 0
            let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
            _ = ProxyConfigHelperManager.setUpSystemProxy(port: port,socksPort:socketPort)
        } else {
            _ = ProxyConfigHelperManager.setUpSystemProxy(port: nil,socksPort: nil)
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
    
    @IBAction func actionUpdateConfig(_ sender: Any?) {
        startProxy()
        guard ConfigManager.shared.isRunning else {return}
        let notifaction = self != (sender as? NSObject)
        ApiRequest.requestConfigUpdate() { [weak self] error in
            guard let self = self else {return}
            if (error == nil) {
                self.syncConfig()
                self.resetStreamApi()
                self.selectProxyGroupWithMemory()
                self.selectOutBoundModeWithMenory()
                self.selectAllowLanWithMenory()
                ConfigFileManager.checkFinalRuleAndShowAlert()
                if notifaction{
                    NSUserNotificationCenter
                        .default
                        .post(title: "Reload Config Succeed", info: "Succees")
                }
            } else {
                if (notifaction) {
                    NSUserNotificationCenter
                        .default
                        .post(title: "Reload Config Fail", info: error ?? "")
                }
            }
            
        }
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
    
    @IBAction func actionSetRemoteConfigUrl(_ sender: Any) {
        RemoteConfigManager.showUrlInputAlert()
    }
    
    
    @IBAction func actionUpdateRemoteConfig(_ sender: Any) {
        RemoteConfigManager.updateConfigIfNeed()
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
extension AppDelegate:NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        syncConfig()
        updateConfigFiles()
    }

}

