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
                VStack(alignment: .leading, spacing: 32) {
                    // Date and Time Selection
                    dateTimeSection
                    
                    // Quick Schedule Buttons
                    quickScheduleSection
                    
                    // Participant Selection
                    participantSelectionSection
                    
                    // Custom Message
                    messageSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("When to send reminder")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Large Calendar Picker - Main Focus
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Date")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    DatePicker("Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                }
                
                // Time Picker - Secondary, Smaller
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .frame(height: 120)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var quickScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Schedule")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                Button("Next Week") {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
                }
                .font(.body)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button("Next Month") {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                }
                .font(.body)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Spacer()
            }
        }
    }
    
    private var participantSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Send to")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: toggleSelectAll) {
                    HStack(spacing: 6) {
                        Image(systemName: scheduleSelectAll ? "checkmark.circle.fill" : "circle")
                        Text(scheduleSelectAll ? "Deselect All" : "Select All")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
            }
            
            if filteredSelectedRequests.isEmpty {
                Text("No participants selected")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
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
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.participantName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let expense = request.expense {
                        HStack(spacing: 4) {
                            Text(expense.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if expense.paymentMethod != .cash {
                                Image(systemName: expense.paymentMethod.icon)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Text("$\(request.amount, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .blue : .green)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminder Message")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter custom message...", text: $customMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(3...6)
                
                Text("This message will be sent to selected participants")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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
