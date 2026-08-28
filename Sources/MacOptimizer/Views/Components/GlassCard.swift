import SwiftUI

/// Reusable Liquid Glass Container Card
public struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    public init(cornerRadius: CGFloat = 16, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .liquidGlassCard(cornerRadius: cornerRadius)
    }
}
