//
//  AnrDetectUtil.swift
//  Rooms
//
//  Created by miniLV on 2021/1/4.
//  Copyright © 2020 miniLV. All rights reserved.
//


import Cocoa

class AnrDetectUtil {
    static let shared = AnrDetectUtil()
    
    private init() {}
    lazy var thread = AnrDetectThread()
    
    let macModal: String = Mac.getMacModel()
    
    func start(threshold: Double = 10) {
        thread.start(threshold: threshold) { allThreadBackTrace in
            Logger.log("[ANR] \(allThreadBackTrace)", level: .error)
        }
    }
    
    func stop() {
        thread.cancel()
    }
}

struct Mac {
    static func getMacModel() -> String {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)
        }
        
        IOObjectRelease(service)
        return modelIdentifier ?? ""
    }
}
