//
//  QRCodeUtil.swift
//  ClashX
//
//  Created by CYC on 2018/8/26.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import CoreImage
import Foundation

class QRCodeUtil: NSObject {
    static func ScanQRCodeOnScreen() -> [String]? {

        var displayCount: UInt32 = 0;
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if (result != .success) {
            return nil
        }
        let allocated = Int(displayCount)
        var activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
        defer {
            activeDisplays.deallocate()
        }
        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        if (result != .success) {
            print("error: \(result)")
            return nil
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
        var ssUrls = [String]()
        
        for i in 0..<displayCount {
            let display = activeDisplays[Int(i)]
            if let image = CGDisplayCreateImage(display) {
                for feature in detector.features(in: CIImage(cgImage: image)) {
                    let qrFeature = feature as! CIQRCodeFeature
                    if qrFeature.messageString?.hasPrefix("ss://") ?? false {
                        ssUrls.append(qrFeature.messageString!)
                    }
                }
            }
        }
        return ssUrls.count > 0 ? ssUrls : nil
    }
}
