//
//  DateFormatter+.swift
//  ClashX
//
//  Created by yicheng on 2019/12/14.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

extension DateFormatter {
    static var js: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: NSCalendar.Identifier.ISO8601.rawValue)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SZ"
        return dateFormatter
    }
}
