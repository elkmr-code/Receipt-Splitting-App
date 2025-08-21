import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 1 // Start on Timeline
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Split Person History Tab
            GroupsView()
                .tabItem {
                    Label("Split History", systemImage: "person.3.fill")
                }
                .tag(0)
            
            // Timeline Tab (Main)
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Groups View
struct GroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SplitRequest.createdDate, order: .reverse) var splitRequests: [SplitRequest]
    @Query(sort: \ScheduledSplitRequest.createdDate, order: .reverse) var scheduled: [ScheduledSplitRequest]
    @State private var isScheduleExpanded = false
    @State private var showingScheduleSheet = false
    @State private var selectedForSchedule: Set<UUID> = []
    @State private var expenseToEdit: Expense? = nil
    
    // New state for robust selection
    @State private var isSelectionMode = false
    @State private var pendingAction: BulkAction?
    @State private var groupPendingDelete: String? = nil
    @State private var expandedGroups: Set<String> = []
    @State private var expandedSettledGroups: Set<String> = []

    enum BulkAction: Identifiable {
        case paid, pending, delete
        var id: Self { self }
        
        var title: String {
            switch self {
            case .paid: "Mark as Paid"
            case .pending: "Mark as Pending"
            case .delete: "Delete"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if splitRequests.isEmpty {
                    ContentUnavailableView(
                        "No Requests",
                        systemImage: "person.3",
                        description: Text("Scan a receipt and create split reminders")
                    )
                } else {
                    ScheduledSection(
                        scheduled: scheduled,
                        isScheduleExpanded: $isScheduleExpanded,
                        modelContext: modelContext
                    )
                    
                    UnsettledSection(
                        requests: unsettledOrders(),
                        isSelectionMode: isSelectionMode,
                        selectedForSchedule: $selectedForSchedule,
                        groupPendingDelete: $groupPendingDelete,
                        expenseToEdit: $expenseToEdit,
                        onToggleSelection: toggleSelection,
                        onUpdateStatus: updateStatus,
                        onDeleteRequest: deleteRequest,
                        expandedGroups: $expandedGroups
                    )
                    
                    SettledSection(
                        requests: settledOrders(),
                        isSelectionMode: isSelectionMode,
                        selectedForSchedule: $selectedForSchedule,
                        groupPendingDelete: $groupPendingDelete,
                        expenseToEdit: $expenseToEdit,
                        onToggleSelection: toggleSelection,
                        onUpdateStatus: updateStatus,
                        onDeleteRequest: deleteRequest,
                        expandedSettledGroups: $expandedSettledGroups
                    )
                }
            }
            .navigationTitle("Split Person History")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .onAppear {
                // Collapse any expanded groups when returning to this tab
                expandedGroups.removeAll()
                expandedSettledGroups.removeAll()
            }
            .onDisappear {
                // Reset expanded states when navigating away from this tab
                expandedGroups.removeAll()
                expandedSettledGroups.removeAll()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingScheduleSheet = true }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                ScheduleModalView(
                    selectedRequests: selectedForSchedule,
                    allRequests: splitRequests,
                    onSchedule: { request in
                        modelContext.insert(request)
                        try? modelContext.save()
                        showingScheduleSheet = false
                    }
                )
            }
            .sheet(item: $expenseToEdit) { exp in
                EnhancedSplitExpenseView(expense: exp)
            }
            .confirmationDialog("Are you sure?", isPresented: .constant(pendingAction != nil), titleVisibility: .visible) {
                Button(pendingAction?.title ?? "Confirm", role: (pendingAction == .delete) ? .destructive : .none) {
                    performBulkAction()
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text("This will affect \(countPendingItemsInSelection()) items.")
            }
            .alert("Delete group?", isPresented: Binding(get: { groupPendingDelete != nil }, set: { if !$0 { groupPendingDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let g = groupPendingDelete { deleteGroup(named: g) }
                    groupPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { groupPendingDelete = nil }
            } message: {
                if let g = groupPendingDelete { Text("This will delete all requests under \"\(g)\".") }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func settledOrders() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            let expenseName = request.expense?.name ?? "Unknown Expense"
            let expenseId = request.expense?.id.uuidString ?? "unknown"
            let timestamp = request.expense?.date ?? Date()
            return "\(expenseName)|\(expenseId)|\(timestamp.timeIntervalSince1970)"
        }
        let settled = grouped.filter { (expenseKey, requests) in
            return !requests.isEmpty && requests.allSatisfy { $0.status == .paid }
        }
        return settled.sorted { $0.key < $1.key }
    }
    
    private func unsettledOrders() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            let expenseName = request.expense?.name ?? "Unknown Expense"
            let expenseId = request.expense?.id.uuidString ?? "unknown"
            let timestamp = request.expense?.date ?? Date()
            return "\(expenseName)|\(expenseId)|\(timestamp.timeIntervalSince1970)"
        }
        let unsettled = grouped.filter { (expenseKey, requests) in
            return !requests.isEmpty && requests.contains { $0.status != .paid }
        }
        return unsettled.sorted { $0.key < $1.key }
    }
    
    private func countPendingItemsInSelection() -> Int {
        // Only count selected items that are pending and from unsettled orders
        let unsettledRequestIds = Set(unsettledOrders().flatMap { $0.value.map { $0.id } })
        return selectedForSchedule.filter { selectedId in
            guard unsettledRequestIds.contains(selectedId),
                  let request = splitRequests.first(where: { $0.id == selectedId }) else { 
                return false 
            }
            return request.status != .paid
        }.count
    }
    
    private func updateStatus(_ request: SplitRequest, to status: RequestStatus) {
        request.status = status
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
    }


    
    private func performBulkAction() {
        guard let action = pendingAction else { return }
        
        for id in selectedForSchedule {
            guard let request = splitRequests.first(where: { $0.id == id }) else { continue }
            switch action {
            case .paid:
                request.status = .paid
            case .pending:
                request.status = .pending
            case .delete:
                modelContext.delete(request)
            }
        }
        
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
        
        // Reset state
        isSelectionMode = false
        selectedForSchedule.removeAll()
        pendingAction = nil
    }

    private func deleteGroup(named group: String) {
        let targets = splitRequests.filter { ($0.expense?.name ?? "Unknown Expense") == group }
        for r in targets { modelContext.delete(r) }
        if let expense = targets.first?.expense {
            for p in expense.splitParticipants { modelContext.delete(p) }
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
    }

    private func toggleSelection(_ request: SplitRequest) {
        if selectedForSchedule.contains(request.id) { selectedForSchedule.remove(request.id) } else { selectedForSchedule.insert(request.id) }
    }

    private func deleteRequest(_ request: SplitRequest) {
        if let expense = request.expense {
            for p in expense.splitParticipants where p.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == request.participantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                modelContext.delete(p)
            }
        }
        modelContext.delete(request)
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
}

// MARK: - Scheduled Section
struct ScheduledSection: View {
    let scheduled: [ScheduledSplitRequest]
    @Binding var isScheduleExpanded: Bool
    let modelContext: ModelContext
    
    var body: some View {
        Section {
            Button {
                withAnimation(.easeInOut) { isScheduleExpanded.toggle() }
            } label: {
                HStack {
                    Text("Scheduled Messages (\(scheduled.count))")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isScheduleExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if isScheduleExpanded {
                ForEach(scheduled) { req in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(req.participants.joined(separator: ", "))
                                .font(.subheadline)
                            Text(req.scheduledDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(req.scheduledDate, style: .time)
                            .font(.caption)
                        Button(role: .destructive) {
                            modelContext.delete(req); try? modelContext.save()
                        } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
    }
}

// MARK: - Unsettled Section
struct UnsettledSection: View {
    let requests: [(key: String, value: [SplitRequest])]
    let isSelectionMode: Bool
    @Binding var selectedForSchedule: Set<UUID>
    @Binding var groupPendingDelete: String?
    @Binding var expenseToEdit: Expense?
    let onToggleSelection: (SplitRequest) -> Void
    let onUpdateStatus: (SplitRequest, RequestStatus) -> Void
    let onDeleteRequest: (SplitRequest) -> Void
    @Binding var expandedGroups: Set<String>
    
    var body: some View {
        Section("Unsettled") {
            if requests.isEmpty {
                Text("No unsettled orders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(requests, id: \.key) { group, groupRequests in
                    let isExpanded = expandedGroups.contains(group)
                    // Header Row
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            let components = group.split(separator: "|")
                            Text(String(components.first ?? Substring(group)))
                                .font(.headline)
                            if components.count >= 3, let ts = Double(String(components[2])) {
                                Text(Date(timeIntervalSince1970: ts), style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("$\(groupRequests.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                            .fontWeight(.semibold)
                        Button(action: {
                            if isExpanded { expandedGroups.remove(group) }
                            else { expandedGroups.insert(group) }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if let e = groupRequests.first?.expense { expenseToEdit = e } }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) { groupPendingDelete = group }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if groupRequests.allSatisfy({ $0.status == .paid }) {
                            Button("Mark Pending") { groupRequests.forEach { onUpdateStatus($0, .pending) } }
                                .tint(.orange)
                        } else {
                            Button("Mark Paid") { groupRequests.forEach { onUpdateStatus($0, .paid) } }
                                .tint(.green)
                        }
                    }
                    // Participant Rows
                    if isExpanded {
                        ForEach(groupRequests) { req in
                            HStack(spacing: 12) {
                                if isSelectionMode {
                                    Button(action: { onToggleSelection(req) }) {
                                        Image(systemName: selectedForSchedule.contains(req.id) ? "checkmark.circle.fill" : "circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                                GroupRequestRow(request: req)
                                    .onTapGesture { expenseToEdit = req.expense }
                            }
                            .contentShape(Rectangle())
                            .padding(.leading, 16)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) { onDeleteRequest(req) }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if req.status == .paid {
                                    Button("Pending") { onUpdateStatus(req, .pending) }.tint(.orange)
                                } else {
                                    Button("Paid") { onUpdateStatus(req, .paid) }.tint(.green)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settled Section
struct SettledSection: View {
    let requests: [(key: String, value: [SplitRequest])]
    let isSelectionMode: Bool
    @Binding var selectedForSchedule: Set<UUID>
    @Binding var groupPendingDelete: String?
    @Binding var expenseToEdit: Expense?
    let onToggleSelection: (SplitRequest) -> Void
    let onUpdateStatus: (SplitRequest, RequestStatus) -> Void
    let onDeleteRequest: (SplitRequest) -> Void
    @Binding var expandedSettledGroups: Set<String>
    
    var body: some View {
        Section("Settled") {
            if requests.isEmpty {
                Text("No settled orders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(requests, id: \.key) { group, groupRequests in
                    let isExpanded = expandedSettledGroups.contains(group)
                    // Header row
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            let comps = group.split(separator: "|")
                            Text(String(comps.first ?? Substring(group)))
                                .font(.headline)
                            if comps.count >= 3, let ts = Double(String(comps[2])) {
                                Text(Date(timeIntervalSince1970: ts), style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("$\(groupRequests.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                            .fontWeight(.semibold)
                        Button(action: {
                            if isExpanded { expandedSettledGroups.remove(group) }
                            else { expandedSettledGroups.insert(group) }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if let e = groupRequests.first?.expense { expenseToEdit = e } }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) { groupPendingDelete = group }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Restore") {
                            groupRequests.forEach { onUpdateStatus($0, .pending) }
                        }
                        .tint(.orange)
                    }
                    // Participant rows
                    if isExpanded {
                        ForEach(groupRequests) { req in
                            HStack(spacing: 12) {
                                if isSelectionMode {
                                    Button(action: { onToggleSelection(req) }) {
                                        Image(systemName: selectedForSchedule.contains(req.id) ? "checkmark.circle.fill" : "circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                                GroupRequestRow(request: req)
                                    .onTapGesture { expenseToEdit = req.expense }
                            }
                            .contentShape(Rectangle())
                            .padding(.leading, 16)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) { onDeleteRequest(req) }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if req.status == .paid {
                                    Button("Pending") { onUpdateStatus(req, .pending) }.tint(.orange)
                                } else {
                                    Button("Paid") { onUpdateStatus(req, .paid) }.tint(.green)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct GroupRequestRow: View {
    let request: SplitRequest
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.participantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: request.status.icon)
                        .font(.caption2)
                    Text(request.status == .paid ? "Paid" : "Pending")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(request.status == .paid ? .green : .orange)
            }
            
            Spacer()
            
            Text("$\(request.amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Expandable Order Row
struct ExpandableOrderRow: View {
    let orderName: String
    let requests: [SplitRequest]
    let isSelectionMode: Bool
    @Binding var selectedForSchedule: Set<UUID>
    let onToggleSelection: (SplitRequest) -> Void
    let onUpdateStatus: (SplitRequest, RequestStatus) -> Void
    let onDeleteGroup: () -> Void
    let onDeleteRequest: (SplitRequest) -> Void
    let onOpenExpense: (Expense?) -> Void

    @State private var expanded: Bool = false

    // Extract display name and timestamp from composite key
    private var displayName: String {
        let components = orderName.split(separator: "|")
        return String(components.first ?? Substring(orderName))
    }
    
    private var expenseDate: Date? {
        let components = orderName.split(separator: "|")
        guard components.count >= 3,
              let timestampString = Double(String(components[2])) else {
            return requests.first?.expense?.date
        }
        return Date(timeIntervalSince1970: timestampString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row - NO swipe actions
            expenseHeaderRow
                
            // Individual participant rows with swipe actions
            if expanded {
                participantRowsSection
            }
        }
        .onAppear {
            // Reset expanded state when view appears to ensure collapsed state when navigating back
            expanded = false
        }
    }
    
    private var expenseHeaderRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                if let date = expenseDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("$\(requests.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                .fontWeight(.semibold)
            Button(action: { expanded.toggle() }) { 
                Image(systemName: expanded ? "chevron.up" : "chevron.down") 
            }
            .buttonStyle(.plain)
            Button(role: .destructive, action: onDeleteGroup) { 
                Image(systemName: "trash") 
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) { onDeleteGroup() }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if requests.allSatisfy({ $0.status == .paid }) {
                Button("Mark All Pending") { requests.forEach { onUpdateStatus($0, .pending) } }
                    .tint(.orange)
            } else {
                Button("Mark All Paid") { requests.forEach { onUpdateStatus($0, .paid) } }
                    .tint(.green)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onOpenExpense(requests.first?.expense) }
    }
    
    private var participantRowsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(requests) { req in
                HStack(spacing: 12) {
                    if isSelectionMode {
                        Button(action: { onToggleSelection(req) }) {
                            Image(systemName: selectedForSchedule.contains(req.id) ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                    }
                    GroupRequestRow(request: req)
                        .onTapGesture { onOpenExpense(req.expense) }
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) { onDeleteRequest(req) }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if req.status == .paid {
                        Button("Pending") { onUpdateStatus(req, .pending) }.tint(.orange)
                    } else {
                        Button("Paid") { onUpdateStatus(req, .paid) }.tint(.green)
                    }
                }
            }
        }
        .padding(.leading, 16) // Indent participant rows to show they're part of the expense
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @AppStorage("userName") private var userName = "User"
    @AppStorage("userEmail") private var userEmail = ""
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Statistics") {
                    StatRow(label: "Total Expenses", value: "142")
                    StatRow(label: "This Month", value: "$1,234.56")
                    StatRow(label: "Active Splits", value: "5")
                }
                
                Section {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    
                    Button(action: { exportData() }) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $exportSheetModel) { model in
                ExportDataSheet(model: model)
            }
        }
    }

    @State private var exportSheetModel: ExportDataSheetModel?
    private func exportData() {
        exportSheetModel = ExportDataSheetModel()
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @AppStorage("enableNotifications") private var enableNotifications = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $userName)
                    TextField("Email", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Preferences") {
                    Picker("Currency", selection: $defaultCurrency) {
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
                        Text("GBP (£)").tag("GBP")
                        Text("JPY (¥)").tag("JPY")
                    }
                    
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {}
                    Button("Terms of Service") {}
                }
            }
            .navigationTitle("Settings")
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

#Preview {
    MainTabView()
        .modelContainer(for: [Expense.self, ExpenseItem.self, SplitRequest.self, SplitParticipantData.self])
}