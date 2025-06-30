//
//  Gradients.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/30/25.
//

import SwiftUI

extension LinearGradient {
    static var metallicGold: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "FEEEB6"), // Lighter Gold
                Color(hex: "B49248")  // Darker Gold
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// A small helper to allow us to initialize a Color with a Hex string
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
