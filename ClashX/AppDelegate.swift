//
//  AppDelegate.swift
//  ClashX
//
//  Created by CYC on 2018/6/10.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Alamofire
import Cocoa
import LetsMove
import RxCocoa
import RxSwift

import AppCenter
import AppCenterAnalytics
import Firebase


private let statusItemLengthWithSpeed: CGFloat = 70

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var proxySettingMenuItem: NSMenuItem!
    @IBOutlet var autoStartMenuItem: NSMenuItem!

    @IBOutlet var proxyModeGlobalMenuItem: NSMenuItem!
    @IBOutlet var proxyModeDirectMenuItem: NSMenuItem!
    @IBOutlet var proxyModeRuleMenuItem: NSMenuItem!
    @IBOutlet var allowFromLanMenuItem: NSMenuItem!

    @IBOutlet var proxyModeMenuItem: NSMenuItem!
    @IBOutlet var showNetSpeedIndicatorMenuItem: NSMenuItem!
    @IBOutlet var dashboardMenuItem: NSMenuItem!
    @IBOutlet var separatorLineTop: NSMenuItem!
    @IBOutlet var sepatatorLineEndProxySelect: NSMenuItem!
    @IBOutlet var configSeparatorLine: NSMenuItem!
    @IBOutlet var logLevelMenuItem: NSMenuItem!
    @IBOutlet var httpPortMenuItem: NSMenuItem!
    @IBOutlet var socksPortMenuItem: NSMenuItem!
    @IBOutlet var apiPortMenuItem: NSMenuItem!
    @IBOutlet var ipMenuItem: NSMenuItem!
    @IBOutlet var remoteConfigAutoupdateMenuItem: NSMenuItem!
    @IBOutlet var buildApiModeMenuitem: NSMenuItem!
    @IBOutlet var showProxyGroupCurrentMenuItem: NSMenuItem!
    @IBOutlet var copyExportCommandMenuItem: NSMenuItem!
    @IBOutlet var copyExportCommandExternalMenuItem: NSMenuItem!
    @IBOutlet var experimentalMenu: NSMenu!
    @IBOutlet var externalControlSeparator: NSMenuItem!

    var disposeBag = DisposeBag()
    var statusItemView: StatusItemView!
    var isSpeedTesting = false

    var runAfterConfigReload: (() -> Void)?

    var dashboardWindowController: ClashWebViewWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        // crash recorder
        failLaunchProtect()
        registCrashLogger()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // setup menu item first
        statusItem = NSStatusBar.system.statusItem(withLength: statusItemLengthWithSpeed)

        statusItemView = StatusItemView.create(statusItem: statusItem)
        statusItemView.frame = CGRect(x: 0, y: 0, width: statusItemLengthWithSpeed, height: 22)
        statusMenu.delegate = self
        setupStatusMenuItemData()
        AppVersionUtil.showUpgradeAlert()
        DispatchQueue.main.async {
            self.postFinishLaunching()
        }
    }

    func postFinishLaunching() {
        defer {
            statusItem.menu = statusMenu
        }
        iCloudManager.shared.setup()
        setupExperimentalMenuItem()

        // install proxy helper
        _ = ClashResourceManager.check()
        PrivilegedHelperManager.shared.checkInstall()
        ConfigFileManager.copySampleConfigIfNeed()

        PFMoveToApplicationsFolderIfNecessary()

        // claer not existed selected model
        removeUnExistProxyGroups()

        // start proxy
        initClashCore()
        setupData()
        runAfterConfigReload = { [weak self] in
            if !ConfigManager.builtInApiMode {
                self?.selectAllowLanWithMenory()
            }
        }
        updateConfig(showNotification: false)
        updateLoggingLevel()

        // start watch config file change
        ConfigManager.watchCurrentConfigFile()

        RemoteConfigManager.shared.autoUpdateCheck()

        NSAppleEventManager.shared()
            .setEventHandler(self,
                             andSelector: #selector(handleURL(event:reply:)),
                             forEventClass: AEEventClass(kInternetEventClass),
                             andEventID: AEEventID(kAEGetURL))
        setupNetworkNotifier()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let group = DispatchGroup()
        var shouldWait = false

        if ConfigManager.shared.proxyPortAutoSet && !ConfigManager.shared.isProxySetByOtherVariable.value || NetworkChangeNotifier.isCurrentSystemSetToClash(looser: true) ||
            NetworkChangeNotifier.hasInterfaceProxySetToClash() {
            Logger.log("ClashX quit need clean proxy setting")
            shouldWait = true
            group.enter()
            SystemProxyManager.shared.disableProxy {
                group.leave()
            }
        }

        if !shouldWait {
            Logger.log("ClashX quit without clean waiting")
            return .terminateNow
        }

        if statusItem != nil, statusItem.menu != nil {
            statusItem.menu = nil
        }
        disposeBag = DisposeBag()

        DispatchQueue.global(qos: .default).async {
            let res = group.wait(timeout: .now() + 5)
            switch res {
            case .success:
                Logger.log("ClashX quit after clean up finish")
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
                DispatchQueue.global().asyncAfter(deadline: .now()+1) {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            case .timedOut:
                Logger.log("ClashX quit after clean up timeout")
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
                DispatchQueue.global().asyncAfter(deadline: .now()+1) {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
        }

        Logger.log("ClashX quit wait for clean up")
        return .terminateLater
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        UserDefaults.standard.set(0, forKey: "launch_fail_times")
        Logger.log("ClashX will terminate")
        if NetworkChangeNotifier.isCurrentSystemSetToClash(looser: true) ||
            NetworkChangeNotifier.hasInterfaceProxySetToClash() {
            Logger.log("Need Reset Proxy Setting again",level: .error)
            SystemProxyManager.shared.disableProxy()
        }
    }

    func setupStatusMenuItemData() {
        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind { [weak self] show in
                guard let self = self else { return }
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                let statusItemLength: CGFloat = (show ?? true) ? statusItemLengthWithSpeed : 25
                self.statusItem.length = statusItemLength
                self.statusItemView.frame.size.width = statusItemLength
                self.statusItemView.showSpeedContainer(show: show ?? true)
            }.disposed(by: disposeBag)

        statusItemView.updateViewStatus(enableProxy: ConfigManager.shared.proxyPortAutoSet)

        LaunchAtLogin.shared
            .isEnableVirable
            .asObservable()
            .subscribe(onNext: { [weak self] enable in
                guard let self = self else { return }
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)

        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off
    }

    func setupData() {
        ConfigManager.shared
            .showNetSpeedIndicatorObservable.skip(1)
            .bind {
                _ in
                ApiRequest.shared.resetTrafficStreamApi()
            }.disposed(by: disposeBag)

        Observable
            .merge([ConfigManager.shared.proxyPortAutoSetObservable,
                    ConfigManager.shared.isProxySetByOtherVariable.asObservable()])
            .map { _ -> NSControl.StateValue in
                if ConfigManager.shared.isProxySetByOtherVariable.value && ConfigManager.shared.proxyPortAutoSet {
                    return .mixed
                }
                return ConfigManager.shared.proxyPortAutoSet ? .on : .off
            }.distinctUntilChanged()
            .bind { [weak self] status in
                guard let self = self else { return }
                self.proxySettingMenuItem.state = status
                self.statusItemView.updateViewStatus(enableProxy: status == .on)
            }.disposed(by: disposeBag)

        let configObservable = ConfigManager.shared
            .currentConfigVariable
            .asObservable()
        Observable.zip(configObservable, configObservable.skip(1))
            .filter { _, new in return new != nil }
            .bind { [weak self] old, config in
                guard let self = self, let config = config else { return }
                self.proxyModeDirectMenuItem.state = .off
                self.proxyModeGlobalMenuItem.state = .off
                self.proxyModeRuleMenuItem.state = .off

                switch config.mode {
                case .direct: self.proxyModeDirectMenuItem.state = .on
                case .global: self.proxyModeGlobalMenuItem.state = .on
                case .rule: self.proxyModeRuleMenuItem.state = .on
                }
                self.allowFromLanMenuItem.state = config.allowLan ? .on : .off

                self.proxyModeMenuItem.title = "\(NSLocalizedString("Proxy Mode", comment: "")) (\(config.mode.name))"

                if old?.usedHttpPort != config.usedHttpPort || old?.usedSocksPort != config.usedSocksPort {
                    Logger.log("port config updated,new: \(config.usedHttpPort),\(config.usedSocksPort)")
                    if ConfigManager.shared.proxyPortAutoSet {
                        SystemProxyManager.shared.enableProxy(port: config.usedHttpPort, socksPort: config.usedSocksPort)
                    }
                }

                self.httpPortMenuItem.title = "Http Port: \(config.usedHttpPort)"
                self.socksPortMenuItem.title = "Socks Port: \(config.usedSocksPort)"
                self.apiPortMenuItem.title = "Api Port: \(ConfigManager.shared.apiPort)"
                self.ipMenuItem.title = "IP: \(NetworkChangeNotifier.getPrimaryIPAddress() ?? "")"

                if RemoteControlManager.selectConfig == nil {
                    ClashStatusTool.checkPortConfig(cfg: config)
                }

            }.disposed(by: disposeBag)
        
        if !PrivilegedHelperManager.shared.isHelperCheckFinished.value &&
            ConfigManager.shared.proxyPortAutoSet {
            PrivilegedHelperManager.shared.isHelperCheckFinished
                .filter({$0})
                .take(1)
                .takeWhile{_ in ConfigManager.shared.proxyPortAutoSet}
                .observeOn(MainScheduler.instance)
                .subscribe { _ in
                    SystemProxyManager.shared.enableProxy()
                }.disposed(by: disposeBag)
        }
        
        if !PrivilegedHelperManager.shared.isHelperCheckFinished.value {
            proxySettingMenuItem.target = nil
            PrivilegedHelperManager.shared.isHelperCheckFinished
                .filter({$0})
                .take(1)
                .observeOn(MainScheduler.instance)
                .subscribe { [weak self] _ in
                    guard let self = self else { return }
                    self.proxySettingMenuItem.target = self
                }.disposed(by: disposeBag)
        }
    }

    func setupNetworkNotifier() {
        NetworkChangeNotifier.start()

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusDidChange)
            .observeOn(MainScheduler.instance)
            .delay(.milliseconds(200), scheduler: MainScheduler.instance)
            .bind { _ in
                guard NetworkChangeNotifier.getPrimaryInterface() != nil else { return }
                let proxySetted = NetworkChangeNotifier.isCurrentSystemSetToClash()
                ConfigManager.shared.isProxySetByOtherVariable.accept(!proxySetted)
                if !proxySetted && ConfigManager.shared.proxyPortAutoSet {
                    let proxiesSetting = NetworkChangeNotifier.getRawProxySetting()
                    Logger.log("Proxy changed by other process!, current:\(proxiesSetting), is Interface Set: \(NetworkChangeNotifier.hasInterfaceProxySetToClash())", level: .warning)
                }
            }.disposed(by: disposeBag)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(resetProxySettingOnWakeupFromSleep),
            name: NSWorkspace.didWakeNotification, object: nil
        )

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusIPUpdate).map({ _ in
                NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false)
            })
            .startWith(NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false))
            .distinctUntilChanged()
            .skip(1)
            .filter { $0 != nil }
            .observeOn(MainScheduler.instance)
            .debounce(.seconds(5), scheduler: MainScheduler.instance).bind { [weak self] _ in
                self?.healthHeckOnNetworkChange()
            }.disposed(by: disposeBag)

        ConfigManager.shared
            .isProxySetByOtherVariable
            .asObservable()
            .filter { _ in ConfigManager.shared.proxyPortAutoSet }
            .distinctUntilChanged()
            .filter { $0 }.bind { _ in
                let rawProxy = NetworkChangeNotifier.getRawProxySetting()
                Logger.log("proxy changed to no clashX setting: \(rawProxy)", level: .warning)
                NSUserNotificationCenter.default.postProxyChangeByOtherAppNotice()
            }.disposed(by: disposeBag)

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusIPUpdate).map({ _ in
                NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false)
            }).bind { [weak self] _ in
                if RemoteControlManager.selectConfig != nil {
                    self?.resetStreamApi()
                }
            }.disposed(by: disposeBag)
    }

    func updateProxyList(withMenus menus: [NSMenuItem]) {
        let startIndex = statusMenu.items.firstIndex(of: separatorLineTop)! + 1
        let endIndex = statusMenu.items.firstIndex(of: sepatatorLineEndProxySelect)!
        sepatatorLineEndProxySelect.isHidden = menus.count == 0
        for _ in 0..<endIndex - startIndex {
            statusMenu.removeItem(at: startIndex)
        }
        for each in menus {
            statusMenu.insertItem(each, at: startIndex)
        }
    }

    func updateConfigFiles() {
        guard let menu = configSeparatorLine.menu else { return }
        MenuItemFactory.generateSwitchConfigMenuItems {
            items in
            let lineIndex = menu.items.firstIndex(of: self.configSeparatorLine)!
            for _ in 0..<lineIndex {
                menu.removeItem(at: 0)
            }
            for item in items.reversed() {
                menu.insertItem(item, at: 0)
            }
        }
    }

    func updateLoggingLevel() {
        ApiRequest.updateLogLevel(level: ConfigManager.selectLoggingApiLevel)
        for item in logLevelMenuItem.submenu?.items ?? [] {
            item.state = item.title.lowercased() == ConfigManager.selectLoggingApiLevel.rawValue ? .on : .off
        }
        NotificationCenter.default.post(name: .reloadDashboard, object: nil)
    }

    func startProxy() {
        if ConfigManager.shared.isRunning { return }

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
        let string = run(ConfigManager.builtInApiMode.goObject(), ConfigManager.allowConnectFromLan.goObject())?.toString() ?? ""
        let jsonData = string.data(using: .utf8) ?? Data()
        if let res = try? JSONDecoder().decode(StartProxyResp.self, from: jsonData) {
            let port = res.externalController.components(separatedBy: ":").last ?? "9090"
            ConfigManager.shared.apiPort = port
            ConfigManager.shared.apiSecret = res.secret
            ConfigManager.shared.isRunning = true
            proxyModeMenuItem.isEnabled = true
            dashboardMenuItem.isEnabled = true
        } else {
            ConfigManager.shared.isRunning = false
            proxyModeMenuItem.isEnabled = false
            NSUserNotificationCenter.default.postConfigErrorNotice(msg: string)
        }
    }

    func syncConfig(completeHandler: (() -> Void)? = nil) {
        ApiRequest.requestConfig { config in
            ConfigManager.shared.currentConfig = config
            completeHandler?()
        }
    }

    func resetStreamApi() {
        ApiRequest.shared.delegate = self
        ApiRequest.shared.resetStreamApis()
    }

    func updateConfig(configName: String? = nil, showNotification: Bool = true, completeHandler: ((ErrorString?) -> Void)? = nil) {
        startProxy()
        guard ConfigManager.shared.isRunning else { return }

        let config = configName ?? ConfigManager.selectConfigName

        ClashProxy.cleanCache()

        ApiRequest.requestConfigUpdate(configName: config) {
            [weak self] err in
            guard let self = self else { return }

            defer {
                completeHandler?(err)
            }

            if let error = err {
                NSUserNotificationCenter.default
                    .post(title: NSLocalizedString("Reload Config Fail", comment: ""),
                          info: error)
            } else {
                self.syncConfig()
                self.resetStreamApi()
                self.runAfterConfigReload?()
                self.runAfterConfigReload = nil
                if showNotification {
                    NSUserNotificationCenter.default
                        .post(title: NSLocalizedString("Reload Config Succeed", comment: ""),
                              info: NSLocalizedString("Success", comment: ""))
                }

                if let newConfigName = configName {
                    ConfigManager.selectConfigName = newConfigName
                }
                self.selectProxyGroupWithMemory()
                self.selectOutBoundModeWithMenory()
                MenuItemFactory.recreateProxyMenuItems()
                NotificationCenter.default.post(name: .reloadDashboard, object: nil)
            }
        }
    }

    func setupExperimentalMenuItem() {
        ConnectionManager.addCloseOptionMenuItem(&experimentalMenu)
        ClashResourceManager.addUpdateMMDBMenuItem(&experimentalMenu)
        SystemProxyManager.shared.addDisableRestoreProxyMenuItem(&experimentalMenu)
        MenuItemFactory.addExperimentalMenuItem(&experimentalMenu)
        if WebPortalManager.hasWebProtal {
            WebPortalManager.shared.addWebProtalMenuItem(&statusMenu)
        }
        iCloudManager.shared.addEnableMenuItem(&experimentalMenu)
        AutoUpgardeManager.shared.setup()
        AutoUpgardeManager.shared.addChanelMenuItem(&experimentalMenu)
        updateExperimentalFeatureStatus()
        RemoteControlManager.setupMenuItem(separator: externalControlSeparator)
    }

    func updateExperimentalFeatureStatus() {
        buildApiModeMenuitem.state = ConfigManager.builtInApiMode ? .on : .off
        showProxyGroupCurrentMenuItem.state = ConfigManager.shared.disableShowCurrentProxyInMenu ? .off : .on
    }

    @objc func resetProxySettingOnWakeupFromSleep() {
        guard !ConfigManager.shared.isProxySetByOtherVariable.value,
            ConfigManager.shared.proxyPortAutoSet else { return }
        guard NetworkChangeNotifier.getPrimaryInterface() != nil else { return }
        if !NetworkChangeNotifier.isCurrentSystemSetToClash() {
            let rawProxy = NetworkChangeNotifier.getRawProxySetting()
            Logger.log("Resting proxy setting, current:\(rawProxy)", level: .warning)
            SystemProxyManager.shared.disableProxy()
            SystemProxyManager.shared.enableProxy()
        }

        if RemoteControlManager.selectConfig != nil {
            resetStreamApi()
        }
    }

    @objc func healthHeckOnNetworkChange() {
        ApiRequest.requestProxyGroupList {
            res in
            for group in res.proxyGroups {
                if group.type.isAutoGroup {
                    Logger.log("Start Auto Health check for \(group.name)")
                    ApiRequest.healthCheck(proxy: group.name)
                }
            }
        }
    }
}

// MARK: Main actions

extension AppDelegate {
    @IBAction func actionDashboard(_ sender: NSMenuItem) {
        if dashboardWindowController == nil {
            dashboardWindowController = ClashWebViewWindowController.create()
            dashboardWindowController?.onWindowClose = {
                [weak self] in
                self?.dashboardWindowController = nil
            }
        }
        dashboardWindowController?.showWindow(sender)
    }

    @IBAction func actionAllowFromLan(_ sender: NSMenuItem) {
        ApiRequest.updateAllowLan(allow: !ConfigManager.allowConnectFromLan) {
            [weak self] in
            guard let self = self else { return }
            self.syncConfig()
            ConfigManager.allowConnectFromLan = !ConfigManager.allowConnectFromLan
        }
    }

    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.shared.isEnabled = !LaunchAtLogin.shared.isEnabled
    }

    @IBAction func actionSwitchProxyMode(_ sender: NSMenuItem) {
        let mode: ClashProxyMode
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
        ApiRequest.updateOutBoundMode(mode: mode) { success in
            ConfigManager.shared.currentConfig = config
            ConfigManager.selectOutBoundMode = mode
            MenuItemFactory.recreateProxyMenuItems()
        }
    }

    @IBAction func actionShowNetSpeedIndicator(_ sender: NSMenuItem) {
        ConfigManager.shared.showNetSpeedIndicator = !(sender.state == .on)
    }

    @IBAction func actionSetSystemProxy(_ sender: Any) {
        var canSaveProxy = true
        if ConfigManager.shared.isProxySetByOtherVariable.value {
            // should reset proxy to clashx
            ConfigManager.shared.isProxySetByOtherVariable.accept(false)
            ConfigManager.shared.proxyPortAutoSet = true
            // clear then reset.
            canSaveProxy = false
            SystemProxyManager.shared.disableProxy(port: 0, socksPort: 0, forceDisable: true)
        } else {
            ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        }

        if ConfigManager.shared.proxyPortAutoSet {
            if canSaveProxy {
                SystemProxyManager.shared.saveProxy()
            }
            SystemProxyManager.shared.enableProxy()
        } else {
            SystemProxyManager.shared.disableProxy()
        }
    }

    @IBAction func actionCopyExportCommand(_ sender: NSMenuItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socksport = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        let localhost = "127.0.0.1"
        let isLocalhostCopy = sender == copyExportCommandMenuItem
        let ip = isLocalhostCopy ? localhost :
            NetworkChangeNotifier.getPrimaryIPAddress() ?? localhost
        pasteboard.setString("export https_proxy=http://\(ip):\(port) http_proxy=http://\(ip):\(port) all_proxy=socks5://\(ip):\(socksport)", forType: .string)
    }

    @IBAction func actionSpeedTest(_ sender: Any) {
        if isSpeedTesting {
            NSUserNotificationCenter.default.postSpeedTestingNotice()
            return
        }
        NSUserNotificationCenter.default.postSpeedTestBeginNotice()

        isSpeedTesting = true

        ApiRequest.getMergedProxyData { [weak self] resp in
            let group = DispatchGroup()

            for (name, _) in resp?.enclosingProviderResp?.providers ?? [:] {
                group.enter()
                ApiRequest.healthCheck(proxy: name) {
                    group.leave()
                }
            }

            for p in resp?.proxiesMap["GLOBAL"]?.all ?? [] {
                group.enter()
                ApiRequest.getProxyDelay(proxyName: p) { _ in
                    group.leave()
                }
            }
            group.notify(queue: DispatchQueue.main) {
                NSUserNotificationCenter.default.postSpeedTestFinishNotice()
                self?.isSpeedTesting = false
            }
        }
    }

    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
}

// MARK: Streaming Info

extension AppDelegate: ApiRequestStreamDelegate {
    func didUpdateTraffic(up: Int, down: Int) {
        statusItemView.updateSpeedLabel(up: up, down: down)
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

    @IBAction func actionSetUseApiMode(_ sender: Any) {
        let alert = NSAlert()
        alert.informativeText = NSLocalizedString("Need to Restart the ClashX to Take effect, Please start clashX manually", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Apply and Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            ConfigManager.builtInApiMode = !ConfigManager.builtInApiMode
            NSApp.terminate(nil)
        }
    }

    @IBAction func actionUpdateProxyGroupMenu(_ sender: Any) {
        ConfigManager.shared.disableShowCurrentProxyInMenu = !ConfigManager.shared.disableShowCurrentProxyInMenu
        updateExperimentalFeatureStatus()
        MenuItemFactory.recreateProxyMenuItems()
    }

    @IBAction func actionSetBenchmarkUrl(_ sender: Any) {
        let alert = NSAlert()
        let textfiled = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 20))
        textfiled.stringValue = ConfigManager.shared.benchMarkUrl
        alert.messageText = NSLocalizedString("Benchmark", comment: "")
        alert.accessoryView = textfiled
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        if alert.runModal() == .alertFirstButtonReturn {
            if textfiled.stringValue.isUrlVaild() {
                ConfigManager.shared.benchMarkUrl = textfiled.stringValue
            } else {
                let err = NSAlert()
                err.messageText = NSLocalizedString("URL is not valid", comment: "")
                err.runModal()
            }
        }
    }
}

// MARK: crash hanlder

extension AppDelegate {
    func registCrashLogger() {
        #if DEBUG
            return
        #else
            FirebaseApp.configure()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                AppCenter.start(withAppSecret: "dce6e9a3-b6e3-4fd2-9f2d-35c767a99663", services: [
                    Analytics.self,
                ])
            }

        #endif
    }

    func failLaunchProtect() {
        #if DEBUG
            return
        #else
            UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
            let x = UserDefaults.standard
            var launch_fail_times: Int = 0
            if let xx = x.object(forKey: "launch_fail_times") as? Int { launch_fail_times = xx }
            launch_fail_times += 1
            x.set(launch_fail_times, forKey: "launch_fail_times")
            if launch_fail_times > 3 {
                // 发生连续崩溃
                ConfigFileManager.backupAndRemoveConfigFile()
                try? FileManager.default.removeItem(atPath: kConfigFolderPath + "Country.mmdb")
                if let domain = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                }
                NSUserNotificationCenter.default.post(title: "Fail on launch protect", info: "You origin Config has been renamed")
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                x.set(0, forKey: "launch_fail_times")
            })
        #endif
    }
}

// MARK: Memory

extension AppDelegate {
    func selectProxyGroupWithMemory() {
        let copy = [SavedProxyModel](ConfigManager.selectedProxyRecords)
        for item in copy {
            guard item.config == ConfigManager.selectConfigName else { continue }
            Logger.log("Auto selecting \(item.group) \(item.selected)", level: .debug)
            ApiRequest.updateProxyGroup(group: item.group, selectProxy: item.selected) { success in
                if !success {
                    ConfigManager.selectedProxyRecords.removeAll { model -> Bool in
                        return model.key == item.key
                    }
                }
            }
        }
    }

    func removeUnExistProxyGroups() {
        let action: (([String]) -> Void) = { list in
            let unexists = ConfigManager.selectedProxyRecords.filter {
                !list.contains($0.config)
            }
            ConfigManager.selectedProxyRecords.removeAll {
                unexists.contains($0)
            }
        }

        if iCloudManager.shared.isICloudEnable() {
            iCloudManager.shared.getConfigFilesList { list in
                action(list)
            }
        } else {
            let list = ConfigManager.getConfigFilesList()
            action(list)
        }
    }

    func selectOutBoundModeWithMenory() {
        ApiRequest.updateOutBoundMode(mode: ConfigManager.selectOutBoundMode) {
            [weak self] _ in
            ConnectionManager.closeAllConnection()
            self?.syncConfig()
        }
    }

    func selectAllowLanWithMenory() {
        ApiRequest.updateAllowLan(allow: ConfigManager.allowConnectFromLan) {
            [weak self] in
            self?.syncConfig()
        }
    }

    func hasMenuSelected() -> Bool {
        if #available(macOS 11, *) {
            return statusMenu.items.contains { $0.state == .on }
        } else {
            return true
        }
    }
}

// MARK: NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        MenuItemFactory.refreshExistingMenuItems()
        updateConfigFiles()
        syncConfig()
        NotificationCenter.default.post(name: .proxyMeneViewShowLeftPadding,
                                        object: nil,
                                        userInfo: ["show": hasMenuSelected()])
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        menu.items.forEach {
            ($0.view as? ProxyGroupMenuHighlightDelegate)?.highlight(item: item)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        menu.items.forEach {
            ($0.view as? ProxyGroupMenuHighlightDelegate)?.highlight(item: nil)
        }
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
        else { return }

        if host == "install-config" {
            guard let url = components.queryItems?.first(where: { item in
                item.name == "url"
            })?.value else { return }

            var userInfo = ["url": url]
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
