//
//  ProxyGroupMenuItemView.swift
//  ClashX
//
//  Created by yicheng on 2019/10/16.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyGroupMenuItemView: MenuItemBaseView {
    private let groupNameLabel: NSTextField
    private let selectProxyLabel: NSTextField
    private let arrowLabel: NSControl = {
        if #available(macOS 11, *) {
            let image = NSImage(named: NSImage.goForwardTemplateName)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .bold, scale: .small))!
            return NSImageView(image: image)
        } else {
            let label = NSTextField(labelWithString: "▶")
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.textColor = NSColor.labelColor
            return label
        }
    }()

    private var leftPaddingConstraint: NSLayoutConstraint?
    private let leftPadding: CGFloat = 20

    override var cells: [NSCell?] {
        return [groupNameLabel.cell, selectProxyLabel.cell, arrowLabel.cell]
    }

    init(group: ClashProxyName, targetProxy: ClashProxyName, hasLeftPadding: Bool) {
        groupNameLabel = VibrancyTextField(labelWithString: group)
        selectProxyLabel = VibrancyTextField(labelWithString: targetProxy)
        super.init(autolayout: true)

        // arrow
        effectView.addSubview(arrowLabel)
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        let rightConstraint: CGFloat
        if #available(macOS 11, *) {
            rightConstraint = -8
        } else {
            rightConstraint = -10
        }
        arrowLabel.rightAnchor.constraint(equalTo: effectView.rightAnchor, constant: rightConstraint).isActive = true
        arrowLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true

        // group
        groupNameLabel.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(groupNameLabel)
        leftPaddingConstraint = groupNameLabel.leftAnchor.constraint(equalTo: effectView.leftAnchor, constant: leftPadding)
        leftPaddingConstraint?.isActive = true
        groupNameLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true
        groupNameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // select
        selectProxyLabel.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(selectProxyLabel)
        selectProxyLabel.rightAnchor.constraint(equalTo: effectView.rightAnchor, constant: -30).isActive = true
        selectProxyLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true
        selectProxyLabel.lineBreakMode = .byTruncatingHead

        // space
        selectProxyLabel.leftAnchor.constraint(greaterThanOrEqualTo: groupNameLabel.rightAnchor, constant: 20).isActive = true

        // max
        effectView.widthAnchor.constraint(lessThanOrEqualToConstant: 330).isActive = true
        // font & color
        groupNameLabel.font = type(of: self).labelFont
        selectProxyLabel.font = type(of: self).labelFont
        groupNameLabel.textColor = NSColor.labelColor
        selectProxyLabel.textColor = NSColor.secondaryLabelColor
        // noti
        NotificationCenter.default.addObserver(self, selector: #selector(proxyInfoDidUpdate(note:)), name: .proxyUpdate(for: group), object: nil)

        if #available(macOS 11, *) {
            updateLeftMenuPadding(show: hasLeftPadding)
            NotificationCenter.default.addObserver(self, selector: #selector(showLeftPaddingUpdate(note:)), name: .proxyMeneViewShowLeftPadding, object: nil)
        }
    }

    private func updateLeftMenuPadding(show: Bool) {
        if show {
            leftPaddingConstraint?.constant = leftPadding
        } else {
            leftPaddingConstraint?.constant = 10
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func proxyInfoDidUpdate(note: NSNotification) {
        guard let info = note.object as? ClashProxy else { assertionFailure(); return }
        selectProxyLabel.stringValue = info.now ?? ""
    }

    @objc private func showLeftPaddingUpdate(note: NSNotification) {
        guard let show = note.userInfo?["show"] as? Bool else { assertionFailure(); return }
        updateLeftMenuPadding(show: show)
    }
}

extension ProxyGroupMenuItemView: ProxyGroupMenuHighlightDelegate {
    func highlight(item: NSMenuItem?) {
        isHighlighted = item == enclosingMenuItem
    }
}
