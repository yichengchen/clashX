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

import Crashlytics
import Fabric

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
    @IBOutlet var remoteConfigAutoupdateMenuItem: NSMenuItem!
    @IBOutlet var buildApiModeMenuitem: NSMenuItem!
    @IBOutlet var showProxyGroupCurrentMenuItem: NSMenuItem!
    @IBOutlet var copyExportCommandMenuItem: NSMenuItem!
    @IBOutlet var experimentalMenu: NSMenu!

    var disposeBag = DisposeBag()
    var statusItemView: StatusItemView!
    var isSpeedTesting = false
    var isMenuOptionEnter = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        checkOnlyOneClashX()

        // setup menu item first
        statusItem = NSStatusBar.system.statusItem(withLength: statusItemLengthWithSpeed)
        statusItem.menu = statusMenu

        statusItemView = StatusItemView.create(statusItem: statusItem)
        statusItemView.frame = CGRect(x: 0, y: 0, width: statusItemLengthWithSpeed, height: 22)
        statusMenu.delegate = self
        setupExperimentalMenuItem()

        // crash recorder
        failLaunchProtect()
        registCrashLogger()

        // install proxy helper
        _ = ClashResourceManager.check()
        SystemProxyManager.shared.checkInstall()
        ConfigFileManager.copySampleConfigIfNeed()

        PFMoveToApplicationsFolderIfNecessary()

        // claer not existed selected model
        removeUnExistProxyGroups()

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

        setupNetworkNotifier()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.shared.proxyPortAutoSet && !ConfigManager.shared.isProxySetByOtherVariable.value {
            let port = ConfigManager.shared.currentConfig?.port ?? 0
            let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
            SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort)
        }
    }

    func setupData() {
        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off

        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind { [weak self] show in
                guard let self = self else { return }
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                let statusItemLength: CGFloat = (show ?? true) ? statusItemLengthWithSpeed : 25
                self.statusItem.length = statusItemLength
                self.statusItemView.frame.size.width = statusItemLength
                self.statusItemView.showSpeedContainer(show: show ?? true)
                self.statusItemView.updateStatusItemView()
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

                self.updateProxyList()

                if old?.port != config.port && ConfigManager.shared.proxyPortAutoSet {
                    SystemProxyManager.shared.enableProxy(port: config.port, socksPort: config.socketPort)
                }

                self.httpPortMenuItem.title = "Http Port:\(config.port)"
                self.socksPortMenuItem.title = "Socks Port:\(config.socketPort)"
                self.apiPortMenuItem.title = "Api Port:\(ConfigManager.shared.apiPort)"

            }.disposed(by: disposeBag)

        ConfigManager
            .shared
            .isRunningVariable
            .asObservable()
            .distinctUntilChanged()
            .bind { [weak self] _ in
                guard let self = self else { return }
                self.updateProxyList()
            }.disposed(by: disposeBag)

        LaunchAtLogin.shared
            .isEnableVirable
            .asObservable()
            .subscribe(onNext: { [weak self] enable in
                guard let self = self else { return }
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)
    }

    func checkOnlyOneClashX() {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 {
            assertionFailure()
            NSApp.terminate(nil)
        }
    }

    func setupNetworkNotifier() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            NetworkChangeNotifier.start()
        }

        NotificationCenter
            .default
            .rx
            .notification(kSystemNetworkStatusDidChange)
            .observeOn(MainScheduler.instance)
            .bind { _ in
                let (http, https, socks) = NetworkChangeNotifier.currentSystemProxySetting()
                let currentPort = ConfigManager.shared.currentConfig?.port ?? 0
                let currentSocks = ConfigManager.shared.currentConfig?.socketPort ?? 0

                let proxySetted = http == currentPort && https == currentPort && socks == currentSocks
                ConfigManager.shared.isProxySetByOtherVariable.accept(!proxySetted)
            }.disposed(by: disposeBag)
    }

    func updateProxyList() {
        if ConfigManager.shared.isRunning {
            MenuItemFactory.menuItems { [weak self] items in
                self?.updateProxyList(withMenus: items)
            }
        } else {
            updateProxyList(withMenus: [])
        }
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
        let lineIndex = menu.items.firstIndex(of: configSeparatorLine)!
        for _ in 0..<lineIndex {
            menu.removeItem(at: 0)
        }
        for item in MenuItemFactory.generateSwitchConfigMenuItems().reversed() {
            menu.insertItem(item, at: 0)
        }
    }

    func updateLoggingLevel() {
        ApiRequest.updateLogLevel(level: ConfigManager.selectLoggingApiLevel)
        for item in logLevelMenuItem.submenu?.items ?? [] {
            item.state = item.title.lowercased() == ConfigManager.selectLoggingApiLevel.rawValue ? .on : .off
        }
        NotificationCenter.default.post(name: kLogLevelDidChange, object: nil)
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
        let string = run(ConfigManager.builtInApiMode.goObject())?.toString() ?? ""
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
                self.selectOutBoundModeWithMenory()
                self.selectAllowLanWithMenory()
                ConfigFileManager.checkFinalRuleAndShowAlert()
                if showNotification {
                    NSUserNotificationCenter.default
                        .post(title: NSLocalizedString("Reload Config Succeed", comment: ""),
                              info: NSLocalizedString("Succees", comment: ""))
                }

                if let newConfigName = configName {
                    ConfigManager.selectConfigName = newConfigName
                }
                self.selectProxyGroupWithMemory()
            }
        }
    }

    func setupExperimentalMenuItem() {
        ConnectionManager.addCloseOptionMenuItem(&experimentalMenu)
        AutoUpgardeManager.shared.setup()
        AutoUpgardeManager.shared.addChanelMenuItem(&experimentalMenu)
        updateExperimentalFeatureStatus()
    }

    func updateExperimentalFeatureStatus() {
        buildApiModeMenuitem.state = ConfigManager.builtInApiMode ? .on : .off
        showProxyGroupCurrentMenuItem.state = ConfigManager.shared.disableShowCurrentProxyInMenu ? .off : .on
    }
}

// MARK: Main actions

extension AppDelegate {
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
        }
    }

    @IBAction func actionShowNetSpeedIndicator(_ sender: NSMenuItem) {
        ConfigManager.shared.showNetSpeedIndicator = !(sender.state == .on)
    }

    @IBAction func actionSetSystemProxy(_ sender: Any) {
        if ConfigManager.shared.isProxySetByOtherVariable.value {
            // should reset proxy to clashx
            ConfigManager.shared.isProxySetByOtherVariable.accept(false)
            ConfigManager.shared.proxyPortAutoSet = true
        } else {
            ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        }
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
        let localhost = "127.0.0.1"

        let ip = isMenuOptionEnter ? NetworkChangeNotifier.getPrimaryIPAddress() ?? localhost : localhost
        pasteboard.setString("export https_proxy=http://\(ip):\(port) http_proxy=http://\(ip):\(port) all_proxy=socks5://\(ip):\(socksport)", forType: .string)
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
        Fabric.with([Crashlytics.self])
    }

    func failLaunchProtect() {
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
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            x.set(0, forKey: "launch_fail_times")
        })
    }
}

// MARK: Memory

extension AppDelegate {
    func selectProxyGroupWithMemory() {
        let copy = [SavedProxyModel](ConfigManager.selectedProxyRecords)
        for item in copy {
            guard item.config == ConfigManager.selectConfigName else { continue }
            ApiRequest.updateProxyGroup(group: item.group, selectProxy: item.selected) { success in
                if !success {
                    ConfigManager.selectedProxyRecords.removeAll { model -> Bool in
                        return model == item
                    }
                }
            }
        }
    }

    func removeUnExistProxyGroups() {
        let list = ConfigManager.getConfigFilesList()
        let unexists = ConfigManager.selectedProxyRecords.filter {
            !list.contains($0.config)
        }
        ConfigManager.selectedProxyRecords.removeAll {
            unexists.contains($0)
        }
    }

    func selectOutBoundModeWithMenory() {
        ApiRequest.updateOutBoundMode(mode: ConfigManager.selectOutBoundMode) {
            [weak self] _ in
            self?.syncConfig()
        }
    }

    func selectAllowLanWithMenory() {
        ApiRequest.updateAllowLan(allow: ConfigManager.allowConnectFromLan) {
            [weak self] in
            self?.syncConfig()
        }
    }

    func updateCopyProxyItem() {
        isMenuOptionEnter = NSEvent.modifierFlags == [.option]
        copyExportCommandMenuItem.title = isMenuOptionEnter ? NSLocalizedString("Copy Shell Export Command with External IP", comment: "") : NSLocalizedString("Copy Shell Export Command", comment: "")
    }
}

// MARK: NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {}

    func menuNeedsUpdate(_ menu: NSMenu) {
        syncConfig()
        updateConfigFiles()
        updateCopyProxyItem()
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
