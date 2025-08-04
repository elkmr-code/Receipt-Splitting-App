import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false
    
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
                            
                            Button(action: addSampleData) {
                                Label("Add Sample Data", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
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
                
                if !expenses.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
        }
    }
    
    private func deleteExpenses(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenses[index])
        }
    }
    
    private func addSampleData() {
        let sampleExpenses = [
            Expense(
                name: "Dinner at Italian Restaurant",
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                payerName: "Sarah",
                paymentMethod: .creditCard,
                category: .dining,
                notes: "Birthday celebration for Mike"
            ),
            Expense(
                name: "Weekend Grocery Shopping",
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                payerName: "John",
                paymentMethod: .applePay,
                category: .groceries,
                notes: "Shared groceries for the house"
            ),
            Expense(
                name: "Movie Night",
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                payerName: "Emily",
                paymentMethod: .venmo,
                category: .entertainment,
                notes: "Tickets and snacks"
            )
        ]
        
        // Add sample items to expenses
        for expense in sampleExpenses {
            modelContext.insert(expense)
            
            switch expense.category {
            case .dining:
                let items = [
                    ExpenseItem(name: "Pasta Carbonara", price: 18.50, expense: expense),
                    ExpenseItem(name: "Margherita Pizza", price: 16.00, expense: expense),
                    ExpenseItem(name: "Caesar Salad", price: 12.00, expense: expense),
                    ExpenseItem(name: "Tiramisu", price: 8.50, expense: expense),
                    ExpenseItem(name: "Wine Bottle", price: 25.00, expense: expense)
                ]
                for item in items {
                    modelContext.insert(item)
                    expense.items.append(item)
                }
                
            case .groceries:
                let items = [
                    ExpenseItem(name: "Organic Bananas", price: 3.99, expense: expense),
                    ExpenseItem(name: "Whole Milk", price: 4.25, expense: expense),
                    ExpenseItem(name: "Bread", price: 2.50, expense: expense),
                    ExpenseItem(name: "Chicken Breast", price: 12.99, expense: expense),
                    ExpenseItem(name: "Mixed Vegetables", price: 6.75, expense: expense)
                ]
                for item in items {
                    modelContext.insert(item)
                    expense.items.append(item)
                }
                
            case .entertainment:
                let items = [
                    ExpenseItem(name: "Movie Tickets (x3)", price: 36.00, expense: expense),
                    ExpenseItem(name: "Large Popcorn", price: 8.50, expense: expense),
                    ExpenseItem(name: "Drinks", price: 12.00, expense: expense)
                ]
                for item in items {
                    modelContext.insert(item)
                    expense.items.append(item)
                }
                
            default:
                break
            }
        }
        
        try? modelContext.save()
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
        .modelContainer(for: [Expense.self, ExpenseItem.self])
}
