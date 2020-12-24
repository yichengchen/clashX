//
//  Settings.swift
//  ClashX
//
//  Created by yicheng on 2020/12/18.
//  Copyright © 2020 west2online. All rights reserved.
//

enum Settings {
    @UserDefault("mmdbDownloadUrl", defaultValue: "")
    static var mmdbDownloadUrl:String
    
    @UserDefault("filterInterface", defaultValue: true)
    static var filterInterface:Bool

    @UserDefault("usePacMode", defaultValue: false)
    static var usePacMode:Bool
}
