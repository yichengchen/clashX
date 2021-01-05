//
//  ANRDetectorThread.swift
//  MacAnrDemo
//
//  Created by miniLV on 2021/1/4.
//  Copyright © 2020 miniLV. All rights reserved.
//
public typealias AnrDetectCallBack = (_ report: String) -> Void

class AnrDetectThread: Thread {
    private var threshold: Double = 0
    private let maxThreadToPrint = 25
    private var handler: AnrDetectCallBack?
    
    private var mainThreadId: mach_port_t!
    private let semaphore = DispatchSemaphore(value: 0)
    private var isMainThreadBlock = false
    
    func start(threshold: Double, handler: @escaping AnrDetectCallBack) {
        if Thread.isMainThread {
            mainThreadId = mach_thread_self()
        } else {
            DispatchQueue.main.sync {
                mainThreadId = mach_thread_self()
            }
        }
        
        self.handler = handler
        self.threshold = threshold
        name = "com.west2online.ClashX.anrDetectThread"
        start()
    }
    
    override func main() {
        while !isCancelled {
            isMainThreadBlock = true
            DispatchQueue.main.async {
                self.isMainThreadBlock = false
                self.semaphore.signal()
            }
            
            usleep(useconds_t(threshold * 1000000))
            if isMainThreadBlock {
                didAnr()
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    func didAnr() {
        let allThreadTrace = traceAllThread(max: maxThreadToPrint)
        let report = "-----------\n main thread is \(Int(mainThreadId))\n\(allThreadTrace)\n---------"
        
        handler?(report)
    }
    
    func traceMainThread() -> String {
        return BSBacktraceLogger.backtrace(ofMachthread: mainThreadId)
    }
    
    func traceAllThread(max: Int = Int.max) -> String {
        var threads: thread_act_array_t?
        var totalThreadCount = mach_msg_type_number_t()
        
        if task_threads(mach_task_self_, &threads, &totalThreadCount) != KERN_SUCCESS || threads == nil {
            return ""
        }
        
        let targetCount = min(max, Int(totalThreadCount))
        var resultString = "Call Backtrace of \(targetCount)/\(totalThreadCount) threads:\n"
        
        for i in 0..<targetCount {
            let index = Int(i)
            if let bt = BSBacktraceLogger.backtrace(ofMachthread: threads![index]) {
                resultString.append(bt)
            }
        }
        return resultString
    }
}
