import SwiftUI

// MARK: - Small building blocks

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

/// A compact circular meter.
struct GaugeRing: View {
    var value: Double          // 0...1
    var center: String
    var label: String
    var sub: String
    var color: Color
    var size: CGFloat = 66

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, value)))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .animation(.easeOut(duration: 0.7), value: value)
                VStack(spacing: 0) {
                    Text(label.uppercased())
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    Text(center)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: size, height: size)

            Text(sub.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The financial trajectory. Smooth curve, gradient fill, a glowing point at
/// today and a marker at the lowest projected balance.
struct ForecastChart: View {
    let forecast: Forecast
    var accent: Color
    var height: CGFloat = 96
    /// Optional second curve drawn faintly behind (the base plan in scenarios).
    var ghost: Forecast? = nil

    private func geometry(_ size: CGSize, _ points: [ForecastPoint], min lo: Double, max hi: Double) -> [CGPoint] {
        let span = Swift.max(1, hi - lo)
        let padY: CGFloat = 10
        return points.enumerated().map { i, p in
            let x = size.width * CGFloat(i) / CGFloat(Swift.max(1, points.count - 1))
            let y = padY + (1 - CGFloat((p.balance - lo) / span)) * (size.height - padY * 2)
            return CGPoint(x: x, y: y)
        }
    }

    private func areaPath(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = smooth(pts)
        guard let first = pts.first, let last = pts.last else { return p }
        p.addLine(to: CGPoint(x: last.x, y: height))
        p.addLine(to: CGPoint(x: first.x, y: height))
        p.closeSubpath()
        return p
    }

    private func smooth(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for i in 1..<pts.count {
            let p0 = pts[i - 1], p1 = pts[i]
            let midX = (p0.x + p1.x) / 2
            path.addCurve(to: p1,
                          control1: CGPoint(x: midX, y: p0.y),
                          control2: CGPoint(x: midX, y: p1.y))
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let all = forecast.points.map(\.balance) + (ghost?.points.map(\.balance) ?? [])
            let lo = all.min() ?? 0
            let hi = all.max() ?? 1
            let pts = geometry(geo.size, forecast.points, min: lo, max: hi)
            let line = smooth(pts)

            ZStack {
                if let ghost {
                    smooth(geometry(geo.size, ghost.points, min: lo, max: hi))
                        .stroke(Color.primary.opacity(0.22),
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                }

                // area fill
                areaPath(pts, height: geo.size.height).fill(
                    LinearGradient(colors: [accent.opacity(0.28), accent.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )

                line.stroke(
                    LinearGradient(colors: [accent, accent.opacity(0.65)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

                // lowest point
                if let lowIndex = forecast.points.firstIndex(where: { $0.dayOffset == forecast.lowest.dayOffset }),
                   lowIndex < pts.count {
                    Circle()
                        .fill(Palette.moneyOut)
                        .frame(width: 6, height: 6)
                        .position(pts[lowIndex])
                }

                // today
                if let first = pts.first {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .position(first)
                }
            }
        }
        .frame(height: height)
    }
}

/// One row in a list of money movements.
struct EventRow: View {
    let event: UpcomingEvent
    let today: Date
    var accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.category.symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(Dates.relative(event.date, today: today))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if event.kind == .recurring {
                        Text("RECURRING")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(0.3)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }
            }
            Spacer(minLength: 6)
            Text(Money.signed(event.amount))
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(event.direction == .money_in ? Palette.moneyIn : Palette.moneyOut)
        }
        .padding(.vertical, 5)
    }
}

/// A transaction that already happened.
struct TransactionRow: View {
    let transaction: Transaction
    let today: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: transaction.category.symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.describedAs.capitalized)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(Dates.relative(transaction.date, today: today))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if transaction.isPending {
                        Text("PENDING")
                            .font(.system(size: 8, weight: .semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 6)
            Text(Money.signed(transaction.amount))
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.amount >= 0 ? Palette.moneyIn : Palette.moneyOut)
        }
        .padding(.vertical, 5)
    }
}
