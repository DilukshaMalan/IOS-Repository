//
//  GridFlashView.swift
//  GridFlash
//
//  A grid-tap reflex game with 2 modes and 4 progressive levels.
//  Lit tiles go dark — tap them before they do to score!
//
//  Levels:
//   1 → 3×3  | 10s  | tile stays lit 2.4s
//   2 → 4×4  | 15s  | tile stays lit 1.8s
//   3 → 5×5  | 20s  | tile stays lit 1.3s
//   4 → 6×6  | 25s  | tile stays lit 0.9s
//

import SwiftUI
internal import Combine

// MARK: - Level Config
struct LevelConfig {
    let level: Int
    let gridSize: Int       // n × n
    let gameDuration: Int   // seconds
    let litDuration: Double // seconds a tile stays lit before auto-off
    let spawnInterval: Double // seconds between new tile spawns
    let maxLitAtOnce: Int   // max tiles lit at same time
}

let levels: [LevelConfig] = [
    LevelConfig(level: 1, gridSize: 3, gameDuration: 10, litDuration: 2.4, spawnInterval: 0.9, maxLitAtOnce: 2),
    LevelConfig(level: 2, gridSize: 4, gameDuration: 15, litDuration: 1.8, spawnInterval: 0.75, maxLitAtOnce: 3),
    LevelConfig(level: 3, gridSize: 5, gameDuration: 20, litDuration: 1.3, spawnInterval: 0.6, maxLitAtOnce: 4),
    LevelConfig(level: 4, gridSize: 6, gameDuration: 25, litDuration: 0.9, spawnInterval: 0.45, maxLitAtOnce: 5),
]

// MARK: - Game Mode
enum GameMode {
    case classic    // survive all 4 levels in sequence
    case timeAttack // pick a level, go hard for fixed time
}

// MARK: - Tile State
struct GridTile: Identifiable {
    let id: Int          // row * gridSize + col
    var isLit: Bool = false
    var litStartTime: Date? = nil
}

// MARK: - App State
enum AppScreen {
    case modeSelect
    case levelSelect   // only for timeAttack
    case playing
    case levelComplete
    case gameOver
}

// MARK: - Glass Modifier (reused from TapFrenzy)
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
            )
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

// MARK: - Scale Press Style
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Main View
struct GridFlashView: View {

    // MARK: Persistent High Score
    @AppStorage("gridFlashHighScore") private var highScore: Int = 0

    // Navigation
    @State private var screen: AppScreen = .modeSelect
    @State private var gameMode: GameMode = .classic
    @State private var currentLevelIndex: Int = 0

    // Score
    @State private var totalScore: Int = 0
    @State private var levelScore: Int = 0
    @State private var missedCount: Int = 0
    @State private var newHighScore: Bool = false   // flag for "NEW BEST!" banner

    // Grid
    @State private var tiles: [GridTile] = []
    @State private var timeRemaining: Int = 0

    // Timers
    @State private var countdownTimer: AnyCancellable? = nil
    @State private var spawnTimer: AnyCancellable? = nil
    @State private var tileTimers: [Int: AnyCancellable] = [:]

    // Feedback flash
    @State private var flashMessage: String? = nil
    @State private var flashColor: Color = .cyan

    var currentConfig: LevelConfig { levels[currentLevelIndex] }

    // MARK: Body
    var body: some View {
        ZStack {
            // Deep space background (consistent with TapFrenzy)
            spaceBackground

            switch screen {
            case .modeSelect:    modeSelectView
            case .levelSelect:   levelSelectView
            case .playing:       playingView
            case .levelComplete: levelCompleteView
            case .gameOver:      gameOverView
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Background
    var spaceBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.15),
                    Color(red: 0.06, green: 0.02, blue: 0.20),
                    Color(red: 0.01, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Atmosphere blobs
            Circle()
                .fill(Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color.purple.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: 260)
        }
        .ignoresSafeArea()
    }

    // MARK: - Mode Select
    var modeSelectView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("GRID")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 1.0), Color.cyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("FLASH")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .offset(y: -12)
                Text("tap the light before it fades")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 4)
            }
            .padding(.bottom, 44)

            // Mode Cards
            VStack(spacing: 16) {
                ModeCard(
                    icon: "square.grid.2x2.fill",
                    title: "Classic",
                    subtitle: "4 levels · increasing grid · beat them all",
                    accentColor: Color(red: 0.1, green: 0.6, blue: 1.0)
                ) {
                    gameMode = .classic
                    currentLevelIndex = 0
                    startGame()
                }

                ModeCard(
                    icon: "timer",
                    title: "Time Attack",
                    subtitle: "pick a level · go as long as you can",
                    accentColor: Color(red: 0.7, green: 0.2, blue: 1.0)
                ) {
                    gameMode = .timeAttack
                    screen = .levelSelect
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            // Mini level preview row
            HStack(spacing: 12) {
                ForEach(levels, id: \.level) { lv in
                    VStack(spacing: 4) {
                        Text("Lv \(lv.level)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(lv.gridSize)×\(lv.gridSize)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(lv.gameDuration)s")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .glassPanel(cornerRadius: 14)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Level Select (Time Attack)
    var levelSelectView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 6) {
                Text("TIME ATTACK")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("Choose your challenge")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }

            VStack(spacing: 14) {
                ForEach(levels, id: \.level) { lv in
                    Button(action: {
                        currentLevelIndex = lv.level - 1
                        startGame()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Level \(lv.level) — \(lv.gridSize)×\(lv.gridSize)")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("\(lv.gameDuration)s · tiles fade in \(String(format: "%.1f", lv.litDuration))s")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            difficultyBadge(level: lv.level)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassPanel(cornerRadius: 18)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.horizontal, 28)

            Button(action: { screen = .modeSelect }) {
                Text("← Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    func difficultyBadge(level: Int) -> some View {
        let labels = ["Easy", "Medium", "Hard", "Extreme"]
        let colors: [Color] = [.green, .yellow, .orange, .red]
        return Text(labels[level - 1])
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(colors[level - 1])
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(colors[level - 1].opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(colors[level - 1].opacity(0.4), lineWidth: 1))
    }

    // MARK: - Playing View
    var playingView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // HUD
                playHUD

                Spacer()

                // Flash feedback
                if let msg = flashMessage {
                    Text(msg)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(flashColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(flashColor.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(flashColor.opacity(0.4), lineWidth: 1))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }

                // Grid
                gridView(geo: geo)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var playHUD: some View {
        HStack {
            // Score
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(totalScore + levelScore)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, Color(red: 0.2, green: 0.7, blue: 1.0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
            }

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

            // Level badge
            VStack(spacing: 2) {
                Text("LEVEL")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(currentLevelIndex + 1) / \(levels.count)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Timer
            VStack(alignment: .trailing, spacing: 2) {
                Text("TIME")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(timeRemaining)s")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(timeRemaining <= 5 ? .red : .white)
                    .scaleEffect(timeRemaining <= 5 ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: timeRemaining)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
        .padding(.bottom, 18)
        .background(Color.black.opacity(0.3))
        .overlay(Divider().background(Color.white.opacity(0.07)), alignment: .bottom)
    }

    // MARK: - Grid View
    func gridView(geo: GeometryProxy) -> some View {
        let config = currentConfig
        let gridSize = config.gridSize
        let availableWidth = geo.size.width - 40
        let availableHeight = geo.size.height - 200
        let cellSide = min(availableWidth / CGFloat(gridSize), availableHeight / CGFloat(gridSize)) - 8

        return VStack(spacing: 8) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let idx = row * gridSize + col
                        if idx < tiles.count {
                            TileView(
                                tile: tiles[idx],
                                size: cellSide,
                                onTap: { tappedTile(index: idx) }
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 22)
    }

    // MARK: - Level Complete
    var levelCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 6) {
                Text("⚡ LEVEL \(currentLevelIndex + 1) CLEAR")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                Text("You tapped \(levelScore) tiles")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }

            // Stats row
            HStack(spacing: 16) {
                statCard(label: "Level Score", value: "\(levelScore)", color: .cyan)
                statCard(label: "Total Score", value: "\(totalScore + levelScore)", color: .purple)
                statCard(label: "Missed", value: "\(missedCount)", color: .orange)
            }
            .padding(.horizontal, 28)

            // Next level or final
            if currentLevelIndex < levels.count - 1 {
                let next = levels[currentLevelIndex + 1]
                VStack(spacing: 8) {
                    Text("NEXT UP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Level \(next.level) — \(next.gridSize)×\(next.gridSize) grid · \(next.gameDuration)s")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .glassPanel(cornerRadius: 16)
                .padding(.horizontal, 28)

                Button(action: {
                    totalScore += levelScore
                    currentLevelIndex += 1
                    startGame()
                }) {
                    Text("Next Level →")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.cyan, Color(red: 0.2, green: 0.7, blue: 1.0)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .cyan.opacity(0.4), radius: 14)
                }
                .buttonStyle(PressScaleStyle())
                .padding(.horizontal, 28)
            } else {
                // Beat all levels
                Text("🏆 You beat all 4 levels!")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                if newHighScore {
                    Text("🎉 NEW BEST: \(highScore)!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow.opacity(0.8))
                }
                actionButtons
            }

            Spacer()
        }
    }

    // MARK: - Game Over
    var gameOverView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("GAME OVER")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
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

            VStack(spacing: 6) {
                Text("Final Score")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(totalScore + levelScore)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                    )
            }

            // High score row
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow.opacity(0.7))
                    .font(.system(size: 13))
                Text("Best: \(highScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }

            HStack(spacing: 16) {
                statCard(label: "Level Reached", value: "\(currentLevelIndex + 1)", color: .cyan)
                statCard(label: "Missed", value: "\(missedCount)", color: .orange)
            }
            .padding(.horizontal, 28)

            Text(scoreComment)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .italic()
                .foregroundColor(.white.opacity(0.5))

            actionButtons

            Spacer()
        }
    }

    var scoreComment: String {
        let s = totalScore + levelScore
        switch s {
        case ..<5:   return "Keep your eyes sharp! 👀"
        case 5..<15: return "Getting the hang of it! 💪"
        case 15..<30: return "Quick reflexes! ⚡"
        default:     return "Grid Flash Master! 🏆"
        }
    }

    var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                currentLevelIndex = gameMode == .timeAttack ? currentLevelIndex : 0
                totalScore = 0
                newHighScore = false
                startGame()
            }) {
                Text("Play Again")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .green.opacity(0.4), radius: 12)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 28)

            Button(action: {
                stopAllTimers()
                newHighScore = false
                totalScore = 0
                screen = .modeSelect
            }) {
                Text("Main Menu")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Stat Card
    func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassPanel(cornerRadius: 16)
    }

    // MARK: - Game Logic

    func startGame() {
        let config = currentConfig
        levelScore = 0
        missedCount = 0
        timeRemaining = config.gameDuration
        flashMessage = nil

        // Build tiles
        let count = config.gridSize * config.gridSize
        tiles = (0..<count).map { GridTile(id: $0) }

        screen = .playing

        // Countdown timer (every 1s)
        countdownTimer?.cancel()
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.endLevel()
                }
            }

        // Spawn timer (lights tiles)
        spawnTimer?.cancel()
        spawnTimer = Timer.publish(every: config.spawnInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.spawnLitTile()
            }
    }

    func spawnLitTile() {
        let config = currentConfig
        let litCount = tiles.filter { $0.isLit }.count
        guard litCount < config.maxLitAtOnce else { return }

        let darkIndices = tiles.indices.filter { !tiles[$0].isLit }
        guard let idx = darkIndices.randomElement() else { return }

        withAnimation(.easeIn(duration: 0.12)) {
            tiles[idx].isLit = true
            tiles[idx].litStartTime = Date()
        }

        // Auto-extinguish after litDuration
        let tileID = tiles[idx].id
        tileTimers[tileID]?.cancel()
        tileTimers[tileID] = Timer.publish(every: config.litDuration, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { _ in
                self.extinguishTile(id: tileID, missed: true)
            }
    }

    func tappedTile(index: Int) {
        guard index < tiles.count, tiles[index].isLit else { return }

        let tileID = tiles[index].id
        tileTimers[tileID]?.cancel()
        tileTimers.removeValue(forKey: tileID)

        withAnimation(.easeOut(duration: 0.15)) {
            tiles[index].isLit = false
            tiles[index].litStartTime = nil
        }

        levelScore += 1
        showFlash(message: tapPraise, color: .cyan)
    }

    func extinguishTile(id: Int, missed: Bool) {
        guard let idx = tiles.indices.first(where: { tiles[$0].id == id }) else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            tiles[idx].isLit = false
            tiles[idx].litStartTime = nil
        }
        tileTimers[id]?.cancel()
        tileTimers.removeValue(forKey: id)

        if missed {
            missedCount += 1
            showFlash(message: "Missed! 👻", color: .orange)
        }
    }

    var tapPraise: String {
        let praises = ["Nice! ✨", "Sharp! ⚡", "Tap! 💥", "Lit! 🔥", "Yes! 🎯", "Fast! 🚀"]
        return praises.randomElement() ?? "Nice!"
    }

    func showFlash(message: String, color: Color) {
        flashColor = color
        withAnimation(.spring(response: 0.2)) { flashMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.25)) { self.flashMessage = nil }
        }
    }

    func endLevel() {
        stopAllTimers()

        // Save high score
        let finalScore = totalScore + levelScore
        if finalScore > highScore {
            highScore = finalScore
            newHighScore = true
        }

        // Classic: advance or game over based on score threshold
        if gameMode == .classic {
            let totalSpawnable = max(1, levelScore + missedCount)
            let accuracy = Double(levelScore) / Double(totalSpawnable)

            if accuracy >= 0.4 || currentLevelIndex == 0 {
                withAnimation { screen = .levelComplete }
            } else {
                withAnimation { screen = .gameOver }
            }
        } else {
            withAnimation { screen = .gameOver }
        }
    }

    func stopAllTimers() {
        countdownTimer?.cancel()
        spawnTimer?.cancel()
        tileTimers.values.forEach { $0.cancel() }
        tileTimers.removeAll()
    }
}

// MARK: - Tile View
struct TileView: View {
    let tile: GridTile
    let size: CGFloat
    let onTap: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Base dark tile
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        tile.isLit
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.6, blue: 1.0),
                                    Color(red: 0.05, green: 0.4, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.18),
                                    Color(red: 0.06, green: 0.06, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: size, height: size)

                // Glow overlay for lit tile
                if tile.isLit {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.3, green: 0.75, blue: 1.0).opacity(pulsing ? 0.35 : 0.15))
                        .frame(width: size, height: size)
                        .blur(radius: pulsing ? 10 : 4)

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: size - 4, height: size - 4)
                }

                // Border for dark tiles
                if !tile.isLit {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: size, height: size)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .onChange(of: tile.isLit) { isNowLit in
            if isNowLit {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                withAnimation { pulsing = false }
            }
        }
        .onAppear {
            if tile.isLit {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
        }
    }
}

// MARK: - Mode Card
struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .glassPanel(cornerRadius: 20)
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview {
    GridFlashView()
}