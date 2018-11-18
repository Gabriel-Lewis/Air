//
//  MenuViewController.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Cocoa

class MenuViewController: NSViewController {
    
    var formatter: DateFormatter = {
       let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    @IBOutlet weak var dateLabel: NSTextField?
    @IBOutlet weak var zipcodeLabel: NSTextField!
    
    var date: Date = Date()
    override func viewDidLoad() {
        super.viewDidLoad()
        let date = formatter.string(from: self.date)
        self.dateLabel?.cell?.title = date
        zipcodeLabel.delegate = self
        if let zipcode = UserDefaults.standard.zipcode {
            self.zipcodeLabel.cell?.title = zipcode
        } else {
            self.zipcodeLabel.cell?.title = "94115"
        }

    }
    
    @IBAction func quit(_ sender: NSButton) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func zipcodeDidChange(_ sender: NSTextField) {
        guard let text = sender.cell?.title else { return }
        guard validZipCode(postalCode: text) else { return }
        UserDefaults.standard.zipcode = text
        UserDefaults.standard.synchronize()
    }
    
    func textFieldDidChange(_ sender: NSTextField) {
        guard let text = sender.cell?.title else { return }
        guard validZipCode(postalCode: text) else { return }
        UserDefaults.standard.zipcode = text
        UserDefaults.standard.synchronize()
        refresh()
    }
    
    
    @IBAction func refreshCode(_ sender: Any) {
        refresh()
    }
    
    @objc func refresh() {
        AppDelegate.shared?.updateAirQuality()
    }
    
    func validZipCode(postalCode:String)->Bool{
        let postalcodeRegex = "^[0-9]{5}(-[0-9]{4})?$"
        let pinPredicate = NSPredicate(format: "SELF MATCHES %@", postalcodeRegex)
        let bool = pinPredicate.evaluate(with: postalCode) as Bool
        return bool
    }
    
    func updateDateLabel() {
        self.date = Date()
        let dateString = formatter.string(from: date)
        self.dateLabel?.cell?.title = "\(dateString)"
    }
}

extension MenuViewController: NSTextFieldDelegate {
    public override func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, self.zipcodeLabel.identifier == textField.identifier {
            guard validZipCode(postalCode: textField.stringValue) else { return }
            UserDefaults.standard.zipcode = textField.stringValue
            UserDefaults.standard.synchronize()
            refresh()
        }
    }
}
