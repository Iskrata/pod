//
//  ContentView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import AppKit
import SwiftUI

struct DiagonalBackgroundView: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.base
          .edgesIgnoringSafeArea(.all)

        Path { path in
          let width = geometry.size.width
          let height = geometry.size.height

          path.move(to: CGPoint(x: width, y: height - 30))
          path.addLine(to: CGPoint(x: 30, y: 0))
          path.addLine(to: CGPoint(x: width, y: 0))
          path.addLine(to: CGPoint(x: width, y: height - 30))
        }
        .fill(.subBase)
      }
    }.clipped()
  }
}

struct ContentView: View {
  @AppStorage("fontSize") var fontSize = 13.0

  @StateObject private var globalState = GlobalState.shared

  private let views: [Screen: any ProtocolView] = [
    .onboarding: OnboardingViewModel(),
    .song: GlobalState.shared.songViewModel,
    .albums: GlobalState.shared.albumViewModel,
  ]

  var body: some View {
    ZStack {
      VStack {
        Rectangle()
          .fill(Color.white)
          .frame(width: 320, height: 240)
          .overlay(
            ZStack {
              if let currentView = views[globalState.activeView]?.view {
                AnyView(currentView)
              } else {
                Text("No View Available")
              }
            }
          )
          .border(Color.black, width: 4)
          .shadow(radius: 10)
          .cornerRadius(5)

        Spacer()

        ClickWheel(views: views)
      }
      .padding()
    }.background(DiagonalBackgroundView())
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
