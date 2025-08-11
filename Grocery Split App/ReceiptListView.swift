import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false
    @State private var showingDashboard = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if expenses.isEmpty {
                    // Empty state with sample data option
                    VStack(spacing: 20) {
                        Image(systemName: "receipt")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Expenses Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Split bills and expenses with family and friends")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Button(action: { showingAddExpense = true }) {
                                Label("Add Your First Expense", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(expenses) { expense in
                            NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                                ExpenseRowView(expense: expense)
                            }
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                }
            }
            .navigationTitle("Expense Split")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingDashboard = true }) {
                        Image(systemName: "rectangle.grid.2x2")
                    }
                }
                
                if !expenses.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingDashboard) {
                DashboardView()
            }
        }
    }
    
    private func deleteExpenses(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenses[index])
        }
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: expense.category.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(expense.totalCost, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expense.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: expense.paymentMethod.icon)
                            .font(.caption)
                        Text(expense.paymentMethod.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Text("Paid by \(expense.payerName)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpenseListView()
        .modelContainer(for: [Expense.self, ExpenseItem.self, Receipt.self, SplitRequest.self])
}
