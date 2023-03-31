//
//  Extensions.swift
//  nostrnode
//
//  Created by Peter Denton on 3/30/23.
//

import Foundation

extension Data {
    var hex: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}
