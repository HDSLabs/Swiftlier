//
//  UserReportableError.swift
//  SwiftPlusPlus
//
//  Created by Andrew J Wagner on 4/24/16.
//  Copyright © 2016 Drewag LLC. All rights reserved.
//

public protocol UserReportableError: ErrorType {
    var alertTitle: String {get}
    var alertMessage: String {get}
    var otherInfo: [String:String]? {get}
}
