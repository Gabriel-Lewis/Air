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

    private var sparkline: SparklineView?

    var date: Date = Date()
    override func viewDidLoad() {
        super.viewDidLoad()
        let date = formatter.string(from: self.date)
        self.dateLabel?.cell?.title = date
        zipcodeLabel.delegate = self
        self.zipcodeLabel.cell?.title = UserDefaults.standard.zipcode ?? AirQuality.defaultZipcode

        setupChart()
        updateChart()
    }

    /// Grows the popover and adds the trend chart in the new space above the
    /// existing controls. Subview autoresizing is turned off so the fixed-frame
    /// controls from the xib stay exactly where they are.
    private func setupChart() {
        let chartHeight: CGFloat = 80
        let topMargin: CGFloat = 8

        view.autoresizesSubviews = false

        // Sit the chart just above the top-most control (the zip code field) so
        // there's no dead space between the chart and the controls below it.
        let chartBottom = zipcodeLabel.frame.maxY + 4
        var frame = view.frame
        frame.size.height = chartBottom + chartHeight + topMargin
        view.frame = frame

        let chart = SparklineView(frame: NSRect(x: 12,
                                                y: chartBottom,
                                                width: view.bounds.width - 24,
                                                height: chartHeight))
        chart.autoresizingMask = [.width, .minYMargin]
        view.addSubview(chart)
        self.sparkline = chart
    }

    func updateChart() {
        sparkline?.readings = AQIHistory.shared.readings
    }
    
    @IBAction func quit(_ sender: NSButton) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func zipcodeDidChange(_ sender: NSTextField) {
        applyZipcode(sender.stringValue)
    }

    func textFieldDidChange(_ sender: NSTextField) {
        applyZipcode(sender.stringValue)
    }

    /// Single entry point for a zip-code edit. Persists the value and, when the
    /// location actually changes, resets the chart history and notification
    /// baseline so data from different places isn't mixed together.
    private func applyZipcode(_ newZip: String) {
        guard validZipCode(postalCode: newZip) else { return }
        let previous = UserDefaults.standard.zipcode
        UserDefaults.standard.zipcode = newZip
        UserDefaults.standard.synchronize()
        if newZip != previous {
            AQIHistory.shared.clear()
            Notifier.shared.reset()
            updateChart()
        }
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
            applyZipcode(textField.stringValue)
        }
    }
}


/// A small trend chart of recent AQI readings, drawn with Core Graphics so it
/// adds no dependencies and keeps the app's deployment target and universal build.
final class SparklineView: NSView {

    var readings: [AQIReading] = [] {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // No background — draw a bare sparkline directly over the popover.
        guard readings.count >= 2 else {
            drawMessage("Collecting air quality history…", atTop: false)
            return
        }

        // Reserve a band at the top for the label. It's wide enough that neither
        // the line nor its ~9px glow halo reaches up into the text.
        let plot = NSRect(x: bounds.minX + 8,
                          y: bounds.minY + 8,
                          width: bounds.width - 16,
                          height: bounds.height - 8 - 30)
        let values = readings.map { CGFloat($0.aqi) }
        // Floor the scale at 50 so a stretch of "Good" readings isn't blown up to full height.
        let scale = max(values.max() ?? 1, 50)

        func point(_ i: Int) -> NSPoint {
            let x = plot.minX + plot.width * CGFloat(i) / CGFloat(readings.count - 1)
            let y = plot.minY + plot.height * (values[i] / scale)
            return NSPoint(x: x, y: y)
        }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        func categoryColor(_ i: Int) -> NSColor {
            return SparklineView.color(forCategory: readings[i].categoryNumber)
        }

        // Soft filled band under each segment, tinted with that segment's
        // category color so the chart's fill matches the menu-bar color.
        for i in 0..<readings.count - 1 {
            let p0 = point(i), p1 = point(i + 1)
            let band = NSBezierPath()
            band.move(to: NSPoint(x: p0.x, y: plot.minY))
            band.line(to: p0)
            band.line(to: p1)
            band.line(to: NSPoint(x: p1.x, y: plot.minY))
            band.close()
            categoryColor(i).withAlphaComponent(0.18).setFill()
            band.fill()
        }

        // The trend line, drawn one segment at a time so its color and glow
        // track the AQI category — the same colors the menu bar uses.
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for i in 0..<readings.count - 1 {
            let color = categoryColor(i)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 6, color: color.withAlphaComponent(0.8).cgColor)
            ctx.setStrokeColor(color.cgColor)
            ctx.beginPath()
            ctx.move(to: point(i))
            ctx.addLine(to: point(i + 1))
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Glowing dot on the latest reading, colored by its category.
        let last = readings.count - 1
        let p = point(last)
        let dotColor = categoryColor(last)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 7, color: dotColor.cgColor)
        ctx.setFillColor(dotColor.cgColor)
        ctx.addPath(CGPath(ellipseIn: NSRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7), transform: nil))
        ctx.fillPath()
        ctx.restoreGState()

        let spanHours = readings[last].date.timeIntervalSince(readings[0].date) / 3600
        let span = spanHours >= 1 ? "\(Int(spanHours.rounded()))h" : "<1h"
        drawMessage("AQI \(readings[last].aqi) · \(span) / 24h", atTop: true)
    }

    private func drawMessage(_ text: String, atTop: Bool) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedStringKey: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let y = atTop ? bounds.maxY - size.height - 4 : bounds.midY - size.height / 2
        let rect = NSRect(x: bounds.minX, y: y, width: bounds.width, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    /// The exact colors AppDelegate paints behind the menu-bar AQI value, so
    /// the chart reads as the same scale.
    static func color(forCategory number: Int) -> NSColor {
        switch number {
        case 0, 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        case 6: return .black
        default: return .gray
        }
    }
}
