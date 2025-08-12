import SwiftUI
import SwiftData

@main
struct ExpenseSplitApp: App {
    var body: some Scene {
        WindowGroup {
            ExpenseListView()
        }
        .modelContainer(for: [Expense.self, ExpenseItem.self, Receipt.self, SplitRequest.self, ScheduledSplitRequest.self])
    }
}
