import Foundation
import SwiftData

struct Person {
    let name: String
    var amountOwed: Double
}

enum SplitPreference: String, CaseIterable {
    case equally = "Split Equally"
    case byAmount = "Split by Amount"
    case byPercentage = "Split by Percentage"
}

class SplittingService {
    
    static func splitExpense(_ expense: Expense, among people: [String], preference: SplitPreference = .equally) -> [Person] {
        let validPeople = people.filter { !$0.isEmpty && $0.trimmingCharacters(in: .whitespacesAndNewlines) != "" }
        guard !validPeople.isEmpty && expense.totalCost > 0 else { return [] }
        
        switch preference {
        case .equally:
            return splitEqually(expense, among: validPeople)
        case .byAmount:
            // For now, default to equal splitting
            return splitEqually(expense, among: validPeople)
        case .byPercentage:
            // For now, default to equal splitting
            return splitEqually(expense, among: validPeople)
        }
    }
    
    private static func splitEqually(_ expense: Expense, among people: [String]) -> [Person] {
        guard !people.isEmpty && expense.totalCost > 0 else { return [] }
        let amountPerPerson = expense.totalCost / Double(people.count)
        return people.map { Person(name: $0.trimmingCharacters(in: .whitespacesAndNewlines), amountOwed: amountPerPerson) }
    }
    
    static func calculateTotalOwed(for people: [Person]) -> Double {
        return people.reduce(0) { $0 + $1.amountOwed }
    }
    
    static func generateSplitSummary(expense: Expense, people: [Person]) -> String {
        let splitDetails = people.map { "\($0.name): $\(String(format: "%.2f", $0.amountOwed))" }.joined(separator: "\n")
        
        return """
        💰 Expense: \(expense.name)
        💵 Total: $\(String(format: "%.2f", expense.totalCost))
        💳 Paid by: \(expense.payerName)
        
        💸 Split (\(people.count) people):
        \(splitDetails)
        
        Generated with Expense Split App
        """
    }
}
