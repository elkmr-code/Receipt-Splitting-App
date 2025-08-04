import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Receipt Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Date: \(receipt.date, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Paid by: \(receipt.payerName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Total: \(receipt.totalCost, format: .currency(code: "USD"))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Items List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let items = receipt.items, !items.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                    Text(item.price, format: .currency(code: "USD"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                
                                Divider()
                                    .padding(.leading)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    } else {
                        Text("No items found. Process a receipt to add items.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let receipt = Receipt(name: "Grocery Run - Aug 4", payerName: "John Doe")
    return ReceiptDetailView(receipt: receipt)
}