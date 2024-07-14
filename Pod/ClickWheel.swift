//
//  ClickWheel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 12.07.24.
//

import SwiftUI

struct ClickWheel: View {
    var views: [Screen: any ProtocolView]
    
    @State private var lastAngle: Double?
    @State private var scrollDirections: [Double] = []
    
    func handleDragChange(value: DragGesture.Value) {
        let center = CGPoint(x: 150, y: 150)
        let currentPoint = CGPoint(x: value.location.x, y: value.location.y)
        
        let angle = atan2(currentPoint.y - center.y, currentPoint.x - center.x) * 180 / .pi
        
        if let lastAngle = self.lastAngle {
            var angleDelta = angle - lastAngle
            
            if angleDelta > 180 {
                angleDelta -= 360
            } else if angleDelta < -180 {
                angleDelta += 360
            }
            
            if abs(angleDelta) > 5 {
                scrollDirections.append(angleDelta)
                
                if scrollDirections.count > 5 {
                    scrollDirections.removeFirst()
                }
                
                if scrollDirections.count == 5 {
                    let averageDirection = scrollDirections.reduce(0, +) / Double(scrollDirections.count)
                    
                    if averageDirection > 0 {
                        views[GlobalState.shared.activeView]?.wheelDown()
                        scrollDirections.removeAll()
                    } else {
                        views[GlobalState.shared.activeView]?.wheelUp()
                        scrollDirections.removeAll()
                        
                    }
                }
            }
        }
        self.lastAngle = angle
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
                                Image("left")
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
                                Image("right")
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
