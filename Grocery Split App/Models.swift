import Foundation
import SwiftData
import SwiftUI

@Model
class Item {
    var id: UUID
    var name: String
    var price: Double
    var quantity: Int
    var receipt: Receipt?
    var assignedTo: Roommate?
    
    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1, receipt: Receipt? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
        self.receipt = receipt
    }
    
    var totalPrice: Double {
        return price * Double(quantity)
    }
}

@Model
class Receipt {
    var id: UUID
    var name: String
    var date: Date
    var payerName: String
    var rawText: String
    var isSettled: Bool
    @Relationship(deleteRule: .cascade, inverse: \Item.receipt) var items: [Item]
    
    init(id: UUID = UUID(), name: String = "", date: Date = Date(), payerName: String = "", rawText: String = "", total: Double? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.payerName = payerName
        self.rawText = rawText
        self.isSettled = false
        self.items = []
    }
    
    var totalCost: Double {
        return items.reduce(0) { $0 + $1.price }
    }
    
    var calculatedTotal: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var involvedRoommates: [Roommate] {
        let roommates = items.compactMap { $0.assignedTo }
        return Array(Set(roommates))
    }
    
    func calculateBalances() -> [Roommate: Double] {
        var balances: [Roommate: Double] = [:]
        
        for item in items {
            if let roommate = item.assignedTo {
                balances[roommate, default: 0.0] += item.totalPrice
            }
        }
        
        return balances
    }
    
    func settlementSuggestions() -> [(from: Roommate, to: Roommate, amount: Double)] {
        let balances = calculateBalances()
        guard !balances.isEmpty else { return [] }
        
        let total = calculatedTotal
        let avgAmount = total / Double(balances.count)
        
        var debtors: [(Roommate, Double)] = []
        var creditors: [(Roommate, Double)] = []
        
        for (roommate, amount) in balances {
            let difference = amount - avgAmount
            if difference > 0.01 {
                debtors.append((roommate, difference))
            } else if difference < -0.01 {
                creditors.append((roommate, abs(difference)))
            }
        }
        
        var suggestions: [(from: Roommate, to: Roommate, amount: Double)] = []
        var debtorIndex = 0
        var creditorIndex = 0
        
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let (debtor, debtAmount) = debtors[debtorIndex]
            let (creditor, creditAmount) = creditors[creditorIndex]
            
            let transferAmount = min(debtAmount, creditAmount)
            suggestions.append((from: debtor, to: creditor, amount: transferAmount))
            
            debtors[debtorIndex].1 -= transferAmount
            creditors[creditorIndex].1 -= transferAmount
            
            if debtors[debtorIndex].1 <= 0.01 {
                debtorIndex += 1
            }
            if creditors[creditorIndex].1 <= 0.01 {
                creditorIndex += 1
            }
        }
        
        return suggestions
    }
}

@Model
class Roommate: Hashable {
    var id: UUID
    var name: String
    var colorTag: String
    var weight: Double
    
    init(id: UUID = UUID(), name: String, colorTag: String = "blue", weight: Double = 1.0) {
        self.id = id
        self.name = name
        self.colorTag = colorTag
        self.weight = weight
    }
    
    var displayColor: Color {
        switch colorTag {
        case "blue":
            return .blue
        case "green":
            return .green
        case "red":
            return .red
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "yellow":
            return .yellow
        case "teal":
            return .teal
        default:
            return .blue
        }
    }
    
    static func == (lhs: Roommate, rhs: Roommate) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
class SplitPreference {
    var id: UUID
    var roommateId: UUID
    var itemCategory: String
    var preferenceWeight: Double
    
    init(id: UUID = UUID(), roommateId: UUID, itemCategory: String, preferenceWeight: Double = 1.0) {
        self.id = id
        self.roommateId = roommateId
        self.itemCategory = itemCategory
        self.preferenceWeight = preferenceWeight
    }
}

// Struct for parsed items (not persisted)
struct ParsedItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let quantity: Int
    
    init(name: String, price: Double, quantity: Int = 1) {
        self.name = name
        self.price = price
        self.quantity = quantity
    }
}
