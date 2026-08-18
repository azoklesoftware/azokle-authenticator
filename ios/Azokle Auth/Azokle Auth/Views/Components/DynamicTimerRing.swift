//
//  DynamicTimerRing.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI

public struct DynamicTimerRing: View {
    public let progress: TOTPProgress
    public var size: CGFloat = 28
    public var lineWidth: CGFloat = 3
    public var showSeconds: Bool = false

    public init(progress: TOTPProgress, size: CGFloat = 28, lineWidth: CGFloat = 3, showSeconds: Bool = false) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.showSeconds = showSeconds
    }

    public var body: some View {
        let isCritical = progress.remainingSeconds <= 5
        let ringColor = Theme.timerColor(remainingSeconds: progress.remainingSeconds, totalPeriod: progress.totalPeriod)

        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress Arc
            Circle()
                .trim(from: 0.0, to: CGFloat(max(0.001, min(1.0, progress.progress))))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.linear(duration: 0.5), value: progress.progress)
                .scaleEffect(isCritical ? 1.06 : 1.0)
                .animation(isCritical ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isCritical)

            if showSeconds {
                Text("\(progress.remainingSeconds)")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)
                    .monospacedDigit()
            }
        }
    }
}

public struct DynamicTimerBar: View {
    public let progress: TOTPProgress
    public var height: CGFloat = 4

    public init(progress: TOTPProgress, height: CGFloat = 4) {
        self.progress = progress
        self.height = height
    }

    public var body: some View {
        let ringColor = Theme.timerColor(remainingSeconds: progress.remainingSeconds, totalPeriod: progress.totalPeriod)

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(ringColor)
                    .frame(width: max(0, geo.size.width * CGFloat(progress.progress)), height: height)
                    .animation(.linear(duration: 0.5), value: progress.progress)
            }
        }
        .frame(height: height)
    }
}
