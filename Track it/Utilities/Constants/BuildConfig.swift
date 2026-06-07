//
//  BuildConfig.swift
//  Track It
//
//  Created by Arvoldek on 07/06/2026.
//

import Foundation

/// Configuration settings that vary between build environments
public enum BuildConfig {
    /// Whether the app is running in debug mode
    static let isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Base URL for API calls (if needed in future)
    static let baseURL: String = {
        #if DEBUG
        return "https://debug.api.trackit.example.com"
        #else
        return "https://api.trackit.example.com"
        #endif
    }()

    /// Whether to enable logging
    static let enableLogging: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Whether to enable analytics tracking
    static let enableAnalytics: Bool = {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }()

    /// Whether to use mock data for previews
    static let useMockData: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// App version from Info.plist
    static let appVersion: String = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    /// Build number from Info.plist
    static let buildNumber: String = {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()

    /// Complete version string with build number
    static let versionWithBuild: String = {
        return "v\(appVersion) (\(buildNumber))"
    }()
}
