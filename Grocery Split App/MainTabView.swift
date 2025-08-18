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
    
    // New state for robust selection
    @State private var isSelectionMode = false
    @State private var pendingAction: BulkAction?
    
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
                    // Collapsible scheduled queue
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
                    
                    // Two-section layout: Settled and Unsettled orders
                    let settled = settledOrders()
                    let unsettled = unsettledOrders()
                    
                    // Unsettled section (top)
                    Section("Unsettled") {
                        if unsettled.isEmpty {
                            Text("No unsettled orders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(unsettled, id: \.key) { group, requests in
                                ExpandableOrderRow(
                                    orderName: group,
                                    requests: requests,
                                    isSelectionMode: isSelectionMode,
                                    selectedForSchedule: $selectedForSchedule,
                                    onToggleSelection: toggleSelection,
                                    onUpdateStatus: updateStatus,
                                    onDeleteGroup: { groupPendingDelete = group }
                                )
                            }
                        }
                    }
                    
                    // Settled section (bottom)
                    Section("Settled") {
                        if settled.isEmpty {
                            Text("No settled orders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(settled, id: \.key) { group, requests in
                                ExpandableOrderRow(
                                    orderName: group,
                                    requests: requests,
                                    isSelectionMode: isSelectionMode,
                                    selectedForSchedule: $selectedForSchedule,
                                    onToggleSelection: toggleSelection,
                                    onUpdateStatus: updateStatus,
                                    onDeleteGroup: { groupPendingDelete = group }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Split Person History")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        let allSelected = selectedForSchedule.count == splitRequests.count && !splitRequests.isEmpty
                        Button(allSelected ? "Deselect All" : "Select All") {
                            if allSelected { selectedForSchedule.removeAll() } else { selectedForSchedule = Set(splitRequests.map { $0.id }) }
                        }
                        Menu {
                            Button("Paid") { self.pendingAction = .paid }
                            Button("Pending") { self.pendingAction = .pending }
                            Button("Delete", role: .destructive) { self.pendingAction = .delete }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(selectedForSchedule.isEmpty)
                        Button("Done") { isSelectionMode = false; selectedForSchedule.removeAll() }
                    } else {
                        Button("Select All") {
                            isSelectionMode = true
                            selectedForSchedule = Set(splitRequests.map { $0.id })
                        }
                        Button { showingScheduleSheet = true } label: { Label("Schedule", systemImage: "calendar.badge.clock") }
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
            .confirmationDialog("Are you sure?", isPresented: .constant(pendingAction != nil), titleVisibility: .visible) {
                Button(pendingAction?.title ?? "Confirm", role: (pendingAction == .delete) ? .destructive : .none) {
                    performBulkAction()
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text("This will affect \(selectedForSchedule.count) items.")
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
    
    private func groupedRequests() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            request.expense?.name ?? "Unknown Expense"
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - Settled/Unsettled categorization
    private func settledOrders() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            request.expense?.name ?? "Unknown Expense"
        }
        
        // Filter for orders where ALL participants are paid
        let settled = grouped.filter { (expenseName, requests) in
            return !requests.isEmpty && requests.allSatisfy { $0.status == .paid }
        }
        
        return settled.sorted { $0.key < $1.key }
    }
    
    private func unsettledOrders() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            request.expense?.name ?? "Unknown Expense"
        }
        
        // Filter for orders where ANY participant is unpaid
        let unsettled = grouped.filter { (expenseName, requests) in
            return !requests.isEmpty && requests.contains { $0.status != .paid }
        }
        
        return unsettled.sorted { $0.key < $1.key }
    }
    
    private func updateStatus(_ request: SplitRequest, to status: RequestStatus) {
        request.status = status
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
    }

    // MARK: - Selection & Bulk Actions
    
    private func toggleSelection(for request: SplitRequest) {
        if selectedForSchedule.contains(request.id) {
            selectedForSchedule.remove(request.id)
        } else {
            selectedForSchedule.insert(request.id)
        }
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
        // Delete all requests under this expense group
        for r in splitRequests where (r.expense?.name ?? "Unknown Expense") == group {
            modelContext.delete(r)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
    }

    @State private var groupPendingDelete: String? = nil
}

struct GroupRequestRow: View {
    let request: SplitRequest
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.participantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Show only status (Paid/Pending) - no message text
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
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row (always visible)
            Button(action: { withAnimation(.easeInOut) { isExpanded.toggle() } }) {
                HStack {
                    Text(orderName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Order summary
                    let totalAmount = requests.reduce(0) { $0 + $1.amount }
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(role: .destructive, action: onDeleteGroup) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(requests) { request in
                        HStack(spacing: 12) {
                            if isSelectionMode {
                                Button(action: { onToggleSelection(request) }) {
                                    Image(systemName: selectedForSchedule.contains(request.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(selectedForSchedule.contains(request.id) ? .blue : .gray)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 30, height: 30)
                            }
                            GroupRequestRow(request: request)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelectionMode { onToggleSelection(request) }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Paid") { onUpdateStatus(request, .paid) }.tint(.green)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("Pending") { onUpdateStatus(request, .pending) }.tint(.orange)
                        }
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
                // Profile Header
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
                
                // Quick Stats
                Section("Statistics") {
                    StatRow(label: "Total Expenses", value: "142")
                    StatRow(label: "This Month", value: "$1,234.56")
                    StatRow(label: "Active Splits", value: "5")
                }
                
                // Settings
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
