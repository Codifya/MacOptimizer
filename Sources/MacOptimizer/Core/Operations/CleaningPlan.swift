import Foundation

/// Represents a single item planned for removal during dry-run analysis.
public struct CleanableItemPlan: Identifiable, Sendable, Hashable {
    public let id: String
    public let path: String
    public let name: String
    public let category: JunkCategoryType
    public let sizeBytes: Int64
    public let risk: OperationRisk
    public var isSelected: Bool
    
    public var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
    
    public init(
        id: String = UUID().uuidString,
        path: String,
        name: String,
        category: JunkCategoryType,
        sizeBytes: Int64,
        risk: OperationRisk = .low,
        isSelected: Bool = true
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.category = category
        self.sizeBytes = sizeBytes
        self.risk = risk
        self.isSelected = isSelected
    }
}

/// A comprehensive dry-run plan generated before any disk modifications take place.
public struct CleaningPlan: Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var items: [CleanableItemPlan]
    public let warnings: [String]
    
    public var totalEstimatedBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedEstimatedBytes: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    public var maxRiskLevel: OperationRisk {
        items.filter { $0.isSelected }.map { $0.risk }.max() ?? .safe
    }
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        items: [CleanableItemPlan] = [],
        warnings: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.warnings = warnings
    }
}

/// Summary result of an executed CleaningPlan.
public struct CleaningExecutionResult: Sendable {
    public let planId: UUID
    public let totalFreedBytes: Int64
    public let cleanedItemCount: Int
    public let failedItemCount: Int
    public let errors: [String]
    public let durationSeconds: Double
    
    public init(
        planId: UUID,
        totalFreedBytes: Int64,
        cleanedItemCount: Int,
        failedItemCount: Int,
        errors: [String] = [],
        durationSeconds: Double = 0.0
    ) {
        self.planId = planId
        self.totalFreedBytes = totalFreedBytes
        self.cleanedItemCount = cleanedItemCount
        self.failedItemCount = failedItemCount
        self.errors = errors
        self.durationSeconds = durationSeconds
    }
}
