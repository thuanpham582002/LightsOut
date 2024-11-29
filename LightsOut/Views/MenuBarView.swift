//
//  MenuBarView.swift
//  BlackoutTest

import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @State private var isLoading: Bool = false
    @State private var isSpinning: Bool = false
    @State private var cachedHeight: CGFloat = 200
    @AppStorage("ShowStartupPrompt") private var showStartupPrompt: Bool = true
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(cachedHeight: $cachedHeight, isSpinning: $isSpinning)
            } else {
                ContentView(isLoading: $isLoading)
                    .environmentObject(viewModel)
                    .background(
                        GeometryReader { geometry in
                            Color("Background")
                                .onAppear {
                                    cachedHeight = geometry.size.height
                                }
                        }
                    )
                    .cornerRadius(8)
            }
            // Custom Alert Overlay
            if showStartupPrompt {
                CustomAlertView(
                    title: "Enable Launch at Login",
                    message: "Would you like this app to launch automatically when you log in?",
                    primaryButton: ("Yes", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = true
                    }),
                    secondaryButton: ("No", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = false
                    })
                )
            }
        }
        
        .animation(.snappy, value: isLoading)
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @Binding var isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            MenuBarHeader(isLoading: $isLoading)
            DisplayListView()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
