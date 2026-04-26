//
//  OnboardingScreen.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation

struct OnboardingScreenModel: Identifiable {
  var id = UUID()

  let title: String
  let iconName: String

  var heading: String?
  var description: String?
  var isRadioSetup: Bool
  var isSpotifySetup: Bool

  init(
    title: String, iconName: String, heading: String? = nil, description: String? = nil,
    isRadioSetup: Bool = false, isSpotifySetup: Bool = false
  ) {
    self.title = title
    self.iconName = iconName
    self.heading = heading
    self.description = description
    self.isRadioSetup = isRadioSetup
    self.isSpotifySetup = isSpotifySetup
  }
}
