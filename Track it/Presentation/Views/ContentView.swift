//
//  ContentView.swift
//  Track It
//
//  Created by Arvoldek on 07/06/2026.
//

import SwiftUI

/// Main content view of the application
/// This will be replaced with the actual tracker list view in later phases
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 40)

                Text("Welcome to Track It")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)

                Text("Start tracking your habits today")
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                NavigationLink {
                    Text("Trackers")
                        .navigationTitle("Trackers")
                } label: {
                    Text("Get Started")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

/// Preview for ContentView
#Preview {
    ContentView()
}
