//
//  DisplayListView.swift
//  BlackoutTest


import SwiftUI

struct DisplayListView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel

    var body: some View {
        VStack(spacing: 6) {
            if viewModel.displays.isEmpty {
                Text("No displays detected")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.displays) { display in
                    DisplayControlView(display: display)
                        .environmentObject(viewModel)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct DisplayControlView: View {
    @ObservedObject var display: DisplayInfo
    @State private var isPending: Bool = false
    @State private var pendingAnimationOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                DisplayDetails(display: display)
                Spacer()
                StatusButton(
                    isPending: $isPending,
                    pendingAnimationOpacity: $pendingAnimationOpacity,
                    display: display
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("TileBackground"))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .padding(.vertical, 3)
    }
}
