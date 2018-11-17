//
//  AppDelegate.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Cocoa
import NotificationCenter

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    static var shared: AppDelegate? {
        return NSApplication.shared.delegate as? AppDelegate
    }
    var timer: Timer?
    let popover = NSPopover()
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func showPopover(sender: AnyObject?) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    var menuVew: MenuViewController?
    
    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
    }
    
    @objc func togglePopover(sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        
        if let button = statusItem.button {
            button.title = "240"
            button.target = self
            button.action = #selector(self.togglePopover(sender:))
            button.highlight(true)
        }
        let menu = MenuViewController(nibName: NSNib.Name(rawValue: "MenuView"), bundle: nil)
        popover.contentViewController = menu
        self.menuVew = menu
        // Disable delay for popover - default is true
        popover.animates = true
        // When something else is clicked, close the popover
        popover.behavior = .transient
        
        updateAirQuality()
        startTimer()
    }
    
    func startTimer() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: 600, target: self, selector: #selector(updateAirQuality), userInfo: nil, repeats: true)
    }
    
    @objc func updateAirQuality() {
        AirQuality.shared.getAirQuality { (aqi, category) in
            DispatchQueue.main.async {
                if let button = self.statusItem.button {
                    self.statusItem.button?.highlight(true)
                    let pstyle = NSMutableParagraphStyle()
                    pstyle.alignment = .center
                    
                    switch category.number {
                    case 0, 1, 2:
                        button.layer?.backgroundColor = NSColor.green.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.black, NSAttributedStringKey.paragraphStyle : pstyle ])
                    case 3:
                        button.layer?.backgroundColor = NSColor.yellow.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.black, NSAttributedStringKey.paragraphStyle : pstyle ])
                    case 4:
                        button.layer?.backgroundColor = NSColor.red.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : pstyle ])
                    case 5:
                        button.layer?.backgroundColor = NSColor.purple.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : pstyle ])
                    case 6:
                        button.layer?.backgroundColor = NSColor.black.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : pstyle ])
                    default:
                        button.layer?.backgroundColor = NSColor.gray.cgColor
                        button.attributedTitle = NSAttributedString(string: aqi, attributes: [ NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : pstyle ])
                    }
                }
                self.menuVew?.updateDateLabel()
            }
        }
    }
    
    
}
