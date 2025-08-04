import SwiftUI
import SwiftData
import PhotosUI
import Vision

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var roommates: [Roommate]
    
    @StateObject private var ocrService = OCRService()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var isScanning = false
    @State private var ocrText = ""
    @State private var parsedItems: [ParsedItem] = []
    @State private var splitItems: [Item] = []
    @State private var showingPreview = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if receiptImage == nil {
                        inputOptionsSection
                    } else {
                        imagePreviewSection
                    }
                    
                    if !ocrText.isEmpty {
                        ocrResultsSection
                    }
                    
                    if !parsedItems.isEmpty {
                        parsedItemsSection
                    }
                    
                    if !splitItems.isEmpty {
                        splitPreviewSection
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(splitItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                loadSelectedPhoto(newPhoto)
            }
            .overlay {
                if isScanning {
                    scanningOverlay
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "receipt.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Add Grocery Receipt")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose how you'd like to add your receipt")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var inputOptionsSection: some View {
        VStack(spacing: 16) {
            // Scan Receipt Button (simulated)
            Button {
                simulateScan()
            } label: {
                Label("Scan Receipt", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            // Use Sample Receipt Button
            Button {
                useSampleReceipt()
            } label: {
                Label("Use Sample Receipt", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Photo Picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Import from Photos", systemImage: "photo.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt Image")
                .font(.headline)
            
            if let image = receiptImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
            
            HStack {
                Button("Remove Image") {
                    receiptImage = nil
                    ocrText = ""
                    parsedItems = []
                    splitItems = []
                }
                .foregroundColor(.red)
                
                Spacer()
                
                if !ocrText.isEmpty {
                    Button("Process Again") {
                        processCurrentImage()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var ocrResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OCR Results")
                .font(.headline)
            
            ScrollView {
                Text(ocrText)
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 150)
            
            Button("Parse Items") {
                parseItems()
            }
            .buttonStyle(.bordered)
            .disabled(ocrText.isEmpty)
        }
    }
    
    private var parsedItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parsed Items (\(parsedItems.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Split Items") {
                    splitParsedItems()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedItems.isEmpty)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(parsedItems) { item in
                    ParsedItemRow(item: item)
                }
            }
        }
    }
    
    private var splitPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Split Preview")
                .font(.headline)
            
            ForEach(roommates, id: \.id) { roommate in
                RoommateItemsPreview(roommate: roommate, items: splitItems)
            }
            
            HStack {
                Text("Total: \(splitItems.reduce(0) { $0 + $1.totalPrice }, format: .currency(code: "USD"))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.top)
        }
    }
    
    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
                
                Text("Scanning Receipt...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Hold your device steady")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    // MARK: - Actions
    
    private func simulateScan() {
        isScanning = true
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                isScanning = false
                useSampleReceipt()
            }
        }
    }
    
    private func useSampleReceipt() {
        // Create a simple sample receipt image (white background with text)
        let image = createSampleReceiptImage()
        receiptImage = image
        
        Task {
            do {
                let text = try await ocrService.simulateOCRProcessing()
                await MainActor.run {
                    ocrText = text
                    parseItems()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process sample receipt: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func loadSelectedPhoto(_ photoItem: PhotosPickerItem?) {
        guard let photoItem = photoItem else { return }
        
        Task {
            do {
                if let data = try await photoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        receiptImage = image
                        processCurrentImage()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func processCurrentImage() {
        guard let image = receiptImage else { return }
        
        Task {
            do {
                let text = try await ocrService.performOCR(on: image)
                await MainActor.run {
                    ocrText = text
                    parseItems()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "OCR failed: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func parseItems() {
        let (items, _) = ReceiptParser.parseReceiptTextEnhanced(ocrText)
        parsedItems = items
        
        if items.isEmpty {
            errorMessage = "No items found in the receipt. Try a different image or add items manually."
            showingError = true
        } else {
            splitParsedItems()
        }
    }
    
    private func splitParsedItems() {
        guard !roommates.isEmpty else {
            errorMessage = "No roommates found. Please add roommates first."
            showingError = true
            return
        }
        
        splitItems = SplittingService.splitItems(
            parsedItems,
            among: Array(roommates),
            method: .roundRobin,
            modelContext: modelContext
        )
    }
    
    private func saveReceipt() {
        let receipt = Receipt(rawText: ocrText)
        receipt.items = splitItems
        
        for item in splitItems {
            item.receipt = receipt
            modelContext.insert(item)
        }
        
        modelContext.insert(receipt)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save receipt: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func createSampleReceiptImage() -> UIImage {
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text to simulate a receipt
            let text = "SAMPLE RECEIPT\n\nBananas $3.99\nMilk $4.59\nBread $4.29"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            let rect = CGRect(x: 20, y: 50, width: 260, height: 300)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}

struct ParsedItemRow: View {
    let item: ParsedItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if item.quantity > 1 {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(item.price * Double(item.quantity), format: .currency(code: "USD"))
                .font(.body)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RoommateItemsPreview: View {
    let roommate: Roommate
    let items: [Item]
    
    private var roommateItems: [Item] {
        items.filter { $0.assignedTo?.id == roommate.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(roommate.displayColor)
                    .frame(width: 16, height: 16)
                
                Text(roommate.name)
                    .font(.headline)
                
                Spacer()
                
                Text(roommateItems.reduce(0) { $0 + $1.totalPrice }, format: .currency(code: "USD"))
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(roommateItems, id: \.id) { item in
                    HStack {
                        Text("• \(item.name)")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(item.totalPrice, format: .currency(code: "USD"))
                            .font(.caption)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding()
        .background(roommate.displayColor.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    AddReceiptView()
        .modelContainer(for: [Receipt.self, Item.self, Roommate.self])
}
