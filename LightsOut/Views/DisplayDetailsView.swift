    //
//  DisplayDetails.swift
//  BlackoutTest
//
//  Created by Alon Natapov on 26/11/2024.
//

import SwiftUI

struct DisplayDetails: View {
    @ObservedObject var display: DisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(display.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            if display.isPrimary {
                Text("Primary Display")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("AppBlue"))
                    )
            }
        }
    }
}

