import SwiftUI
import SwiftData

// MARK: - Preview Message Section Component
struct PreviewMessageSection: View {
    let participant: SplitRequest
    let expense: Expense
    @Binding var isExpanded: Bool
    @Binding var messageText: String
    @State private var isEditing: Bool = false
    @State private var tempMessageText: String = ""
    @Environment(\.modelContext) private var modelContext
    
    private let maxCharacters = 160 // SMS character limit
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "message")
                            .foregroundColor(.blue)
                        Text("Message Preview")
                            .font(.headline)
                    }
                    
                    if !isExpanded {
                        // Collapsed state: show template name and preview
                        Text(messageTemplate.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(messagePreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    if !isExpanded {
                        Button("Edit") {
                            tempMessageText = messageText.isEmpty ? generatedMessage : messageText
                            isExpanded = true
                            isEditing = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("Preview") {
                            isExpanded = true
                            isEditing = false
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        
                        if !messageText.isEmpty {
                            Button("Send") {
                                sendMessage()
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                    
                    Button(isExpanded ? "Collapse" : "Expand") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                            if !isExpanded {
                                isEditing = false
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 12) {
                    if isEditing {
                        // Edit Mode
                        VStack(spacing: 8) {
                            TextEditor(text: $tempMessageText)
                                .frame(minHeight: 100, maxHeight: 150)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            
                            // Character Count
                            HStack {
                                Text("\(tempMessageText.count)/\(maxCharacters)")
                                    .font(.caption)
                                    .foregroundColor(tempMessageText.count > maxCharacters ? .red : .secondary)
                                
                                Spacer()
                                
                                if tempMessageText.count > maxCharacters {
                                    Text("Message too long")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Edit Actions
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    tempMessageText = messageText.isEmpty ? generatedMessage : messageText
                                    isEditing = false
                                }
                                .foregroundColor(.red)
                                
                                Button("Reset") {
                                    tempMessageText = generatedMessage
                                }
                                .foregroundColor(.orange)
                                
                                Spacer()
                                
                                Button("Confirm & Send") {
                                    if tempMessageText.count <= maxCharacters {
                                        messageText = tempMessageText
                                        saveMessage()
                                        sendMessage()
                                        isEditing = false
                                        isExpanded = false
                                    }
                                }
                                .disabled(tempMessageText.count > maxCharacters)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                            }
                            .font(.caption)
                        }
                    } else {
                        // Preview Mode
                        VStack(spacing: 12) {
                            // Message Preview
                            Text(currentMessage)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Preview Actions
                            HStack(spacing: 12) {
                                Button("Edit") {
                                    tempMessageText = messageText.isEmpty ? generatedMessage : messageText
                                    isEditing = true
                                }
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                if !currentMessage.isEmpty {
                                    Button("Send Message") {
                                        if messageText.isEmpty {
                                            messageText = generatedMessage
                                            saveMessage()
                                        }
                                        sendMessage()
                                        isExpanded = false
                                    }
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if messageText.isEmpty {
                messageText = generatedMessage
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var messageTemplate: MessageTemplateData {
        return MessageComposer.getTemplate(for: expense, participant: participant)
    }
    
    private var generatedMessage: String {
        return MessageComposer.generateMessage(for: expense, participant: participant, template: messageTemplate)
    }
    
    private var currentMessage: String {
        return messageText.isEmpty ? generatedMessage : messageText
    }
    
    private var messagePreview: String {
        let preview = currentMessage.prefix(80)
        return preview.count < currentMessage.count ? String(preview) + "..." : String(preview)
    }
    
    // MARK: - Actions
    
    private func saveMessage() {
        participant.messageText = messageText
        try? modelContext.save()
    }
    
    private func sendMessage() {
        // Update split request status
        participant.status = .sent
        participant.messageText = currentMessage
        expense.lastSentDate = Date()
        
        // Save to SwiftData
        try? modelContext.save()
        
        // In production, this would integrate with:
        // - Messages app
        // - Email
        // - Third-party services like Twilio
        
        // For now, we'll show a success state
        print("Message sent to \(participant.participantName): \(currentMessage)")
    }
}

#Preview {
    // Create sample data for preview
    let mockExpense = Expense(
        name: "Dinner at Italian Restaurant",
        payerName: "John Doe",
        paymentMethod: .creditCard,
        category: .dining
    )
    
    let mockParticipant = SplitRequest(
        participantName: "Jane Smith",
        amount: 25.50
    )
    
    PreviewMessageSection(
        participant: mockParticipant,
        expense: mockExpense,
        isExpanded: .constant(false),
        messageText: .constant("")
    )
    .padding()
    .modelContainer(for: [Expense.self, ExpenseItem.self, SplitRequest.self])
}