//
//  UserDefaults.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Foundation

extension UserDefaults {
    var zipcode: String? {
        get {
            return UserDefaults.standard.string(forKey: #function)
        }
        set {
            guard let string = newValue else { return }
            UserDefaults.standard.set(string, forKey: #function)
        }
    }
}
