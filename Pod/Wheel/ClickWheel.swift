//
//  ClickWheel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 12.07.24.
//

import SwiftUI

class WheelState: ObservableObject {
    static let shared = WheelState()
    var lastAngle: Double?
    var scrollDirections: [Double] = []
}

struct ClickWheel: View {
    var views: [Screen: any ProtocolView]
    private let wheelState = WheelState.shared
    @ObservedObject private var globalState = GlobalState.shared

    func handleDragChange(value: DragGesture.Value) {
        let center = CGPoint(x: 150, y: 150)
        let currentPoint = CGPoint(x: value.location.x, y: value.location.y)

        let angle = atan2(currentPoint.y - center.y, currentPoint.x - center.x) * 180 / .pi

        if let lastAngle = wheelState.lastAngle {
            var angleDelta = angle - lastAngle

            if angleDelta > 180 {
                angleDelta -= 360
            } else if angleDelta < -180 {
                angleDelta += 360
            }

            if abs(angleDelta) > 5 {
                wheelState.scrollDirections.append(angleDelta)

                if wheelState.scrollDirections.count > 5 {
                    wheelState.scrollDirections.removeFirst()
                }

                if wheelState.scrollDirections.count == 5 {
                    let averageDirection = wheelState.scrollDirections.reduce(0, +) / Double(wheelState.scrollDirections.count)

                    SoundManager.shared.playTick()
                    if averageDirection > 0 {
                        views[GlobalState.shared.activeView]?.wheelDown()
                        wheelState.scrollDirections.removeAll()
                    } else {
                        views[GlobalState.shared.activeView]?.wheelUp()
                        wheelState.scrollDirections.removeAll()
                    }
                }
            }
        }
        wheelState.lastAngle = angle
    }

    private func isHL(_ c: WheelControl) -> Bool {
        globalState.highlightedWheelControl == c
    }

    var body: some View {
        ZStack {
            // Base wheel circle (with optional ring highlight overlay around the perimeter)
            Circle()
                .fill(.wheel)
                .frame(width: 200, height: 200)
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: isHL(.ring) ? 4 : 0)
                        .padding(2)
                        .modifier(PulseModifier(active: isHL(.ring), kind: .ring))
                )
                .overlay(VStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        views[GlobalState.shared.activeView]?.menuClick()
                    }) {
                        VStack {
                            Image("menu")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(isHL(.menu) ? .accentColor : .wheelButton)

                            Spacer()
                        }
                        .frame(width: 40.0, height: 40.0)
                        .contentShape(Rectangle())
                        .modifier(PulseModifier(active: isHL(.menu), kind: .button))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 80.0, height: 40.0)

                    HStack (spacing: 5) {
                        Spacer()

                        Button(action: {
                            SoundManager.shared.playClick()
                            views[GlobalState.shared.activeView]?.prevClick()
                        }) {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .foregroundColor(isHL(.prev) ? .accentColor : .wheelButton)
                                    .frame(width: 3, height: 15)
                                Image("left")
                                    .foregroundColor(isHL(.prev) ? .accentColor : .wheelButton)
                                Image("left")
                                    .foregroundColor(isHL(.prev) ? .accentColor : .wheelButton)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .modifier(PulseModifier(active: isHL(.prev), kind: .button))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 40.0, height: 80.0)


                        Button(action: {
                            SoundManager.shared.playClick()
                            views[GlobalState.shared.activeView]?.middleClick()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.base)
                                    .frame(width: 80, height: 80)
                            }
                            .modifier(PulseModifier(active: isHL(.middle), kind: .center))
                        }
                        .buttonStyle(PlainButtonStyle())


                        Button(action: {
                            SoundManager.shared.playClick()
                            views[GlobalState.shared.activeView]?.nextClick()
                        }) {

                            HStack(spacing: 0) {
                                Spacer()
                                Image("right")
                                    .foregroundColor(isHL(.next) ? .accentColor : .wheelButton)
                                Image("right")
                                    .foregroundColor(isHL(.next) ? .accentColor : .wheelButton)
                                Rectangle()
                                    .foregroundColor(isHL(.next) ? .accentColor : .wheelButton)
                                    .frame(width: 3, height: 15)
                            }
                            .contentShape(Rectangle())
                            .modifier(PulseModifier(active: isHL(.next), kind: .button))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 40.0, height: 40.0)

                        Spacer()
                    }


                    Button(action: {
                        SoundManager.shared.playClick()
                        views[GlobalState.shared.activeView]?.playPauseClick()
                    }) {
                        VStack {
                            Spacer()
                            HStack(spacing: 5) {
                                Image("right")
                                    .foregroundColor(isHL(.playPause) ? .accentColor : .wheelButton)

                                Rectangle()
                                    .foregroundColor(isHL(.playPause) ? .accentColor : .wheelButton)
                                    .frame(width: 3, height: 15)
                                Rectangle()
                                    .foregroundColor(isHL(.playPause) ? .accentColor : .wheelButton)
                                    .frame(width: 3, height: 15)
                            }
                        }
                        .frame(width: 40.0, height: 40.0)
                        .contentShape(Rectangle())
                        .modifier(PulseModifier(active: isHL(.playPause), kind: .button))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 80.0, height: 40.0)

                }.padding(12)).padding(30)
        }
        .simultaneousGesture(DragGesture().onChanged { value in
            self.handleDragChange(value: value)
        })
    }
}

private struct PulseModifier: ViewModifier {
    let active: Bool
    enum Kind { case ring, button, center }
    let kind: Kind
    @State private var phase: Bool = false

    private var pulseDuration: Double { 0.55 }

    func body(content: Content) -> some View {
        Group {
            switch kind {
            case .ring:
                content
                    .scaleEffect(active && phase ? 1.04 : 1.0)
                    .opacity(active ? (phase ? 1.0 : 0.35) : 1.0)
                    .shadow(color: active ? Color.accentColor.opacity(phase ? 0.9 : 0.2) : .clear, radius: phase ? 10 : 4)
            case .button:
                content
                    .scaleEffect(active && phase ? 1.35 : 1.0)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(active ? (phase ? 0.7 : 0.15) : 0))
                            .blur(radius: 12)
                            .scaleEffect(2.2)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor.opacity(active ? (phase ? 1.0 : 0.3) : 0), lineWidth: active ? 2 : 0)
                            .scaleEffect(active && phase ? 1.6 : 1.2)
                            .allowsHitTesting(false)
                    )
            case .center:
                content
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: active ? 4 : 0)
                            .scaleEffect(active && phase ? 1.18 : 1.02)
                            .opacity(active ? (phase ? 1.0 : 0.25) : 0)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        Circle()
                            .fill(Color.accentColor.opacity(active ? (phase ? 0.45 : 0.1) : 0))
                            .frame(width: 80, height: 80)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: active ? Color.accentColor.opacity(phase ? 0.8 : 0.2) : .clear, radius: active ? (phase ? 16 : 6) : 0)
            }
        }
        .onAppear { startPulseIfActive() }
        .onChange(of: active) { now in
            if now {
                phase = false
                startPulseIfActive()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { phase = false }
            }
        }
    }

    private func startPulseIfActive() {
        guard active else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

#Preview {
    ClickWheel(views: [:])
}
