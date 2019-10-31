//
//  UnsafePointer+bridge.swift
//  ClashX
//
//  Created by yicheng on 2019/10/31.
//  Copyright © 2019 west2online. All rights reserved.
//

func bridge<T: AnyObject>(obj: T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
}

func bridge<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}
