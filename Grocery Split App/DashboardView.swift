import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \SplitRequest.createdDate, order: .reverse) var requests: [SplitRequest]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var filter: DashboardFilter = .all
    @State private var selection = Set<UUID>()
    @State private var showPurgeAlert = false
    @State private var purgedCount = 0
    @State private var selectAll = false
    @State private var isSelectionMode = false
    @State private var showingScheduleSheet = false
    @State private var scheduledRequests: [ScheduledSplitRequest] = []
    @State private var showingScheduleSuccess = false
    @State private var scheduleSuccessMessage = ""

    var filtered: [SplitRequest] {
        requests.filter { filter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                filterBar
                Text("Done items auto-delete after 30 days.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Select All button - positioned above the rows
                HStack {
                    Button(action: toggleSelectAll) { 
                        HStack {
                            Image(systemName: selectAll ? "checkmark.circle.fill" : "circle")
                            Text(isSelectionMode ? (selectAll ? "Deselect All" : "Select All") : "Select All")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Show Done button when in selection mode to exit selection
                    if isSelectionMode {
                        Button("Done") {
                            selection.removeAll()
                            selectAll = false
                            isSelectionMode = false
                        }
                        .buttonStyle(.bordered)
                        .padding(.trailing)
                    }
                    
                    Spacer()
                }
                
                // Scheduled Messages Queue
                if !scheduledRequests.isEmpty {
                    scheduleQueueSection
                }
                
                if filtered.isEmpty {
                    ContentUnavailableView("No records", systemImage: "tray")
                } else {
                    List {
                        ForEach(filtered) { req in
                            row(req)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .padding(.top, 8)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button("Done") { 
                        dismiss() 
                    } 
                }
            }
            .onAppear { autoPurgeDone() }
            .alert("Auto-purged \(purgedCount) done items older than 30 days", isPresented: $showPurgeAlert) { Button("OK", role: .cancel) {} }
            .safeAreaInset(edge: .bottom) {
                if !selection.isEmpty {
                    HStack {
                        Button("Unsettled") { bulkMarkUnsettled() }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        Button("Repaid") { bulkUpdate(.paid) }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        Spacer()
                        Button("Schedule Send") { showingScheduleSheet = true }
                            .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                ScheduleModalView(
                    selectedRequests: selection,
                    allRequests: filtered,
                    onSchedule: { scheduledRequest in
                        scheduledRequests.append(scheduledRequest)
                        showingScheduleSheet = false
                        scheduleSuccessMessage = "Successfully scheduled messages for \\(scheduledRequest.participants.count) participant(s) on \\(scheduledRequest.scheduledDate.formatted(date: .abbreviated, time: .shortened))"
                        showingScheduleSuccess = true
                    }
                )
            }
            .alert("Schedule Success", isPresented: $showingScheduleSuccess) { 
                Button("OK", role: .cancel) {} 
            } message: { 
                Text(scheduleSuccessMessage) 
            }
        }
    }
    
    private var scheduleQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Messages")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(scheduledRequests) { scheduledRequest in
                    scheduledRequestRow(scheduledRequest)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func scheduledRequestRow(_ scheduledRequest: ScheduledSplitRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scheduledRequest.participants.joined(separator: ", "))
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(scheduledRequest.scheduledDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(scheduledRequest.scheduledDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                deleteScheduledRequest(scheduledRequest)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func deleteScheduledRequest(_ scheduledRequest: ScheduledSplitRequest) {
        scheduledRequests.removeAll { $0.id == scheduledRequest.id }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardFilter.allCases, id: \.self) { f in
                    Button(action: { filter = f }) {
                        Text(f.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filter == f ? f.color : Color(.systemGray6))
                            .foregroundColor(filter == f ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func row(_ req: SplitRequest) -> some View {
        HStack {
            // Only show selection circle when in selection mode
            if isSelectionMode {
                Button(action: { toggleRowSelection(req) }) {
                    Image(systemName: selection.contains(req.id) ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
            }
            let statusColor: Color = req.status == .paid ? .gray.opacity(0.6) : (isOverdue(req) ? .red : .primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(req.participantName)
                    .font(.headline)
                    .foregroundColor(statusColor)
                // Show merchant/receipt name prominently
                if let expense = req.expense {
                    Text(expense.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Show payment method info on each row
                    HStack(spacing: 4) {
                        Image(systemName: expense.paymentMethod.icon)
                            .font(.caption2)
                        Text(expense.paymentMethod.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    if !req.messageText.isEmpty && req.messageText != expense.name {
                        Text(req.messageText)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(req.messageText)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(req.amount, specifier: "%.2f")")
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                Text(req.createdDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .background(isOverdue(req) ? Color.red.opacity(0.07) : (req.status == .paid ? Color.gray.opacity(0.05) : Color.clear))
        // Right swipe actions - show "Unsettled" and "Repaid" options
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { 
            Button("Repaid") { 
                markPaid(req)
            }
            .tint(.green)
            
            if req.status == .paid {
                Button("Unsettled") { 
                    restore(req) 
                }
                .tint(.red) 
            }
        }
        .onTapGesture {
            // Only enable selection mode when "Select All" has been used
            if isSelectionMode {
                toggleRowSelection(req)
            }
        }
    }

    private func isOverdue(_ r: SplitRequest) -> Bool {
        if let due = r.dueDate { return Date() > due && r.status != .paid }
        return false
    }

    private func markPaid(_ r: SplitRequest) {
        r.status = .paid
        try? modelContext.save()
    }

    private func markOverdue(_ r: SplitRequest) {
        r.status = .overdue
        r.priority = .high
        try? modelContext.save()
    }

    private func restore(_ r: SplitRequest) {
        r.status = .pending
        r.priority = .normal
        r.nextSendDate = nil
        try? modelContext.save()
    }

    private func bulkUpdate(_ status: RequestStatus) {
        for id in selection {
            if let r = requests.first(where: { $0.id == id }) { r.status = status }
        }
        try? modelContext.save()
        selection.removeAll()
        selectAll = false
        isSelectionMode = false
    }

    private func bulkMarkUnsettled() {
        for id in selection {
            if let r = requests.first(where: { $0.id == id }) {
                r.status = .pending
                r.priority = .normal
                r.nextSendDate = nil
            }
        }
        try? modelContext.save()
        selection.removeAll()
        selectAll = false
        isSelectionMode = false
    }

    // MARK: - Auto purge done > 30 days
    private func autoPurgeDone() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var removed = 0
        for r in requests where r.status == .paid && r.createdDate < cutoff {
            modelContext.delete(r)
            removed += 1
        }
        if removed > 0 { purgedCount = removed; showPurgeAlert = true }
    }

    private func toggleRowSelection(_ r: SplitRequest) {
        if selection.contains(r.id) { 
            selection.remove(r.id) 
        } else { 
            selection.insert(r.id) 
        }
        
        // Update selectAll state based on current selection
        selectAll = selection.count == filtered.count
        
        // Exit selection mode if no items are selected
        if selection.isEmpty {
            isSelectionMode = false
        }
    }

    private func toggleSelectAll() {
        if !isSelectionMode {
            // Entering selection mode - select all items
            isSelectionMode = true
            selection = Set(filtered.map { $0.id })
            selectAll = true
        } else if selectAll {
            // Currently all selected - deselect all but stay in selection mode
            selection.removeAll()
            selectAll = false
        } else {
            // Currently some/none selected - select all
            selection = Set(filtered.map { $0.id })
            selectAll = true
        }
    }
}

enum DashboardFilter: CaseIterable {
    case all, unsettled, repaid
    var title: String {
        switch self {
        case .unsettled: return "Unsettled"
        case .repaid: return "Repaid"
        case .all: return "All"
        }
    }
    var color: Color {
        switch self {
        case .unsettled: return .red
        case .repaid: return .primary
        case .all: return .primary
        }
    }
    func matches(_ r: SplitRequest) -> Bool {
        switch self {
        case .unsettled:
            return r.status != .paid
        case .repaid:
            return r.status == .paid
        case .all:
            return true
        }
    }
}

struct ScheduledSplitRequest: Identifiable {
    let id = UUID()
    let splitRequestIds: Set<UUID>
    let scheduledDate: Date
    let message: String
    var participants: [String]
    
    init(splitRequestIds: Set<UUID>, scheduledDate: Date, message: String, participants: [String]) {
        self.splitRequestIds = splitRequestIds
        self.scheduledDate = scheduledDate
        self.message = message
        self.participants = participants
    }
}


