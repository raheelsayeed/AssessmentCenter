//
//  Extensions.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 13/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation

extension String {
    func base64encoded() -> String {
        let data = self.data(using: .utf8)
        let base64string = data!.base64EncodedString()
        return base64string
    }
    func URLEncoded() -> String {
        let escapedString = self.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        return escapedString!
    }
}

extension Date {
    
    public static let dateFormatter_CST : DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "CST")
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        return formatter
    }()
    
    public static let dateFormatter_UTC : DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "CST")
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        return formatter
    }()
    
}
