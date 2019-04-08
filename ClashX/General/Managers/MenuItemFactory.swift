//
//  MenuItemFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/4.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import SwiftyJSON
import RxCocoa

class MenuItemFactory {
    static func menuItems(completionHandler:@escaping (([NSMenuItem])->())){
        ApiRequest.requestProxyGroupList { (proxyInfo) in
            var menuItems = [NSMenuItem]()
            if (ConfigManager.shared.currentConfig?.mode == .direct) {
                completionHandler(menuItems)
                return
            }
            
            for proxy in proxyInfo.proxyGroups {
                var menu:NSMenuItem?
                switch proxy.type {
                case .select: menu = self.generateSelectorMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                case .urltest,.fallback: menu = generateUrlTestMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                case .loadBalance:
                    menu = generateLoadBalanceMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                default: continue
                }
                
                if let menu = menu {
                    menuItems.append(menu)
                    menu.isEnabled=true
                }
            }
            completionHandler(menuItems.reversed())
        }
    }
    
    static func generateSelectorMenuItem(proxyGroup:ClashProxy,
                                         proxyInfo:ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap
        
        let isGlobalMode = ConfigManager.shared.currentConfig?.mode == .global
        if (isGlobalMode) {
            if proxyGroup.name != "GLOBAL" {return nil}
        } else {
            if proxyGroup.name == "GLOBAL" {return nil}
        }
        
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.now ?? ""
        let submenu = NSMenu(title: proxyGroup.name)
        var hasSelected = false
        
        for proxy in proxyGroup.all ?? []{
            guard let proxyModel = proxyMap[proxy] else {continue}
            
            if isGlobalMode && proxyModel.type == .select {
                continue
            }
            let proxyItem = ProxyMenuItem(proxy: proxyModel, action: #selector(MenuItemFactory.actionSelectProxy(sender:)),
                                          maxProxyNameLength:proxyGroup.maxProxyNameLength)
            proxyItem.target = MenuItemFactory.self
            proxyItem.isSelected = proxy == selectedName
            
            if proxyItem.isSelected {hasSelected = true}
            submenu.addItem(proxyItem)
        }
        
        menu.submenu = submenu
        if (!hasSelected && submenu.items.count>0) {
            self.actionSelectProxy(sender: submenu.items[0] as! ProxyMenuItem)
        }
        return menu
    }
    
    static func generateUrlTestMenuItem(proxyGroup:ClashProxy,proxyInfo:ClashProxyResp)->NSMenuItem? {
        
        let proxyMap = proxyInfo.proxiesMap
        
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.now ?? ""
        let submenu = NSMenu(title: proxyGroup.name)

        let nowMenuItem = NSMenuItem(title: "now:\(selectedName)", action: #selector(empty), keyEquivalent: "")
        nowMenuItem.target = MenuItemFactory.self

        submenu.addItem(nowMenuItem)
        submenu.addItem(NSMenuItem.separator())

        for proxyName in proxyGroup.all ?? [] {
            guard let proxy = proxyMap[proxyName] else {continue}
            let proxyMenuItem = NSMenuItem(title: proxy.name, action: nil, keyEquivalent: "")
            if proxy.name == selectedName {
                proxyMenuItem.state = .on
            }
            let historyMenu = NSMenu(title: "")
            for his in proxy.history {
                historyMenu.addItem(
                    NSMenuItem(title: "\(his.dateDisplay) \(his.delayDisplay)", action: nil, keyEquivalent: ""))
            }
            if historyMenu.items.count > 0 {
                proxyMenuItem.submenu = historyMenu
                submenu.addItem(proxyMenuItem)
            }
        }
        menu.submenu = submenu
        return menu
    }
    
    static func generateLoadBalanceMenuItem(proxyGroup:ClashProxy, proxyInfo:ClashProxyResp)->NSMenuItem? {
        
        let proxyMap = proxyInfo.proxiesMap

        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: proxyGroup.name)
        
        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else {continue}
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          action:#selector(empty),
                                          maxProxyNameLength:proxyGroup.maxProxyNameLength)
            proxyItem.isSelected = false
            proxyItem.target = MenuItemFactory.self
            submenu.addItem(proxyItem)
        }
        
        menu.submenu = submenu
        
        return menu
    }
   
    static func generateSwitchConfigSubMenu() -> NSMenu {
        let subMenu = NSMenu(title: "Switch Configs")
        for config in ConfigManager.getConfigFilesList() {
            let item = NSMenuItem(title: config, action: #selector(MenuItemFactory.actionSelectConfig(sender:)), keyEquivalent: "")
            item.target = MenuItemFactory.self
            item.state = ConfigManager.selectConfigName == config ? .on : .off
            subMenu.addItem(item)
        }
        return subMenu
    }
}


extension MenuItemFactory {
    @objc static func actionSelectProxy(sender:ProxyMenuItem){
        guard let proxyGroup = sender.menu?.title else {return}
        let proxyName = sender.proxyName
        
        ApiRequest.updateProxyGroup(group: proxyGroup, selectProxy: proxyName) { (success) in
            if (success) {
                for items in sender.menu?.items ?? [NSMenuItem]() {
                    items.state = .off
                }
                sender.state = .on
                // remember select proxy
                ConfigManager.selectedProxyMap[proxyGroup] = proxyName
            }
        }
    }
    
    
    @objc static func actionSelectConfig(sender:NSMenuItem){
        let config = sender.title
        ConfigManager.selectConfigName = config
        NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
    }
    
    @objc static func empty(){}
}

