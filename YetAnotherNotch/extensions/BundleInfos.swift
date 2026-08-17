//
//  BundleInfos.swift
//  YetAnotherNotch
//
//  Created by Richard Kunkli on 08/08/2024.
//

import SwiftUI

extension Bundle {
    var releaseVersionNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }
}
