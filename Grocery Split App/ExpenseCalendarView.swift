import SwiftUI
import SwiftData

struct ExpenseCalendarView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedMonth = Date()
    @State private var showingDayExpenses = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // Month Header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedMonth))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Calendar Grid
            CalendarGridView(
                month: selectedMonth,
                datesWithExpenses: viewModel.datesWithExpenses,
                onDateTap: { date in
                    viewModel.loadExpensesForDate(date)
                    showingDayExpenses = true
                }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .sheet(isPresented: $showingDayExpenses) {
            DayExpensesSheet(
                date: viewModel.selectedDate ?? Date(),
                expenses: viewModel.expensesForSelectedDate
            )
        }
    }
    
    private func previousMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        }
    }
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    let month: Date
    let datesWithExpenses: Set<DateComponents>
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday Headers
            HStack {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Days
            LazyVGrid(columns: columns, spacing: 8) {
                let days = getDaysInMonth()
                ForEach(days.indices, id: \.self) { index in
                    let date = days[index]
                    if let date = date {
                        DayView(
                            date: date,
                            hasExpense: hasExpenseOnDate(date),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                            onTap: onDateTap
                        )
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining days to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func hasExpenseOnDate(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return datesWithExpenses.contains(components)
    }
}

// MARK: - Day View
struct DayView: View {
    let date: Date
    let hasExpense: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: (Date) -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: { onTap(date) }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.blue.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                    )
                
                VStack(spacing: 2) {
                    Text(dayNumber)
                        .font(.system(size: 14, weight: isToday ? .semibold : .regular))
                        .foregroundColor(isCurrentMonth ? .primary : .secondary.opacity(0.5))
                    
                    if hasExpense {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 40)
        }
        .disabled(!isCurrentMonth)
    }
}

// MARK: - Day Expenses Sheet
struct DayExpensesSheet: View {
    let date: Date
    let expenses: [Expense]
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.totalCost }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Spending")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("$\(totalAmount, specifier: "%.2f")")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Expenses List
                    if expenses.isEmpty {
                        ContentUnavailableView(
                            "No Expenses",
                            systemImage: "tray",
                            description: Text("No expenses recorded on this date")
                        )
                        .frame(minHeight: 200)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(expenses) { expense in
                                CalendarExpenseRowView(expense: expense)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(dateFormatter.string(from: date))
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
}

// MARK: - Expense Row View (Calendar Sheet variant)
struct CalendarExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Label(expense.category.rawValue, systemImage: expense.category.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !expense.notes.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(expense.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Text("$\(expense.totalCost, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            if !expense.items.isEmpty {
                HStack {
                    Text("\(expense.items.count) items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(expense.paymentMethod.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

#Preview {
    ExpenseCalendarView(viewModel: DashboardViewModel())
}
