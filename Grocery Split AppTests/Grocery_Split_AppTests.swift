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

}
