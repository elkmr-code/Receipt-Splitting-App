import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var receipts: [Receipt]
    @Query private var roommates: [Roommate]
    
    @State private var showingAddReceipt = false
    @State private var showingDemoMode = false
    @State private var selectedReceipt: Receipt?
    
    var body: some View {
        NavigationStack {
            VStack {
                if receipts.isEmpty {
                    emptyStateView
                } else {
                    receiptListContent
                }
            }
            .navigationTitle("Grocery Splits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddReceipt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Demo") {
                        showingDemoMode = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showingAddReceipt) {
                AddReceiptView()
            }
            .sheet(isPresented: $showingDemoMode) {
                DemoModeView()
            }
            .onAppear {
                ensureDefaultRoommates()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Receipts Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add your first grocery receipt to start splitting costs with your roommates!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    showingAddReceipt = true
                } label: {
                    Label("Add Receipt", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button {
                    showingDemoMode = true
                } label: {
                    Label("Try Demo", systemImage: "play.circle")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var receiptListContent: some View {
        List {
            ForEach(receipts.sorted { $0.date > $1.date }) { receipt in
                ReceiptRowView(receipt: receipt)
                    .onTapGesture {
                        selectedReceipt = receipt
                    }
            }
            .onDelete(perform: deleteReceipts)
        }
        .navigationDestination(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
    }
    
    private func deleteReceipts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let sortedReceipts = receipts.sorted { $0.date > $1.date }
                modelContext.delete(sortedReceipts[index])
            }
        }
    }
    
    private func ensureDefaultRoommates() {
        if roommates.isEmpty {
            let _ = SplittingService.createDefaultRoommates(modelContext: modelContext)
            try? modelContext.save()
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.date, style: .date)
                        .font(.headline)
                    
                    Text("\(receipt.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(receipt.calculatedTotal, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if receipt.isSettled {
                        Text("Settled")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Show involved roommates
            HStack(spacing: 8) {
                Text("Split between:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(receipt.involvedRoommates, id: \.id) { roommate in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(roommate.displayColor)
                            .frame(width: 12, height: 12)
                        
                        Text(roommate.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Settlement preview
            let suggestions = receipt.settlementSuggestions()
            if !suggestions.isEmpty && !receipt.isSettled {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Text("\(suggestion.from.name) owes \(suggestion.to.name) \(suggestion.amount, format: .currency(code: "USD"))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// Demo Mode View for quick demonstration
struct DemoModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ocrService = OCRService()
    
    @State private var isRunningDemo = false
    @State private var demoStep = 0
    @State private var demoReceipt: Receipt?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Demo Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("See how Shared Grocery Split works with a sample receipt")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isRunningDemo {
                    demoProgressView
                } else {
                    Button {
                        runDemo()
                    } label: {
                        Text("Start Demo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .navigationTitle("Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var demoProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(demoStepText)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let receipt = demoReceipt {
                Button {
                    dismiss()
                    // Navigate to receipt detail - this would need to be handled by parent
                } label: {
                    Text("View Results")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    private var demoStepText: String {
        switch demoStep {
        case 0: return "Loading sample receipt..."
        case 1: return "Running OCR scan..."
        case 2: return "Parsing items..."
        case 3: return "Splitting between roommates..."
        case 4: return "Calculating balances..."
        default: return "Demo complete!"
        }
    }
    
    private func runDemo() {
        isRunningDemo = true
        demoStep = 0
        
        Task {
            // Step 1: Simulate loading
            try await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { demoStep = 1 }
            
            // Step 2: Run OCR
            let ocrText = try await ocrService.simulateOCRProcessing()
            await MainActor.run { demoStep = 2 }
            
            // Step 3: Parse items
            try await Task.sleep(nanoseconds: 500_000_000)
            let (parsedItems, total) = ReceiptParser.parseReceiptTextEnhanced(ocrText)
            await MainActor.run { demoStep = 3 }
            
            // Step 4: Split items
            try await Task.sleep(nanoseconds: 500_000_000)
            let roommates = getRoommates()
            let items = SplittingService.splitItems(parsedItems, among: roommates, modelContext: modelContext)
            await MainActor.run { demoStep = 4 }
            
            // Step 5: Create receipt
            try await Task.sleep(nanoseconds: 500_000_000)
            let receipt = Receipt(rawText: ocrText)
            receipt.items = items
            
            for item in items {
                item.receipt = receipt
                modelContext.insert(item)
            }
            
            modelContext.insert(receipt)
            try? modelContext.save()
            
            await MainActor.run {
                demoReceipt = receipt
                demoStep = 5
            }
        }
    }
    
    private func getRoommates() -> [Roommate] {
        let descriptor = FetchDescriptor<Roommate>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

#Preview {
    ReceiptListView()
        .modelContainer(for: [Receipt.self, Item.self, Roommate.self])
}
