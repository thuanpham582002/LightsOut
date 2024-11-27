//
//  MenuBarView.swift
//  BlackoutTest
//
//  Created by Alon Natapov on 26/11/2024.
//
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @State private var isLoading: Bool = false
    @State private var isSpinning: Bool = false
    @State private var cachedHeight: CGFloat = 200

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
