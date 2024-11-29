//
//  AlertView.swift
//  LightsOut

import SwiftUI

struct CustomAlertView: View {
    let title: String
    let message: String
    let primaryButton: (String, () -> Void)
    let secondaryButton: (String, () -> Void)

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Alert container
            VStack(spacing: 24) {
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Message
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                // Buttons
                HStack(spacing: 12) {
                    // Secondary button
                    Text(secondaryButton.0)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .onTapGesture(perform: secondaryButton.1)
                

                    // Primary button
                    Text(primaryButton.0)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.8), lineWidth: 1)
                        )
                        .onTapGesture(perform: primaryButton.1)
                
                }
            }
            .padding(20)
            .background(Color("Background")) // Replace with a flat custom dark gray color
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 40)
        }
    }
}
