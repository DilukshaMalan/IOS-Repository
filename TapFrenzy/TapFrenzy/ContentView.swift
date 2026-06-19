//
//  ContentView.swift
//  TapFrenzy
//
//  Redesigned with: Constrained Box Area, Anti-Overlap Logic,
//  Smooth Pop-up Animations, and Glassmorphism UI.
//

import SwiftUI
internal import Combine

// MARK: - Encourage Messages
let encourageMessages = ["Great! 🎯", "Super! ⚡", "Excellent! 🔥", "Amazing! 💥", "Perfect! ✨", "Boom! 💪", "Nice! 🚀"]

// MARK: - Button Model
struct GameButton: Identifiable {
    let id = UUID() // Changing ID forces a fresh pop-up animation
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
struct ContentView: View {

    // MARK: Game State
    @State private var points = 0
    @State private var timeRemaining = 20
    @State private var gameStarted = false
    @State private var gameOver = false

    // MARK: Buttons
    @State private var buttons: [GameButton] = []
    @State private var baseSize: CGFloat = 130      // shrinks every second

    // MARK: Encourage Popup
    @State private var currentMessage: String? = nil
    @State private var consecutiveTaps = 0

    // MARK: Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Body
    var body: some View {
        GeometryReader { mainGeometry in
            ZStack {
                // ── BACKGROUND ──────────────────────────────────────────
                meshBackground

                // ── GAME LAYER ──────────────────────────────────────────
                VStack(spacing: 0) {
                    
                    // Top HUD
                    hudBar
                        .padding(.top, mainGeometry.safeAreaInsets.top)

                    // Play Area (Strict Box Container)
                    GeometryReader { playArea in
                        ZStack {
                            // Visual border for the play area limit
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                                )

                            // Encourage popup
                            if let msg = currentMessage {
                                EncouragePopup(message: msg)
                                    .zIndex(10)
                                    .position(x: playArea.size.width / 2, y: 50)
                                    .animation(.spring(response: 0.3), value: currentMessage)
                            }

                            // Game Buttons
                            ForEach(buttons) { btn in
                                gameButtonView(btn: btn)
                            }

                            // START PROMPT
                            if !gameStarted && !gameOver {
                                startPrompt(in: playArea.size)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24)) // Ensure nothing escapes visually
                        .onAppear {
                            spawnSingleButton(in: playArea.size)
                        }
                        .onReceive(timer) { _ in
                            guard gameStarted && !gameOver else { return }
                            tickGame(in: playArea.size)
                        }
                    }
                    .padding(16) // Padding from the screen edges
                    .padding(.bottom, mainGeometry.safeAreaInsets.bottom + 10)
                }
                .blur(radius: gameOver ? 6 : 0)

                // ── SCORE OVERLAY ───────────────────────────────────────
                if gameOver {
                    scoreOverlay(in: mainGeometry.size)
                }
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
    }

    // MARK: - HUD Bar
    var hudBar: some View {
        HStack {
            Label("\(points)", systemImage: "star.fill")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )

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
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.30))
        .overlay(
            Divider().background(Color.white.opacity(0.08)),
            alignment: .bottom
        )
    }

    // MARK: - Start Prompt
    func startPrompt(in size: CGSize) -> some View {
        VStack(spacing: 14) {
            Text("TAP FRENZY")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                )
            Text("Tap the \u{1F7E2} green button\nAvoid the \u{1F534} red button!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Text("Tap anywhere to begin")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(24)
        .glassCard()
        .position(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Game Button View
    func gameButtonView(btn: GameButton) -> some View {
        let color: Color = btn.isRed ? .red : .green
        let glowColor: Color = btn.isRed ? Color.red.opacity(0.6) : Color.green.opacity(0.6)
        let label: String = btn.isRed ? "✕" : "✓"

        return Button(action: {
            // Because geometry depends on the parent playArea, passing the button tap upward
            handleTap(btn: btn)
        }) {
            ZStack {
                Circle()
                    .fill(glowColor)
                    .blur(radius: 18)
                    .frame(width: btn.size + 24, height: btn.size + 24)

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

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.55), color.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: btn.size - 8, height: btn.size - 8)

                Text(label)
                    .font(.system(size: btn.size * 0.36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        }
        .buttonStyle(TapScaleStyle())
        .disabled(gameOver)
        .position(x: btn.x, y: btn.y)
        // Smooth Pop-up transitions when spawned or removed
        .transition(.scale(scale: 0.1).combined(with: .opacity))
    }

    // MARK: - Score Overlay
    func scoreOverlay(in size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("🏆 GAME OVER 🏆")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))

                Text("Final Score")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))

                Text("\(points)")
                    .font(.system(size: 86, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))

                Text(scoreTagline)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .italic()
                    .foregroundColor(.white.opacity(0.6))

                Button(action: {
                    resetGame(in: size) // Note: this size is screen size, but reset overrides it momentarily
                }) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color.green.opacity(0.85), Color.cyan.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
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

    func tickGame(in size: CGSize) {
        timeRemaining -= 1
        if baseSize > 65 { baseSize -= 3 }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if Bool.random() && buttons.count == 1 {
                spawnTwoButtons(in: size)
            } else if Bool.random() && buttons.count == 2 {
                spawnSingleButton(in: size)
            } else {
                moveAllButtonsRandomly(in: size)
            }
        }

        if timeRemaining <= 0 {
            withAnimation(.spring()) { gameOver = true }
        }
    }

    func handleTap(btn: GameButton) {
        if !gameStarted { gameStarted = true }
        guard !gameOver else { return }

        if btn.isRed {
            points = max(points - 1, 0)
            consecutiveTaps = 0
            hideEncourageMessage()
        } else {
            points += 1
            consecutiveTaps += 1
            showEncourageMessage()
        }

        // Parent size is roughly available. We use a proxy size for immediate reshuffle.
        // We'll calculate a standard size since tap doesn't carry the direct geometry proxy.
        // A safer way is to just trigger the movement using the last known geometry.
        // We can just rely on the next tick, or recreate roughly.
        // For simplicity, we just trigger random move using a fixed assumed frame or let the timer handle it.
        // But instant feedback is better:
        let playAreaSize = CGSize(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.height - 200)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            if Bool.random() {
                spawnTwoButtons(in: playAreaSize)
            } else {
                spawnSingleButton(in: playAreaSize)
            }
        }
    }

    func showEncourageMessage() {
        let msg = encourageMessages.randomElement() ?? "Great!"
        withAnimation(.spring(response: 0.3)) {
            currentMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                currentMessage = nil
            }
        }
    }

    func hideEncourageMessage() {
        withAnimation { currentMessage = nil }
    }

    // MARK: - Button Spawning & Overlap Logic

    func safeX(size: CGSize, pad: CGFloat) -> CGFloat {
        // Ensure bounds are logical to prevent fatal errors
        let minX = pad
        let maxX = max(size.width - pad, minX)
        return CGFloat.random(in: minX...maxX)
    }

    func safeY(size: CGSize, pad: CGFloat) -> CGFloat {
        let minY = pad
        let maxY = max(size.height - pad, minY)
        return CGFloat.random(in: minY...maxY)
    }

    // Distance formula to check for overlaps
    func distanceBetween(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        return hypot(x2 - x1, y2 - y1)
    }

    func spawnSingleButton(in size: CGSize) {
        let pad = baseSize / 2 + 10
        buttons = [
            GameButton(x: safeX(size: size, pad: pad), y: safeY(size: size, pad: pad), size: baseSize, isRed: false)
        ]
    }

    func spawnTwoButtons(in size: CGSize) {
        let redSize  = baseSize + 10
        let greenSize = baseSize - 10

        let padR = redSize / 2 + 10
        let padG = greenSize / 2 + 10

        let redX = safeX(size: size, pad: padR)
        let redY = safeY(size: size, pad: padR)

        var greenX: CGFloat = 0
        var greenY: CGFloat = 0
        
        // Anti-Overlap Logic
        let minimumAllowedDistance = padR + padG + 15 // radius1 + radius2 + 15pt gap
        var attempts = 0
        
        repeat {
            greenX = safeX(size: size, pad: padG)
            greenY = safeY(size: size, pad: padG)
            attempts += 1
            // Try to find a valid spot, fallback after 50 attempts to prevent infinite loops
        } while (distanceBetween(x1: redX, y1: redY, x2: greenX, y2: greenY) < minimumAllowedDistance) && (attempts < 50)

        buttons = [
            GameButton(x: redX, y: redY, size: redSize, isRed: true),
            GameButton(x: greenX, y: greenY, size: greenSize, isRed: false)
        ]
    }

    func moveAllButtonsRandomly(in size: CGSize) {
        // Generate entirely new buttons with new UUIDs so they trigger the "Pop" animation
        buttons = buttons.map { btn in
            let pad = btn.size / 2 + 10
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
        }
        
        let playAreaSize = CGSize(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.height - 200)
        spawnSingleButton(in: playAreaSize)
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
    ContentView()
}
