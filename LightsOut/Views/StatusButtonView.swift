//
//  DisplayStatusButtonView.swift
//  BlackoutTest
//
//  Created by Alon Natapov on 26/11/2024.
//

import SwiftUI

struct StatusButton: View {
    @Binding var isPending: Bool
    @Binding var pendingAnimationOpacity: Double
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isPending ? Color("AppBlue") : (display.isBlackedOut ? Color("AppRed") : Color("EnabledButton")))
                .frame(width: 90, height: 32)

            if isPending {
                Text("Pending")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(pendingAnimationOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            pendingAnimationOpacity = 0.3
                        }
                    }
            } else {
                Text(display.isBlackedOut ? "Disabled" : "Active")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            if isPending { return }

            if display.isBlackedOut {
                display.isBlackedOut.toggle()
                viewModel.unblackOutDisplay(displayID: display.id)
            } else {
                isPending = true
                viewModel.blackOutDisplay(displayID: display.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    display.isBlackedOut.toggle()
                    isPending = false
                    pendingAnimationOpacity = 1.0
                }
            }
        }
    }
}


