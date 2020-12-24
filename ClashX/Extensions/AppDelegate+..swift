//
//  AppDelegate+.swift
//  ClashX
//
//  Created by yicheng on 2019/10/25.
//  Copyright © 2019 west2online. All rights reserved.
//
import AppKit

extension AppDelegate {
    static var shared: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }

    static var isAboveMacOS14: Bool {
        if #available(macOS 10.14, *) {
            return true
        }
        return false
    }

    static var isAboveMacOS152: Bool {
        if #available(macOS 10.15.3, *) {
            return true
        }
        return false
    }
}
