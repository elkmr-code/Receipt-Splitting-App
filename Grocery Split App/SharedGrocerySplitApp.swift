import SwiftUI
import SwiftData

@main
struct SharedGrocerySplitApp: App {
    var body: some Scene {
        WindowGroup {
            ReceiptListView()
        }
        .modelContainer(for: [Receipt.self, Item.self, Roommate.self, SplitPreference.self])
    }
}
