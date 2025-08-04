import Foundation
import SwiftData

enum PaymentMethod: String, CaseIterable, Codable {
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case paypal = "PayPal"
    case venmo = "Venmo"
    case linePay = "LINE Pay"
    case applePay = "Apple Pay"
    case zelle = "Zelle"
    case bankTransfer = "Bank Transfer"
    
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .creditCard, .debitCard: return "creditcard"
        case .paypal: return "p.circle.fill"
        case .venmo: return "v.circle.fill"
        case .linePay: return "l.circle.fill"
        case .applePay: return "apple.logo"
        case .zelle: return "z.circle.fill"
        case .bankTransfer: return "building.columns"
        }
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case groceries = "Groceries"
    case dining = "Dining Out"
    case entertainment = "Entertainment"
    case transport = "Transportation"
    case utilities = "Utilities"
    case shopping = "Shopping"
    case travel = "Travel"
    case healthcare = "Healthcare"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .groceries: return "cart"
        case .dining: return "fork.knife"
        case .entertainment: return "tv"
        case .transport: return "car"
        case .utilities: return "house"
        case .shopping: return "bag"
        case .travel: return "airplane"
        case .healthcare: return "cross.case"
        case .other: return "ellipsis.circle"
        }
    }
}

@Model
class ExpenseItem {
    var id: UUID
    var name: String
    var price: Double
    var expense: Expense?
    
    init(id: UUID = UUID(), name: String, price: Double, expense: Expense? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.expense = expense
    }
}

@Model
class Expense {
    var id: UUID
    var name: String
    var date: Date
    var payerName: String
    var paymentMethod: PaymentMethod
    var category: ExpenseCategory
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \ExpenseItem.expense) var items: [ExpenseItem]
    
    init(id: UUID = UUID(), name: String, date: Date = Date(), payerName: String, paymentMethod: PaymentMethod = .cash, category: ExpenseCategory = .other, notes: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.payerName = payerName
        self.paymentMethod = paymentMethod
        self.category = category
        self.notes = notes
        self.items = []
    }
    
    var totalCost: Double {
        return items.reduce(0) { $0 + $1.price }
    }
}
