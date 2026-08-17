//
//  DataTypes+Extensions.swift
//  YetAnotherNotch
//
//  Created by Harsh Vardhan  Goswami  on 27/08/24.
//

import Foundation

extension NSSize {
    var aspectRatio: Double {
        width / height
    }

    func scaled(by factor: Double) -> CGSize {
        CGSize(width: (width * factor).evenInt, height: (height * factor).evenInt)
    }
}

extension Double {
    var i: Int { Int(self) }

    /// Rounded up to an even integer. Odd pixel dimensions make the notch blur on retina.
    var evenInt: Int {
        let x = rounded().i
        return x + x % 2
    }
}
