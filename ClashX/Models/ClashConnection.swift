//
//  ClashConnection.swift
//  ClashX
//
//  Created by yicheng on 2019/10/28.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

struct ClashConnectionSnapShot: Codable {
    let connections: [Connection]
}

extension ClashConnectionSnapShot {
    struct Connection: Codable {
        let id: String
        let chains: [String]
    }
}
