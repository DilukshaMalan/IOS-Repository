//
//  ContentView.swift
//  TapFrenzy
//
//  Created by Student2 on 2026-06-10.
//

import SwiftUI
internal import Combine

struct ContentView: View {
    // Game variables that SwiftUI will watch and update on the screen automatically
    @State private var points = 0
    @State private var timeRemaining = 60
    @State private var gameStarted = false
    @State private var gameOver = false
    
    // This is the timer clock that ticks every 1 second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 40) {
            
            // 1. Points Tracker
            Text("Points: \(points)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Spacer()
            
            // 2. The Game Button
            Button(action: {
                // This logic runs whenever the button is clicked
                if !gameStarted {
                    gameStarted = true // Start the countdown timer on the very first tap
                }
                
                if !gameOver {
                    points += 1 // Increase score by 1 point per tap if game is active
                }
            }) {
                Text(gameOver ? "Done!" : "Tap")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .frame(width: 150, height: 150)
                    // The color automatically switches to red if gameOver is true, otherwise stays blue
                    .background(gameOver ? Color.red : Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }
            // This disables the button completely when gameOver is true
            .disabled(gameOver)
            
            Spacer()
            
            // 3. Time Remaining Tracker
            Text(gameOver ? "Game Over!" : "Time: \(timeRemaining)s")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(gameOver ? .red : .secondary)
                .padding(.bottom, 20)

        }
        .padding()
        // This listens to our timer clock and handles the countdown logic
        .onReceive(timer) { _ in
            // Only countdown if the player has started the game and time hasn't run out
            if gameStarted && timeRemaining > 0 {
                timeRemaining -= 1
                
                // When time hits 0, trigger Game Over rules
                if timeRemaining == 0 {
                    gameOver = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
