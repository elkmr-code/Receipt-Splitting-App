import Foundation
import SwiftUI

// MARK: - Barcode Service
class BarcodeService: ObservableObject {
    @Published var isScanning = false
    @Published var scanResult: String?
    @Published var error: String?
    
    // Mock receipt database
    private let mockReceipts: [String: String] = [
        "TXN12345": """
        Milk 3.50
        Bread 2.00
        Eggs 4.20
        Apple 1.00
        Total 10.70
        """,
        "TXN67890": """
        Organic Bananas 3.99
        Whole Milk 1 Gallon 4.29
        Greek Yogurt 5.49
        Chicken Breast 12.99
        Broccoli 2.99
        Total 29.75
        """,
        "TXN11111": """
        Coffee Beans 12.99
        Orange Juice 3.79
        Pasta 1.99
        Pasta Sauce 2.49
        Parmesan Cheese 6.99
        Total 28.25
        """
    ]
    
    // Simulate barcode scanning
    func scanBarcode() async throws -> String {
        await MainActor.run {
            isScanning = true
            error = nil
            scanResult = nil
        }
        
        // Simulate scanning delay
        try await Task.sleep(for: .seconds(2))
        
        // Randomly select a mock barcode
        let mockBarcodes = Array(mockReceipts.keys)
        let randomBarcode = mockBarcodes.randomElement() ?? "TXN12345"
        
        await MainActor.run {
            isScanning = false
            scanResult = randomBarcode
        }
        
        return randomBarcode
    }
    
    // Get receipt text for a barcode
    func getReceiptText(for barcode: String) -> String? {
        return mockReceipts[barcode]
    }
    
    // Get all available mock barcodes (for testing)
    func getAvailableBarcodes() -> [String] {
        return Array(mockReceipts.keys)
    }
}

// MARK: - Barcode Receipt Parser
struct BarcodeReceiptParser {
    
    struct ParsedItem {
        let name: String
        let price: Double
        
        var asTuple: (name: String, price: Double) {
            return (name: name, price: price)
        }
    }
    
    func parseItems(from receiptText: String) -> [ParsedItem] {
        let lines = receiptText.components(separatedBy: .newlines)
        var items: [ParsedItem] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and total lines
            if trimmedLine.isEmpty || 
               trimmedLine.lowercased().contains("total") ||
               trimmedLine.lowercased().contains("subtotal") ||
               trimmedLine.lowercased().contains("tax") {
                continue
            }
            
            // Parse line format: "Item Name Price"
            // Look for the last space-separated number as the price
            let components = trimmedLine.components(separatedBy: " ")
            
            if components.count >= 2,
               let priceString = components.last,
               let price = Double(priceString),
               price > 0 {
                
                // Join all components except the last one as the item name
                let nameComponents = Array(components.dropLast())
                let itemName = nameComponents.joined(separator: " ")
                
                if !itemName.isEmpty {
                    items.append(ParsedItem(name: itemName, price: price))
                }
            }
        }
        
        return items
    }
}

// MARK: - Barcode Scanner View Model
@MainActor
class BarcodeScannerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scannedBarcode: String?
    @Published var parsedItems: [BarcodeReceiptParser.ParsedItem] = []
    @Published var showingResults = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var selectedItems: Set<Int> = []
    
    private let barcodeService = BarcodeService()
    private let parser = BarcodeReceiptParser()
    
    func startScanning() {
        Task {
            do {
                isScanning = true
                let barcode = try await barcodeService.scanBarcode()
                
                // Get receipt text for the scanned barcode
                if let receiptText = barcodeService.getReceiptText(for: barcode) {
                    let items = parser.parseItems(from: receiptText)
                    
                    await MainActor.run {
                        self.scannedBarcode = barcode
                        self.parsedItems = items
                        self.showingResults = true
                        self.isScanning = false
                        
                        // Pre-select all items by default
                        self.selectedItems = Set(0..<items.count)
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "No receipt found for barcode: \(barcode)"
                        self.showingError = true
                        self.isScanning = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Scanning failed: \(error.localizedDescription)"
                    self.showingError = true
                    self.isScanning = false
                }
            }
        }
    }
    
    func toggleItemSelection(at index: Int) {
        if selectedItems.contains(index) {
            selectedItems.remove(index)
        } else {
            selectedItems.insert(index)
        }
    }
    
    func selectAllItems() {
        selectedItems = Set(0..<parsedItems.count)
    }
    
    func deselectAllItems() {
        selectedItems.removeAll()
    }
    
    func getSelectedItems() -> [(name: String, price: Double)] {
        return selectedItems.compactMap { index in
            guard index < parsedItems.count else { return nil }
            return parsedItems[index].asTuple
        }
    }
    
    func reset() {
        scannedBarcode = nil
        parsedItems = []
        showingResults = false
        selectedItems = []
        isScanning = false
    }
}