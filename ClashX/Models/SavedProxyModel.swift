//
//  SavedProxyModel.swift
//  ClashX
//
//  Created by yicheng on 2019/11/1.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

struct SavedProxyModel: Codable {
    let group: ClashProxyName
    let selected: ClashProxyName
    let config: String

    var key: String {
        return "\(group)_\(config)"
    }

    static let key = "SavedProxyModels"

    static func loadsFromUserDefault() -> [SavedProxyModel] {
        if let data = UserDefaults.standard.object(forKey: key) as? Data,
            let models = try? JSONDecoder().decode([SavedProxyModel].self, from: data) {
            var set = Set<String>()
            let filtered = models.filter({ model in
                let pass = !set.contains(model.key)
                set.insert(model.key)
                if !pass {
                    print("pass", model)
                }
                return pass
            })
            return filtered
        }
        return []
    }

    static func save(_ models: [SavedProxyModel]) {
        do {
            let data = try JSONEncoder().encode(models)
            UserDefaults.standard.set(data, forKey: key)
        } catch let err {
            Logger.log("save model fail,\(err)", level: .error)
            assertionFailure()
        }
    }
}

extension SavedProxyModel: Equatable {}
