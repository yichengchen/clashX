//
//  ClashRule.swift
//  ClashX
//
//  Created by CYC on 2018/10/27.
//  Copyright © 2018 west2online. All rights reserved.
//

import Foundation

class ClashRule:Codable {
    
    let type:String
    let payload:String?
    let proxy:String?
}

class ClashRuleResponse:Codable {
    let rules:[ClashRule]
    static func fromData(_ data:Data)->ClashRuleResponse{
        let decoder = JSONDecoder()
        let model = try? decoder.decode(ClashRuleResponse.self, from: data)
        return model!
    }
}
