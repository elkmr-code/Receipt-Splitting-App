import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Bindable var expense: Expense
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingSplitView = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Expense Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: expense.category.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(expense.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingEditSheet = true }) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Date:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(expense.date, style: .date)
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Paid by:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(expense.payerName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Payment Method:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: expense.paymentMethod.icon)
                                    .font(.caption)
                                Text(expense.paymentMethod.rawValue)
                                    .font(.subheadline)
                            }
                        }
                        
                        if !expense.notes.isEmpty {
                            HStack {
                                Text("Notes:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(expense.notes)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Amount:")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(expense.totalCost, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Items Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items (\(expense.items.count))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if !expense.items.isEmpty {
                            Button(action: { showingSplitView = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.3.fill")
                                        .font(.subheadline)
                                    Text("Split Bill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    if expense.items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No items added")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("This expense doesn't have itemized details")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        LazyVStack(spacing: 1) {
                            ForEach(expense.items.sorted(by: { $0.name < $1.name })) { item in
                                EditableExpenseItemRow(
                                    item: item,
                                    onUpdate: { updatedItem in
                                        if let index = expense.items.firstIndex(where: { $0.id == updatedItem.id }) {
                                            expense.items[index] = updatedItem
                                        }
                                    },
                                    onDelete: {
                                        expense.items.removeAll { $0.id == item.id }
                                    }
                                )
                            }
                        }
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        Button(action: { showingEditSheet = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 30))
                                Text("Edit")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: shareExpense) {
                            VStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                Text("Share")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        if !expense.items.isEmpty {
                            Button(action: { showingSplitView = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "divide.circle.fill")
                                        .font(.system(size: 30))
                                    Text("Split")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            EditExpenseView(expense: expense)
        }
        .sheet(isPresented: $showingSplitView) {
            EnhancedSplitExpenseView(expense: expense)
        }
    }
    
    private func shareExpense() {
        let itemsList = expense.items.isEmpty ? "No itemized details" : expense.items.map { "• \($0.name): $\(String(format: "%.2f", $0.price))" }.joined(separator: "\n")
        
        let shareText = """
        💰 Expense: \(expense.name)
        📅 Date: \(expense.date.formatted(date: .abbreviated, time: .omitted))
        💳 Paid by: \(expense.payerName)
        🏷️ Category: \(expense.category.rawValue)
        💶 Payment: \(expense.paymentMethod.rawValue)
        💵 Total: $\(String(format: "%.2f", expense.totalCost))
        
        📝 Items:
        \(itemsList)
        
        Generated with Expense Split App
        """
        
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct EditExpenseView: View {
    @Bindable var expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Expense Name", text: $expense.name)
                    TextField("Payer Name", text: $expense.payerName)
                    DatePicker("Date", selection: $expense.date, displayedComponents: .date)
                }
                
                Section("Category & Payment") {
                    Picker("Category", selection: $expense.category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    Picker("Payment Method", selection: $expense.paymentMethod) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            HStack {
                                Image(systemName: method.icon)
                                Text(method.rawValue)
                            }
                            .tag(method)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $expense.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SplitExpenseView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @State private var people: [String] = [""]
    @State private var splitMethod: SplitMethod = .equally
    
    enum SplitMethod: String, CaseIterable {
        case equally = "Split Equally"
        case byAmount = "Split by Amount"
        case byPercentage = "Split by Percentage"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Expense Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Splitting: \(expense.name)")
                            .font(.headline)
                        Text("Total: \(expense.totalCost, format: .currency(code: "USD"))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Paid by: \(expense.payerName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // People List
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("People")
                                .font(.headline)
                            Spacer()
                            Button(action: addPerson) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        ForEach(Array(people.enumerated()), id: \.offset) { index, person in
                            HStack {
                                TextField("Person \(index + 1)", text: $people[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if people.count > 1 {
                                    Button(action: { removePerson(at: index) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Split Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Split Method")
                            .font(.headline)
                        
                        Picker("Split Method", selection: $splitMethod) {
                            ForEach(SplitMethod.allCases, id: \.self) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Split Results
                    if !people.filter({ !$0.isEmpty }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Split Results")
                                .font(.headline)
                            
                            let validPeople = people.filter { !$0.isEmpty }
                            let amountPerPerson = expense.totalCost / Double(validPeople.count)
                            
                            ForEach(validPeople, id: \.self) { person in
                                HStack {
                                    Text(person)
                                        .font(.body)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", amountPerPerson))")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Share Button
                    if !people.filter({ !$0.isEmpty }).isEmpty {
                        Button(action: shareSplit) {
                            Text("Share Split Details")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Split Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPerson() {
        people.append("")
    }
    
    private func removePerson(at: Int) {
        people.remove(at: at)
    }
    
    private func shareSplit() {
        let validPeople = people.filter { !$0.isEmpty }
        let amountPerPerson = expense.totalCost / Double(validPeople.count)
        
        let splitDetails = validPeople.map { "\($0): $\(String(format: "%.2f", amountPerPerson))" }.joined(separator: "\n")
        
        let shareText = """
        💰 Expense Split: \(expense.name)
        💵 Total: $\(String(format: "%.2f", expense.totalCost))
        💳 Paid by: \(expense.payerName)
        
        💸 Split (\(validPeople.count) people):
        \(splitDetails)
        
        Generated with Expense Split App
        """
        
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct EditableExpenseItemRow: View {
    @State private var item: ExpenseItem
    let onUpdate: (ExpenseItem) -> Void
    let onDelete: () -> Void
    @State private var isEditing = false
    @State private var priceText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(item: ExpenseItem, onUpdate: @escaping (ExpenseItem) -> Void, onDelete: @escaping () -> Void) {
        self._item = State(initialValue: item)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._priceText = State(initialValue: String(format: "%.2f", item.price))
    }
    
    var body: some View {
        HStack {
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Item name", text: $item.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $priceText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: priceText) { _, newValue in
                                // Only allow valid decimal numbers
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    priceText = filtered
                                }
                            }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isEditing = false
                            priceText = String(format: "%.2f", item.price)
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .foregroundColor(.blue)
                        .disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || priceText.isEmpty)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("Individual item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(item.price, format: .currency(code: "USD"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveChanges() {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Item name cannot be empty"
            showingAlert = true
            return
        }
        
        guard let price = Double(priceText), price >= 0 else {
            alertMessage = "Please enter a valid price"
            showingAlert = true
            return
        }
        
        item.price = price
        onUpdate(item)
        isEditing = false
    }
}

#Preview {
    let expense = Expense(name: "Sample Dinner", payerName: "John", paymentMethod: .creditCard, category: .dining)
    return ExpenseDetailView(expense: expense)
        .modelContainer(for: [Expense.self, ExpenseItem.self])
}
