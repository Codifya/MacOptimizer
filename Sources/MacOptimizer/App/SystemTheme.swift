import SwiftUI

/// Styling, Liquid Glass materials, gradients, and design tokens for MacOptimizer
public enum SystemTheme {
    // MARK: - Vibrant Colors
    public static let primaryGradient = LinearGradient(
        colors: [Color.blue, Color.cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let memoryGradient = LinearGradient(
        colors: [Color.green, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let junkGradient = LinearGradient(
        colors: [Color.purple, Color.indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let updateGradient = LinearGradient(
        colors: [Color.orange, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let dangerGradient = LinearGradient(
        colors: [Color.red, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Glass Background Modifier
    public struct LiquidGlassCard: ViewModifier {
        @Environment(\.colorScheme) var colorScheme
        var cornerRadius: CGFloat = 16
        
        public func body(content: Content) -> some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.12)
                                        : Color.black.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                )
        }
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(SystemTheme.LiquidGlassCard(cornerRadius: cornerRadius))
    }
}
