import SwiftUI
import SwiftData
import Charts

struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var roommates: [Roommate]
    
    let receipt: Receipt
    
    @State private var showingShareSheet = false
    @State private var showingEditMode = false
    @State private var selectedItem: Item?
    @State private var showingReassignSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    receiptHeaderSection
                    balanceSummarySection
                    itemsGroupedByRoommateSection
                    settlementSection
                    if !receipt.isSettled {
                        actionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Receipt Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share Split", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showingEditMode.toggle()
                        } label: {
                            Label(showingEditMode ? "Done Editing" : "Edit Items", 
                                  systemImage: showingEditMode ? "checkmark" : "pencil")
                        }
                        
                        if !receipt.isSettled {
                            Button {
                                markAsSettled()
                            } label: {
                                Label("Mark as Settled", systemImage: "checkmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(receipt: receipt)
            }
            .sheet(item: $selectedItem) { item in
                ReassignItemSheet(item: item, roommates: roommates) { newRoommate in
                    reassignItem(item, to: newRoommate)
                }
            }
        }
    }
    
    private var receiptHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "receipt.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.date, style: .date)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(receipt.items.count) items")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(receipt.calculatedTotal, format: .currency(code: "USD"))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Circle()
                            .fill(receipt.isSettled ? .green : .orange)
                            .frame(width: 8, height: 8)
                        
                        Text(receipt.isSettled ? "Settled" : "Pending")
                            .font(.caption)
                            .foregroundColor(receipt.isSettled ? .green : .orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private var balanceSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            let balances = receipt.calculateBalances()
            let avgAmount = receipt.calculatedTotal / Double(balances.count)
            
            VStack(spacing: 12) {
                ForEach(receipt.involvedRoommates, id: \.id) { roommate in
                    let amount = balances[roommate] ?? 0.0
                    let difference = amount - avgAmount
                    
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(roommate.displayColor)
                                .frame(width: 20, height: 20)
                            
                            Text(roommate.name)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(amount, format: .currency(code: "USD"))
                                .font(.body)
                                .fontWeight(.semibold)
                            
                            if abs(difference) > 0.01 {
                                Text(difference > 0 ? "owes \(difference, format: .currency(code: "USD"))" : "gets \(abs(difference), format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundColor(difference > 0 ? .red : .green)
                            } else {
                                Text("even")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(roommate.displayColor.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Balance chart using iOS 17 Charts
            if #available(iOS 17.0, *) {
                balanceChartSection(balances: balances)
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func balanceChartSection(balances: [Roommate: Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending Breakdown")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Chart {
                ForEach(receipt.involvedRoommates, id: \.id) { roommate in
                    let amount = balances[roommate] ?? 0.0
                    SectorMark(
                        angle: .value("Amount", amount),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(roommate.displayColor)
                    .opacity(0.8)
                }
            }
            .frame(height: 120)
        }
        .padding(.top)
    }
    
    private var itemsGroupedByRoommateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Items by Person")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(receipt.involvedRoommates, id: \.id) { roommate in
                RoommateItemsSection(
                    roommate: roommate,
                    items: receipt.items.filter { $0.assignedTo?.id == roommate.id },
                    isEditMode: showingEditMode
                ) { item in
                    if showingEditMode {
                        selectedItem = item
                    }
                }
            }
        }
    }
    
    private var settlementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settlement")
                .font(.headline)
                .fontWeight(.semibold)
            
            let suggestions = receipt.settlementSuggestions()
            
            if suggestions.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("All balanced! No transfers needed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SettlementRow(suggestion: suggestion)
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                markAsSettled()
            } label: {
                Label("Mark as Settled", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            
            Button {
                showingShareSheet = true
            } label: {
                Label("Share Summary", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    private func markAsSettled() {
        withAnimation(.easeInOut(duration: 0.5)) {
            receipt.isSettled = true
            try? modelContext.save()
        }
    }
    
    private func reassignItem(_ item: Item, to roommate: Roommate) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            item.assignedTo = roommate
            try? modelContext.save()
        }
    }
}

struct RoommateItemsSection: View {
    let roommate: Roommate
    let items: [Item]
    let isEditMode: Bool
    let onItemTap: (Item) -> Void
    
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(roommate.displayColor)
                        .frame(width: 16, height: 16)
                    
                    Text(roommate.name)
                        .font(.headline)
                }
                
                Spacer()
                
                Text(totalAmount, format: .currency(code: "USD"))
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(items, id: \.id) { item in
                    ItemRow(item: item, isEditMode: isEditMode) {
                        onItemTap(item)
                    }
                }
            }
        }
        .padding()
        .background(roommate.displayColor.opacity(0.1))
        .cornerRadius(16)
        .animation(.default, value: items.count)
    }
}

struct ItemRow: View {
    let item: Item
    let isEditMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if item.quantity > 1 {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(item.totalPrice, format: .currency(code: "USD"))
                    .font(.body)
                    .fontWeight(.semibold)
                
                if isEditMode {
                    Button {
                        onTap()
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                onTap()
            }
        }
    }
}

struct SettlementRow: View {
    let suggestion: (from: Roommate, to: Roommate, amount: Double)
    
    var body: some View {
        HStack(spacing: 12) {
            // From person
            HStack(spacing: 6) {
                Circle()
                    .fill(suggestion.from.displayColor)
                    .frame(width: 12, height: 12)
                
                Text(suggestion.from.name)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            // To person
            HStack(spacing: 6) {
                Circle()
                    .fill(suggestion.to.displayColor)
                    .frame(width: 12, height: 12)
                
                Text(suggestion.to.name)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Text(suggestion.amount, format: .currency(code: "USD"))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ReassignItemSheet: View {
    let item: Item
    let roommates: [Roommate]
    let onReassign: (Roommate) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Reassign Item")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Who should \"\(item.name)\" be assigned to?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    ForEach(roommates, id: \.id) { roommate in
                        Button {
                            onReassign(roommate)
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(roommate.displayColor)
                                    .frame(width: 20, height: 20)
                                
                                Text(roommate.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if item.assignedTo?.id == roommate.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(roommate.displayColor.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let receipt: Receipt
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = generateShareText()
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    private func generateShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var text = "🛒 Grocery Split Summary\n"
        text += "Date: \(formatter.string(from: receipt.date))\n"
        text += "Total: \(receipt.calculatedTotal.formatted(.currency(code: "USD")))\n\n"
        
        text += "Items by person:\n"
        for roommate in receipt.involvedRoommates {
            let roommateItems = receipt.items.filter { $0.assignedTo?.id == roommate.id }
            let total = roommateItems.reduce(0) { $0 + $1.totalPrice }
            
            text += "\n\(roommate.name): \(total.formatted(.currency(code: "USD")))\n"
            for item in roommateItems {
                text += "  • \(item.name): \(item.totalPrice.formatted(.currency(code: "USD")))\n"
            }
        }
        
        let suggestions = receipt.settlementSuggestions()
        if !suggestions.isEmpty {
            text += "\nSettlement:\n"
            for suggestion in suggestions {
                text += "\(suggestion.from.name) owes \(suggestion.to.name) \(suggestion.amount.formatted(.currency(code: "USD")))\n"
            }
        }
        
        text += "\nShared via Grocery Split App"
        
        return text
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Receipt.self, Item.self, Roommate.self, SplitPreference.self, configurations: config)
    
    // Create sample data
    let alice = Roommate(name: "Alice", colorTag: "blue")
    let bob = Roommate(name: "Bob", colorTag: "green")
    
    let receipt = Receipt()
    let item1 = Item(name: "Bananas", price: 3.99)
    let item2 = Item(name: "Milk", price: 4.59)
    
    item1.assignedTo = alice
    item2.assignedTo = bob
    item1.receipt = receipt
    item2.receipt = receipt
    
    receipt.items = [item1, item2]
    
    container.mainContext.insert(alice)
    container.mainContext.insert(bob)
    container.mainContext.insert(receipt)
    container.mainContext.insert(item1)
    container.mainContext.insert(item2)
    
    return ReceiptDetailView(receipt: receipt)
        .modelContainer(container)
}
