//
//  AirQuality.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Foundation

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
    private var url: URL {
        let urlString = "http://www.airnowapi.org/aq/observation/zipCode/current/?format=application/json&API_KEY=AC5D3CAB-2869-4108-8ABE-2ADED73E7340&zipCode="
        guard let zipcode = zipcode else {
            return URL(string: urlString + "94115")!
        }
        return URL(string: urlString + zipcode)!
    }
    
    var zipcode: String? {
        return UserDefaults.standard.zipcode
    }
    
    static let shared = AirQuality()
    private init() {
        
    }
    
    func getAirQuality(completion: @escaping ((String, Category) -> ())) {
        self.unauthenticatedRequest { (data, err) in
            if let err = err as? NSError {
                print("err: \(err.code)")
            }
            let decoder = JSONDecoder()
            guard let data = data else { fatalError() }
            guard let json = try? decoder.decode(AirQualityData.self, from: data) else { fatalError() }
            
            for quality in json {
                print("quality: \(quality)")
            }
            guard json.isEmpty == false else {
                completion("N/A", Category.init(number: -1, name: "n/a"))
                return
            }
            
            completion("\(json[1].aqi)", json[1].category)
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
