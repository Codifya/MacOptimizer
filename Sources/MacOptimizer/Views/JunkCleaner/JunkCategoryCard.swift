import SwiftUI
import AppKit

/// Expandable card for a category of cleanable junk files
public struct JunkCategoryCard: View {
    let group: JunkCategoryGroup
    let onToggleSelectAll: () -> Void
    let onToggleItem: (String) -> Void
    @State private var isExpanded: Bool = false
    
    public var body: some View {
        GlassCard(cornerRadius: 14, padding: 14) {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    // Category Checkbox
                    Button(action: onToggleSelectAll) {
                        Image(systemName: group.isAllSelected ? "checkmark.square.fill" : (group.selectedCount > 0 ? "minus.square.fill" : "square"))
                            .font(.system(size: 18))
                            .foregroundColor(group.selectedCount > 0 ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Category Icon
                    Image(systemName: group.type.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .background(iconColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(group.type.title)
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("(\(group.items.count) öğe)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(group.type.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Size Badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(group.totalFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if group.selectedCount > 0 && group.selectedCount < group.items.count {
                            Text("Seçili: \(group.selectedFormatted)")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Expand/Collapse Chevron
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                
                // Expanded Items List
                if isExpanded && !group.items.isEmpty {
                    Divider()
                        .opacity(0.4)
                    
                    VStack(spacing: 6) {
                        ForEach(group.items) { item in
                            HStack(spacing: 10) {
                                Button {
                                    onToggleItem(item.id)
                                } label: {
                                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(item.isSelected ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    
                                    Text(item.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer(minLength: 6)
                                
                                Text(item.sizeFormatted)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Button {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                } label: {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Finder'da Göster")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }
    
    private var iconColor: Color {
        switch group.type.tintColorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "teal": return .teal
        case "red": return .red
        case "indigo": return .indigo
        case "pink": return .pink
        default: return .blue
        }
    }
}
