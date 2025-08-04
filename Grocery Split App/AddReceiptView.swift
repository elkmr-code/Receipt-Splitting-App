import SwiftUI
import PhotosUI
import SwiftData

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedItems: [(name: String, price: Double)] = []
    @State private var receiptName = ""
    @State private var payerName = ""
    @State private var showingParsedItems = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Selection Section
                    VStack(spacing: 16) {
                        Text("Select Receipt Image")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemBlue))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: loadSampleReceipt) {
                            Label("Process Sample Receipt", systemImage: "doc.text.image")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemOrange))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    // Image Preview
                    if let selectedImage = selectedImage {
                        VStack(spacing: 8) {
                            Text("Selected Image")
                                .font(.headline)
                            
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                    
                    // Receipt Details Input
                    if selectedImage != nil {
                        VStack(spacing: 12) {
                            TextField("Receipt Name (e.g., Grocery Run - Aug 4)", text: $receiptName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Payer Name", text: $payerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Process Button
                    if selectedImage != nil && !receiptName.isEmpty && !payerName.isEmpty {
                        Button(action: processImage) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isProcessing ? "Processing..." : "Process Image")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isProcessing ? Color(.systemGray) : Color(.systemGreen))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isProcessing)
                    }
                    
                    // Parsed Items Review
                    if showingParsedItems && !parsedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Review Parsed Items")
                                .font(.headline)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(Array(parsedItems.enumerated()), id: \.offset) { index, item in
                                    HStack {
                                        Text(item.name)
                                            .font(.body)
                                        Spacer()
                                        Text(item.price, format: .currency(code: "USD"))
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            
                            let total = parsedItems.reduce(0) { $0 + $1.price }
                            Text("Total: \(total, format: .currency(code: "USD"))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.top)
                            
                            Button(action: saveReceipt) {
                                Text("Save Receipt")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBlue))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }
            }
        }
    }
    
    private func loadSampleReceipt() {
        if let image = UIImage(named: "sample-receipt") {
            selectedImage = image
            receiptName = "Sample Grocery Receipt"
            payerName = "Sample User"
        }
    }
    
    private func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        
        Task {
            do {
                let rawText = await OCRService.performOCR(on: image)
                let parsed = ReceiptParser.parse(rawText: rawText)
                
                await MainActor.run {
                    parsedItems = parsed
                    showingParsedItems = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Handle error - you could show an alert here
                }
            }
        }
    }
    
    private func saveReceipt() {
        let newReceipt = Receipt(name: receiptName, payerName: payerName)
        
        for parsedItem in parsedItems {
            let item = Item(name: parsedItem.name, price: parsedItem.price)
            item.receipt = newReceipt
            newReceipt.items?.append(item)
        }
        
        modelContext.insert(newReceipt)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle save error
            print("Error saving receipt: \(error)")
        }
    }
}

#Preview {
    AddReceiptView()
        .modelContainer(for: [Receipt.self, Item.self])
}