//
//  DisplayStatusButtonView.swift
//  BlackoutTest

import SwiftUI

struct StatusButton: View {
    @ObservedObject var display: DisplayInfo
    @FocusState private var isFocused: Bool
    @State private var isShifted: Bool = false
    var body: some View {
        SoftButton(display: display)
    }

}

func printmem(of object: AnyObject) {
    let address = Unmanaged.passUnretained(object).toOpaque()
    print("Memory address: \(address)")
}

struct HardButton: View {
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(display.state == .pending ? Color("AppBlue") : (!display.state.isEnabled() ? Color("AppRed") : Color("EnabledButton")))
                .frame(width: 90, height: 32)

            if display.state == .pending {
                Text("Pending")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.3)

            } else {
                Text(!display.state.isEnabled() ? "Disabled" : "Active")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            if display.state == .pending { return }

            if !display.state.isEnabled() {
                viewModel.unSoftDisableDisplay(display: display)
            } else {
                viewModel.softDisableDisplay(display: display)
            }
        }
    }
}

struct SoftButton: View {
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(display.state == .pending ? Color("AppBlue") : (!display.state.isEnabled() ? Color("AppRed") : Color("EnabledButton")))
                .frame(width: 90, height: 32)

            if display.state == .pending {
                Text("Pending")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.3)

            } else {
                Text(!display.state.isEnabled() ? "Disabled" : "Active")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            printmem(of: display)
            if display.state == .pending { return }

            if !display.state.isEnabled() {
                viewModel.unSoftDisableDisplay(display: display)
                print("dis: \(display.state)")
            } else {
                viewModel.softDisableDisplay(display: display)
                print("dis: \(display.state)")

            }
        }
    }
}


