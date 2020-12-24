//
//  Logger.swift
//  ClashX
//
//  Created by CYC on 2018/8/7.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import CocoaLumberjack
import Foundation
class Logger {
    static let shared = Logger()
    var fileLogger: DDFileLogger = DDFileLogger()

    private init() {
        #if DEBUG
            DDLog.add(DDOSLogger.sharedInstance)
        #endif
        //default time zone is "UTC"
        let dataFormatter = DateFormatter()
        dataFormatter.setLocalizedDateFormatFromTemplate("YYYY/MM/dd HH:mm:ss:SSS")
        fileLogger.logFormatter = DDLogFileFormatterDefault.init(dateFormatter: dataFormatter)
        fileLogger.rollingFrequency = TimeInterval(60 * 60 * 24) // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3
        DDLog.add(fileLogger)
    }

    private func logToFile(msg: String, level: ClashLogLevel) {
        switch level {
        case .debug, .silent:
            DDLogDebug(msg)
        case .error:
            DDLogError(msg)
        case .info:
            DDLogInfo(msg)
        case .warning:
            DDLogWarn(msg)
        case .unknow:
            DDLogVerbose(msg)
        }
    }

    static func log(_ msg: String, level: ClashLogLevel = .info) {
        shared.logToFile(msg: "[\(level.rawValue)] \(msg)", level: level)
    }

    func logFilePath() -> String {
        return fileLogger.logFileManager.sortedLogFilePaths.first ?? ""
    }
}
