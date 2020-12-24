//
//  Cgo+Convert.swift
//  ClashX
//
//  Created by yicheng on 2019/10/2.
//  Copyright © 2019 west2online. All rights reserved.
//

extension String {
    func goStringBuffer() -> UnsafeMutablePointer<Int8> {
        if let pointer = (self as NSString).utf8String {
            return UnsafeMutablePointer(mutating: pointer)
        }
        Logger.log("Convert goStringBuffer Fail!!!!", level: .error)
        let p = ("" as NSString).utf8String!
        return UnsafeMutablePointer(mutating: p)
    }
}

extension UnsafeMutablePointer where Pointee == Int8 {
    func toString() -> String {
        let string = String(cString: self)
        deallocate()
        return string
    }

    func toData() -> Data {
        return toString().data(using: .utf8) ?? Data()
    }
}

extension Bool {
    func goObject() -> GoUint8 {
        return self == true ? 1 : 0
    }
}

extension GoUint8 {
    func toBool() -> Bool {
        return self == 1
    }
}
