//
//  ClashStatusTool.swift
//  ClashX Pro
//
//  Created by yicheng on 2020/4/28.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

class ClashStatusTool {
    static func checkPortConfig(cfg: ClashConfig?) {
        guard ConfigManager.shared.isRunning else { return }
        guard let cfg = cfg else { return }
        if cfg.usedHttpPort == 0 {
            Logger.log("checkPortConfig: \(cfg.mixedPort) ", level: .error)
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("ClashX Start Error!", comment: "")
            alert.informativeText = NSLocalizedString("Ports Open Fail, Please try to restart ClashX", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
            alert.addButton(withTitle: "Edit Config")
            DispatchQueue.main.async {
                let ret = alert.runModal()
                if ret == .alertSecondButtonReturn {
                    NSWorkspace.shared.openFile(Paths.localConfigPath(for: "config"))
                }
                NSApp.terminate(nil)
            }
           
        }
    }
}
