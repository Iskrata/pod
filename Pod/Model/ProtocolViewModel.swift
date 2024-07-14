//
//  ProtocolView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import SwiftUI

protocol ProtocolView: ObservableObject {
    var view: AnyView { get }

    func nextClick()
    func prevClick()
    func playPauseClick()
    func middleClick()
    func wheelUp()
    func wheelDown()
    func menuClick()
}
