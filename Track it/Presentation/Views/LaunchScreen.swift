//
//  LaunchScreen.swift
//  Track It
//
//  Created by Arvoldek on 07/06/2026.
//

import SwiftUI

/// Launch screen shown while the app is loading
struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // App icon with checkmark symbol
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(Color("LaunchIcon"))
                    .symbolEffect(.bounce, value: true)

                Text("Track It")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color("LaunchText"))
                    .transition(.opacity)
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.5), value: true)
    }
}

/// Preview for LaunchScreen
#Preview {
    LaunchScreen()
}
