import Foundation
import SwiftUI

// MARK: - Message Composer Helper
struct MessageComposer {
    
// MARK: - Message Templates
struct MessageTemplate {
    let name: String
    let template: String
    let placeholders: [String]
}

// MARK: - Message Composer Helper (Updated for Production SwiftData Models)
struct MessageComposer {
    
    static func getTemplate(for expense: Expense, participant: SplitRequest) -> MessageTemplate {
        if expense.items.isEmpty {
            // Simple expense without items
            return MessageTemplate(
                name: "Simple Split",
                template: "Hi {name}! You owe {amount} for {expense} from {date}. Payment request from {payer}. Thanks!",
                placeholders: ["{name}", "{amount}", "{expense}", "{date}", "{payer}"]
            )
        } else {
            // Itemized expense
            return MessageTemplate(
                name: "Itemized Split", 
                template: "Hi {name}! Your share for {expense} is {amount}. Items: {items}. Payment requested by {payer} on {date}. Due: {dueDate}.",
                placeholders: ["{name}", "{amount}", "{expense}", "{items}", "{payer}", "{date}", "{dueDate}"]
            )
        }
    }
    
    static func generateMessage(for expense: Expense, participant: SplitRequest, template: MessageTemplate) -> String {
        var message = template.template
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = expense.currencyCode
        
        // Replace placeholders
        message = message.replacingOccurrences(of: "{name}", with: participant.participantName)
        message = message.replacingOccurrences(of: "{amount}", with: currencyFormatter.string(from: NSNumber(value: participant.amount)) ?? "$0.00")
        message = message.replacingOccurrences(of: "{expense}", with: expense.name)
        message = message.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: expense.date))
        message = message.replacingOccurrences(of: "{payer}", with: expense.payerName)
        
        // Handle items if present
        if !expense.items.isEmpty {
            let itemsList = expense.items.prefix(3).map { $0.name }.joined(separator: ", ")
            let itemsSuffix = expense.items.count > 3 ? " & \(expense.items.count - 3) more" : ""
            message = message.replacingOccurrences(of: "{items}", with: itemsList + itemsSuffix)
        }
        
        // Handle due date
        if let dueDate = participant.dueDate {
            message = message.replacingOccurrences(of: "{dueDate}", with: dateFormatter.string(from: dueDate))
        } else {
            message = message.replacingOccurrences(of: "{dueDate}", with: "ASAP")
        }
        
        return message
    }
    
    static func generateGroupMessage(for expense: Expense, participants: [SplitRequest]) -> String {
        let totalParticipants = participants.count
        let totalAmount = participants.reduce(0) { $0 + $1.amount }
        
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = expense.currencyCode
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        var message = "Split request for \(expense.name) on \(dateFormatter.string(from: expense.date))\n"
        message += "Total: \(currencyFormatter.string(from: NSNumber(value: expense.totalCost)) ?? "$0.00")\n"
        message += "Split \(totalParticipants) ways:\n\n"
        
        for participant in participants {
            message += "• \(participant.participantName): \(currencyFormatter.string(from: NSNumber(value: participant.amount)) ?? "$0.00")\n"
        }
        
        message += "\nRequested by \(expense.payerName)"
        
        return message
    }
    
    // MARK: - Legacy Support for SplitParticipant (for backward compatibility)
    enum LegacyMessageTemplate: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case friendly = "Friendly" 
        case formal = "Formal"
        case detailed = "Detailed"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .standard: return "envelope"
            case .friendly: return "heart"
            case .formal: return "briefcase"
            case .detailed: return "doc.text"
            }
        }
        
        var description: String {
            switch self {
            case .standard: return "Simple and direct payment request"
            case .friendly: return "Casual and friendly tone"
            case .formal: return "Professional business tone"
            case .detailed: return "Detailed breakdown with context"
            }
        }
        
        func generateMessage(
            for expense: Expense,
            participants: [SplitParticipant],
            paymentMethod: PaymentMethod,
            customMessage: String? = nil
        ) -> String {
            let expenseName = expense.name
            let totalAmount = expense.totalCost
            let payerName = expense.payerName
            let participantCount = participants.count
            
            switch self {
            case .standard:
                return generateStandardMessage(
                    expenseName: expenseName,
                    totalAmount: totalAmount,
                    payerName: payerName,
                    participantCount: participantCount,
                    paymentMethod: paymentMethod
                )
                
            case .friendly:
                return generateFriendlyMessage(
                    expenseName: expenseName,
                    totalAmount: totalAmount,
                    payerName: payerName,
                    participants: participants,
                    paymentMethod: paymentMethod
                )
                
            case .formal:
                return generateFormalMessage(
                    expenseName: expenseName,
                    totalAmount: totalAmount,
                    payerName: payerName,
                    participants: participants,
                    paymentMethod: paymentMethod
                )
                
            case .detailed:
                return generateDetailedMessage(
                    expense: expense,
                    participants: participants,
                    paymentMethod: paymentMethod
                )
            }
        }
        
        private func generateStandardMessage(
            expenseName: String,
            totalAmount: Double,
            payerName: String,
            participantCount: Int,
            paymentMethod: PaymentMethod
        ) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let formattedTotal = formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)"
            
            return """
            Payment Request: \(expenseName)
            
            Hi! I paid for "\(expenseName)" (\(formattedTotal) total) and we're splitting it \(participantCount) ways.
            
            Your share: \(formatter.string(from: NSNumber(value: totalAmount / Double(participantCount))) ?? "$\(totalAmount / Double(participantCount))")
            
            Please send payment via \(paymentMethod.rawValue).
            
            Thanks!
            \(payerName)
            """
        }
        
        private func generateFriendlyMessage(
            expenseName: String,
            totalAmount: Double,
            payerName: String,
            participants: [SplitParticipant],
            paymentMethod: PaymentMethod
        ) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            
            let emojis = ["😊", "👍", "🙌", "✨"]
            let randomEmoji = emojis.randomElement() ?? "😊"
            
            return """
            Hey! \(randomEmoji)
            
            Hope you had a great time with "\(expenseName)"! I covered the bill (\(formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)")) and figured we could split it.
            
            No rush, but when you get a chance, your share comes to \(formatter.string(from: NSNumber(value: totalAmount / Double(participants.count))) ?? "$\(totalAmount / Double(participants.count))").
            
            You can send it via \(paymentMethod.rawValue) whenever convenient!
            
            Thanks so much!
            \(payerName) \(randomEmoji)
            """
        }
        
        private func generateFormalMessage(
            expenseName: String,
            totalAmount: Double,
            payerName: String,
            participants: [SplitParticipant],
            paymentMethod: PaymentMethod
        ) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            return """
            Subject: Payment Request - \(expenseName)
            
            Dear Participant,
            
            I am writing to request payment for your portion of the shared expense "\(expenseName)" from \(dateFormatter.string(from: Date())).
            
            Total Amount Paid: \(formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)")
            Number of Participants: \(participants.count)
            Your Share: \(formatter.string(from: NSNumber(value: totalAmount / Double(participants.count))) ?? "$\(totalAmount / Double(participants.count))")
            
            Please remit payment via \(paymentMethod.rawValue) at your earliest convenience.
            
            Thank you for your prompt attention to this matter.
            
            Best regards,
            \(payerName)
            """
        }
        
        private func generateDetailedMessage(
            expense: Expense,
            participants: [SplitParticipant],
            paymentMethod: PaymentMethod
        ) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            
            var message = """
            💰 Payment Request Details
            
            Expense: \(expense.name)
            Category: \(expense.category.rawValue)
            Date: \(DateFormatter.shortDate.string(from: expense.date))
            Original Payer: \(expense.payerName)
            Payment Method Used: \(expense.paymentMethod.rawValue)
            """
            
            if !expense.items.isEmpty {
                message += "\n\n📝 Item Breakdown:"
                for item in expense.items {
                    message += "\n• \(item.name): \(formatter.string(from: NSNumber(value: item.price)) ?? "$\(item.price)")"
                }
            }
            
            let totalAmount = expense.totalCost
            let participantCount = participants.count
            let shareAmount = totalAmount / Double(participantCount)
            
            message += """
            
            
            💵 Payment Summary:
            Total Amount: \(formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)")
            Split \(participantCount) ways
            Your Share: \(formatter.string(from: NSNumber(value: shareAmount)) ?? "$\(shareAmount)")
            
            🏦 Payment Instructions:
            Please send \(formatter.string(from: NSNumber(value: shareAmount)) ?? "$\(shareAmount)") via \(paymentMethod.rawValue).
            
            """
            
            if !expense.notes.isEmpty {
                message += "📌 Additional Notes:\n\(expense.notes)\n\n"
            }
            
            message += "Thanks!\n\(expense.payerName)"
            
            return message
        }
    }
    
    // MARK: - Payment Method Instructions
    static func generatePaymentInstructions(for method: PaymentMethod, payerInfo: String? = nil) -> String {
        switch method {
        case .venmo:
            return "Send via Venmo to: @\(payerInfo ?? "username")"
        case .cashapp:
            return "Send via CashApp to: $\(payerInfo ?? "username")"
        case .zelle:
            return "Send via Zelle to: \(payerInfo ?? "email@example.com")"
        case .paypal:
            return "Send via PayPal to: \(payerInfo ?? "email@example.com")"
        case .bankTransfer:
            return "Bank transfer details will be provided separately"
        case .cash:
            return "Cash payment - we can arrange a convenient time to meet"
        default:
            return "Payment method: \(method.rawValue)"
        }
    }
    
    // MARK: - Auto-regeneration on split changes
    static func regenerateMessage(
        template: LegacyMessageTemplate,
        expense: Expense,
        participants: [SplitParticipant],
        paymentMethod: PaymentMethod,
        customMessage: String? = nil
    ) -> String {
        return template.generateMessage(
            for: expense,
            participants: participants,
            paymentMethod: paymentMethod,
            customMessage: customMessage
        )
    }
}

// MARK: - Supporting Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}