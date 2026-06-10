//
//  ContentView.swift
//  TapFrenzy
//
//  Created by Student2 on 2026-06-10.
//

import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var points = 0
    @State private var timeRemaining = 60
    @State private var gameStarted = false
    @State private var gameOver = false
    
    // Position coordinates for the button
    @State private var buttonX: CGFloat = 0
    @State private var buttonY: CGFloat = 0
    
    // Size tracker for the button (starts at 150)
    @State private var buttonSize: CGFloat = 150
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack { // ZStack lets us layer the Score Board directly on top of the game
                
                // --- LAYER 1: THE MAIN GAME ---
                VStack {
                    // Top Bar: Points and Time
                    HStack {
                        Text("Points: \(points)")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Text("Time: \(timeRemaining)s")
                            .font(.title2)
                            .bold()
                            .foregroundColor(timeRemaining <= 10 ? .red : .primary) // Turns red in last 10s
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    
                    // The Playable Area
                    ZStack {
                        // The Game Button
                        Button(action: {
                            if !gameStarted {
                                gameStarted = true
                                moveButtonRandomly(in: geometry.size)
                            }
                            
                            if !gameOver {
                                points += 1
                                moveButtonRandomly(in: geometry.size)
                            }
                        }) {
                            Text("Tap")
                                .font(buttonSize > 80 ? .title : .body)
                                .bold()
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        }
                        .disabled(gameOver)
                        .position(x: buttonX == 0 ? geometry.size.width / 2 : buttonX,
                                  y: buttonY == 0 ? geometry.size.height / 2 : buttonY)
                        .animation(.easeInOut(duration: 0.2), value: buttonX)
                        .animation(.easeInOut(duration: 0.2), value: buttonSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .blur(radius: gameOver ? 5 : 0) // Blurs out the game field when game over pops up!
                
                // --- LAYER 2: THE SCORE BOARD OVERLAY ---
                if gameOver {
                    Color.black.opacity(0.5) // Darkens the background slightly
                        .ignoresSafeArea()
                    
                    VStack(spacing: 25) {
                        Text("🏆 GAME OVER 🏆")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.orange)
                        
                        Text("Final Score")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(points)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(points > 40 ? "Frenzy Master! 🔥" : "Nice Try! 👍")
                            .font(.subheadline)
                            .italic()
                        
                        // Restart Button
                        Button(action: {
                            resetGame(in: geometry.size)
                        }) {
                            Text("Play Again")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(30)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(radius: 20)
                    .padding(40) // Keeps the popup away from the screen edge
                    .transition(.scale.combined(with: .opacity)) // Smooth popup animation
                }
            }
            .onAppear {
                buttonX = geometry.size.width / 2
                buttonY = geometry.size.height / 2
            }
            .onReceive(timer) { _ in
                if gameStarted && timeRemaining > 0 {
                    timeRemaining -= 1
                    
                    moveButtonRandomly(in: geometry.size)
                    
                    if buttonSize > 60 {
                        buttonSize -= 1.5
                    }
                    
                    if timeRemaining == 0 {
                        withAnimation {
                            gameOver = true
                        }
                    }
                }
            }
        }
    }
    
    // Calculates a safe random position on the screen
    func moveButtonRandomly(in screenSize: CGSize) {
        let padding: CGFloat = buttonSize / 2 + 20
        let minX = padding
        let maxX = screenSize.width - padding
        let minY = padding + 80
        let maxY = screenSize.height - padding
        
        buttonX = CGFloat.random(in: minX...maxX)
        buttonY = CGFloat.random(in: minY...maxY)
    }
    
    // Resets everything back to original state for a clean game
    func resetGame(in screenSize: CGSize) {
        withAnimation {
            points = 0
            timeRemaining = 60
            buttonSize = 150
            gameStarted = false
            gameOver = false
            buttonX = screenSize.width / 2
            buttonY = screenSize.height / 2
        }
    }
}

#Preview {
    ContentView()
}
