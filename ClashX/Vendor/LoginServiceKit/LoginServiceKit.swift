//
//  LoginServiceKit.swift
//
//  LoginServiceKit
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2019 Clipy Project.
//

//
//  Some code copyright 2009 Naotaka Morimoto.
//
//    Much of this code was taken and adapted from GTMLoginItems of Google
//    Toolbox for Mac and QSBPreferenceWindowController of Quick Search Box
//    for the Mac by Google Inc.
//    This code is also released under Apache License, Version 2.0.
//

//  Copyright (c) 2008-2009 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Cocoa

public final class LoginServiceKit: NSObject {}

public extension LoginServiceKit {
    static func isExistLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        return (loginItem(at: path) != nil)
    }

    @discardableResult
    static func addLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        guard !isExistLoginItems(at: path) else { return false }

        guard let sharedFileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) else { return false }
        let loginItemList = sharedFileList.takeRetainedValue()
        let url = URL(fileURLWithPath: path)
        if #available(macOS 11, *) {
            LSSharedFileListInsertItemURL(loginItemList, nil, nil, nil, url as CFURL, nil, nil)
        } else {
            LSSharedFileListInsertItemURL(loginItemList, kLSSharedFileListItemBeforeFirst.takeRetainedValue(), nil, nil, url as CFURL, nil, nil)
        }
        return true
    }

    @discardableResult
    static func removeLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        guard isExistLoginItems(at: path) else { return false }

        guard let sharedFileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) else { return false }
        let loginItemList = sharedFileList.takeRetainedValue()
        let url = URL(fileURLWithPath: path)
        let loginItemsListSnapshot: NSArray = LSSharedFileListCopySnapshot(loginItemList, nil).takeRetainedValue()
        guard let loginItems = loginItemsListSnapshot as? [LSSharedFileListItem] else { return false }
        for loginItem in loginItems {
            guard let resolvedUrl = LSSharedFileListItemCopyResolvedURL(loginItem, 0, nil) else { continue }
            let itemUrl = resolvedUrl.takeRetainedValue() as URL
            guard url.absoluteString == itemUrl.absoluteString else { continue }
            LSSharedFileListItemRemove(loginItemList, loginItem)
        }
        return true
    }
}

private extension LoginServiceKit {
    static func loginItem(at path: String) -> LSSharedFileListItem? {
        guard !path.isEmpty else { return nil }

        guard let sharedFileList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) else { return nil }
        let loginItemList = sharedFileList.takeRetainedValue()
        let url = URL(fileURLWithPath: path)
        let loginItemsListSnapshot: NSArray = LSSharedFileListCopySnapshot(loginItemList, nil).takeRetainedValue()
        guard let loginItems = loginItemsListSnapshot as? [LSSharedFileListItem] else { return nil }
        for loginItem in loginItems {
            guard let resolvedUrl = LSSharedFileListItemCopyResolvedURL(loginItem, 0, nil) else { continue }
            let itemUrl = resolvedUrl.takeRetainedValue() as URL
            guard url.absoluteString == itemUrl.absoluteString else { continue }
            return loginItem
        }
        return nil
    }
}
