import SwiftUI

/// Architecture or Status Badge (Apple Silicon, Universal, Intel)
public struct MetricBadge: View {
    let text: String
    let colorName: String
    
    public init(text: String, colorName: String = "blue") {
        self.text = text
        self.colorName = colorName
    }
    
    private var badgeColor: Color {
        switch colorName {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .secondary
        }
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.18))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
            )
    }
}

/// Smooth Animated Progress Bar
public struct AnimatedProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let gradient: LinearGradient
    var height: CGFloat = 8
    
    public init(progress: Double, gradient: LinearGradient = SystemTheme.primaryGradient, height: CGFloat = 8) {
        self.progress = max(0.0, min(1.0, progress))
        self.gradient = gradient
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: height)
                
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: height)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

/// Custom Styled Action Button
public struct ActionButton: View {
    let title: String
    let iconName: String?
    let gradient: LinearGradient
    let isLoading: Bool
    let action: () -> Void
    
    public init(
        title: String,
        iconName: String? = nil,
        gradient: LinearGradient = SystemTheme.primaryGradient,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.gradient = gradient
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }
}
