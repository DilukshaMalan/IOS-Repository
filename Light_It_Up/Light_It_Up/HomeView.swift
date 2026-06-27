//
//  HomeView.swift
//  TapFrenzy
//
//  App home screen — choose between TapFrenzy and GridFlash.
//

import SwiftUI

// MARK: - Home View
struct HomeView: View {

    // Read each game's saved high score — updates live when returning from a game
    @AppStorage("tapFrenzyHighScore") private var tapFrenzyBest: Int = 0
    @AppStorage("gridFlashHighScore") private var gridFlashBest: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background (shared space theme) ────────────────────
                homeBackground

                VStack(spacing: 0) {
                    Spacer()

                    // ── App Title ──────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("ARCADE")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(6)

                        HStack(spacing: 0) {
                            Text("TAP")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 1.0), .cyan],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            Text("VERSE")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, Color(red: 0.6, green: 0.2, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        }

                        Text("choose your game")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.bottom, 48)

                    // ── Game Tiles ─────────────────────────────────────
                    VStack(spacing: 18) {
                        // TapFrenzy tile
                        NavigationLink(destination: TapFrenzyView()) {
                            GameTile(
                                title: "Tap Frenzy",
                                subtitle: "Tap the button before it runs away",
                                tag: "REFLEXES",
                                icon: "hand.tap.fill",
                                accentTop: Color(red: 0.1, green: 0.55, blue: 1.0),
                                accentBottom: Color(red: 0.4, green: 0.1, blue: 0.9),
                                decorSymbol: "●",
                                stats: [("20s", "Game Time"), ("+1 / -1", "Score"), ("20+", "Frenzy")],
                                highScore: tapFrenzyBest
                            )
                        }
                        .buttonStyle(HomeTilePress())

                        // GridFlash tile
                        NavigationLink(destination: GridFlashView()) {
                            GameTile(
                                title: "Grid Flash",
                                subtitle: "Tap lit tiles before they go dark",
                                tag: "MEMORY",
                                icon: "square.grid.3x3.fill",
                                accentTop: Color(red: 0.0, green: 0.75, blue: 0.85),
                                accentBottom: Color(red: 0.1, green: 0.35, blue: 0.9),
                                decorSymbol: "◼",
                                stats: [("4", "Levels"), ("6×6", "Max Grid"), ("25s", "Final")],
                                highScore: gridFlashBest
                            )
                        }
                        .buttonStyle(HomeTilePress())
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // ── Footer ─────────────────────────────────────────
                    Text("more games coming soon")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.bottom, 36)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background
    var homeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.14),
                    Color(red: 0.06, green: 0.02, blue: 0.20),
                    Color(red: 0.02, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Neon blobs
            Circle()
                .fill(Color(red: 0.1, green: 0.4, blue: 1.0).opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: -130, y: -220)

            Circle()
                .fill(Color.purple.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 140, y: 280)

            Circle()
                .fill(Color.cyan.opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 60, y: 60)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Game Tile Card
struct GameTile: View {
    let title: String
    let subtitle: String
    let tag: String
    let icon: String
    let accentTop: Color
    let accentBottom: Color
    let decorSymbol: String
    let stats: [(String, String)]   // (value, label)
    let highScore: Int              // persistent best score

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Card background with gradient tint
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(
                                colors: [accentTop.opacity(0.22), accentBottom.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(
                            LinearGradient(
                                colors: [accentTop.opacity(0.55), accentBottom.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.3
                        )
                )
                .shadow(color: accentTop.opacity(0.25), radius: 24, x: 0, y: 10)

            // Decorative scattered symbols (background texture)
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        Text(decorSymbol)
                            .font(.system(size: CGFloat([28, 18, 12, 22, 10, 16][i])))
                            .foregroundColor(accentTop.opacity(Double([0.07, 0.05, 0.08, 0.04, 0.06, 0.05][i])))
                            .position(
                                x: CGFloat([220, 290, 260, 300, 240, 310][i]),
                                y: CGFloat([20, 50, 80, 30, 65, 90][i])
                            )
                    }
                }
            }
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 0) {

                // Top row: tag + best score badge + icon
                HStack(alignment: .top) {
                    // Genre tag pill
                    Text(tag)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(accentTop)
                        .tracking(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentTop.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(accentTop.opacity(0.35), lineWidth: 1))

                    Spacer()

                    // Best score badge (only shown once a score exists)
                    if highScore > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("\(highScore)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.35), lineWidth: 1))
                    }

                    // Icon bubble
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentTop.opacity(0.30), accentBottom.opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accentTop)
                    }
                }
                .padding(.bottom, 16)

                // Title
                Text(title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 5)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
                    .padding(.bottom, 20)

                // Divider
                Rectangle()
                    .fill(accentTop.opacity(0.18))
                    .frame(height: 1)
                    .padding(.bottom, 16)

                // Stats row
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { i, stat in
                        VStack(spacing: 3) {
                            Text(stat.0)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(accentTop)
                            Text(stat.1)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)

                        if i < stats.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1, height: 28)
                        }
                    }
                }

                // Play cue
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Play")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(accentTop.opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentTop.opacity(0.5))
                    }
                    .padding(.top, 14)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tile Press Style
struct HomeTilePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
}