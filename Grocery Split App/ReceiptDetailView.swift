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
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .accessibilityLabel("Expense name: \(expense.name)")
                            Text(expense.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Category: \(expense.category.rawValue)")
                        }
                        
                        Spacer()
                        
                        Button(action: { showingEditSheet = true }) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Edit expense")
                        .accessibilityHint("Edit expense details like name, category, and payment information")
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Total amount: \(expense.totalCost, format: .currency(code: "USD"))")
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
                            .accessibilityLabel("Split bill")
                            .accessibilityHint("Create split requests for this expense")
                        }
                    }
                    
                    if expense.items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("No items added")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text("This expense doesn't have itemized details yet. You can add items by editing the expense or importing from a receipt scan.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No items added. This expense doesn't have itemized details yet.")
                        .accessibilityHint("You can add items by editing the expense or importing from a receipt scan.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(expense.items.sorted(by: { $0.name < $1.name })) { item in
                                EditableExpenseItemRow(
                                    item: item,
                                    onUpdate: { updatedItem in
                                        if let index = expense.items.firstIndex(where: { $0.id == updatedItem.id }) {
                                            expense.items[index] = updatedItem
                                            // Trigger model context save for real-time updates
                                            try? modelContext.save()
                                        }
                                    },
                                    onDelete: {
                                        expense.items.removeAll { $0.id == item.id }
                                        // Trigger model context save for real-time updates
                                        try? modelContext.save()
                                    }
                                )
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.05), radius: 2)
                                .padding(.vertical, 2)
                                
                                if item.id != expense.items.sorted(by: { $0.name < $1.name }).last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: shareExpense) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share expense")
                .accessibilityHint("Share expense details with others")
            }
        }
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
    @State private var showingDeleteConfirmation = false
    
    init(item: ExpenseItem, onUpdate: @escaping (ExpenseItem) -> Void, onDelete: @escaping () -> Void) {
        self._item = State(initialValue: item)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._priceText = State(initialValue: String(format: "%.2f", item.price))
    }
    
    private var isValidForSaving: Bool {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let priceValue = Double(sanitizedPriceText)
        return !trimmedName.isEmpty && priceValue != nil && priceValue! >= 0
    }
    
    private var sanitizedPriceText: String {
        // Remove any invalid characters and ensure proper decimal format
        let filtered = priceText.filter { "0123456789.".contains($0) }
        let components = filtered.components(separatedBy: ".")
        
        if components.count <= 1 {
            return filtered
        } else if components.count == 2 {
            let wholePart = components[0]
            let decimalPart = String(components[1].prefix(2))
            return wholePart + "." + decimalPart
        } else {
            // Multiple decimal points - keep only the first one
            return components[0] + "." + components.dropFirst().joined()
        }
    }
    
    var body: some View {
        HStack {
            if isEditing {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Item name", text: $item.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .accessibilityLabel("Item name")
                        
                        Text("$")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        TextField("0.00", text: $priceText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .accessibilityLabel("Price")
                            .onChange(of: priceText) { _, newValue in
                                priceText = sanitizePriceInput(newValue)
                            }
                    }
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isValidForSaving ? Color.blue : Color.gray)
                        .cornerRadius(6)
                        .disabled(!isValidForSaving)
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .accessibilityLabel("Item: \(item.name)")
                
                Spacer()
                
                Text(item.price, format: .currency(code: "USD"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Price: \(item.price, format: .currency(code: "USD"))")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double tap to edit as fallback
            startEditing()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showingDeleteConfirmation = true
                // Haptic feedback for delete action
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            .accessibilityLabel("Delete item")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                startEditing()
                // Haptic feedback for edit action
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel("Edit item")
        }
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete \"\(item.name)\"? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sanitizePriceInput(_ input: String) -> String {
        // Remove any invalid characters first
        let validChars = input.filter { "0123456789.".contains($0) }
        
        // Handle multiple decimal points
        let components = validChars.components(separatedBy: ".")
        if components.count <= 1 {
            return validChars
        } else if components.count == 2 {
            let wholePart = components[0]
            let decimalPart = String(components[1].prefix(2)) // Limit to 2 decimal places
            return wholePart + "." + decimalPart
        } else {
            // Multiple decimal points - keep only the first one
            let wholePart = components[0]
            let decimalPart = String(components.dropFirst().joined().prefix(2))
            return wholePart + "." + decimalPart
        }
    }
    
    private func startEditing() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isEditing = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = false
            priceText = String(format: "%.2f", item.price)
            item.name = item.name // Reset any unsaved name changes
        }
    }
    
    private func deleteItem() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        onDelete()
    }
    
    private func saveChanges() {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "Item name cannot be empty"
            showingAlert = true
            return
        }
        
        guard let price = Double(sanitizedPriceText), price >= 0 else {
            alertMessage = "Please enter a valid price (0.00 or higher)"
            showingAlert = true
            return
        }
        
        // Ensure name is trimmed
        item.name = trimmedName
        item.price = price
        
        // Haptic feedback for successful save
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        onUpdate(item)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isEditing = false
        }
    }
}

#Preview {
    let expense = Expense(name: "Sample Dinner", payerName: "John", paymentMethod: .creditCard, category: .dining)
    return ExpenseDetailView(expense: expense)
        .modelContainer(for: [Expense.self, ExpenseItem.self])
}
