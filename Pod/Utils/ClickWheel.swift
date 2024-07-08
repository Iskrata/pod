//
//  ClickWheel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 2.07.24.
//

import SwiftUI

class ClickWheel: ObservableObject {
    @Published private var lastAngle: Double?
    @Published private var scrollDirections: [Double] = []
    @Published private var rotation: Double = 0.0

    func handleDragChange(value: Int) {
    }

}
