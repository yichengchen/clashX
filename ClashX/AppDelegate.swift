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
    
    @IBOutlet weak var logLevelMenuItem: NSMenuItem!
    @IBOutlet weak var httpPortMenuItem: NSMenuItem!
    @IBOutlet weak var socksPortMenuItem: NSMenuItem!
    @IBOutlet weak var apiPortMenuItem: NSMenuItem!
    
    var disposeBag = DisposeBag()
    let ssQueue = DispatchQueue(label: "com.w2fzu.ssqueue", attributes: .concurrent)
    var statusItemView:StatusItemView!
    
    var isRunning = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        failLaunchProtect()
        _ = ProxyConfigManager.install()
        PFMoveToApplicationsFolderIfNecessary()
        statusItemView = StatusItemView.create(statusItem: nil,statusMenu: statusMenu)
        statusItemView.onPopUpMenuAction = {
            [weak self] in
            guard let `self` = self else {return}
            self.syncConfig()
        }
        setupData()
        setupDashboard()
        startProxy()
        updateLoggingLevel()
    }
    

    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.shared.proxyPortAutoSet {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
        }
    }

    func setupData() {
        
        // check and refresh api url
        _ = ConfigManager.apiUrl
        // start watch config file change
        ConfigFileFactory.shared.watchConfigFile()
        
        NotificationCenter.default.rx.notification(kShouldUpDateConfig).bind {
            [unowned self] (note)  in
            self.actionUpdateConfig(self)
        }.disposed(by: disposeBag)
        
        
        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind {[unowned self] (show) in
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                self.statusItem = NSStatusBar.system.statusItem(withLength: (show ?? true) ? 65 : 25)
                self.statusItem.view = self.statusItemView
                self.statusItemView.showSpeedContainer(show: (show ?? true))
                self.statusItemView.statusItem = self.statusItem
            }.disposed(by: disposeBag)
        
        ConfigManager.shared
            .proxyPortAutoSetObservable
            .distinctUntilChanged()
            .bind{ [unowned self]
                en in
                let enable = en ?? false
                self.proxySettingMenuItem.state = enable ? .on : .off
            }.disposed(by: disposeBag)
        
        let configObservable = ConfigManager.shared
            .currentConfigVariable
            .asObservable()
        Observable.zip(configObservable,configObservable.skip(1))
            .filter{(_, new) in return new != nil}
            .bind {[unowned self] (old,config) in
                self.proxyModeDirectMenuItem.state = .off
                self.proxyModeGlobalMenuItem.state = .off
                self.proxyModeRuleMenuItem.state = .off
                
                switch config!.mode {
                case .direct:self.proxyModeDirectMenuItem.state = .on
                case .global:self.proxyModeGlobalMenuItem.state = .on
                case .rule:self.proxyModeRuleMenuItem.state = .on
                }
                self.allowFromLanMenuItem.state = config!.allowLan ? .on : .off
                self.proxyModeMenuItem.title = "Proxy Mode (\(config!.mode.rawValue))"
                
                self.updateProxyList()
                
                if (old?.port != config?.port && ConfigManager.shared.proxyPortAutoSet) {
                    _ = ProxyConfigManager.setUpSystemProxy(port: config!.port,socksPort: config!.socketPort)
                }
                
                self.httpPortMenuItem.title  = "Http Port:\(config?.port ?? 0)"
                self.socksPortMenuItem.title = "Socks Port:\(config?.socketPort ?? 0)"
                self.apiPortMenuItem.title = "Api Port:\(ConfigManager.shared.apiPort)"

        }.disposed(by: disposeBag)
        
        LaunchAtLogin.shared
            .isEnableVirable
            .asObservable()
            .subscribe(onNext: { (enable) in
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)
        
  
    }
    
    func setupDashboard() {
        if (!ClashWebViewContoller.enableDashBoard()) {
            statusMenu.removeItem(dashboardMenuItem)
        }
    }
    
    func failLaunchProtect(){
        let x = UserDefaults.standard
        var launch_fail_times:Int = 0
        if let xx = x.object(forKey: "launch_fail_times") as? Int {launch_fail_times = xx }
        launch_fail_times += 1
        x.set(launch_fail_times, forKey: "launch_fail_times")
        if launch_fail_times > 2 {
            //发生连续崩溃
            ConfigFileFactory.backupAndRemoveConfigFile()
            try? FileManager.default.removeItem(atPath: kConfigFolderPath + "Country.mmdb")
            NSUserNotificationCenter.default.post(title: "Fail on launch protect", info: "You origin Config has been rename to config.ini.bak")
        }
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            x.set(0, forKey: "launch_fail_times")
        });
    }
    
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
            _ in
            self.syncConfig()
        }
    }
    
    func selectAllowLanWithMenory() {
        ApiRequest.updateAllowLan(allow: ConfigManager.allowConnectFromLan){
            self.syncConfig()
        }
    }
    
    func updateProxyList() {
        ProxyMenuItemFactory.menuItems { [unowned self] (menus) in
            let startIndex = self.statusMenu.items.index(of: self.separatorLineTop)!+1
            let endIndex = self.statusMenu.items.index(of: self.sepatatorLineEndProxySelect)!
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
    }
    
    func updateLoggingLevel() {
        for item in self.logLevelMenuItem.submenu?.items ?? [] {
            item.state = item.title.lowercased() == ConfigManager.selectLoggingApiLevel.rawValue ? .on : .off
        }
    }
    
    
    func startProxy() {
        if self.isRunning {return}
        
        self.isRunning = true
        print("Trying start proxy")
        if let cstring = run() {
//            self.isRunning = false
            let error = String(cString: cstring)
            if (error != "success") {
                NSUserNotificationCenter.default.postConfigErrorNotice(msg:error)
            } else {
                self.resetStreamApi()
                self.selectOutBoundModeWithMenory()
                self.selectAllowLanWithMenory()
                self.selectProxyGroupWithMemory()
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
            ((self.statusItem.view) as! StatusItemView).updateSpeedLabel(up: up, down: down)
        }
        
        ApiRequest.shared.requestLog { (type, msg) in
            Logger.log(msg: msg,level: ClashLogLevel(rawValue: type) ?? .unknow)
        }
    }

    
//Actions:
    
    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
        
    @IBAction func actionSetSystemProxy(_ sender: Any) {
        ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        if ConfigManager.shared.proxyPortAutoSet {
            let port = ConfigManager.shared.currentConfig?.port ?? 0
            let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
            _ = ProxyConfigManager.setUpSystemProxy(port: port,socksPort:socketPort)
        } else {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
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
        
    
    }
    
    
    @IBAction func actionAllowFromLan(_ sender: NSMenuItem) {
        ApiRequest.updateAllowLan(allow: !ConfigManager.allowConnectFromLan) {
            [unowned self] in
            self.syncConfig()
            ConfigManager.allowConnectFromLan = !ConfigManager.allowConnectFromLan
        }
        
    }
    
    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.shared.isEnabled = !LaunchAtLogin.shared.isEnabled
    }
    
    var genConfigWindow:NSWindowController?=nil
    @IBAction func actionGenConfig(_ sender: Any) {
        let ctrl = PreferencesWindowController(windowNibName: "PreferencesWindowController")
        
        
        genConfigWindow?.close()
        genConfigWindow=ctrl
        ctrl.window?.title = ctrl.contentViewController?.title ?? ""
        ctrl.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)

    }
    
    @IBAction func openConfigFolder(_ sender: Any) {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash")
        NSWorkspace.shared.openFile(path)
    }
    
    @IBAction func actionUpdateConfig(_ sender: Any) {
        ApiRequest.requestConfigUpdate() { [unowned self] error in
            if (error == nil) {
                self.syncConfig()
                self.resetStreamApi()
                self.selectProxyGroupWithMemory()
                self.selectOutBoundModeWithMenory()
                NSUserNotificationCenter
                    .default
                    .post(title: "Reload Config Succeed", info: "succees")
            } else {
                NSUserNotificationCenter
                    .default
                    .post(title: "Reload Config Fail", info: error ?? "")
            }
            
        }
    }
    
    @IBAction func actionSetLogLevel(_ sender: NSMenuItem) {
        let level = ClashLogLevel(rawValue: sender.title.lowercased()) ?? .unknow
        ConfigManager.selectLoggingApiLevel = level
        updateLoggingLevel()
        resetStreamApi()
    }
    
    @IBAction func actionImportBunchJsonFile(_ sender: NSMenuItem) {
        ConfigFileFactory.importConfigFile()
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
    
    @IBAction func actionImportConfigFromSSURL(_ sender: NSMenuItem) {
        let pasteBoard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string)
        if let proxyModel = ProxyServerModel(urlStr: pasteBoard ?? "") {
            ConfigFileFactory.addProxyToConfig(proxy: proxyModel)
        } else {
            NSUserNotificationCenter.default.postImportConfigFromUrlFailNotice(urlStr: pasteBoard ?? "empty")
        }
    }
    
    @IBAction func actionScanQRCode(_ sender: NSMenuItem) {
        if let urls = QRCodeUtil.ScanQRCodeOnScreen() {
            for url in urls {
                if let proxyModel = ProxyServerModel(urlStr: url) {
                    ConfigFileFactory.addProxyToConfig(proxy: proxyModel)
                } else {
                    NSUserNotificationCenter
                        .default
                        .postImportConfigFromUrlFailNotice(urlStr: url)
                }
            }
        }else {
            NSUserNotificationCenter.default.postQRCodeNotFoundNotice()
        }
    }
    
    @IBAction func actionShowNetSpeedIndicator(_ sender: NSMenuItem) {
        ConfigManager.shared.showNetSpeedIndicator = !ConfigManager.shared.showNetSpeedIndicator
    }
    
    @IBAction func actionShowLog(_ sender: Any) {
        NSWorkspace.shared.openFile(Logger.shared.logFilePath())

    }
   
}


