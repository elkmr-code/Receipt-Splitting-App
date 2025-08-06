import SwiftUI
import SwiftData

struct EnhancedSplitExpenseView: View {
    @Bindable var expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var participants: [SplitParticipant] = []
    @State private var splitMethod: SplitMethod = .evenSplit
    @State private var showingShareSheet = false
    @State private var shareContent = ""
    @State private var selectedParticipants: Set<UUID> = []
    @State private var customSplitAmounts: [UUID: Double] = [:]
    @State private var shareMessage = "Hey! Here's your share from our recent expense. No rush, but would love to settle this when you get a chance! 😊"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var itemAssignments: [UUID: Set<UUID>] = [:] // participantId -> Set of itemIds
    @State private var showingItemAssignment = false
    
    enum SplitMethod: String, CaseIterable {
        case evenSplit = "Even Split"
        case customSplit = "Custom Amounts"
        case percentageSplit = "Percentage Split"
        case itemBased = "Item-Based Split"
        
        var icon: String {
            switch self {
            case .evenSplit: return "equal.circle"
            case .customSplit: return "slider.horizontal.3"
            case .percentageSplit: return "percent"
            case .itemBased: return "list.bullet"
            }
        }
        
        var description: String {
            switch self {
            case .evenSplit: return "Split equally among all participants"
            case .customSplit: return "Set custom amounts for each person"
            case .percentageSplit: return "Split by percentage contribution"
            case .itemBased: return "Assign specific items to people"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Expense Summary
                    expenseSummarySection
                    
                    // Participants Section
                    participantsSection
                    
                    // Split Method Selection
                    if !participants.isEmpty {
                        splitMethodSection
                        splitPreviewSection
                        shareOptionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Split Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(participants.isEmpty)
                }
            }
        }
        .onAppear {
            setupDefaultParticipants()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
        .alert("Alert", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingItemAssignment) {
            ItemAssignmentView(
                expense: expense,
                participants: participants,
                itemAssignments: $itemAssignments,
                onComplete: {
                    calculateItemBasedSplit()
                    showingItemAssignment = false
                }
            )
        }
    }
    
    // MARK: - View Components
    
    private var expenseSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Splitting: \(expense.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text("Total Amount:")
                    .font(.headline)
                Spacer()
                Text("$\(expense.totalCost, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participants")
                    .font(.headline)
                Spacer()
                Button(action: addParticipant) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            if participants.isEmpty {
                emptyParticipantsView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(participants) { participant in
                        ParticipantRow(
                            participant: participant,
                            splitMethod: splitMethod,
                            totalAmount: expense.totalCost,
                            onUpdate: { updatedParticipant in
                                updateParticipant(updatedParticipant)
                            },
                            onDelete: {
                                deleteParticipant(participant)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var emptyParticipantsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Add people to split this expense")
                .foregroundColor(.secondary)
            
            Button(action: addParticipant) {
                Text("Add Person")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Split Method")
                .font(.headline)
            
            VStack(spacing: 8) {
                // First Row: Even Split
                splitMethodButton(for: .evenSplit)
                
                // Second Row: Percentage Split
                splitMethodButton(for: .percentageSplit)
                
                // Third Row: Item-Based Split
                splitMethodButton(for: .itemBased)
                
                // Fourth Row: Custom Split
                splitMethodButton(for: .customSplit)
            }
        }
    }
    
    private func splitMethodButton(for method: SplitMethod) -> some View {
        Button(action: {
            splitMethod = method
            recalculateSplit()
        }) {
            HStack {
                Image(systemName: method.icon)
                    .font(.title3)
                    .foregroundColor(splitMethod == method ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(method.description)
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
                
                if splitMethod == method {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(splitMethod == method ? Color.blue : Color(.systemGray6))
            .foregroundColor(splitMethod == method ? .white : .primary)
            .cornerRadius(10)
        }
    }
    
    private var splitPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Split Preview")
                    .font(.headline)
                Spacer()
            }
            
            let validParticipants = participants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            if validParticipants.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("Add participants to see split preview")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(validParticipants) { participant in
                        participantPreviewRow(participant)
                    }
                }
                
                splitValidationView
            }
        }
    }
    
    private func participantPreviewRow(_ participant: SplitParticipant) -> some View {
        let isValidParticipant = !participant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return HStack {
            Text(participant.name)
                .font(.body)
                .foregroundColor(isValidParticipant ? .primary : .secondary)
            Spacer()
            Text("$\(participant.amount, specifier: "%.2f")")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(isValidParticipant ? .green : .gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .opacity(isValidParticipant ? 1.0 : 0.6)
    }
    
    private var splitValidationView: some View {
        Group {
            let validParticipants = participants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let totalSplit = validParticipants.reduce(0) { $0 + $1.amount }
            let difference = expense.totalCost - totalSplit
            
            if abs(difference) > 0.01 {
                HStack {
                    Text("⚠️ Split total doesn't match expense total")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Difference: $\(difference, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                
                Button("Auto-adjust to match total") {
                    autoAdjustSplit()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
    
    private var shareOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share Split Details")
                .font(.headline)
            
            messageCustomizationView
            participantSelectionView
            shareButtonsView
        }
    }
    
    private var messageCustomizationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom message:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Add a friendly message...", text: $shareMessage, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(2...4)
        }
    }
    
    private var participantSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send to:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Button(action: selectAllParticipants) {
                    Text("Select All")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Button(action: deselectAllParticipants) {
                    Text("Deselect All")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Spacer()
            }
            
            LazyVStack(spacing: 4) {
                ForEach(participants) { participant in
                    participantSelectionRow(participant)
                }
            }
        }
    }
    
    private func participantSelectionRow(_ participant: SplitParticipant) -> some View {
        Button(action: { toggleParticipantSelection(participant) }) {
            HStack {
                let isSelected = selectedParticipants.contains(participant.id)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(participant.name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("$\(participant.amount, specifier: "%.2f")")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(selectedParticipants.contains(participant.id) ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var shareButtonsView: some View {
        HStack(spacing: 12) {
            Button(action: shareIndividually) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.title2)
                    Text("Send")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: shareWithPaymentMethods) {
                VStack(spacing: 4) {
                    Image(systemName: "creditcard.circle")
                        .font(.title2)
                    Text("With Payment")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupDefaultParticipants() {
        if participants.isEmpty {
            participants.append(SplitParticipant(name: expense.payerName, amount: 0, percentage: 0, weight: 1.0))
        }
    }
    
    private func addParticipant() {
        let participantName = "Person \(participants.count + 1)"
        // Don't add empty participants - ensure they have a valid name and amount
        participants.append(SplitParticipant(name: participantName, amount: 0, percentage: 0, weight: 1.0))
        recalculateSplit()
    }
    
    private func updateParticipant(_ updatedParticipant: SplitParticipant) {
        if let index = participants.firstIndex(where: { $0.id == updatedParticipant.id }) {
            participants[index] = updatedParticipant
            // Recalculate when participant data changes to maintain consistency
            if splitMethod == .evenSplit {
                recalculateSplit()
            }
        }
    }
    
    private func deleteParticipant(_ participant: SplitParticipant) {
        participants.removeAll { $0.id == participant.id }
        selectedParticipants.remove(participant.id)
        recalculateSplit()
    }
    
    private func recalculateSplit() {
        guard !participants.isEmpty && expense.totalCost > 0 else { return }
        
        // Filter out participants with invalid names (empty or just whitespace)
        let validParticipants = participants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !validParticipants.isEmpty else { return }
        
        switch splitMethod {
        case .evenSplit:
            let amountPerPerson = expense.totalCost / Double(validParticipants.count)
            let percentagePerPerson = 100.0 / Double(validParticipants.count)
            for i in participants.indices {
                if !participants[i].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    participants[i].amount = amountPerPerson
                    participants[i].percentage = percentagePerPerson
                } else {
                    participants[i].amount = 0.0
                    participants[i].percentage = 0.0
                }
            }
            
        case .customSplit:
            // Don't automatically recalculate for custom split - let user input amounts
            break
            
        case .percentageSplit:
            let totalPercentage = participants.reduce(0) { $0 + $1.percentage }
            if totalPercentage > 0 {
                for i in participants.indices {
                    participants[i].amount = expense.totalCost * (participants[i].percentage / 100.0)
                }
            }
            
        case .itemBased:
            if !expense.items.isEmpty {
                showingItemAssignment = true
                calculateItemBasedSplit()
            } else {
                recalculateEvenSplit()
            }
        }
    }
    
    private func recalculateEvenSplit() {
        let validParticipants = participants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validParticipants.isEmpty else { return }
        
        let amountPerPerson = expense.totalCost / Double(validParticipants.count)
        for i in participants.indices {
            if !participants[i].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                participants[i].amount = amountPerPerson
                participants[i].percentage = 100.0 / Double(validParticipants.count)
            } else {
                participants[i].amount = 0.0
                participants[i].percentage = 0.0
            }
        }
    }
    
    private func selectAllParticipants() {
        selectedParticipants = Set(participants.map { $0.id })
    }
    
    private func deselectAllParticipants() {
        selectedParticipants.removeAll()
    }
    
    private func toggleParticipantSelection(_ participant: SplitParticipant) {
        if selectedParticipants.contains(participant.id) {
            selectedParticipants.remove(participant.id)
        } else {
            selectedParticipants.insert(participant.id)
        }
    }
    
    private func shareIndividually() {
        let selectedPeople = participants.filter { selectedParticipants.contains($0.id) }
        
        if selectedPeople.isEmpty {
            alertMessage = "Please select at least one participant to share individually."
            showingAlert = true
            return
        }
        
        for participant in selectedPeople {
            let content = generateIndividualShareContent(for: participant)
            shareContent = content
            showingShareSheet = true
        }
    }
    
    private func shareAsGroup() {
        if participants.isEmpty {
            alertMessage = "Please add at least one participant to share as a group."
            showingAlert = true
            return
        }
        shareContent = generateGroupShareContent()
        showingShareSheet = true
    }
    
    private func shareWithPaymentMethods() {
        let selectedPeople = participants.filter { selectedParticipants.contains($0.id) }
        
        if selectedPeople.isEmpty {
            alertMessage = "Please select at least one participant to share with payment methods."
            showingAlert = true
            return
        }
        
        shareContent = generatePaymentShareContent(for: selectedPeople)
        showingShareSheet = true
    }
    
    private func generateIndividualShareContent(for participant: SplitParticipant) -> String {
        return """
        \(shareMessage)
        
        💰 Expense: \(expense.name)
        📅 Date: \(expense.date.formatted(date: .abbreviated, time: .omitted))
        💳 Paid by: \(expense.payerName)
        
        Your share: $\(String(format: "%.2f", participant.amount))
        
        \(generatePaymentInstructions())
        
        Thanks! 😊
        """
    }
    
    private func generateGroupShareContent() -> String {
        let participantsList = participants.map { "• \($0.name): $\(String(format: "%.2f", $0.amount))" }.joined(separator: "\n")
        
        return """
        \(shareMessage)
        
        💰 Expense: \(expense.name)
        📅 Date: \(expense.date.formatted(date: .abbreviated, time: .omitted))
        💳 Paid by: \(expense.payerName)
        💵 Total: $\(String(format: "%.2f", expense.totalCost))
        
        Split breakdown (\(splitMethod.rawValue)):
        \(participantsList)
        
        \(generatePaymentInstructions())
        
        Generated with Grocery Split App
        """
    }
    
    private func generatePaymentShareContent(for selectedPeople: [SplitParticipant]) -> String {
        let participantsList = selectedPeople.map { "• \($0.name): $\(String(format: "%.2f", $0.amount))" }.joined(separator: "\n")
        
        return """
        \(shareMessage)
        
        💰 Expense: \(expense.name)
        📅 Date: \(expense.date.formatted(date: .abbreviated, time: .omitted))
        💳 Originally paid by: \(expense.payerName) via \(expense.paymentMethod.rawValue)
        
        Amount(s) owed:
        \(participantsList)
        
        \(generatePaymentInstructions())
        
        Payment methods accepted:
        💳 Venmo: @\(expense.payerName.lowercased())
        💰 Zelle: \(expense.payerName)@email.com
        🍎 Apple Pay: Available
        💵 Cash: Always welcome!
        
        No rush, but would appreciate settling when convenient! 😊
        """
    }
    
    private func generatePaymentInstructions() -> String {
        return "Please send payment to \(expense.payerName) when convenient."
    }
    
    private func autoAdjustSplit() {
        // For custom splits, automatically adjust to match the total
        let validParticipants = participants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let totalSplit = validParticipants.reduce(0) { $0 + $1.amount }
        let difference = expense.totalCost - totalSplit
        
        guard !validParticipants.isEmpty && abs(difference) > 0.01 else { return }
        
        if splitMethod == .customSplit {
            // For custom split, adjust the first participant's amount to make total correct
            if let firstIndex = participants.firstIndex(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                participants[firstIndex].amount += difference
                
                // Update percentage accordingly
                participants[firstIndex].percentage = (participants[firstIndex].amount / expense.totalCost) * 100
            }
        } else {
            // For other split methods, recalculate evenly
            let amountPerPerson = expense.totalCost / Double(validParticipants.count)
            let percentagePerPerson = 100.0 / Double(validParticipants.count)
            
            for i in participants.indices {
                if !participants[i].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    participants[i].amount = amountPerPerson
                    participants[i].percentage = percentagePerPerson
                } else {
                    participants[i].amount = 0.0
                    participants[i].percentage = 0.0
                }
            }
        }
    }

    private func calculateItemBasedSplit() {
        // Reset all amounts first
        for i in participants.indices {
            participants[i].amount = 0.0
            participants[i].percentage = 0.0
        }
        
        // Calculate amounts based on item assignments
        for i in participants.indices {
            let participant = participants[i]
            if let assignedItemIds = itemAssignments[participant.id] {
                let assignedItems = expense.items.filter { assignedItemIds.contains($0.id) }
                let totalCost = assignedItems.reduce(0) { $0 + $1.price }
                participants[i].amount = totalCost
                participants[i].percentage = expense.totalCost > 0 ? (totalCost / expense.totalCost) * 100 : 0
            }
        }
    }
}

struct SplitParticipant: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var percentage: Double
    var weight: Double
    var email: String = ""
    var paymentMethod: String = ""
}

struct ParticipantRow: View {
    @State var participant: SplitParticipant
    let splitMethod: EnhancedSplitExpenseView.SplitMethod
    let totalAmount: Double
    let onUpdate: (SplitParticipant) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Name", text: $participant.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: participant.name) { _, newValue in
                        let trimmedName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            participant.name = trimmedName
                            onUpdate(participant)
                        }
                    }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            inputFieldsForSplitMethod
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var inputFieldsForSplitMethod: some View {
        switch splitMethod {
        case .customSplit:
            HStack {
                Text("Amount:")
                Spacer()
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", value: $participant.amount, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .onChange(of: participant.amount) { _, _ in
                            onUpdate(participant)
                        }
                }
            }
            
        case .percentageSplit:
            HStack {
                Text("Percentage:")
                Spacer()
                TextField("0", value: $participant.percentage, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .onChange(of: participant.percentage) { _, _ in
                        participant.amount = totalAmount * (participant.percentage / 100.0)
                        onUpdate(participant)
                    }
                Text("%")
            }
            
        default:
            // Remove amount display from main participants section
            // Amounts will only be shown in the selection section below
            EmptyView()
        }
    }
}

struct ItemAssignmentView: View {
    let expense: Expense
    let participants: [SplitParticipant]
    @Binding var itemAssignments: [UUID: Set<UUID>]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Assign items to participants")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(expense.items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(item.price, format: .currency(code: "USD"))
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            Text("Assign to:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(participants) { participant in
                                    let isAssigned = itemAssignments[participant.id]?.contains(item.id) ?? false
                                    
                                    Button(action: {
                                        toggleItemAssignment(participantId: participant.id, itemId: item.id)
                                    }) {
                                        HStack {
                                            Image(systemName: isAssigned ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isAssigned ? .blue : .gray)
                                            Text(participant.name)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isAssigned ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Assign Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleItemAssignment(participantId: UUID, itemId: UUID) {
        if itemAssignments[participantId] == nil {
            itemAssignments[participantId] = Set<UUID>()
        }
        
        if itemAssignments[participantId]!.contains(itemId) {
            itemAssignments[participantId]!.remove(itemId)
        } else {
            itemAssignments[participantId]!.insert(itemId)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Expense.self, configurations: config)
    
    let expense = Expense(name: "Dinner", payerName: "John", paymentMethod: .venmo, category: .dining)
    expense.items = [
        ExpenseItem(name: "Pizza", price: 25.99),
        ExpenseItem(name: "Drinks", price: 12.50)
    ]
    
    return EnhancedSplitExpenseView(expense: expense)
        .modelContainer(container)
}
