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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.wheel)
                .frame(width: 200, height: 200)
                .overlay(VStack {
                    Button(action: {
                        views[GlobalState.shared.activeView]?.menuClick()
                    }) {
                        VStack {
                            Image("menu")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.wheelButton)
                            
                            Spacer()
                        }
                        .frame(width: 40.0, height: 40.0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 80.0, height: 40.0)
                    
                    HStack (spacing: 5) {
                        Spacer()
                        
                        Button(action: {
                            views[GlobalState.shared.activeView]?.prevClick()
                        }) {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .foregroundColor(.wheelButton)
                                    .frame(width: 3, height: 15)
                                Image("left")
                                    .foregroundColor(.wheelButton)
                                Image("left")
                                    .foregroundColor(.wheelButton)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 40.0, height: 80.0)
                        
                        
                        Button(action: {
                            views[GlobalState.shared.activeView]?.middleClick()
                        }) {
                            Circle()
                                .fill(.base)
                                .frame(width: 80, height: 80)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        
                        Button(action: {
                            views[GlobalState.shared.activeView]?.nextClick()
                        }) {
                            
                            HStack(spacing: 0) {
                                Spacer()
                                Image("right")
                                    .foregroundColor(.wheelButton)
                                Image("right")
                                    .foregroundColor(.wheelButton)
                                Rectangle()
                                    .foregroundColor(.wheelButton)
                                    .frame(width: 3, height: 15)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 40.0, height: 40.0)

                        Spacer()
                    }
                    
                    
                    Button(action: {
                        views[GlobalState.shared.activeView]?.playPauseClick()
                    }) {
                        VStack {
                            Spacer()
                            HStack(spacing: 5) {
                                Image("right")
                                    .foregroundColor(.wheelButton)
                                
                                Rectangle()
                                    .foregroundColor(.wheelButton)
                                    .frame(width: 3, height: 15)
                                Rectangle()
                                    .foregroundColor(.wheelButton)
                                    .frame(width: 3, height: 15)
                            }
                        }
                        .frame(width: 40.0, height: 40.0)
                        .contentShape(Rectangle())
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

#Preview {
    ClickWheel(views: [:])
}
