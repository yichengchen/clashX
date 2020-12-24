//
//  ProxyGroupSpeedTestMenuItem.swift
//  ClashX
//
//  Created by yicheng on 2019/10/15.
//  Copyright © 2019 west2online. All rights reserved.
//

import Carbon
import Cocoa

class ProxyGroupSpeedTestMenuItem: NSMenuItem {
    let proxyGroup: ClashProxy
    let testType: TestType

    init(group: ClashProxy) {
        proxyGroup = group
        if group.type.isAutoGroup {
            testType = .reTest
        } else if group.type == .select {
            testType = .benchmark
        } else {
            testType = .unknown
        }

        super.init(title: NSLocalizedString("Benchmark", comment: ""), action: nil, keyEquivalent: "")
        target = self
        action = #selector(healthCheck)

        switch testType {
        case .benchmark:
            view = ProxyGroupSpeedTestMenuItemView(testType.title)
        case .reTest:
            title = testType.title
        case .unknown:
            assertionFailure()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func healthCheck() {
        guard testType == .reTest else { return }
        ApiRequest.healthCheck(proxy: proxyGroup.name)
        menu?.cancelTracking()
    }
}

extension ProxyGroupSpeedTestMenuItem: ProxyGroupMenuHighlightDelegate {
    func highlight(item: NSMenuItem?) {
        (view as? ProxyGroupSpeedTestMenuItemView)?.isHighlighted = item == self
    }
}

fileprivate class ProxyGroupSpeedTestMenuItemView: MenuItemBaseView {
    private let label: NSTextField

    init(_ title: String) {
        label = NSTextField(labelWithString: title)
        label.font = type(of: self).labelFont
        label.sizeToFit()
        let rect = NSRect(x: 0, y: 0, width: label.bounds.width + 40, height: 20)
        super.init(frame: rect, autolayout: false)
        addSubview(label)
        label.frame = NSRect(x: 20, y: 0, width: label.bounds.width, height: 20)
        label.textColor = NSColor.labelColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var cells: [NSCell?] {
        return [label.cell]
    }

    override var labels: [NSTextField] {
        return [label]
    }

    override func didClickView() {
        startBenchmark()
    }

    private func startBenchmark() {
        guard let group = (enclosingMenuItem as? ProxyGroupSpeedTestMenuItem)?.proxyGroup
        else { return }
        let testGroup = DispatchGroup()

        var proxies = [ClashProxyName]()
        var providers = Set<ClashProviderName>()
        for testable in group.speedtestAble {
            switch testable {
            case let .provider(_, provider):
                providers.insert(provider)
            case let .proxy(name):
                proxies.append(name)
            }
        }

        for proxyName in proxies {
            testGroup.enter()
            ApiRequest.getProxyDelay(proxyName: proxyName) { delay in
                let delayStr = delay == 0 ? NSLocalizedString("fail", comment: "") : "\(delay) ms"
                NotificationCenter.default.post(name: .speedTestFinishForProxy,
                                                object: nil,
                                                userInfo: ["proxyName": proxyName, "delay": delayStr, "rawValue": delay])
                testGroup.leave()
            }
        }

        label.stringValue = NSLocalizedString("Testing", comment: "")
        enclosingMenuItem?.isEnabled = false
        setNeedsDisplay()

        for provider in providers {
            testGroup.enter()

            ApiRequest.healthCheck(proxy: provider) {
                testGroup.leave()
            }
        }

        testGroup.notify(queue: .main) {
            [weak self] in
            guard let self = self, let menu = self.enclosingMenuItem else { return }
            self.label.stringValue = menu.title
            menu.isEnabled = true
            self.setNeedsDisplay()
            if providers.count > 0 {
                MenuItemFactory.refreshExistingMenuItems()
            }
        }
    }
}

extension ProxyGroupSpeedTestMenuItem {
    enum TestType {
        case benchmark
        case reTest
        case unknown

        var title: String {
            switch self {
            case .benchmark: return NSLocalizedString("Benchmark", comment: "")
            case .reTest: return NSLocalizedString("ReTest", comment: "")
            case .unknown: return ""
            }
        }
    }
}
