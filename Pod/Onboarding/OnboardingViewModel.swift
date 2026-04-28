//
//  OnboardingViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case rotate
    case menu
    case skip
    case playPause
    case select
    case music
    case spotify
    case radio
    case ready
}

class OnboardingViewModel: ProtocolView {
    var view: AnyView {
        AnyView(Onboarding(viewModel: self))
    }

    @Published var step: OnboardingStep = .welcome
    @Published var hasScrolledUp = false
    @Published var hasScrolledDown = false
    @Published var pressedPrev = false
    @Published var pressedNext = false

    private let hapticManager = NSHapticFeedbackManager.defaultPerformer

    func applyHighlight() {
        switch step {
        case .welcome:   GlobalState.shared.highlightedWheelControl = .middle
        case .rotate:    GlobalState.shared.highlightedWheelControl = .ring
        case .menu:      GlobalState.shared.highlightedWheelControl = .menu
        case .skip:      GlobalState.shared.highlightedWheelControl = .prev
        case .playPause: GlobalState.shared.highlightedWheelControl = .playPause
        case .select:    GlobalState.shared.highlightedWheelControl = .middle
        case .music, .spotify, .radio, .ready:
            GlobalState.shared.highlightedWheelControl = .middle
        }
    }

    func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
            applyHighlight()
        } else {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            GlobalState.shared.highlightedWheelControl = nil
            GlobalState.shared.activeView = .mainMenu
        }
    }

    func retreat() {
        if let prev = OnboardingStep(rawValue: step.rawValue - 1), step != .welcome {
            step = prev
            applyHighlight()
        }
    }

    // MARK: - Wheel inputs

    func wheelUp() {
        hapticManager.perform(.generic, performanceTime: .now)
        if step == .rotate {
            hasScrolledUp = true
            tryAdvanceRotate()
        }
    }

    func wheelDown() {
        hapticManager.perform(.generic, performanceTime: .now)
        if step == .rotate {
            hasScrolledDown = true
            tryAdvanceRotate()
        }
    }

    private func tryAdvanceRotate() {
        guard hasScrolledUp && hasScrolledDown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.step == .rotate else { return }
            self.advance()
        }
    }

    func menuClick() {
        switch step {
        case .menu:
            advance()
        case .spotify, .radio, .music, .ready, .select, .playPause, .skip, .rotate:
            retreat()
        case .welcome:
            break
        }
    }

    func nextClick() {
        if step == .skip {
            pressedNext = true
            updateSkipHighlight()
            tryAdvanceSkip()
        }
    }

    func prevClick() {
        if step == .skip {
            pressedPrev = true
            updateSkipHighlight()
            tryAdvanceSkip()
        }
    }

    private func updateSkipHighlight() {
        if !pressedPrev {
            GlobalState.shared.highlightedWheelControl = .prev
        } else if !pressedNext {
            GlobalState.shared.highlightedWheelControl = .next
        }
    }

    private func tryAdvanceSkip() {
        guard pressedPrev && pressedNext else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.step == .skip else { return }
            self.advance()
        }
    }

    func playPauseClick() {
        if step == .playPause {
            advance()
        }
    }

    func middleClick() {
        switch step {
        case .rotate:
            // require both rotation directions before allowing skip
            if hasScrolledUp && hasScrolledDown { advance() }
        case .skip:
            if pressedPrev && pressedNext { advance() }
        default:
            advance()
        }
    }
}
