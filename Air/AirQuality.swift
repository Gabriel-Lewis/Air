//
//  AirQuality.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Foundation
import UserNotifications

typealias AirQualityData = [AirQualityDatum]

struct AirQualityDatum: Codable {
    let dateObserved: String
    let hourObserved: Int
    let localTimeZone, reportingArea, stateCode: String
    let latitude, longitude: Double
    let parameterName: String
    let aqi: Int
    let category: Category
    
    enum CodingKeys: String, CodingKey {
        case dateObserved = "DateObserved"
        case hourObserved = "HourObserved"
        case localTimeZone = "LocalTimeZone"
        case reportingArea = "ReportingArea"
        case stateCode = "StateCode"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case parameterName = "ParameterName"
        case aqi = "AQI"
        case category = "Category"
    }
}

struct Category: Codable {
    let number: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case number = "Number"
        case name = "Name"
    }
}



class AirQuality {
    static let defaultZipcode = "94115"

    private var url: URL {
        let urlString = "https://www.airnowapi.org/aq/observation/zipCode/current/?format=application/json&API_KEY=\(Secrets.apiKey)&zipCode="
        return URL(string: urlString + (zipcode ?? AirQuality.defaultZipcode))!
    }
    
    var zipcode: String? {
        return UserDefaults.standard.zipcode
    }
    
    static let shared = AirQuality()
    private init() {
        
    }
    
    func getAirQuality(completion: @escaping ((String, Category, AirQualityDatum?) -> ())) {
        self.unauthenticatedRequest { (data, err) in
            if let err = err as? NSError {
                print("err: \(err.code)")
            }
            let decoder = JSONDecoder()
            guard let data = data,
                let json = try? decoder.decode(AirQualityData.self, from: data),
                let worst = json.max(by: { $0.aqi < $1.aqi }) else {
                    completion("N/A", Category(number: -1, name: "n/a"), nil)
                    return
            }
            // Report the worst reading across all parameters (e.g. PM2.5 vs ozone),
            // which is how the overall AQI for an area is defined.
            completion("\(worst.aqi)", worst.category, worst)
        }
    }
    
    func unauthenticatedRequest(data: Data? = nil, completion: @escaping ((Data?, Error?) -> Void)) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        let session = URLSession.shared
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = session.dataTask(with: request) { data, _, error -> Void in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let data = data else {
                completion(nil, nil)
                return
            }
            completion(data, nil)
        }
        task.resume()
    }
}


// MARK: - History

/// One point on the trend chart.
struct AQIReading: Codable {
    let date: Date
    let aqi: Int
    let categoryNumber: Int
}

/// Persists a rolling window of recent AQI readings, used to draw the trend chart.
final class AQIHistory {
    static let shared = AQIHistory()
    private let key = "aqiHistory"
    private let window: TimeInterval = 24 * 60 * 60 // keep a rolling 24 hours

    private init() {}

    var readings: [AQIReading] {
        guard let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([AQIReading].self, from: data) else {
                return []
        }
        return decoded
    }

    @discardableResult
    func record(aqi: Int, categoryNumber: Int, date: Date = Date()) -> [AQIReading] {
        var all = readings
        all.append(AQIReading(date: date, aqi: aqi, categoryNumber: categoryNumber))
        // Keep only readings from the last 24 hours (robust to sleep gaps and
        // any change in the poll interval).
        let cutoff = date.addingTimeInterval(-window)
        all = all.filter { $0.date >= cutoff }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return all
    }

    /// Discards all history. Call when the location (zip code) changes so
    /// readings from different places aren't charted together.
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}


// MARK: - Notifications

/// Posts a local notification when the AQI category changes (e.g. Good -> Moderate),
/// rather than on every poll, so the user isn't spammed while conditions are steady.
final class Notifier {
    static let shared = Notifier()
    private let lastCategoryKey = "lastNotifiedCategory"

    private init() {}

    func requestAuthorization() {
        // UserNotifications requires macOS 10.14+; on older systems this is a no-op
        // and the app simply runs without change notifications.
        guard #available(macOS 10.14, *) else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("notification auth error: \(error)")
            }
        }
    }

    /// Forgets the last category so the next reading establishes a fresh
    /// baseline (used when the location changes).
    func reset() {
        UserDefaults.standard.removeObject(forKey: lastCategoryKey)
    }

    func notifyIfCategoryChanged(area: String, aqi: Int, category: Category) {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: lastCategoryKey) as? Int
        defaults.set(category.number, forKey: lastCategoryKey)

        // Skip the very first reading and any poll where the category is unchanged.
        guard let previous = previous, previous != category.number else { return }
        guard #available(macOS 10.14, *) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(area): \(category.name)"
        let direction = category.number > previous ? "worsened" : "improved"
        content.body = "Air quality \(direction) — AQI is now \(aqi)."
        content.sound = UNNotificationSound.default()

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
