//
//  ProxyItemView.swift
//  ClashX
//
//  Created by yicheng on 2019/11/2.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyItemView: MenuItemBaseView {
    let nameLabel: NSTextField
    let delayLabel: NSTextField
    var imageView: NSImageView?

    static let fixedPlaceHolderWidth: CGFloat = 20 + 50 + 25

    init(proxy: ClashProxy) {
        nameLabel = VibrancyTextField(labelWithString: proxy.name)
        delayLabel = VibrancyTextField(labelWithString: "").setup(allowsVibrancy: false)
        let cell = PaddedNSTextFieldCell()
        cell.widthPadding = 2
        if #available(macOS 11, *) {
            cell.heightPadding = 2
        } else {
            cell.heightPadding = 1
        }
        delayLabel.cell = cell
        super.init(autolayout: false)
        effectView.addSubview(nameLabel)
        effectView.addSubview(delayLabel)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        delayLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = type(of: self).labelFont
        if #available(macOS 11, *) {
            delayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        } else {
            delayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        }
        nameLabel.alignment = .left
        delayLabel.alignment = .right

        delayLabel.wantsLayer = true
        delayLabel.layer?.cornerRadius = 2
        delayLabel.textColor = NSColor.white

        update(str: proxy.history.last?.delayDisplay, value: proxy.history.last?.delay)
    }

    override func layout() {
        super.layout()
        nameLabel.sizeToFit()
        delayLabel.sizeToFit()
        imageView?.frame = CGRect(x: 5, y: effectView.bounds.height / 2 - 6, width: 12, height: 12)
        nameLabel.frame = CGRect(x: 18,
                                 y: (effectView.bounds.height - nameLabel.bounds.height) / 2,
                                 width: nameLabel.bounds.width,
                                 height: nameLabel.bounds.height)
        delayLabel.frame = CGRect(x: effectView.bounds.width - delayLabel.bounds.width - 8,
                                  y: (effectView.bounds.height - delayLabel.bounds.height) / 2,
                                  width: delayLabel.bounds.width,
                                  height: delayLabel.bounds.height)
    }

    func update(str: String?, value: Int?) {
        delayLabel.stringValue = str ?? ""
        needsLayout = true

        guard let delay = value, str != nil else {
            delayLabel.layer?.backgroundColor = NSColor.clear.cgColor
            return
        }
        switch delay {
        case 0:
            delayLabel.layer?.backgroundColor = CGColor.fail
        case 0..<300:
            delayLabel.layer?.backgroundColor = CGColor.good
        default:
            delayLabel.layer?.backgroundColor = CGColor.meduim
        }
    }

    func update(selected: Bool) {
        if selected {
            if imageView == nil {
                let image: NSImage
                if #available(OSX 11.0, *) {
                    image = NSImage(named: NSImage.menuOnStateTemplateName)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .bold, scale: .small))!
                } else {
                    image = NSImage(named: NSImage.menuOnStateTemplateName)!
                }
                imageView = NSImageView(image: image)
                imageView?.translatesAutoresizingMaskIntoConstraints = false
                effectView.addSubview(imageView!)
            }
        } else {
            imageView?.removeFromSuperview()
            imageView = nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didClickView() {
        (enclosingMenuItem as? ProxyMenuItem)?.didClick()
    }

    override var cells: [NSCell?] {
        return [nameLabel.cell, imageView?.cell]
    }
}

fileprivate extension CGColor {
    static let good = CGColor(red: 30.0 / 255, green: 181.0 / 255, blue: 30.0 / 255, alpha: 1)
    static let meduim = CGColor(red: 1, green: 135.0 / 255, blue: 0, alpha: 1)
    static let fail = CGColor(red: 218.0 / 255, green: 0.0, blue: 3.0 / 255, alpha: 1)
}
