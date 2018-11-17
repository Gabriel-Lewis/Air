//
//  ZipcodeValidator.swift
//  Air
//
//  Created by Gabriel Lewis on 11/17/18.
//  Copyright © 2018 gabriel.lewis. All rights reserved.
//

import Foundation

public enum PostalCode: String {
    case US = "(\\d{5})(?:[ \\-](\\d{4}))?"
}
