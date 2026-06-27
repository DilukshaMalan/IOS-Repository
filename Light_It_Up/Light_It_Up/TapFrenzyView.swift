//
//  TapFrenzyView.swift
//  TapFrenzy
//
//  Redesigned with: Glassmorphism UI, split-button mechanic,
//  encourage popups, 20-second game, red/green button logic.
//

import SwiftUI
internal import Combine

// MARK: - Encourage Messages
let encourageMessages = ["Great! 🎯", "Super! ⚡", "Excellent! 🔥", "Amazing! 💥", "Perfect! ✨", "Boom! 💪", "Nice! 🚀"]

// MARK: - Button Model
struct GameButton: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var isRed: Bool   // red = deduct, green = earn
}

// MARK: - Glass Modifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

// MARK: - Encourage Popup View
struct EncouragePopup: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 12)
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
    }
}

// MARK: - Main Content View
struct TapFrenzyView: View {

    // MARK: Persistent High Score
    @AppStorage("tapFrenzyHighScore") private var highScore: Int = 0

    // MARK: Game State
    @State private var points = 0
    @State private var timeRemaining = 20          // ← 20 seconds
    @State private var gameStarted = false
    @State private var gameOver = false
    @State private var newHighScore = false         // flag to show "NEW BEST!" banner

    // MARK: Buttons (1 or 2)
    @State private var buttons: [GameButton] = []
    @State private var baseSize: CGFloat = 130      // shrinks every second

    // MARK: Encourage Popup
    @State private var currentMessage: String? = nil
    @State private var consecutiveTaps = 0

    // MARK: Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // ── BACKGROUND ──────────────────────────────────────────
                meshBackground

                // ── GAME LAYER ──────────────────────────────────────────
                VStack(spacing: 0) {

                    // Top HUD
                    hudBar

                    // Play Area
                    ZStack {
                        // Encourage popup (floats in upper-center of play area)
                        if let msg = currentMessage {
                            EncouragePopup(message: msg)
                                .zIndex(10)
                                .position(x: geometry.size.width / 2,
                                           y: 60)
                                .animation(.spring(response: 0.3), value: currentMessage)
                        }

                        // Game Buttons
                        ForEach(buttons) { btn in
                            gameButtonView(btn: btn, geometry: geometry)
                        }

                        // START PROMPT (before game begins)
                        if !gameStarted && !gameOver {
                            startPrompt(geometry: geometry)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .blur(radius: gameOver ? 6 : 0)

                // ── SCORE OVERLAY ───────────────────────────────────────
                if gameOver {
                    scoreOverlay(geometry: geometry)
                }
            }
            .onAppear {
                spawnSingleButton(in: geometry.size)
            }
            .onReceive(timer) { _ in
                guard gameStarted && !gameOver else { return }
                tickGame(in: geometry.size)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background
    var meshBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.18),
                    Color(red: 0.08, green: 0.04, blue: 0.25),
                    Color(red: 0.02, green: 0.10, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Neon blobs for atmosphere
            Circle()
                .fill(Color.purple.opacity(0.25))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(x: -100, y: -180)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: 240)

            Circle()
                .fill(Color.indigo.opacity(0.20))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 60, y: 100)
        }
        .ignoresSafeArea()
    }

    // MARK: - HUD Bar
    var hudBar: some View {
        HStack {
            // Current score
            Label("\(points)", systemImage: "star.fill")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )

            Spacer()

            // High score badge (centre)
            VStack(spacing: 1) {
                Text("BEST")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1)
                Text("\(highScore)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.yellow.opacity(0.25), lineWidth: 1))

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(timeRemaining <= 5 ? .red : .white)
                Text("\(timeRemaining)s")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(timeRemaining <= 5 ? .red : .white)
                    .animation(.easeInOut, value: timeRemaining)
                    .scaleEffect(timeRemaining <= 5 ? 1.2 : 1.0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .background(Color.black.opacity(0.30))
        .overlay(
            Divider()
                .background(Color.white.opacity(0.08)),
            alignment: .bottom
        )
    }

    // MARK: - Start Prompt
    func startPrompt(geometry: GeometryProxy) -> some View {
        VStack(spacing: 14) {
            Text("TAP FRENZY")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                )
            Text("Tap the \u{1F7E2} green button to earn points\nAvoid the \u{1F534} red button!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Text("Tap anywhere to begin")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(30)
        .glassCard()
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }

    // MARK: - Game Button View
    func gameButtonView(btn: GameButton, geometry: GeometryProxy) -> some View {
        let color: Color = btn.isRed ? .red : .green
        let glowColor: Color = btn.isRed ? Color.red.opacity(0.6) : Color.green.opacity(0.6)
        let label: String = btn.isRed ? "✕" : "✓"

        return Button(action: {
            handleTap(btn: btn, in: geometry.size)
        }) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(glowColor)
                    .blur(radius: 18)
                    .frame(width: btn.size + 24, height: btn.size + 24)

                // Glass circle body
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [color.opacity(0.9), color.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .frame(width: btn.size, height: btn.size)

                // Inner fill
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.55), color.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: btn.size - 8, height: btn.size - 8)

                // Label
                Text(label)
                    .font(.system(size: btn.size * 0.36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        }
        .buttonStyle(TapScaleStyle())
        .disabled(gameOver)
        .position(x: btn.x, y: btn.y)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: btn.x)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: btn.y)
        .animation(.easeInOut(duration: 0.3), value: btn.size)
    }

    // MARK: - Score Overlay
    func scoreOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("🏆 GAME OVER 🏆")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )

                // New high score banner
                if newHighScore {
                    Text("🎉 NEW BEST!")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                }

                Text("Final Score")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))

                Text("\(points)")
                    .font(.system(size: 86, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                    )

                // High score row
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow.opacity(0.7))
                        .font(.system(size: 13))
                    Text("Best: \(highScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }

                Text(scoreTagline)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .italic()
                    .foregroundColor(.white.opacity(0.6))

                Button(action: {
                    resetGame(in: geometry.size)
                }) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.85), Color.cyan.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .green.opacity(0.4), radius: 12)
                }
                .buttonStyle(TapScaleStyle())
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }
            .padding(30)
            .glassCard()
            .padding(.horizontal, 36)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: - Score Tagline
    var scoreTagline: String {
        switch points {
        case ..<0:   return "Better luck next time… 😅"
        case 0..<10: return "Keep practicing! 👍"
        case 10..<20: return "Getting there! 💪"
        case 20..<30: return "Nice work! 🔥"
        default:     return "Frenzy Master! 🚀"
        }
    }

    // MARK: - Game Logic

    /// Called every second while game is active
    func tickGame(in size: CGSize) {
        timeRemaining -= 1

        // Shrink the base size
        if baseSize > 55 { baseSize -= 4 }

        // Move / refresh buttons
        if Bool.random() && buttons.count == 1 {
            // ~50% chance to split into two buttons
            spawnTwoButtons(in: size)
        } else if Bool.random() && buttons.count == 2 {
            // ~50% chance to merge back to one
            spawnSingleButton(in: size)
        } else {
            moveAllButtonsRandomly(in: size)
        }

        if timeRemaining == 0 {
            // Save high score
            if points > highScore {
                highScore = points
                newHighScore = true
            }
            withAnimation(.spring()) { gameOver = true }
        }
    }

    /// Handle a button tap
    func handleTap(btn: GameButton, in size: CGSize) {
        if !gameStarted {
            gameStarted = true
        }
        guard !gameOver else { return }

        if btn.isRed {
            // Red → deduct
            points = max(points - 1, 0)
            consecutiveTaps = 0
            hideEncourageMessage()
        } else {
            // Green → earn
            points += 1
            consecutiveTaps += 1
            showEncourageMessage()
        }

        // After every tap, reshuffle positions
        if Bool.random() {
            spawnTwoButtons(in: size)
        } else {
            spawnSingleButton(in: size)
        }
    }

    /// Show a random encourage message, auto-dismiss after 0.9s
    func showEncourageMessage() {
        let msg = encourageMessages.randomElement() ?? "Great!"
        withAnimation(.spring(response: 0.3)) {
            currentMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) {
                currentMessage = nil
            }
        }
    }

    func hideEncourageMessage() {
        withAnimation { currentMessage = nil }
    }

    // MARK: - Button Spawn Helpers

    func safeX(size: CGSize, pad: CGFloat) -> CGFloat {
        CGFloat.random(in: pad...(size.width - pad))
    }

    func safeY(size: CGSize, pad: CGFloat) -> CGFloat {
        CGFloat.random(in: (pad + 110)...(size.height - pad - 30))
    }

    func spawnSingleButton(in size: CGSize) {
        let sz = baseSize
        let pad = sz / 2 + 20
        buttons = [
            GameButton(
                x: safeX(size: size, pad: pad),
                y: safeY(size: size, pad: pad),
                size: sz,
                isRed: false
            )
        ]
    }

    func spawnTwoButtons(in size: CGSize) {
        // Red is slightly larger, green is slightly smaller
        let redSize  = baseSize + 18
        let greenSize = baseSize - 14

        let padR = redSize  / 2 + 20
        let padG = greenSize / 2 + 20

        let redBtn = GameButton(
            x: safeX(size: size, pad: padR),
            y: safeY(size: size, pad: padR),
            size: redSize,
            isRed: true
        )
        let greenBtn = GameButton(
            x: safeX(size: size, pad: padG),
            y: safeY(size: size, pad: padG),
            size: greenSize,
            isRed: false
        )
        buttons = [redBtn, greenBtn]
    }

    func moveAllButtonsRandomly(in size: CGSize) {
        buttons = buttons.map { btn in
            let pad = btn.size / 2 + 20
            return GameButton(
                x: safeX(size: size, pad: pad),
                y: safeY(size: size, pad: pad),
                size: btn.size,
                isRed: btn.isRed
            )
        }
    }

    // MARK: - Reset
    func resetGame(in size: CGSize) {
        withAnimation(.spring()) {
            points = 0
            timeRemaining = 20
            baseSize = 130
            gameStarted = false
            gameOver = false
            consecutiveTaps = 0
            currentMessage = nil
            newHighScore = false
        }
        spawnSingleButton(in: size)
    }
}

// MARK: - Press Scale Button Style
struct TapScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    TapFrenzyView()
}