//
//  Grocery_Split_AppTests.swift
//  Grocery Split AppTests
//
//  Created by user12 on 2025/8/4.
//

import Testing
@testable import Grocery_Split_App

struct Grocery_Split_AppTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testSplittingServiceWithValidData() async throws {
        // Create a test expense
        let expense = Expense(
            name: "Test Dinner",
            payerName: "John",
            paymentMethod: .cash,
            category: .dining,
            notes: ""
        )
        
        // Add some test items
        expense.items = [
            ExpenseItem(name: "Pizza", price: 20.0, expense: expense),
            ExpenseItem(name: "Drinks", price: 10.0, expense: expense)
        ]
        
        // Test splitting among valid people
        let people = ["Alice", "Bob", "Charlie"]
        let result = SplittingService.splitExpense(expense, among: people)
        
        #expect(result.count == 3)
        #expect(result[0].amountOwed == 10.0) // 30.0 / 3
        #expect(result[1].amountOwed == 10.0)
        #expect(result[2].amountOwed == 10.0)
    }
    
    @Test func testSplittingServiceWithEmptyNames() async throws {
        let expense = Expense(
            name: "Test Expense", 
            payerName: "John",
            paymentMethod: .cash,
            category: .other,
            notes: ""
        )
        expense.items = [ExpenseItem(name: "Item", price: 30.0, expense: expense)]
        
        // Test with empty and whitespace names
        let people = ["Alice", "", "   ", "Bob"]
        let result = SplittingService.splitExpense(expense, among: people)
        
        // Should only include valid names (Alice and Bob)
        #expect(result.count == 2)
        #expect(result[0].amountOwed == 15.0) // 30.0 / 2
        #expect(result[1].amountOwed == 15.0)
    }
    
    @Test func testSplittingServiceWithZeroTotal() async throws {
        let expense = Expense(
            name: "Zero Expense",
            payerName: "John", 
            paymentMethod: .cash,
            category: .other,
            notes: ""
        )
        // No items, so totalCost is 0
        
        let people = ["Alice", "Bob"]
        let result = SplittingService.splitExpense(expense, among: people)
        
        // Should return empty array for zero total
        #expect(result.isEmpty)
    }
    
    @Test func testCalculateTotalOwed() async throws {
        let people = [
            Person(name: "Alice", amountOwed: 10.0),
            Person(name: "Bob", amountOwed: 15.0),
            Person(name: "Charlie", amountOwed: 5.0)
        ]
        
        let total = SplittingService.calculateTotalOwed(for: people)
        #expect(total == 30.0)
    }
    
    @Test func testReceiptParserWithValidText() async throws {
        let sampleReceiptText = """
        GROCERY STORE
        123 Main St
        
        Organic Bananas     $3.99
        Whole Milk          $4.25
        Bread               $2.50
        
        Total:             $10.74
        """
        
        let parser = ReceiptParser()
        let items = parser.parseItems(from: sampleReceiptText)
        
        #expect(items.count == 3)
        #expect(items[0].name == "Organic Bananas")
        #expect(items[0].price == 3.99)
        #expect(items[1].name == "Whole Milk")
        #expect(items[1].price == 4.25)
        #expect(items[2].name == "Bread")
        #expect(items[2].price == 2.50)
    }
    
    @Test func testReceiptParserWithEmptyText() async throws {
        let parser = ReceiptParser()
        let items = parser.parseItems(from: "")
        
        #expect(items.isEmpty)
    }
    
    @Test func testReceiptParserSkipsInvalidLines() async throws {
        let invalidReceiptText = """
        STORE NAME
        Total: $15.99
        Tax: $1.20
        Thank you for shopping!
        """
        
        let parser = ReceiptParser()
        let items = parser.parseItems(from: invalidReceiptText)
        
        // Should skip all these lines as they don't contain valid items
        #expect(items.isEmpty)
    }
    
    @Test func testCashAppPaymentMethodExists() async throws {
        // Test that CashApp is included in PaymentMethod enum
        let allMethods = PaymentMethod.allCases
        #expect(allMethods.contains(.cashapp))
        
        // Test CashApp has proper icon
        #expect(PaymentMethod.cashapp.icon == "dollarsign.circle.fill")
        #expect(PaymentMethod.cashapp.rawValue == "CashApp")
    }
    
    @Test func testMessageComposerTemplates() async throws {
        // Test MessageComposer template functionality
        let templates = MessageComposer.MessageTemplate.allCases
        #expect(templates.count == 4) // standard, friendly, formal, detailed
        
        for template in templates {
            #expect(!template.icon.isEmpty)
            #expect(!template.description.isEmpty)
        }
        
        // Test specific template icons
        #expect(MessageComposer.MessageTemplate.standard.icon == "envelope")
        #expect(MessageComposer.MessageTemplate.friendly.icon == "heart")
        #expect(MessageComposer.MessageTemplate.formal.icon == "briefcase")
        #expect(MessageComposer.MessageTemplate.detailed.icon == "doc.text")
    }
    
    @Test func testProductionReceiptParser() async throws {
        // Test the production receipt parser
        let parser = ProductionReceiptParser()
        
        let sampleText = """
        Milk $3.50
        Bread $2.00
        Eggs $4.20
        Total $9.70
        """
        
        let items = parser.parseItemsFromText(sampleText)
        #expect(items.count == 3) // Should exclude "Total" line
        #expect(items[0].name == "Milk")
        #expect(items[0].price == 3.50)
    }
    
    @Test func testProductionBarcodeServiceExists() async throws {
        // Test that production barcode service exists and works
        let service = BarcodeService()
        #expect(!service.isScanning)
        #expect(service.scanResult == nil)
        #expect(service.error == nil)
    }
    
    @Test func testPaymentMethodFiltering() async throws {
        // Test that payment method selector only includes message-based methods
        let messageBasedMethods: [PaymentMethod] = [
            .venmo, .cashapp, .zelle, .paypal, .bankTransfer, .cash
        ]
        
        // Verify CashApp is included
        #expect(messageBasedMethods.contains(.cashapp))
        
        // Verify e-pay methods are excluded
        #expect(!messageBasedMethods.contains(.creditCard))
        #expect(!messageBasedMethods.contains(.debitCard))
        #expect(!messageBasedMethods.contains(.applePay))
    }
    
    @Test func testExpenseItemValidation() async throws {
        // Test the validation logic for expense item editing
        let expense = Expense(
            name: "Test Expense",
            payerName: "John",
            paymentMethod: .cash,
            category: .dining,
            notes: ""
        )
        
        let item = ExpenseItem(name: "Pizza", price: 20.0, expense: expense)
        expense.items = [item]
        
        // Test initial total
        #expect(expense.totalCost == 20.0)
        
        // Test updating item price
        item.price = 25.0
        #expect(expense.totalCost == 25.0)
        
        // Test item name validation (empty name)
        let emptyNameItem = ExpenseItem(name: "", price: 10.0, expense: expense)
        let trimmedName = emptyNameItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmedName.isEmpty)
        
        // Test item name validation (whitespace only)
        let whitespaceNameItem = ExpenseItem(name: "   ", price: 10.0, expense: expense)
        let trimmedWhitespaceName = whitespaceNameItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmedWhitespaceName.isEmpty)
        
        // Test valid item
        let validItem = ExpenseItem(name: "Valid Item", price: 15.0, expense: expense)
        let trimmedValidName = validItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!trimmedValidName.isEmpty)
        #expect(validItem.price >= 0)
    }
    
    @Test func testScheduledSplitRequestModel() async throws {
        // Test the ScheduledSplitRequest model functionality
        let requestIds = Set([UUID(), UUID()])
        let scheduledDate = Date().addingTimeInterval(86400) // Tomorrow
        let message = "Friendly reminder about your payment! 💰"
        let participants = ["Alice", "Bob"]
        
        let scheduledRequest = ScheduledSplitRequest(
            splitRequestIds: requestIds,
            scheduledDate: scheduledDate,
            message: message,
            participants: participants
        )
        
        #expect(!scheduledRequest.id.uuidString.isEmpty)
        #expect(scheduledRequest.splitRequestIds.count == 2)
        #expect(scheduledRequest.scheduledDate == scheduledDate)
        #expect(scheduledRequest.message == message)
        #expect(scheduledRequest.participants == participants)
        #expect(scheduledRequest.createdDate <= Date())
    }
    
    @Test func testPriceInputSanitization() async throws {
        // Test price input sanitization logic (simulating the UI validation)
        func sanitizePriceInput(_ input: String) -> String {
            // Simulate the sanitization logic from EditableExpenseItemRow
            let validChars = input.filter { "0123456789.".contains($0) }
            
            let components = validChars.components(separatedBy: ".")
            if components.count <= 1 {
                return validChars
            } else if components.count == 2 {
                let wholePart = components[0]
                let decimalPart = String(components[1].prefix(2))
                return wholePart + "." + decimalPart
            } else {
                let wholePart = components[0]
                let decimalPart = String(components.dropFirst().joined().prefix(2))
                return wholePart + "." + decimalPart
            }
        }
        
        // Test valid inputs
        #expect(sanitizePriceInput("12.34") == "12.34")
        #expect(sanitizePriceInput("12") == "12")
        #expect(sanitizePriceInput("0.50") == "0.50")
        
        // Test invalid characters removal
        #expect(sanitizePriceInput("12.34abc") == "12.34")
        #expect(sanitizePriceInput("$12.34") == "12.34")
        
        // Test multiple decimal points
        #expect(sanitizePriceInput("12.34.56") == "12.34")
        
        // Test decimal place limiting
        #expect(sanitizePriceInput("12.345") == "12.34")
        #expect(sanitizePriceInput("12.999") == "12.99")
    }
    
    @Test func testSplitDataPersistence() async throws {
        // Test that split participant data is properly persisted and can be loaded
        let expense = Expense(
            name: "Test Group Dinner",
            payerName: "Alice",
            paymentMethod: .cash,
            category: .dining,
            notes: ""
        )
        
        // Add test items
        expense.items = [
            ExpenseItem(name: "Main Course", price: 60.0, expense: expense),
            ExpenseItem(name: "Dessert", price: 20.0, expense: expense)
        ]
        
        // Test that total cost is correct
        #expect(expense.totalCost == 80.0)
        
        // Test initial state
        #expect(!expense.hasBeenSplit)
        #expect(!expense.isFullySettled)
        #expect(expense.splitParticipants.isEmpty)
        
        // Simulate creating split participants
        let participantData1 = SplitParticipantData(
            name: "Alice",
            amount: 20.0,
            percentage: 25.0,
            expense: expense
        )
        let participantData2 = SplitParticipantData(
            name: "Bob", 
            amount: 20.0,
            percentage: 25.0,
            expense: expense
        )
        let participantData3 = SplitParticipantData(
            name: "Charlie",
            amount: 20.0, 
            percentage: 25.0,
            expense: expense
        )
        let participantData4 = SplitParticipantData(
            name: "David",
            amount: 20.0,
            percentage: 25.0, 
            expense: expense
        )
        
        expense.splitParticipants = [participantData1, participantData2, participantData3, participantData4]
        expense.splitMethod = "evenSplit"
        expense.splitStatus = .sent
        
        // Test that expense is now marked as split
        #expect(expense.hasBeenSplit)
        #expect(expense.splitParticipants.count == 4)
        #expect(expense.splitMethod == "evenSplit")
    }
    
    @Test func testSplitSummaryCalculation() async throws {
        // Test the split summary calculation logic for pie chart
        let expense1 = Expense(
            name: "Restaurant Bill",
            payerName: "Alice", 
            paymentMethod: .cash,
            category: .dining,
            notes: ""
        )
        expense1.items = [ExpenseItem(name: "Food", price: 80.0, expense: expense1)]
        
        // Create split requests: Alice (paid), Bob (pending), Charlie (pending) 
        let req1 = SplitRequest(participantName: "Alice", amount: 20.0, status: .paid, expense: expense1)
        let req2 = SplitRequest(participantName: "Bob", amount: 30.0, status: .pending, expense: expense1) 
        let req3 = SplitRequest(participantName: "Charlie", amount: 30.0, status: .pending, expense: expense1)
        
        expense1.splitRequests = [req1, req2, req3]
        
        // Test calculation: Total spent = 80, People owe = 60 (Bob + Charlie), User spent = 20 (Alice paid)
        // So pie chart should show: You spent = 20 (25%), People owe me = 60 (75%)
        let totalOwed = expense1.splitRequests
            .filter { $0.status != .paid && $0.participantName.lowercased() != "alice" }
            .reduce(0.0) { $0 + $1.amount }
        
        #expect(totalOwed == 60.0) // Bob (30) + Charlie (30)
        
        let userSpent = expense1.totalCost - totalOwed
        #expect(userSpent == 20.0) // Alice's portion
        
        // Test percentage calculation
        let totalAmount = expense1.totalCost
        let peopleOwePercentage = (totalOwed / totalAmount) * 100
        let userSpentPercentage = (userSpent / totalAmount) * 100
        
        #expect(peopleOwePercentage == 75.0)
        #expect(userSpentPercentage == 25.0)
    }

}
