//
//  SignInResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct SignInResponse: Decodable {
    let redirectUrl: URL
    let popup: Bool
    let method: String
    let upgrade: Bool
    let integrated: Bool
    let deleteAccountLink: String
    
    var code: String? {
        let pattern = "=([^\"]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            
            let string = redirectUrl.absoluteString
            let nsString = string as NSString
            let results = regex.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, let range = Range(match.range(at: 1), in: string) {
                return String(string[range]).replacingOccurrences(of: "&amp;", with: "&")
            }
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
        }
        return nil
    }
}
