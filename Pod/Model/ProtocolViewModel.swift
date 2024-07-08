//
//  ProtocolView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import Foundation

protocol ProtocolView: ObservableObject {
    func nextClick()
    func prevClick()
    func playPauseClick()
    func middleClick()
    func wheelUp()
    func wheelDown()
    func menuClick()
}
