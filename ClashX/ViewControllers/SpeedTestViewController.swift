//
//  SpeedTesdtViewController.swift
//  ClashX
//
//  Created by CYC on 2018/9/23.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

class SpeedTestViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    
    @objc class ProxyModel:NSObject {
        @objc var name:String
        @objc var delay:Int

        init(_ name:String) {
            self.name = name
            self.delay = -2
        }
    }
    
    var proxies = [ProxyModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupData()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupData() {
        
        for columns in self.tableView.tableColumns {
            let sortKey:String
            if columns.identifier.rawValue == "proxies" {
                sortKey = "name"
            } else {
                sortKey = "delay"
            }
            let sortDescriptor = NSSortDescriptor(key: sortKey, ascending: true)
            columns.sortDescriptorPrototype = sortDescriptor
        }
        
        ApiRequest.getAllProxyList { [unowned self](proxies) in
            for proxyName in proxies {
                self.proxies.append(ProxyModel(proxyName))
            }
            self.tableView.reloadData()
            self.speedTest()
        }
    }
    
    func speedTest() {
        for proxy in proxies {
            ApiRequest.getProxyDelay(proxyName: proxy.name) {[weak self] (delay) in
                guard let strongSelf = self else {return}
                SpeedDataRecorder.shared.speedDict[proxy.name] = delay;
                proxy.delay = delay
                strongSelf.tableView.reloadData()
            }
        }
    }
    
}

extension SpeedTestViewController:NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return proxies.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if(tableColumn?.identifier.rawValue == "proxies") {
            return cellForProxyName(tableView, atRow: row)
        } else {
            return cellForDelay(tableView, atRow: row)
        }
    }
        
        
    func cellForProxyName(_ tableView:NSTableView, atRow row:Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProxyNameCell"), owner: nil)
        let model = proxies[row]
        let textField = cell?.viewWithTag(1) as! NSTextField
        textField.stringValue = model.name
        return cell
    }
    
    
    func cellForDelay(_ tableView:NSTableView, atRow row:Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "delayCell"), owner: nil)
        let textField = cell?.viewWithTag(1) as! NSTextField
        let model = proxies[row]

        if (model.delay == -2) {
            textField.stringValue = "testing"
        } else if (model.delay == Int.max) {
            textField.stringValue = "fail"
        } else {
            textField.stringValue = "\(model.delay)"
        }
        return cell
    }


}

extension SpeedTestViewController:NSTableViewDelegate{
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.proxies = (self.proxies as NSArray).sortedArray(using: tableView.sortDescriptors) as! [SpeedTestViewController.ProxyModel]
        tableView.reloadData()
    }
}

