import Foundation
import SwiftData

@Model
class Item {
    var id: UUID
    var name: String
    var price: Double
    var receipt: Receipt?
    
    init(id: UUID = UUID(), name: String, price: Double, receipt: Receipt? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.receipt = receipt
    }
}

@Model
class Receipt {
    var id: UUID
    var name: String
    var date: Date
    var payerName: String
    @Relationship(deleteRule: .cascade, inverse: \Item.receipt) var items: [Item]
    
    init(id: UUID = UUID(), name: String, date: Date = Date(), payerName: String) {
        self.id = id
        self.name = name
        self.date = date
        self.payerName = payerName
        self.items = []
    }
    
    var totalCost: Double {
        return items.reduce(0) { $0 + $1.price }
    }
}
