import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 1 // Start on Timeline
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Groups Tab
            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
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
                    
                    // Group by expense title
                    ForEach(groupedRequests(), id: \.key) { group, requests in
                        Section {
                            ForEach(requests) { request in
                                HStack(spacing: 12) {
                                    if isSelectionMode {
                                        Button(action: { toggleSelection(for: request) }) {
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
                                    if isSelectionMode { toggleSelection(for: request) }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Paid") { updateStatus(request, to: .paid) }.tint(.green)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button("Pending") { updateStatus(request, to: .pending) }.tint(.orange)
                                }
                            }
                        } header: {
                            HStack {
                                Text(group)
                                Spacer()
                                Button(role: .destructive) { deleteGroup(named: group) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        let allSelected = selectedForSchedule.count == splitRequests.count && !splitRequests.isEmpty
                        Button(allSelected ? "Deselect All" : "Select All") {
                            if allSelected {
                                selectedForSchedule.removeAll()
                            } else {
                                selectedForSchedule = Set(splitRequests.map { $0.id })
                            }
                        }
                        Button("Paid") { self.pendingAction = .paid }.disabled(selectedForSchedule.isEmpty)
                        Button("Pending") { self.pendingAction = .pending }.disabled(selectedForSchedule.isEmpty)
                        Button("Delete", role: .destructive) { self.pendingAction = .delete }.disabled(selectedForSchedule.isEmpty)
                        Button("Done") { isSelectionMode = false; selectedForSchedule.removeAll() }
                    } else {
                        Button("Select All") {
                            isSelectionMode = true
                            selectedForSchedule = Set(splitRequests.map { $0.id })
                        }
                        Button {
                            showingScheduleSheet = true
                        } label: {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                        }
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
        }
    }
    
    private func groupedRequests() -> [(key: String, value: [SplitRequest])] {
        let grouped = Dictionary(grouping: splitRequests) { request in
            request.expense?.name ?? "Unknown Expense"
        }
        return grouped.sorted { $0.key < $1.key }
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
                    Text(request.status.rawValue)
                        .font(.caption)
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
        .modelContainer(for: [Expense.self, ExpenseItem.self, SplitRequest.self])
}
