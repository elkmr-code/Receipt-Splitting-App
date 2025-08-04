import Foundation
import SwiftData

@MainActor
class SplittingService: ObservableObject {
    
    enum SplitMethod {
        case roundRobin
        case weighted
        case manual
    }
    
    // Split items among roommates using different algorithms
    static func splitItems(
        _ parsedItems: [ParsedItem],
        among roommates: [Roommate],
        method: SplitMethod = .roundRobin,
        modelContext: ModelContext
    ) -> [Item] {
        guard !roommates.isEmpty else { return [] }
        
        var items: [Item] = []
        
        switch method {
        case .roundRobin:
            items = splitRoundRobin(parsedItems, among: roommates, modelContext: modelContext)
        case .weighted:
            items = splitWeighted(parsedItems, among: roommates, modelContext: modelContext)
        case .manual:
            // Start with round robin, user can reassign manually
            items = splitRoundRobin(parsedItems, among: roommates, modelContext: modelContext)
        }
        
        return items
    }
    
    // Round-robin assignment
    private static func splitRoundRobin(
        _ parsedItems: [ParsedItem],
        among roommates: [Roommate],
        modelContext: ModelContext
    ) -> [Item] {
        var items: [Item] = []
        var roommateIndex = 0
        
        for parsedItem in parsedItems {
            let item = Item(
                name: parsedItem.name,
                price: parsedItem.price,
                quantity: parsedItem.quantity
            )
            
            item.assignedTo = roommates[roommateIndex]
            items.append(item)
            
            // Move to next roommate
            roommateIndex = (roommateIndex + 1) % roommates.count
        }
        
        return items
    }
    
    // Weighted assignment based on roommate preferences
    private static func splitWeighted(
        _ parsedItems: [ParsedItem],
        among roommates: [Roommate],
        modelContext: ModelContext
    ) -> [Item] {
        var items: [Item] = []
        let totalWeight = roommates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            // Fallback to round robin if weights are invalid
            return splitRoundRobin(parsedItems, among: roommates, modelContext: modelContext)
        }
        
        // Create weighted selection pool
        var weightedRoommates: [Roommate] = []
        for roommate in roommates {
            let count = Int((roommate.weight / totalWeight) * Double(parsedItems.count))
            for _ in 0..<max(1, count) {
                weightedRoommates.append(roommate)
            }
        }
        
        var assignmentIndex = 0
        
        for parsedItem in parsedItems {
            let item = Item(
                name: parsedItem.name,
                price: parsedItem.price,
                quantity: parsedItem.quantity
            )
            
            if assignmentIndex < weightedRoommates.count {
                item.assignedTo = weightedRoommates[assignmentIndex]
            } else {
                // Fallback to round robin if we run out of weighted assignments
                item.assignedTo = roommates[assignmentIndex % roommates.count]
            }
            
            items.append(item)
            assignmentIndex += 1
        }
        
        return items
    }
    
    // Smart assignment based on item categories and preferences
    static func smartSplit(
        _ parsedItems: [ParsedItem],
        among roommates: [Roommate],
        preferences: [SplitPreference],
        modelContext: ModelContext
    ) -> [Item] {
        var items: [Item] = []
        
        for parsedItem in parsedItems {
            let item = Item(
                name: parsedItem.name,
                price: parsedItem.price,
                quantity: parsedItem.quantity
            )
            
            // Determine item category
            let category = categorizeItem(parsedItem.name)
            
            // Find roommate with highest preference for this category
            let bestRoommate = findBestRoommateForCategory(
                category,
                among: roommates,
                preferences: preferences
            )
            
            item.assignedTo = bestRoommate
            items.append(item)
        }
        
        // Balance the assignment to ensure fairness
        return balanceAssignments(items, among: roommates)
    }
    
    private static func categorizeItem(_ itemName: String) -> String {
        let name = itemName.lowercased()
        
        // Simple categorization logic
        if name.contains("milk") || name.contains("cheese") || name.contains("yogurt") || name.contains("butter") {
            return "dairy"
        } else if name.contains("chicken") || name.contains("beef") || name.contains("pork") || name.contains("fish") {
            return "meat"
        } else if name.contains("apple") || name.contains("banana") || name.contains("orange") || name.contains("berry") {
            return "fruit"
        } else if name.contains("spinach") || name.contains("lettuce") || name.contains("tomato") || name.contains("carrot") {
            return "vegetables"
        } else if name.contains("bread") || name.contains("pasta") || name.contains("rice") || name.contains("cereal") {
            return "grains"
        } else if name.contains("chips") || name.contains("cookie") || name.contains("candy") || name.contains("soda") {
            return "snacks"
        } else {
            return "other"
        }
    }
    
    private static func findBestRoommateForCategory(
        _ category: String,
        among roommates: [Roommate],
        preferences: [SplitPreference]
    ) -> Roommate {
        var bestRoommate = roommates.first!
        var highestWeight = 0.0
        
        for roommate in roommates {
            let preference = preferences.first { $0.roommateId == roommate.id && $0.itemCategory == category }
            let weight = (preference?.preferenceWeight ?? 1.0) * roommate.weight
            
            if weight > highestWeight {
                highestWeight = weight
                bestRoommate = roommate
            }
        }
        
        return bestRoommate
    }
    
    private static func balanceAssignments(_ items: [Item], among roommates: [Roommate]) -> [Item] {
        // Calculate current totals per roommate
        var totals: [UUID: Double] = [:]
        for roommate in roommates {
            totals[roommate.id] = 0.0
        }
        
        for item in items {
            if let roommateId = item.assignedTo?.id {
                totals[roommateId, default: 0.0] += item.totalPrice
            }
        }
        
        let averageTotal = roommates.isEmpty ? 0.0 : totals.values.reduce(0, +) / Double(roommates.count)
        
        // Find items that can be reassigned to balance totals
        var sortedItems = items.sorted { $0.totalPrice > $1.totalPrice }
        
        for item in sortedItems {
            guard let currentRoommateId = item.assignedTo?.id else { continue }
            let currentTotal = totals[currentRoommateId] ?? 0.0
            
            // If current roommate is significantly over average, try to reassign
            if currentTotal > averageTotal * 1.2 {
                // Find roommate with lowest total
                if let (lowestRoommateId, _) = totals.min(by: { $0.value < $1.value }),
                   let newRoommate = roommates.first(where: { $0.id == lowestRoommateId }) {
                    
                    // Update totals
                    totals[currentRoommateId] = currentTotal - item.totalPrice
                    totals[lowestRoommateId, default: 0.0] += item.totalPrice
                    
                    // Reassign item
                    item.assignedTo = newRoommate
                }
            }
        }
        
        return items
    }
    
    // Create default roommates if none exist
    static func createDefaultRoommates(modelContext: ModelContext) -> [Roommate] {
        let alice = Roommate(name: "Alice", colorTag: "blue", weight: 1.0)
        let bob = Roommate(name: "Bob", colorTag: "green", weight: 1.0)
        
        modelContext.insert(alice)
        modelContext.insert(bob)
        
        return [alice, bob]
    }
}