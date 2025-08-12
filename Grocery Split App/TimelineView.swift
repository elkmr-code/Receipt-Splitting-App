import SwiftUI
import SwiftData
import Charts

// MARK: - Main Timeline View
struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingScanOptions = false
    @State private var showingReceiptCamera = false
    @State private var showingCodeCamera = false
    @State private var currentScanResult: ScanResult?
    @State private var showingItemSelection = false
    @State private var selectedScanItems: Set<UUID> = []
    @State private var selectedExpense: Expense?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Spending Summary
                    SpendingSummaryView(viewModel: viewModel)
                    
                    // Category Chart
                    CategoryChartView(viewModel: viewModel)
                    
                    // Budget Progress
                    BudgetProgressView(viewModel: viewModel)
                    
                    // Calendar View
                    ExpenseCalendarView(viewModel: viewModel)
                    
                    // Recent Expenses
                    RecentExpensesView(
                        expenses: viewModel.recentExpenses,
                        onTap: { expense in
                            selectedExpense = expense
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 14) {
                    // Manual Add
                    Button(action: { showingAddExpense = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .accessibilityLabel("Quick add")
                    }
                    // Single Floating Camera Button
                    Button(action: { showingScanOptions = true }) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .accessibilityLabel("Start scanning")
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
        .sheet(isPresented: $showingAddExpense) {
            QuickAddExpenseView()
        }
        .confirmationDialog("Scan", isPresented: $showingScanOptions) {
            Button("Receipt (OCR)") { showingReceiptCamera = true }
            Button("Barcode / QR") { showingCodeCamera = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingReceiptCamera) {
            CameraScannerView(scanType: .receipt) { result in
                handleScanResult(result)
                showingReceiptCamera = false
            }
        }
        .sheet(isPresented: $showingCodeCamera) {
            CameraScannerView(scanType: .barcode) { result in
                handleScanResult(result)
                showingCodeCamera = false
            }
        }
        .sheet(item: $currentScanResult) { scanResult in
            ItemSelectionView(
                scanResult: scanResult,
                selectedItems: $selectedScanItems,
                onConfirm: { items in
                    let created = createExpense(from: scanResult, using: items)
                    selectedExpense = created
                    currentScanResult = nil
                    selectedScanItems.removeAll()
                },
                onBack: nil
            )
        }
    }
}

// MARK: - Scan Handling
private extension TimelineView {
    func handleScanResult(_ result: ScanResult) {
        // If OCR, we likely have an image and many items; always go to selection
        currentScanResult = result
        showingItemSelection = true
    }
    
    func createExpense(from scanResult: ScanResult, using items: [ParsedItem]) -> Expense {
        let title: String = {
            // Prefer merchant name from parsed OCR text, else fallback to source id/date
            let parsed = ReceiptParser.parseReceiptTextEnhanced(scanResult.originalText)
            if let store = parsed.metadata.storeName, !store.isEmpty { return store }
            let shortDate = Date().formatted(date: .abbreviated, time: .omitted)
            return "Receipt \(shortDate)"
        }()
        
        let payer = UserDefaults.standard.string(forKey: "userName").flatMap { $0.isEmpty ? nil : $0 } ?? "Payer"
        let expense = Expense(
            name: title,
            payerName: payer,
            paymentMethod: .cash,
            category: .other,
            notes: scanResult.type.displayName
        )
        
        modelContext.insert(expense)
        
        // Persist receipt link
        let receipt = Receipt(
            sourceType: scanResult.type == .ocr ? .ocr : .barcode,
            receiptID: scanResult.sourceId,
            rawText: scanResult.originalText,
            imageData: scanResult.image?.pngData(),
            expense: expense
        )
        modelContext.insert(receipt)
        expense.receipt = receipt
        
        // Add selected items
        for p in items {
            let item = ExpenseItem(name: p.name, price: p.totalPrice, expense: expense)
            modelContext.insert(item)
            expense.items.append(item)
        }
        
        try? modelContext.save()
        viewModel.fetchExpenses()
        return expense
    }
}

// MARK: - Spending Summary View
struct SpendingSummaryView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Time Frame Selector
            Picker("Time Frame", selection: $viewModel.selectedTimeFrame) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Text(frame.rawValue).tag(frame)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Total Spending Display
            VStack(spacing: 4) {
                Text("Total Spending")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$\(viewModel.totalSpending, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Category Chart View
struct CategoryChartView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
            
            if viewModel.categoryBreakdown.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                // Bar Chart
                Chart(viewModel.categoryBreakdown) { category in
                    BarMark(
                        x: .value("Amount", category.amount),
                        y: .value("Category", category.category)
                    )
                    .foregroundStyle(category.color)
                    .annotation(position: .trailing) {
                        Text("$\(category.amount, specifier: "%.0f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: CGFloat(viewModel.categoryBreakdown.count * 50))
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Budget Progress View
struct BudgetProgressView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingBudgetEditor = false
    
    var progressColor: Color {
        if viewModel.spendingProgress >= 1.0 {
            return .red
        } else if viewModel.spendingProgress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget Progress")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingBudgetEditor = true }) {
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * viewModel.spendingProgress, height: 24)
                }
            }
            .frame(height: 24)
            
            // Budget Details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.totalSpending, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.budgetAmount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            if viewModel.spendingProgress >= 0.8 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(progressColor)
                        .font(.caption)
                    
                    Text(viewModel.spendingProgress >= 1.0 ? "Budget exceeded!" : "Approaching budget limit")
                        .font(.caption)
                        .foregroundColor(progressColor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(currentBudget: viewModel.budgetAmount) { newBudget in
                viewModel.updateBudget(newBudget)
            }
        }
    }
}

// MARK: - Recent Expenses View
struct RecentExpensesView: View {
    let expenses: [Expense]
    let onTap: (Expense) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Expenses")
                .font(.headline)
            
            if expenses.isEmpty {
                Text("No expenses yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(expenses) { expense in
                    Button(action: { onTap(expense) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("$\(expense.totalCost, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if expense.id != expenses.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Budget Editor View
struct BudgetEditorView: View {
    let currentBudget: Double
    let onSave: (Double) -> Void
    
    @State private var budgetText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget") {
                    TextField("Budget Amount", text: $budgetText)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Text("Set a monthly budget to track your spending and receive alerts when you're approaching or exceeding your limit.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let budget = Double(budgetText), budget > 0 {
                            onSave(budget)
                            dismiss()
                        }
                    }
                    .disabled(Double(budgetText) == nil || Double(budgetText) == 0)
                }
            }
        }
        .onAppear {
            budgetText = String(format: "%.2f", currentBudget)
        }
    }
}

// MARK: - Quick Add Expense View
struct QuickAddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var expenseName = ""
    @State private var amount = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $expenseName)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(expenseName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        let expense = Expense(
            name: expenseName,
            payerName: "Me",
            paymentMethod: .cash,
            category: selectedCategory,
            notes: notes
        )
        
        // Create a single item for the total amount
        let item = ExpenseItem(name: expenseName, price: amountValue, expense: expense)
        modelContext.insert(expense)
        modelContext.insert(item)
        expense.items.append(item)
        
        try? modelContext.save()
        dismiss()
    }
}
