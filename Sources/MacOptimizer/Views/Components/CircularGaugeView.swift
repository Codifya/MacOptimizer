import SwiftUI

/// Animated Circular Gauge for CPU, RAM, Disk percentage display
public struct CircularGaugeView: View {
    let percentage: Double // 0.0 to 1.0
    let title: String
    let valueText: String
    let subText: String
    let gradient: LinearGradient
    var lineWidth: CGFloat = 12
    var size: CGFloat = 130
    
    public init(
        percentage: Double,
        title: String,
        valueText: String,
        subText: String,
        gradient: LinearGradient = SystemTheme.primaryGradient,
        lineWidth: CGFloat = 12,
        size: CGFloat = 130
    ) {
        self.percentage = max(0.0, min(1.0, percentage))
        self.title = title
        self.valueText = valueText
        self.subText = subText
        self.gradient = gradient
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(
                        Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                
                // Active Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(percentage))
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentage)
                
                // Center Labels
                VStack(spacing: 2) {
                    Text(valueText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: size, height: size)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
