import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedItems: [(name: String, price: Double)] = []
    @State private var expenseName = ""
    @State private var payerName = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var selectedPaymentMethod: PaymentMethod = .cash
    @State private var notes = ""
    @State private var showingParsedItems = false
    @State private var showingManualEntry = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingOCRTutorial = !UserDefaults.standard.bool(forKey: "hasSeenOCRTutorial")
    @State private var showingImagePicker = false
    @State private var showingCameraOptions = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Entry Method Selection
                    VStack(spacing: 16) {
                        Text("How would you like to add this expense?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        // OCR Tutorial Tip
                        if showingOCRTutorial {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("💡")
                                            .font(.title2)
                                        Text("Quick Tip: OCR Scanning")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    Text("Scan receipts with your camera for automatic item detection!")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("📸 Works best with clear, well-lit photos of itemized receipts")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: { 
                                            showingOCRTutorial = false
                                            UserDefaults.standard.set(true, forKey: "hasSeenOCRTutorial")
                                            showingCameraOptions = true 
                                        }) {
                                            Text("Try It Now")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }
                                        
                                        Button(action: { 
                                            showingOCRTutorial = false 
                                            UserDefaults.standard.set(true, forKey: "hasSeenOCRTutorial")
                                        }) {
                                            Text("Maybe Later")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                
                                Spacer()
                                
                                Button(action: { showingOCRTutorial = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.title3)
                                        .onTapGesture {
                                            UserDefaults.standard.set(true, forKey: "hasSeenOCRTutorial")
                                        }
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: { showingManualEntry = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 30))
                                    Text("Manual Entry")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: { showingCameraOptions = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30))
                                    Text("Scan Receipt")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: loadSampleReceipt) {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 30))
                                    Text("Try Sample")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Image Preview
                    if let selectedImage = selectedImage {
                        VStack(spacing: 12) {
                            Text("Receipt Image")
                                .font(.headline)
                            
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        }
                    }
                    
                    // Expense Details Input
                    if selectedImage != nil || showingManualEntry {
                        VStack(spacing: 16) {
                            Text("Expense Details")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                TextField("Expense name (e.g., Dinner at Italian Restaurant)", text: $expenseName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                TextField("Who paid for this?", text: $payerName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                // Category Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Category", selection: $selectedCategory) {
                                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                            HStack {
                                                Image(systemName: category.icon)
                                                Text(category.rawValue)
                                            }
                                            .tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                // Payment Method Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Payment Method")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                                            HStack {
                                                Image(systemName: method.icon)
                                                Text(method.rawValue)
                                            }
                                            .tag(method)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                TextField("Notes (optional)", text: $notes, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(2...4)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 2)
                    }
                    
                    // Process/Continue Button
                    if (selectedImage != nil || showingManualEntry) && !expenseName.isEmpty && !payerName.isEmpty {
                        if selectedImage != nil {
                            Button(action: processImage) {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text(isProcessing ? "Processing Receipt..." : "Scan Receipt Items")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isProcessing ? Color(.systemGray) : Color(.systemGreen))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                        } else {
                            Button(action: { showingParsedItems = true; parsedItems = [] }) {
                                Text("Continue to Add Items")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGreen))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Parsed/Manual Items Review
                    if showingParsedItems {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Expense Items")
                                    .font(.headline)
                                Spacer()
                                Button(action: addNewItem) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if parsedItems.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No items found in receipt")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("This is normal when scanning receipts without clear item details. You can add items manually.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: addNewItem) {
                                        Label("Add Item Manually", systemImage: "plus")
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(parsedItems.enumerated()), id: \.offset) { index, item in
                                        EditableItemRow(
                                            item: item,
                                            onUpdate: { updatedItem in
                                                parsedItems[index] = updatedItem
                                            },
                                            onDelete: {
                                                parsedItems.remove(at: index)
                                            }
                                        )
                                    }
                                }
                            }
                            
                            if !parsedItems.isEmpty {
                                let total = parsedItems.reduce(0) { $0 + $1.price }
                                HStack {
                                    Text("Total:")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(total, format: .currency(code: "USD"))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                Button(action: saveExpense) {
                                    Text("Save Expense")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemBlue))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                Button(action: saveExpenseWithoutItems) {
                                    Text("Save Expense Without Items")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemBlue))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 3)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Expense")
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
                            showingManualEntry = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Select Image Source", isPresented: $showingCameraOptions, titleVisibility: .visible) {
            Button("Camera") {
                showingImagePicker = true
            }
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Photo Library")
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, showingManualEntry: $showingManualEntry)
        }
    }
    
    private func addNewItem() {
        parsedItems.append((name: "", price: 0.0))
    }
    
    private func processImage() {
        guard let selectedImage = selectedImage else { return }
        
        isProcessing = true
        showingError = false
        
        Task {
            do {
                let ocrService = OCRService()
                let recognizedText = try await ocrService.recognizeText(from: selectedImage)
                
                let parser = ReceiptParser()
                let items = parser.parseItems(from: recognizedText)
                
                await MainActor.run {
                    if items.isEmpty {
                        parsedItems = []
                        errorMessage = "No items found in the receipt. This is normal for receipts without clear item details. You can add items manually."
                        showingError = true
                    } else {
                        parsedItems = items
                    }
                    showingParsedItems = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error processing receipt: \(error.localizedDescription)"
                    showingError = true
                    isProcessing = false
                    showingParsedItems = true
                    parsedItems = []
                }
            }
        }
    }
    
    private func loadSampleReceipt() {
        parsedItems = [
            (name: "Organic Apples", price: 4.99),
            (name: "Whole Grain Bread", price: 3.49),
            (name: "Free Range Eggs", price: 5.99),
            (name: "Greek Yogurt", price: 6.49),
            (name: "Olive Oil", price: 8.99)
        ]
        expenseName = "Sample Grocery Shopping"
        payerName = "Demo User"
        selectedCategory = .groceries
        selectedPaymentMethod = .creditCard
        notes = "This is a sample expense to demonstrate the app"
        showingParsedItems = true
        showingManualEntry = false
    }
    
    private func saveExpense() {
        let expense = Expense(
            name: expenseName,
            payerName: payerName,
            paymentMethod: selectedPaymentMethod,
            category: selectedCategory,
            notes: notes
        )
        
        modelContext.insert(expense)
        
        for itemData in parsedItems {
            let item = ExpenseItem(name: itemData.name, price: itemData.price, expense: expense)
            modelContext.insert(item)
            expense.items.append(item)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func saveExpenseWithoutItems() {
        let expense = Expense(
            name: expenseName,
            payerName: payerName,
            paymentMethod: selectedPaymentMethod,
            category: selectedCategory,
            notes: notes
        )
        
        modelContext.insert(expense)
        try? modelContext.save()
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var showingManualEntry: Bool
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.showingManualEntry = false
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct EditableItemRow: View {
    @State private var item: (name: String, price: Double)
    let onUpdate: ((name: String, price: Double)) -> Void
    let onDelete: () -> Void
    @State private var isEditing = true // Start in editing mode for new items
    @State private var priceText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isNewItem = true
    
    init(item: (name: String, price: Double), onUpdate: @escaping ((name: String, price: Double)) -> Void, onDelete: @escaping () -> Void) {
        self._item = State(initialValue: item)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        // Start with blank price for new items, formatted price for existing items
        if item.name.isEmpty && item.price == 0.0 {
            self._priceText = State(initialValue: "")
            self._isNewItem = State(initialValue: true)
        } else {
            self._priceText = State(initialValue: String(format: "%.2f", item.price))
            self._isNewItem = State(initialValue: false)
            self._isEditing = State(initialValue: false)
        }
    }
    
    var body: some View {
        HStack {
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Item name", text: $item.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                isNewItem = false
                            }
                        }
                    
                    HStack {
                        Text("$")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $priceText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onTapGesture {
                                // Clear the field when user first taps if it's a new item
                                if isNewItem && priceText == "0.00" {
                                    priceText = ""
                                }
                            }
                            .onChange(of: priceText) { _, newValue in
                                // Remove any existing dollar signs and format
                                let cleanValue = newValue.replacingOccurrences(of: "$", with: "")
                                    .replacingOccurrences(of: ",", with: "")
                                priceText = cleanValue
                                
                                // Mark as no longer new item once user starts typing
                                if !cleanValue.isEmpty {
                                    isNewItem = false
                                }
                            }
                            .onSubmit {
                                validateAndSave()
                            }
                    }
                }
                
                VStack(spacing: 4) {
                    Button("Save") {
                        validateAndSave()
                    }
                    .foregroundColor(.green)
                    .font(.caption)
                    
                    Button("Cancel") {
                        if isNewItem {
                            onDelete() // Delete if it's a new item and user cancels
                        } else {
                            priceText = String(format: "%.2f", item.price)
                            isEditing = false
                        }
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                    Text(item.price, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    priceText = String(format: "%.2f", item.price)
                    isEditing = true
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .alert("Invalid Price", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateAndSave() {
        // Validate item name
        let cleanName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            alertMessage = "Please enter an item name"
            showingAlert = true
            return
        }
        
        // Clear any whitespace and validate price
        let cleanText = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty {
            alertMessage = "Please enter a price"
            showingAlert = true
            return
        }
        
        guard let price = Double(cleanText), price >= 0 else {
            alertMessage = "Please enter a valid positive number"
            showingAlert = true
            return
        }
        
        // Update the item with validated data
        item.name = cleanName
        item.price = price
        isNewItem = false
        onUpdate(item)
        isEditing = false
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, ExpenseItem.self])
}
