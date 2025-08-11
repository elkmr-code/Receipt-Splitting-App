import SwiftUI
import SwiftData

struct ScheduleModalView: View {
    let selectedRequests: Set<UUID>
    let allRequests: [SplitRequest]
    let onSchedule: (ScheduledSplitRequest) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var scheduleSelection: Set<UUID> = []
    @State private var scheduleSelectAll = false
    @State private var customMessage = "Friendly reminder about your payment! 💰"
    
    var filteredSelectedRequests: [SplitRequest] {
        allRequests.filter { selectedRequests.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date and Time Selection
                    dateTimeSection
                    
                    // Quick Schedule Buttons
                    quickScheduleSection
                    
                    // Participant Selection
                    participantSelectionSection
                    
                    // Custom Message
                    messageSection
                }
                .padding()
            }
            .navigationTitle("Schedule Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        scheduleReminder()
                    }
                    .disabled(scheduleSelection.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            scheduleSelection = selectedRequests
            scheduleSelectAll = scheduleSelection.count == filteredSelectedRequests.count
        }
    }
    
    // MARK: - View Components
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When to send reminder")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Date Picker
                DatePicker("Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Time Picker (iOS-style wheel)
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .frame(height: 120)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private var quickScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Schedule")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Next Week") {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button("Next Month") {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                }
                .buttonStyle(.bordered)
                .tint(.green)
                
                Spacer()
            }
        }
    }
    
    private var participantSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Send to")
                    .font(.headline)
                
                Spacer()
                
                Button(action: toggleSelectAll) {
                    HStack {
                        Image(systemName: scheduleSelectAll ? "checkmark.circle.fill" : "circle")
                        Text(scheduleSelectAll ? "Deselect All" : "Select All")
                    }
                    .font(.caption)
                }
            }
            
            if filteredSelectedRequests.isEmpty {
                Text("No participants selected")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredSelectedRequests) { request in
                        participantRow(request)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func participantRow(_ request: SplitRequest) -> some View {
        let isSelected = scheduleSelection.contains(request.id)
        Button(action: { toggleParticipantSelection(request) }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.participantName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let expense = request.expense {
                        Text(expense.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("$\(request.amount, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder Message")
                .font(.headline)
            
            TextField("Enter custom message...", text: $customMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelectAll() {
        if scheduleSelectAll {
            scheduleSelection.removeAll()
            scheduleSelectAll = false
        } else {
            scheduleSelection = Set(filteredSelectedRequests.map { $0.id })
            scheduleSelectAll = true
        }
    }
    
    private func toggleParticipantSelection(_ request: SplitRequest) {
        if scheduleSelection.contains(request.id) {
            scheduleSelection.remove(request.id)
        } else {
            scheduleSelection.insert(request.id)
        }
        
        scheduleSelectAll = scheduleSelection.count == filteredSelectedRequests.count
    }
    
    private func scheduleReminder() {
        let scheduledDateTime = combineDateTime(date: selectedDate, time: selectedTime)
        let selectedParticipants = filteredSelectedRequests.filter { scheduleSelection.contains($0.id) }
        
        let scheduledRequest = ScheduledSplitRequest(
            splitRequestIds: scheduleSelection,
            scheduledDate: scheduledDateTime,
            message: customMessage,
            participants: selectedParticipants.map { $0.participantName }
        )
        
        onSchedule(scheduledRequest)
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? Date()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SplitRequest.self, Expense.self, configurations: config)
    
    let expense = Expense(name: "Dinner", payerName: "John", paymentMethod: .venmo, category: .dining)
    let request1 = SplitRequest(participantName: "Alice", amount: 25.50, status: .pending, messageText: "Dinner split", priority: .normal, expense: expense)
    let request2 = SplitRequest(participantName: "Bob", amount: 30.75, status: .pending, messageText: "Dinner split", priority: .normal, expense: expense)
    
    ScheduleModalView(
        selectedRequests: Set([request1.id, request2.id]),
        allRequests: [request1, request2],
        onSchedule: { _ in }
    )
    .modelContainer(container)
}
