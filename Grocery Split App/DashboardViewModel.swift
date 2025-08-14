import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Time Frame for Dashboard
enum TimeFrame: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
            
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }
}

// MARK: - Category Spending Model
struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
    
    var percentage: Double = 0.0
}

// MARK: - Dashboard View Model
@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTimeFrame: TimeFrame = .week
    @Published var totalSpending: Double = 0.0
    @Published var categoryBreakdown: [CategorySpending] = []
    @Published var budgetAmount: Double = 1000.0 // Default budget
    @Published var spendingProgress: Double = 0.0
    @Published var selectedDate: Date? = nil
    @Published var expensesForSelectedDate: [Expense] = []
    @Published var recentExpenses: [Expense] = []
    @Published var datesWithExpenses: Set<DateComponents> = []
    
    // MARK: - Private Properties
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadBudgetFromUserDefaults()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchExpenses()
    }
    
    // MARK: - Data Fetching
    func fetchExpenses() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let allExpenses = try modelContext.fetch(descriptor)
            processExpenses(allExpenses)
        } catch {
            print("Failed to fetch expenses: \(error)")
        }
    }
    
    private func processExpenses(_ expenses: [Expense]) {
        // Filter by selected time frame
        let dateRange = selectedTimeFrame.dateRange
        let filteredExpenses = expenses.filter { expense in
            expense.date >= dateRange.start && expense.date < dateRange.end
        }
        
        // Calculate total spending
        totalSpending = filteredExpenses.reduce(0) { $0 + $1.totalCost }
        
        // Calculate category breakdown
        calculateCategoryBreakdown(from: filteredExpenses)
        
        // Update spending progress
        updateSpendingProgress()
        
        // Store recent expenses (last 10)
        recentExpenses = Array(expenses.prefix(10))
        
        // Mark dates with expenses for calendar
        markDatesWithExpenses(from: expenses)
    }
    
    // MARK: - Category Breakdown
    private func calculateCategoryBreakdown(from expenses: [Expense]) {
        var categoryTotals: [ExpenseCategory: Double] = [:]
        
        for expense in expenses {
            categoryTotals[expense.category, default: 0] += expense.totalCost
        }
        
        let total = categoryTotals.values.reduce(0, +)
        
        categoryBreakdown = categoryTotals.map { category, amount in
            var spending = CategorySpending(
                category: category.rawValue,
                amount: amount,
                color: colorForCategory(category)
            )
            spending.percentage = total > 0 ? (amount / total) * 100 : 0
            return spending
        }.sorted { $0.amount > $1.amount }
    }
    
    private func colorForCategory(_ category: ExpenseCategory) -> Color {
        switch category {
        case .groceries: return .green
        case .dining: return .orange
        case .entertainment: return .purple
        case .transport: return .blue
        case .utilities: return .gray
        case .shopping: return .pink
        case .travel: return .cyan
        case .healthcare: return .red
        case .other: return .indigo
        }
    }
    
    // MARK: - Budget Management
    func updateBudget(_ newBudget: Double) {
        budgetAmount = newBudget
        saveBudgetToUserDefaults()
        updateSpendingProgress()
    }
    
    private func updateSpendingProgress() {
        spendingProgress = budgetAmount > 0 ? min(totalSpending / budgetAmount, 1.0) : 0.0
        
        // Check if over budget and trigger notification placeholder
        if spendingProgress >= 1.0 {
            triggerOverBudgetNotification()
        }
    }
    
    private func saveBudgetToUserDefaults() {
        UserDefaults.standard.set(budgetAmount, forKey: "monthlyBudget")
    }
    
    private func loadBudgetFromUserDefaults() {
        let saved = UserDefaults.standard.double(forKey: "monthlyBudget")
        if saved > 0 {
            budgetAmount = saved
        }
    }
    
    // MARK: - Calendar Support
    private func markDatesWithExpenses(from expenses: [Expense]) {
        let calendar = Calendar.current
        datesWithExpenses = Set(expenses.map { expense in
            calendar.dateComponents([.year, .month, .day], from: expense.date)
        })
    }
    
    func loadExpensesForDate(_ date: Date) {
        guard let modelContext = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.date >= startOfDay && expense.date < endOfDay
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            expensesForSelectedDate = try modelContext.fetch(descriptor)
            selectedDate = date
        } catch {
            print("Failed to fetch expenses for date: \(error)")
            expensesForSelectedDate = []
        }
    }
    
    // MARK: - Notification Placeholder
    func triggerOverBudgetNotification() {
        // Placeholder for notification logic
        // In production, this would trigger a local notification
        print("⚠️ Budget exceeded! Current spending: $\(String(format: "%.2f", totalSpending))")
    }
    
    // MARK: - Quick Actions
    func deleteExpense(_ expense: Expense) {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(expense)
        do {
            try modelContext.save()
            fetchExpenses() // Refresh data
        } catch {
            print("Failed to delete expense: \(error)")
        }
    }
}

// Lightweight wrapper to inject the same view model to child views that need to call methods
final class DashboardViewModelWrapper: ObservableObject {
    let viewModel: DashboardViewModel
    init(viewModel: DashboardViewModel) { self.viewModel = viewModel }
}
