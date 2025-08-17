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
                    // Bulk select toolbar - circles show only in selection mode
                    if !splitRequests.isEmpty {
                        Section {
                            HStack {
                                Button(action: enterOrToggleSelection) {
                                    Text(isSelectionMode ? (isAllSelected ? "Deselect All" : "Select All") : "Select All")
                                }
                                Spacer()
                                if isSelectionMode {
                                    if !selectedForSchedule.isEmpty {
                                        Button("Paid") { confirmBulk(.paid) }
                                        Button("Pending") { confirmBulk(.pending) }
                                        Button(role: .destructive) { confirmDelete() } label: { Text("Delete") }
                                    }
                                    Button("Done") { exitSelection() }
                                }
                            }
                        }
                    }

                    ForEach(groupedRequests(), id: \.key) { group, requests in
                        Section(group) {
                            ForEach(requests) { request in
                                HStack(spacing: 12) {
                                    if isSelectionMode {
                                        Button(action: { toggleRow(request) }) {
                                            Image(systemName: selectedForSchedule.contains(request.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundColor(selectedForSchedule.contains(request.id) ? .blue : .gray)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 30, height: 30)
                                        .contentShape(Circle())
                                    }
                                    
                                    GroupRequestRow(request: request)
                                        .contentShape(Rectangle())
                                        .allowsHitTesting(false) // completely disable row taps in selection mode
                                }
                                .contentShape(Rectangle())
                                .allowsHitTesting(!isSelectionMode) // disable entire row interaction in selection mode
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Paid") { updateStatus(request, to: .paid) }.tint(.green)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button("Pending") { updateStatus(request, to: .pending) }.tint(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            // Different confirmation dialogs for each action
            .alert("Mark as Paid?", isPresented: Binding(get: { confirmAction == .paid }, set: { _ in confirmAction = nil })) {
                Button("Mark Paid") { bulkUpdate(.paid); confirmAction = nil }
                Button("Cancel", role: .cancel) { confirmAction = nil }
            }
            .alert("Mark as Pending?", isPresented: Binding(get: { confirmAction == .pending }, set: { _ in confirmAction = nil })) {
                Button("Mark Pending") { bulkUpdate(.pending); confirmAction = nil }
                Button("Cancel", role: .cancel) { confirmAction = nil }
            }
            .alert("Delete Selected?", isPresented: Binding(get: { confirmAction == .delete }, set: { _ in confirmAction = nil })) {
                Button("Delete", role: .destructive) { bulkDelete(); confirmAction = nil }
                Button("Cancel", role: .cancel) { confirmAction = nil }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScheduleSheet = true
                    } label: {
                        Label("Schedule", systemImage: "calendar.badge.clock")
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

    // Selection helpers
    @State private var isAllSelected = false
    @State private var isSelectionMode = false
    private func toggleRow(_ r: SplitRequest) {
        if selectedForSchedule.contains(r.id) { selectedForSchedule.remove(r.id) } else { selectedForSchedule.insert(r.id) }
        isAllSelected = selectedForSchedule.count == splitRequests.count
    }
    private func enterOrToggleSelection() {
        if !isSelectionMode {
            isSelectionMode = true
            selectedForSchedule = Set(splitRequests.map { $0.id })
            isAllSelected = true
            return
        }
        // Already in selection mode -> toggle select all
        if isAllSelected { selectedForSchedule.removeAll() } else { selectedForSchedule = Set(splitRequests.map { $0.id }) }
        isAllSelected.toggle()
    }
    private func exitSelection() {
        isSelectionMode = false
        isAllSelected = false
        selectedForSchedule.removeAll()
    }
    private func bulkUpdate(_ status: RequestStatus) {
        for id in selectedForSchedule {
            if let r = splitRequests.first(where: { $0.id == id }) { 
                r.status = status 
            }
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
        exitSelection()
    }

    // MARK: - Confirmations
    private enum ConfirmAction { case paid, pending, delete }
    @State private var confirmAction: ConfirmAction? = nil
    private func confirmBulk(_ status: RequestStatus) {
        confirmAction = (status == .paid) ? .paid : .pending
    }
    private func confirmDelete() {
        confirmAction = .delete
    }
    private func bulkDelete() {
        for id in selectedForSchedule {
            if let r = splitRequests.first(where: { $0.id == id }) { 
                modelContext.delete(r) 
            }
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .splitRequestsChanged, object: nil)
        exitSelection()
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
