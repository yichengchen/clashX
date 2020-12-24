//
//  ClashProxy.swift
//  ClashX
//
//  Created by CYC on 2019/3/17.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

enum ClashProxyType: String, Codable {
    case urltest = "URLTest"
    case fallback = "Fallback"
    case loadBalance = "LoadBalance"
    case select = "Selector"
    case direct = "Direct"
    case reject = "Reject"
    case shadowsocks = "Shadowsocks"
    case shadowsocksR = "ShadowsocksR"
    case socks5 = "Socks5"
    case http = "Http"
    case vmess = "Vmess"
    case snell = "Snell"
    case trojan = "Trojan"
    case relay = "Relay"
    case unknown = "Unknown"

    static let proxyGroups: [ClashProxyType] = [.select, .urltest, .fallback, .loadBalance]

    var isAutoGroup: Bool {
        switch self {
        case .urltest, .fallback, .loadBalance:
            return true
        default:
            return false
        }
    }

    static func isProxyGroup(_ proxy: ClashProxy) -> Bool {
        switch proxy.type {
        case .select, .urltest, .fallback, .loadBalance, .relay: return true
        default: return false
        }
    }

    static func isBuiltInProxy(_ proxy: ClashProxy) -> Bool {
        switch proxy.name {
        case "DIRECT", "REJECT": return true
        default: return false
        }
    }
}

typealias ClashProxyName = String
typealias ClashProviderName = String

class ClashProxySpeedHistory: Codable {
    let time: Date
    let delay: Int

    class hisDateFormaterInstance {
        static let shared = hisDateFormaterInstance()
        lazy var formater: DateFormatter = {
            var f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()
    }

    lazy var delayDisplay: String = {
        switch delay {
        case 0: return NSLocalizedString("fail", comment: "")
        default: return "\(delay) ms"
        }
    }()

    lazy var dateDisplay: String = {
        return hisDateFormaterInstance.shared.formater.string(from: time)
    }()

    lazy var displayString: String = "\(dateDisplay) \(delayDisplay)"
}

class ClashProxy: Codable {
    let name: ClashProxyName
    let type: ClashProxyType
    let all: [ClashProxyName]?
    let history: [ClashProxySpeedHistory]
    let now: ClashProxyName?
    weak var enclosingResp: ClashProxyResp? = nil
    weak var enclosingProvider: ClashProvider? = nil

    enum SpeedtestAbleItem {
        case proxy(name: ClashProxyName)
        case provider(name: ClashProxyName, provider: ClashProviderName)
    }

    private static var nameLengthCachedMap = [ClashProxyName: CGFloat]()
    static func cleanCache() {
        nameLengthCachedMap.removeAll()
    }

    lazy var speedtestAble: [SpeedtestAbleItem] = {
        guard let resp = enclosingResp, let allProxys = all else { return [] }
        var proxys = [SpeedtestAbleItem]()
        for proxy in allProxys {
            if let p = resp.proxiesMap[proxy], !ClashProxyType.isProxyGroup(p) {
                if let provider = p.enclosingProvider {
                    proxys.append(.provider(name: p.name, provider: provider.name))
                } else {
                    proxys.append(.proxy(name: p.name))
                }
            }
        }
        return proxys
    }()

    lazy var isSpeedTestable: Bool = {
        return speedtestAble.count > 0
    }()

    private enum CodingKeys: String, CodingKey {
        case type, all, history, now, name
    }

    lazy var maxProxyNameLength: CGFloat = {
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)

        let lengths = all?.compactMap({ name -> CGFloat in
            if let length = ClashProxy.nameLengthCachedMap[name] {
                return length
            }

            let rects = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
            let attr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 14)]
            let length = (name as NSString)
                .boundingRect(with: rect,
                              options: .usesLineFragmentOrigin,
                              attributes: attr).width
            ClashProxy.nameLengthCachedMap[name] = length
            return length
        })
        return lengths?.max() ?? 0
    }()
}

class ClashProxyResp {
    var proxies: [ClashProxy]

    var proxiesMap: [ClashProxyName: ClashProxy]

    var enclosingProviderResp: ClashProviderResp?

    init(_ data: Any?) {
        guard
            let data = data as? [String: [String: Any]],
            let proxies = data["proxies"]
        else {
            self.proxiesMap = [:]
            self.proxies = []
            return
        }

        var proxiesModel = [ClashProxy]()

        var proxiesMap = [ClashProxyName: ClashProxy]()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.js)
        for value in proxies.values {
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted) else {
                continue
            }
            guard let proxy = try? decoder.decode(ClashProxy.self, from: data) else {
                continue
            }
            proxiesModel.append(proxy)
            proxiesMap[proxy.name] = proxy
        }
        self.proxiesMap = proxiesMap
        self.proxies = proxiesModel

        for proxy in self.proxies {
            proxy.enclosingResp = self
        }
    }

    func updateProvider(_ providerResp: ClashProviderResp) {
        enclosingProviderResp = providerResp
        for provider in providerResp.providers.values {
            for proxy in provider.proxies {
                proxy.enclosingProvider = provider
                proxiesMap[proxy.name] = proxy
                proxies.append(proxy)
            }
        }
    }

    lazy var proxiesSortMap: [ClashProxyName: Int] = {
        var map = [ClashProxyName: Int]()
        for (idx, proxy) in (self.proxiesMap["GLOBAL"]?.all ?? []).enumerated() {
            map[proxy] = idx
        }
        return map
    }()

    lazy var proxyGroups: [ClashProxy] = {
        return proxies.filter {
            ClashProxyType.isProxyGroup($0)
        }.sorted(by: { proxiesSortMap[$0.name] ?? -1 < proxiesSortMap[$1.name] ?? -1 })
    }()

    lazy var longestProxyGroupName = {
        return proxyGroups.max { $1.name.count > $0.name.count }?.name ?? ""
    }()

    lazy var maxProxyNameLength: CGFloat = {
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
        let attr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 0)]
        return (self.longestProxyGroupName as NSString)
            .boundingRect(with: rect,
                          options: .usesLineFragmentOrigin,
                          attributes: attr).width
    }()
}
