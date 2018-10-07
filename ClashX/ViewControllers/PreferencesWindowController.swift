//
//  PreferencesWindowController.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa
import RxCocoa
import RxSwift

class PreferencesWindowController: NSWindowController
    , NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var profilesTableView: NSTableView!
    
    @IBOutlet weak var profileBox: NSBox!
    
    @IBOutlet weak var hostTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var methodTextField: NSComboBox!
    
    @IBOutlet weak var simpleObfsSelectBox: NSComboBox!
    @IBOutlet weak var passwordTabView: NSTabView!
    @IBOutlet weak var passwordTextField: NSTextField!
    @IBOutlet weak var passwordSecureTextField: NSSecureTextField!
    @IBOutlet weak var togglePasswordVisibleButton: NSButton!

    @IBOutlet weak var typeSegmentContol: NSSegmentedControl!
    @IBOutlet weak var remarkTextField: NSTextField!
    

    
    @IBOutlet weak var removeButton: NSButton!
    
    let tableViewDragType: String = "ss.server.profile.data"

    
    var serverConfigs = [ProxyServerModel]()
    var editingConfig:ProxyServerModel?
    
    
    var disposeBag = DisposeBag()


    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        if serverConfigs.count == 0 {
            serverConfigs.append(ProxyServerModel())
        }
        
        methodTextField.addItems(withObjectValues: ProxyServerModel.supportMethod)
        
        profilesTableView.reloadData()
        updateProfileBoxVisible()
        
        self.typeSegmentContol.rx
            .controlEvent.asObservable().subscribe(onNext: { [unowned self](_) in
                self.methodTextField.isEnabled = self.typeSegmentContol.selectedSegment == 0
                self.simpleObfsSelectBox.isEnabled = self.methodTextField.isEnabled
                self.passwordTextField.isEnabled = self.methodTextField.isEnabled
                self.passwordSecureTextField.isEnabled  = self.methodTextField.isEnabled
                self.editingConfig?.proxyType = self.typeSegmentContol.selectedSegment == 0 ? .shadowsocks : .socks5
            }).disposed(by: disposeBag)
        
        self.simpleObfsSelectBox.isEditable = false;
        self.simpleObfsSelectBox.selectItem(at: 0);
        self.simpleObfsSelectBox.rx
            .controlEvent
            .asObservable()
            .subscribe(onNext: { [unowned self](_) in
                let selectStr = self.simpleObfsSelectBox.objectValueOfSelectedItem as! String
                self.editingConfig?.simpleObfs = SimpleObfsType(rawValue: selectStr) ?? .none
        }).disposed(by: disposeBag)

    }
    
    override func awakeFromNib() {
        profilesTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        profilesTableView.allowsMultipleSelection = true
    }
    
    @IBAction func addProfile(_ sender: NSButton) {
        if !(editingConfig?.isValid() ?? true){
            shakeWindows()
            return
        }
        profilesTableView.beginUpdates()
        let profile:ProxyServerModel
        if (editingConfig != nil) {
            profile = editingConfig!.copy() as! ProxyServerModel
            profile.remark = "\(profile.remark)Copy"
        } else {
            profile = ProxyServerModel()
            profile.remark = "NewServer"
        }
        serverConfigs.append(profile)
        
        let index = IndexSet(integer: serverConfigs.count-1)
        profilesTableView.insertRows(at: index, withAnimation: NSTableView.AnimationOptions.effectFade)
        
        self.profilesTableView.scrollRowToVisible(self.serverConfigs.count-1)
        self.profilesTableView.selectRowIndexes(index, byExtendingSelection: false)
        profilesTableView.endUpdates()
        updateProfileBoxVisible()
    }
    
    @IBAction func removeProfile(_ sender: NSButton) {
        let index = Int(profilesTableView.selectedRowIndexes.first!)
        var deleteCount = 0
        if index >= 0 {
            profilesTableView.beginUpdates()
            for (_, toDeleteIndex) in profilesTableView.selectedRowIndexes.enumerated() {
                print(serverConfigs.count)
                serverConfigs.remove(at: toDeleteIndex - deleteCount)
                profilesTableView.removeRows(at: IndexSet(integer: toDeleteIndex - deleteCount), withAnimation: NSTableView.AnimationOptions.effectFade)
                deleteCount += 1
            }
            profilesTableView.endUpdates()
        }
        self.profilesTableView.scrollRowToVisible(index-1)
        self.profilesTableView.selectRowIndexes(IndexSet(integer: index-1), byExtendingSelection: false)
        updateProfileBoxVisible()
    }
    
    @IBAction func ok(_ sender: NSButton) {
        if !(editingConfig?.isValid() ?? false) {
            shakeWindows()
            return
        }
        var vaild = true
        var remarkSet = Set<String>()
        remarkSet.insert("Proxy")
        remarkSet.insert("ProxyAuto")
        for config in serverConfigs {
            if remarkSet.contains(config.remark) || !config.isValid() {
                vaild = false
                break
            } else {
                remarkSet.insert(config.remark)
            }
        }
        
        if (!vaild) {
            self.shakeWindows()
            return
        }
        
        let str = ConfigFileFactory.configFile(proxies: serverConfigs)
        ConfigFileFactory.saveToClashConfigFile(str: str)
        NotificationCenter.default.post(Notification(name:kShouldUpDateConfig))
        window?.performClose(nil)
    }
    
    @IBAction func cancel(_ sender: NSButton) {
        window?.performClose(self)
    }
    
    
    @IBAction func togglePasswordVisible(_ sender: Any) {
        if passwordTabView.selectedTabViewItem?.identifier as! String == "secure" {
            passwordTabView.selectTabViewItem(withIdentifier: "insecure")
            togglePasswordVisibleButton.image = NSImage(named: "icons8-Eye Filled-50")
        } else {
            passwordTabView.selectTabViewItem(withIdentifier: "secure")
            togglePasswordVisibleButton.image = NSImage(named: "icons8-Blind Filled-50")
        }
    }
    
 
    
    func updateProfileBoxVisible() {
        if serverConfigs.count <= 1 {
            removeButton.isEnabled = false
        }else{
            removeButton.isEnabled = true
        }

        if serverConfigs.isEmpty {
            profileBox.isHidden = true
        } else {
            profileBox.isHidden = false
        }
    }
    
    func bindProfile(_ index:Int) {
        NSLog("bind profile \(index)")
        if index >= 0 && index < serverConfigs.count {
            editingConfig = serverConfigs[index]
            
            hostTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "serverHost"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])
            portTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "serverPort"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])
            
            methodTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "method"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])
            passwordTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "password"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])
            passwordSecureTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "password"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])

            remarkTextField.bind(NSBindingName(rawValue: "value"), to: editingConfig!, withKeyPath: "remark"
                , options: [NSBindingOption.continuouslyUpdatesValue: true])
            
            
            
            
        } else {
            editingConfig = nil
            hostTextField.unbind(NSBindingName(rawValue: "value"))
            portTextField.unbind(NSBindingName(rawValue: "value"))
            
            methodTextField.unbind(NSBindingName(rawValue: "value"))
            passwordTextField.unbind(NSBindingName(rawValue: "value"))
            
            remarkTextField.unbind(NSBindingName(rawValue: "value"))
            
            
        }
    }
    
    func getDataAtRow(_ index:Int) -> (String) {
        let profile = serverConfigs[index]
        if !profile.remark.isEmpty {
            return profile.remark
        } else {
            return profile.serverHost
        }
    }
    
    //--------------------------------------------------
    // For NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return serverConfigs.count
    }
    
    func tableView(_ tableView: NSTableView
        , objectValueFor tableColumn: NSTableColumn?
        , row: Int) -> Any? {
        
        let title = getDataAtRow(row)
        
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("main") {
            return title
        } else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("status") {
            return nil
        }
        return ""
    }
    
    // Drag & Drop reorder rows
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: NSPasteboard.PasteboardType(rawValue: tableViewDragType))
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int
        , proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return NSDragOperation()
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo
        , row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            var oldIndexes = [Int]()
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:], using: {
                (draggingItem: NSDraggingItem, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: self.tableViewDragType)), let index = Int(str) {
                    oldIndexes.append(index)
                }
            })
            
            var oldIndexOffset = 0
            var newIndexOffset = 0
            
            // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
            // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
            tableView.beginUpdates()
            for oldIndex in oldIndexes {
                if oldIndex < row {
                    let o = serverConfigs.remove(at: oldIndex + oldIndexOffset)
                    serverConfigs.insert(o, at:row - 1)
                    tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                    oldIndexOffset -= 1
                } else {
                    let o = serverConfigs.remove(at: oldIndex)
                    serverConfigs.insert(o, at:row + newIndexOffset)
                    tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                    newIndexOffset += 1
                }
            }
            tableView.endUpdates()
        
            return true
    }
    
    //--------------------------------------------------
    // For NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView
        , shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return false
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if row < 0 {
            editingConfig = nil
            return true
        }
        if editingConfig != nil {
            if !(editingConfig?.isValid() ?? false) {
                return false
            }
        }
        
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if profilesTableView.selectedRow >= 0 {
            bindProfile(profilesTableView.selectedRow)
        } else {
            if !serverConfigs.isEmpty {
                let index = IndexSet(integer: serverConfigs.count - 1)
                profilesTableView.selectRowIndexes(index, byExtendingSelection: false)
            }
        }
    }

    func shakeWindows(){
        let numberOfShakes:Int = 8
        let durationOfShake:Float = 0.5
        let vigourOfShake:Float = 0.05

        let frame:CGRect = (window?.frame)!
        let shakeAnimation = CAKeyframeAnimation()

        let shakePath = CGMutablePath()
        shakePath.move(to: CGPoint(x:NSMinX(frame), y:NSMinY(frame)))

        for _ in 1...numberOfShakes{
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) - frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) + frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
        }

        shakePath.closeSubpath()
        shakeAnimation.path = shakePath
        shakeAnimation.duration = CFTimeInterval(durationOfShake)
        window?.animations = ["frameOrigin":shakeAnimation]
        window?.animator().setFrameOrigin(window!.frame.origin)
    }
}
