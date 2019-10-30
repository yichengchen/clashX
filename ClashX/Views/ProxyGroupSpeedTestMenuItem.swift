//
//  ProxyGroupSpeedTestMenuItem.swift
//  ClashX
//
//  Created by yicheng on 2019/10/15.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyGroupSpeedTestMenuItem: NSMenuItem {
    var proxyGroup: ClashProxy
    init(group: ClashProxy) {
        proxyGroup = group
        super.init(title: NSLocalizedString("Benchmark", comment: ""), action: nil, keyEquivalent: "")
        switch group.type {
        case .urltest, .fallback:
            view = ProxyGroupSpeedTestMenuItemView(.reTest)
        case .select:
            view = ProxyGroupSpeedTestMenuItemView(.benchmark)
        default:
            assertionFailure()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class ProxyGroupSpeedTestMenuItemView: NSView {
    let testType: TestType
    let label: NSTextField
    let font = NSFont.menuFont(ofSize: 14)
    var isMouseInsideView = false

    init(_ type: TestType) {
        testType = type
        label = NSTextField(labelWithString: type.title)
        label.font = font
        label.sizeToFit()
        super.init(frame: NSRect(x: 0, y: 0, width: label.bounds.width + 40, height: 20))
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(label)
        label.frame = NSRect(x: 20, y: 0, width: label.bounds.width, height: 20)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startBenchmark() {
        guard let group = (enclosingMenuItem as? ProxyGroupSpeedTestMenuItem)?.proxyGroup else { return }

        let testGroup = DispatchGroup()
        label.stringValue = NSLocalizedString("Testing", comment: "")
        enclosingMenuItem?.isEnabled = false
        for proxyName in group.speedtestAble {
            testGroup.enter()
            ApiRequest.getProxyDelay(proxyName: proxyName) { delay in
                let delayStr = delay == 0 ? "fail" : "\(delay) ms"
                NotificationCenter.default.post(name: kSpeedTestFinishForProxy,
                                                object: nil,
                                                userInfo: ["proxyName": proxyName, "delay": delayStr])
                testGroup.leave()
            }
        }

        testGroup.notify(queue: .main) {
            [weak self] in
            guard let self = self, let menu = self.enclosingMenuItem else { return }
            self.label.stringValue = menu.title
            self.label.textColor = NSColor.labelColor
            menu.isEnabled = true
        }
    }

    private func retest() {}
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if #available(macOS 10.15.1, *) {
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited,.activeAlways], owner: self, userInfo: nil))
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved,.activeAlways], owner: self, userInfo: nil))

        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if #available(macOS 10.15.1, *) {
            isMouseInsideView = true
            setNeedsDisplay(bounds)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if #available(macOS 10.15.1, *) {
            isMouseInsideView = false
            setNeedsDisplay(bounds)
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch testType {
        case .benchmark: startBenchmark()
        case .reTest: retest()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let menu = enclosingMenuItem else { return }
        
        let isHighlighted: Bool
        if #available(macOS 10.15.1, *) {
            isHighlighted = isMouseInsideView
        } else {
            isHighlighted = menu.isHighlighted
        }
        if isHighlighted {
            NSColor.selectedMenuItemColor.setFill()
            label.textColor = NSColor.white
        } else {
            NSColor.clear.setFill()
            if enclosingMenuItem?.isEnabled ?? true {
                label.textColor = NSColor.labelColor
            } else {
                label.textColor = NSColor.secondaryLabelColor
            }
        }
        dirtyRect.fill()
    }
}

extension ProxyGroupSpeedTestMenuItemView {
    enum TestType {
        case benchmark
        case reTest

        var title: String {
            switch self {
            case .benchmark: return NSLocalizedString("Benchmark", comment: "")
            case .reTest: return NSLocalizedString("ReTest", comment: "")
            }
        }
    }
}
