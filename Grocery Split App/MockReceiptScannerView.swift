import SwiftUI

/*
 MockReceiptScannerView - A complete SwiftUI view that simulates barcode scanning
 
 Features:
 - Simulates scanning a hardcoded barcode "MOCK123"
 - Displays the receipt_sample.png image as visual reference
 - Parses mock receipt data into ReceiptItem objects
 - Shows "Import Receipt?" alert with "Add All" or "Select Items" options
 - Provides item selection sheet with toggles for individual selection
 - Formats all prices as currency
 - Maintains a running list of imported items with total
 
 Usage:
 1. Add this view to your app navigation
 2. Make sure receipt_sample.png is in your Assets
 3. Tap "Scan Receipt Barcode" to simulate scanning
 4. Choose "Add All" or "Select Items" from the alert
 5. Items are added to the local @State array
 
 Integration with existing app:
 - You can modify the onConfirm callbacks to integrate with your existing data models
 - Replace ReceiptItem with your existing ExpenseItem if needed
 - Customize the mock receipt data in mockReceipts dictionary
 */

// MARK: - ReceiptItem Model
struct ReceiptItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let price: Double
    
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
}

// MARK: - Mock Receipt Scanner View
struct MockReceiptScannerView: View {
    @State private var receiptItems: [ReceiptItem] = []
    @State private var showingImportAlert = false
    @State private var showingItemSelection = false
    @State private var parsedItems: [ReceiptItem] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var isScanning = false
    
    // Mock receipt database
    private let mockReceipts: [String: String] = [
        "MOCK123": """
        Coca-Cola 2.50
        Doritos 3.00
        Bananas 1.20
        Ice Cream 4.00
        Total 10.70
        """
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Text("Mock Receipt Scanner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Receipt Image (if available)
                if let receiptImage = UIImage(named: "receipt_sample") {
                    VStack(spacing: 12) {
                        Text("Sample Receipt")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Image(uiImage: receiptImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
                
                // Scan Button
                Button(action: scanReceiptBarcode) {
                    HStack(spacing: 12) {
                        if isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                        }
                        
                        Text(isScanning ? "Scanning..." : "Scan Receipt Barcode")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isScanning ? Color.gray : Color.blue)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .disabled(isScanning)
                .padding(.horizontal)
                
                // Current Receipt Items
                if !receiptItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Receipt Items")
                                .font(.headline)
                            Spacer()
                            Text("Total: \(totalPrice, format: .currency(code: "USD"))")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(receiptItems) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text("Receipt item")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(item.price, format: .currency(code: "USD"))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No items scanned yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Tap 'Scan Receipt Barcode' to import items from a receipt")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                }
                
                Spacer()
            }
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Import Receipt?", isPresented: $showingImportAlert) {
            Button("Add All") {
                addAllItems()
            }
            
            Button("Select Items") {
                showingItemSelection = true
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Found \(parsedItems.count) items. Do you want to add all items or select specific ones?")
        }
        .sheet(isPresented: $showingItemSelection) {
            ItemSelectionSheet(
                items: parsedItems,
                selectedItems: $selectedItems,
                onConfirm: addSelectedItems
            )
        }
    }
    
    // MARK: - Computed Properties
    private var totalPrice: Double {
        return receiptItems.reduce(0) { $0 + $1.price }
    }
    
    // MARK: - Methods
    private func scanReceiptBarcode() {
        isScanning = true
        
        // Simulate scanning delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isScanning = false
            
            // Hardcoded barcode ID
            let barcodeID = "MOCK123"
            
            // Retrieve mock receipt
            if let receiptText = mockReceipts[barcodeID] {
                parsedItems = parseReceiptText(receiptText)
                
                if !parsedItems.isEmpty {
                    // Pre-select all items
                    selectedItems = Set(parsedItems.map { $0.id })
                    showingImportAlert = true
                }
            }
        }
    }
    
    private func parseReceiptText(_ text: String) -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [ReceiptItem] = []
        
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
            let components = trimmedLine.components(separatedBy: " ")
            
            if components.count >= 2,
               let priceString = components.last,
               let price = Double(priceString),
               price > 0 {
                
                // Join all components except the last one as the item name
                let nameComponents = Array(components.dropLast())
                let itemName = nameComponents.joined(separator: " ")
                
                if !itemName.isEmpty {
                    items.append(ReceiptItem(name: itemName, price: price))
                }
            }
        }
        
        return items
    }
    
    private func addAllItems() {
        receiptItems.append(contentsOf: parsedItems)
        parsedItems.removeAll()
        selectedItems.removeAll()
    }
    
    private func addSelectedItems() {
        let itemsToAdd = parsedItems.filter { selectedItems.contains($0.id) }
        receiptItems.append(contentsOf: itemsToAdd)
        parsedItems.removeAll()
        selectedItems.removeAll()
    }
}

// MARK: - Item Selection Sheet
struct ItemSelectionSheet: View {
    let items: [ReceiptItem]
    @Binding var selectedItems: Set<UUID>
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header with receipt image
                if let receiptImage = UIImage(named: "receipt_sample") {
                    VStack(spacing: 8) {
                        Text("Reference Receipt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(uiImage: receiptImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                Text("Select items to import:")
                    .font(.headline)
                    .padding(.horizontal)
                
                // Selection controls
                HStack(spacing: 16) {
                    Button("Select All") {
                        selectedItems = Set(items.map { $0.id })
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Clear All") {
                        selectedItems.removeAll()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("\(selectedItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Items list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            let isSelected = selectedItems.contains(item.id)
                            
                            Button(action: {
                                if isSelected {
                                    selectedItems.remove(item.id)
                                } else {
                                    selectedItems.insert(item.id)
                                }
                            }) {
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isSelected ? .blue : .gray)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("From receipt scan")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(item.price, format: .currency(code: "USD"))
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Total for selected items
                if !selectedItems.isEmpty {
                    let selectedTotal = items.filter { selectedItems.contains($0.id) }
                        .reduce(0) { $0 + $1.price }
                    
                    HStack {
                        Text("Selected Total:")
                            .font(.headline)
                        Spacer()
                        Text(selectedTotal, format: .currency(code: "USD"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Select Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(selectedItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MockReceiptScannerView()
}