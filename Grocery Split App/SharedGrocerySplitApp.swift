import SwiftUI
import SwiftData

@main
struct ExpenseSplitApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Expense.self, ExpenseItem.self, Receipt.self, SplitRequest.self, SplitParticipantData.self, ScheduledSplitRequest.self])
    }
}
