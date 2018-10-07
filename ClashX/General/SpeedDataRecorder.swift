//
//  SpeedDataRecorder.swift
//  ClashX
//
//  Created by CYC on 2018/10/2.
//  Copyright © 2018 west2online. All rights reserved.
//

import Cocoa

class SpeedDataRecorder {
    static let shared = SpeedDataRecorder()
    private init(){}
    
    var speedDict = [String:Int]()
}
