import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \SplitRequest.createdDate, order: .reverse) var requests: [SplitRequest]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var filter: DashboardFilter = .all
    @State private var selection = Set<UUID>()
    @State private var showingScheduleSheet = false
    @State private var scheduleDate = Date()
    @State private var showingRecipientPicker = false
    @State private var recipients = Set<UUID>()
    @State private var showPurgeAlert = false
    @State private var purgedCount = 0
    @State private var selectAll = false
    @State private var isSelectionMode = false

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button("Done") { 
                        dismiss() 
                    } 
                }
            }
            .onAppear { autoPurgeDone() }
            .alert("Auto-purged \(purgedCount) done items older than 30 days", isPresented: $showPurgeAlert) { Button("OK", role: .cancel) {} }
            .sheet(isPresented: $showingScheduleSheet) { scheduleSheet }
            .sheet(isPresented: $showingRecipientPicker) { recipientPickerSheet }
            .safeAreaInset(edge: .bottom) {
                if !selection.isEmpty {
                    HStack {
                        Button("Repaid") { bulkUpdate(.paid) }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        Button("Unsettled") { bulkMarkUnsettled() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
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

    private func schedule(_ r: SplitRequest, days: Int) {
        r.nextSendDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
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

    private func bulkSchedule(days: Int) {
        for id in selection {
            if let r = requests.first(where: { $0.id == id }) {
                r.nextSendDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
            }
        }
        try? modelContext.save()
        selection.removeAll()
        selectAll = false
        isSelectionMode = false
    }

    // MARK: - Scheduling UI
    private var scheduleSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Choose Date & Time", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                HStack {
                    Button("Next Week") { scheduleDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date() }
                        .buttonStyle(.bordered)
                    Button("Next Month") { scheduleDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date() }
                        .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Schedule Send")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingScheduleSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        showingScheduleSheet = false
                        recipients = selection
                        // default: if nothing selected, allow choosing individuals next
                        showingRecipientPicker = true
                    }.fontWeight(.semibold)
                }
            }
        }
    }

    private var recipientPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                List(filtered, selection: $recipients) { req in
                    HStack {
                        Text(req.participantName)
                        Spacer()
                        Text("$\(req.amount, specifier: "%.2f")").foregroundColor(.secondary)
                    }
                }
                .environment(\.editMode, .constant(.active))
                .listStyle(.insetGrouped)
                .navigationTitle("Select Recipients")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingRecipientPicker = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set Schedule") {
                            let ids = recipients.isEmpty ? (selection.isEmpty ? Set(filtered.map { $0.id }) : selection) : recipients
                            for id in ids { if let r = requests.first(where: { $0.id == id }) { r.nextSendDate = scheduleDate } }
                            try? modelContext.save()
                            showingRecipientPicker = false
                            selection.removeAll()
                            selectAll = false
                            isSelectionMode = false
                        }.fontWeight(.semibold)
                    }
                }
            }
        }
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


