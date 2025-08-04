import SwiftUI
import SwiftData

struct ReceiptListView: View {
    @Query(sort: \Receipt.date, order: .reverse) var receipts: [Receipt]
    @State private var showingAddReceipt = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(receipts) { receipt in
                    NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(receipt.name)
                                .font(.headline)
                            Text(receipt.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Total: \(receipt.totalCost, format: .currency(code: "USD"))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("All Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddReceipt = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReceipt) {
                AddReceiptView()
            }
        }
    }
}

#Preview {
    ReceiptListView()
        .modelContainer(for: [Receipt.self, Item.self])
}