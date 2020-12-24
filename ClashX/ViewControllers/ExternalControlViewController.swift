//
//  ExternalControlViewController.swift
//  ClashX Pro
//
//  Created by 称一称 on 2020/6/16.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

class ExternalControlViewController: NSViewController {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var addButton: NSButton!
    @IBOutlet var deleteButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateButtonStatus()
    }

    func updateButtonStatus() {
        let selectIdx = tableView.selectedRow
        if selectIdx == -1 {
            deleteButton.isEnabled = false
            return
        }
    }

    @IBAction func actionAdd(_ sender: Any) {
        let alertView = NSAlert()
        alertView.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alertView.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alertView.messageText = NSLocalizedString("Add a remote control config", comment: "")
        let addView = ExternalControlAddView(frame: .zero)
        alertView.accessoryView = addView
        let response = alertView.runModal()
        guard response == .alertFirstButtonReturn else { return }
        guard addView.isVaild() else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Invalid input", comment: "")
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        let model = RemoteControl(name: addView.nameField.stringValue, url: addView.urlTextField.stringValue, secret: addView.secretField.stringValue)
        RemoteControlManager.configs.append(model)
        tableView.reloadData()
    }

    @IBAction func actionDelete(_ sender: Any) {
        RemoteControlManager.configs.safeRemove(at: tableView.selectedRow)
        tableView.reloadData()
    }
}

extension ExternalControlViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return RemoteControlManager.configs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let config = RemoteControlManager.configs[safe: row] else { return nil }

        func setupCell(withIdentifier: String, string: String, textFieldtag: Int = 1) -> NSView? {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: withIdentifier), owner: nil)
            if let textField = cell?.viewWithTag(1) as? NSTextField {
                textField.stringValue = string
            } else {
                assertionFailure()
            }

            return cell
        }

        switch tableColumn?.identifier.rawValue ?? "" {
        case "url":
            return setupCell(withIdentifier: "urlCell", string: config.url)
        case "secret":
            return setupCell(withIdentifier: "secretCell", string: config.secret)
        case "name":
            return setupCell(withIdentifier: "nameCell", string: config.name)
        default: assertionFailure()
        }
        return nil
    }
}

class ExternalControlAddView: NSView {
    let urlTextField = NSTextField()
    let secretField = NSTextField()
    let nameField = NSTextField()

    let urlLabel = NSTextField(labelWithString: "Api URL:")
    let nameLabel = NSTextField(labelWithString: "Name:")
    let secretLabel = NSTextField(labelWithString: "Secret:")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        frame = NSRect(x: 0, y: 0, width: 300, height: 85)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupView() {
        addSubview(urlTextField)
        addSubview(secretField)
        addSubview(urlLabel)
        addSubview(secretLabel)
        addSubview(nameField)
        addSubview(nameLabel)
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        secretField.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        secretLabel.translatesAutoresizingMaskIntoConstraints = false
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            secretField.trailingAnchor.constraint(equalTo: trailingAnchor),
            urlTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor),
            urlTextField.topAnchor.constraint(equalTo: topAnchor),
            urlTextField.leadingAnchor.constraint(equalTo: secretField.leadingAnchor),
            urlTextField.bottomAnchor.constraint(equalTo: secretField.topAnchor, constant: -10),
            nameField.topAnchor.constraint(equalTo: secretField.bottomAnchor, constant: 10),
            urlLabel.centerYAnchor.constraint(equalTo: urlTextField.centerYAnchor),
            secretLabel.centerYAnchor.constraint(equalTo: secretField.centerYAnchor),
            urlTextField.leadingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 5),
            secretField.leadingAnchor.constraint(equalTo: secretLabel.trailingAnchor, constant: 5),
            urlLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 0),
            secretLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 0),
            urlTextField.widthAnchor.constraint(equalToConstant: 230),
            nameField.leadingAnchor.constraint(equalTo: urlTextField.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: nameField.centerYAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 5),
        ])
    }

    func isVaild() -> Bool {
        return urlTextField.stringValue.isUrlVaild() && nameLabel.stringValue.count > 0
    }
}
