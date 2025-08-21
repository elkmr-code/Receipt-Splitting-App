import SwiftUI
import SwiftData
import Charts
import UIKit

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
    @State private var showingAddExpense = false
    @State private var scrollOffset: CGFloat = 0
    
    // Scroll-based title display mode
    private var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        scrollOffset > 50 ? .inline : .large
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Spending Summary
                        SpendingSummaryView(viewModel: viewModel)
                        
                        // Category Pie Chart
                        CategoryChartView(viewModel: viewModel)
                        
                        // Split Summary Chart (People owe me vs My spending)
                        SplitSummaryChartView(viewModel: viewModel)
                        
                        // Budget Progress
                        BudgetProgressView(viewModel: viewModel)
                            // Add 5-tap gesture to budget progress area as requested, since title behavior changes with scroll
                            .onTapGesture(count: 5) { debugLoadDemoReceipt() } // OCR demo activation - 5-tap feature location
                        
                        // People owe you section (moved above calendar as requested)
                        OwedSummaryView(viewModel: viewModel)
                        
                        // Calendar View
                        ExpenseCalendarView(viewModel: viewModel)
                        
                        // Recent Expenses
                        RecentExpensesView(
                            expenses: viewModel.recentExpenses,
                            onTap: { expense in selectedExpense = expense }
                        )
                        .environmentObject(DashboardViewModelWrapper(viewModel: viewModel))
                    }
                    .padding()
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scrollView")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = -value
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(titleDisplayMode)
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
        .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
            viewModel.fetchExpenses()
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
                    NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
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
    
    // Hidden developer action: demo parser on 5x title tap
    func debugLoadDemoReceipt() {
        guard let demo = UIImage(named: "DemoReceipt") else { return }
        Task {
            if let payload = try? await BarcodeService().scanBarcode(from: demo),
               let receiptData = BarcodeService().parseReceiptData(from: payload) {
                let items = ProductionReceiptParser().parseItems(from: receiptData)
                let result = ScanResult(type: .barcode, sourceId: receiptData.transactionId, items: items, originalText: payload, image: demo)
                await MainActor.run { self.currentScanResult = result }
            } else if let text = try? await OCRService().recognizeText(from: demo) {
                let parsed = ReceiptParser.parseReceiptTextEnhanced(text)
                let result = ScanResult(type: .ocr, sourceId: "DEMO", items: parsed.items, originalText: text, image: demo)
                await MainActor.run { self.currentScanResult = result }
            }
        }
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
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie").font(.system(size: 48)).foregroundColor(.gray)
                    Text("No expenses yet").font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                Chart(viewModel.categoryBreakdown) { category in
                    let total = max(1.0, viewModel.categoryBreakdown.reduce(0) { $0 + $1.amount })
                    SectorMark(angle: .value("Amount", category.amount), innerRadius: .ratio(0.55))
                        .foregroundStyle(category.color)
                        .annotation(position: .overlay) {
                            if category.amount / total > 0.08 {
                                Text("\(Int(round((category.amount/total)*100)))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                }
                .frame(height: 220)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 8) {
                    ForEach(viewModel.categoryBreakdown) { category in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(category.color).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.category).font(.caption).fontWeight(.medium)
                                Text("$\(category.amount, specifier: "%.2f")").font(.caption2).foregroundColor(.secondary)
                            }
                        }
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

// MARK: - Split Summary Chart View  
struct SplitSummaryChartView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Money Flow")
                .font(.headline)
            
            if viewModel.splitSummary.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie").font(.system(size: 48)).foregroundColor(.gray)
                    Text("No split expenses yet").font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                Chart(viewModel.splitSummary) { split in
                    let total = max(1.0, viewModel.splitSummary.reduce(0) { $0 + $1.amount })
                    SectorMark(angle: .value("Amount", split.amount), innerRadius: .ratio(0.55))
                        .foregroundStyle(split.color)
                        .annotation(position: .overlay) {
                            if split.amount / total > 0.08 {
                                Text("\(Int(round((split.amount/total)*100)))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                }
                .frame(height: 180)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 8) {
                    ForEach(viewModel.splitSummary) { split in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(split.color).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(split.label).font(.caption).fontWeight(.medium)
                                Text("$\(split.amount, specifier: "%.2f")").font(.caption2).foregroundColor(.secondary)
                            }
                        }
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

// MARK: - Owed Summary View
struct OwedSummaryView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.openURL) private var openURL
    
    var totalOwed: Double {
        viewModel.categoryBreakdown.reduce(0) { $0 + $1.owedAmount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("People owe you")
                    .font(.headline)
                Spacer()
                Text("$\(totalOwed, specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8)
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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModelWrapper
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    
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
                // VStack inside outer ScrollView to avoid nested scroll issues
                VStack(spacing: 0) {
                    // Toolbar row
                    HStack {
                        Button(action: toggleSelectAll) {
                            Text(isSelectionMode ? (selectAll ? "Deselect All" : "Select All") : "Select All")
                        }
                        Spacer()
                        if isSelectionMode {
                            if !selection.isEmpty {
                                Button(role: .destructive) { deleteSelected() } label: { Label("Delete", systemImage: "trash") }
                            }
                            Button("Done") { exitSelection() }
                        }
                    }
                    .padding(.bottom, 8)

                    ForEach(expenses) { expense in
                        HStack {
                            if isSelectionMode {
                                Button(action: { toggle(expense) }) {
                                    Image(systemName: selection.contains(expense.id) ? "checkmark.circle.fill" : "circle")
                                }.buttonStyle(.plain)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(expense.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    // Show split indicator
                                    if expense.hasBeenSplit {
                                        Image(systemName: expense.isFullySettled ? "checkmark.circle.fill" : "person.2.fill")
                                            .font(.caption2)
                                            .foregroundColor(expense.isFullySettled ? .green : .blue)
                                    }
                                }
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
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(expense) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                expenseToDelete = expense
                                showingDeleteConfirmation = true
                            }
                        }

                        if expense.id != expenses.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .onDisappear {
            // Reset selection state when navigating away from timeline
            if isSelectionMode {
                exitSelection()
            }
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    deleteExpense(expense)
                }
                expenseToDelete = nil
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Are you sure you want to delete \"\(expense.name)\"? This action cannot be undone.")
            }
        }
    }
    @State private var selection: Set<UUID> = []
    @State private var selectAll: Bool = false
    @State private var isSelectionMode: Bool = false
    private func toggle(_ expense: Expense) {
        if selection.contains(expense.id) { selection.remove(expense.id) } else { selection.insert(expense.id) }
        selectAll = selection.count == expenses.count
    }
    private func toggleSelectAll() {
        if !isSelectionMode {
            isSelectionMode = true
            selection = Set(expenses.map { $0.id })
            selectAll = true
            return
        }
        if selectAll { selection.removeAll() } else { selection = Set(expenses.map { $0.id }) }
        selectAll.toggle()
    }
    private func deleteSelected() {
        for id in selection {
            if let e = expenses.first(where: { $0.id == id }) { modelContext.delete(e) }
        }
        try? modelContext.save()
        exitSelection()
        dashboardVM.viewModel.fetchExpenses()
    }
    private func exitSelection() {
        isSelectionMode = false
        selectAll = false
        selection.removeAll()
    }
    
    private func deleteExpense(_ expense: Expense) {
        modelContext.delete(expense)
        try? modelContext.save()
        dashboardVM.viewModel.fetchExpenses()
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
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
