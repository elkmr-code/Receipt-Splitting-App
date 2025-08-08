import Foundation
import SwiftData

// MARK: - Receipt Source Types
enum ReceiptSourceType: String, CaseIterable, Codable {
    case qr = "QR Code"
    case barcode = "Barcode"
    case ocr = "OCR Scan"
    case manual = "Manual Entry"
    
    var icon: String {
        switch self {
        case .qr: return "qrcode"
        case .barcode: return "barcode"
        case .ocr: return "doc.text.viewfinder"
        case .manual: return "plus.circle.fill"
        }
    }
}

// MARK: - Split Status
enum SplitStatus: String, CaseIterable, Codable {
    case draft = "Draft"
    case pending = "Pending"
    case sent = "Sent"
    case complete = "Complete"
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .pending: return "orange"
        case .sent: return "blue"
        case .complete: return "green"
        }
    }
}

// MARK: - Request Status
enum RequestStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case sent = "Sent"
    case overdue = "Overdue"
    case paid = "Paid"
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .sent: return "paperplane"
        case .overdue: return "exclamationmark.triangle"
        case .paid: return "checkmark.circle"
        }
    }
}

// MARK: - Request Priority
enum RequestPriority: String, CaseIterable, Codable {
    case normal = "Normal"
    case high = "High"
    
    var color: String {
        switch self {
        case .normal: return "blue"
        case .high: return "red"
        }
    }
}

// MARK: - Receipt Model
@Model
class Receipt {
    var id: UUID
    var sourceType: ReceiptSourceType
    var receiptID: String?
    var rawText: String
    var imageData: Data?
    var captureDate: Date
    var expense: Expense?
    
    init(id: UUID = UUID(), 
         sourceType: ReceiptSourceType, 
         receiptID: String? = nil,
         rawText: String = "",
         imageData: Data? = nil,
         captureDate: Date = Date(),
         expense: Expense? = nil) {
        self.id = id
        self.sourceType = sourceType
        self.receiptID = receiptID
        self.rawText = rawText
        self.imageData = imageData
        self.captureDate = captureDate
        self.expense = expense
    }
}

// MARK: - Split Request Model
@Model
class SplitRequest {
    var id: UUID
    var participantName: String
    var amount: Double
    var status: RequestStatus
    var messageText: String
    var priority: RequestPriority
    var dueDate: Date?
    var createdDate: Date
    var expense: Expense?
    
    init(id: UUID = UUID(),
         participantName: String,
         amount: Double,
         status: RequestStatus = .pending,
         messageText: String = "",
         priority: RequestPriority = .normal,
         dueDate: Date? = nil,
         createdDate: Date = Date(),
         expense: Expense? = nil) {
        self.id = id
        self.participantName = participantName
        self.amount = amount
        self.status = status
        self.messageText = messageText
        self.priority = priority
        self.dueDate = dueDate
        self.createdDate = createdDate
        self.expense = expense
    }
}

enum PaymentMethod: String, CaseIterable, Codable {
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case paypal = "PayPal"
    case venmo = "Venmo"
    case cashapp = "CashApp"
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
        case .cashapp: return "dollarsign.circle.fill"
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
    
    // Enhanced fields for split functionality
    var splitStatus: SplitStatus
    var message: String?
    var lastSentDate: Date?
    var currencyCode: String
    @Relationship(deleteRule: .cascade, inverse: \SplitRequest.expense) var splitRequests: [SplitRequest]
    @Relationship(deleteRule: .cascade, inverse: \Receipt.expense) var receipt: Receipt?
    
    init(id: UUID = UUID(), 
         name: String, 
         date: Date = Date(), 
         payerName: String, 
         paymentMethod: PaymentMethod = .cash, 
         category: ExpenseCategory = .other, 
         notes: String = "",
         splitStatus: SplitStatus = .draft,
         message: String? = nil,
         lastSentDate: Date? = nil,
         currencyCode: String = "USD") {
        self.id = id
        self.name = name
        self.date = date
        self.payerName = payerName
        self.paymentMethod = paymentMethod
        self.category = category
        self.notes = notes
        self.items = []
        self.splitStatus = splitStatus
        self.message = message
        self.lastSentDate = lastSentDate
        self.currencyCode = currencyCode
        self.splitRequests = []
        self.receipt = nil
    }
    
    var totalCost: Double {
        return items.reduce(0) { $0 + $1.price }
    }
}
