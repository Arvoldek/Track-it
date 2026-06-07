//
//  TrackItApp.swift
//  Track It
//
//  Created by Arvoldek on 07/06/2026.
//

import SwiftUI

/// Main application entry point
@main
struct TrackItApp: App {
    
    /// Application state controller
    @StateObject private var appState = AppState()
    
    /// Persistence controller for Core Data
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            // Show launch screen briefly
            ZStack {
                LaunchScreen()
                    .opacity(appState.showLaunchScreen ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: appState.showLaunchScreen)
                    .onAppear {
                        // Hide launch screen after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                appState.showLaunchScreen = false
                            }
                        }
                    }
                
                // Main content
                if !appState.showLaunchScreen {
                    ContentView()
                        .transition(.opacity)
                }
            }
        }
    }
}

/// Application state management
final class AppState: ObservableObject {
    @Published var showLaunchScreen: Bool = true
}
