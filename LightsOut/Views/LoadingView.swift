//
//  LoadingView.swift
//  BlackoutTest


import SwiftUI

struct LoadingView: View {
    @Binding var cachedHeight: CGFloat
    @Binding var isSpinning: Bool

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.clockwise.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                .foregroundColor(.white)
                .onAppear { isSpinning = true }
                .onDisappear { isSpinning = false }
            Text("Refreshing displays")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .frame(width: 300, height: cachedHeight)
        .background(Color.blue)
        .cornerRadius(8)
    }
}
