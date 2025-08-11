import SwiftUI

// MARK: - Item Selection View
struct ItemSelectionView: View {
    let scanResult: ScanResult
    @Binding var selectedItems: Set<UUID>
    let onConfirm: ([ParsedItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Add local state to ensure selection works properly
    @State private var localSelectedItems: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header with scan info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: scanResult.type.icon)
                            .foregroundColor(.blue)
                        Text("\(scanResult.type.displayName) Result")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text("Source: \(scanResult.sourceId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Found \(scanResult.items.count) items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Receipt thumbnail and raw text
                if let image = scanResult.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 140)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                DisclosureGroup("View Original Text") {
                    ScrollView {
                        Text(scanResult.originalText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(.horizontal)

                // Selection controls
                HStack(spacing: 16) {
                    Button("Select All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            localSelectedItems = Set(scanResult.items.map { $0.id })
                            selectedItems = localSelectedItems
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Clear All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            localSelectedItems.removeAll()
                            selectedItems.removeAll()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("\(localSelectedItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Items list with improved selection handling
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scanResult.items) { item in
                            ItemSelectionRow(
                                item: item,
                                scanType: scanResult.type,
                                isSelected: localSelectedItems.contains(item.id),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if localSelectedItems.contains(item.id) {
                                            localSelectedItems.remove(item.id)
                                        } else {
                                            localSelectedItems.insert(item.id)
                                        }
                                        selectedItems = localSelectedItems
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Total for selected items
                if !localSelectedItems.isEmpty {
                    let selectedTotal = scanResult.items.filter { localSelectedItems.contains($0.id) }
                        .reduce(0) { $0 + $1.totalPrice }
                    
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
                    .transition(.opacity.combined(with: .scale))
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
                    Button("Add Items (\(localSelectedItems.count))") {
                        let itemsToAdd = scanResult.items.filter { localSelectedItems.contains($0.id) }
                        onConfirm(itemsToAdd)
                        dismiss()
                    }
                    .disabled(localSelectedItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Initialize local state with bound state
            localSelectedItems = selectedItems
        }
    }
}

// MARK: - Item Selection Row Component
struct ItemSelectionRow: View {
    let item: ParsedItem
    let scanType: ScanType
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator with animation
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("From \(scanType.displayName.lowercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if item.quantity > 1 {
                            Text("• Qty: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.totalPrice, format: .currency(code: "USD"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    if item.quantity > 1 {
                        Text("\(item.price, format: .currency(code: "USD")) each")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                Group {
                    if isSelected {
                        Color.blue.opacity(0.1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button highlighting
    }
}

// MARK: - Scanning Results View
struct ScanningResultsView: View {
    let scanResult: ScanResult
    let onAddAll: () -> Void
    let onChooseItems: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: scanResult.type.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("\(scanResult.type.displayName) Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Found \(scanResult.items.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Items preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Items Found:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(scanResult.items.prefix(5)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                Spacer()
                                Text(item.price, format: .currency(code: "USD"))
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        if scanResult.items.count > 5 {
                            Text("... and \(scanResult.items.count - 5) more items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                HStack {
                    Text("Total:")
                        .font(.headline)
                    Spacer()
                    Text(scanResult.total, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onAddAll) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add All Items")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: onChooseItems) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Choose Items")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
                
                Button("Cancel", action: onCancel)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    let mockResult = ScanResult(
        type: .barcode,
        sourceId: "TXN12345",
        items: [
            ParsedItem(name: "Milk", price: 2.50),
            ParsedItem(name: "Bread", price: 1.20),
            ParsedItem(name: "Apples", price: 3.00)
        ],
        originalText: "Milk 2.50\nBread 1.20\nApples 3.00\nTotal 6.70", image: nil
    )
    
    ItemSelectionView(
        scanResult: mockResult,
        selectedItems: .constant(Set()),
        onConfirm: { _ in }
    )
}
