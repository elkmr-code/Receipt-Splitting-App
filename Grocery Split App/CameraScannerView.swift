import SwiftUI
import AVFoundation

// MARK: - Camera Scanner View
struct CameraScannerView: View {
    let scanType: CameraScanType
    let onComplete: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var scanProgress: Double = 0.0
    @State private var showingResult = false
    @State private var scanningStep = 0
    @State private var animationOffset: CGFloat = -200
    
    // Mock scanning steps
    private let scanningSteps = [
        "Initializing camera...",
        "Focusing on target...",
        "Detecting patterns...",
        "Processing data...",
        "Parsing information..."
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera viewfinder background
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    // Mock camera viewfinder
                    ZStack {
                        // Camera preview simulation
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 400)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        // Scanning overlay
                        if isScanning {
                            VStack {
                                // Animated scanning line
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(height: 3)
                                    .offset(y: animationOffset)
                                    .opacity(0.8)
                                
                                Spacer()
                            }
                            .frame(height: 400)
                            .clipped()
                        }
                        
                        // Target frame
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                isScanning ? Color.green : Color.white,
                                lineWidth: 3
                            )
                            .frame(width: 280, height: 180)
                            .overlay(
                                VStack {
                                    HStack {
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                        Spacer()
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                    }
                                    Spacer()
                                    HStack {
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                        Spacer()
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                    }
                                }
                                .padding(8)
                            )
                        
                        // Instructions
                        if !isScanning && !showingResult {
                            VStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: scanType.icon)
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                    
                                    Text("Position \(scanType.displayName.lowercased()) in the frame")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Tap to start scanning")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                                Spacer()
                            }
                        }
                    }
                    .onTapGesture {
                        if !isScanning && !showingResult {
                            startScanning()
                        }
                    }
                    
                    Spacer()
                    
                    // Scanning status
                    VStack(spacing: 16) {
                        if isScanning {
                            VStack(spacing: 12) {
                                ProgressView(value: scanProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                    .frame(height: 8)
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                                
                                if scanningStep < scanningSteps.count {
                                    Text(scanningSteps[scanningStep])
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .animation(.easeInOut, value: scanningStep)
                                }
                                
                                Text("\(Int(scanProgress * 100))%")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        } else if !showingResult {
                            Button(action: startScanning) {
                                HStack {
                                    Image(systemName: "camera")
                                    Text("Start Scanning")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        if showingResult {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                
                                Text("Scan Complete!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Processing results...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Camera Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Simulate camera initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Camera is "ready"
            }
        }
    }
    
    private func startScanning() {
        isScanning = true
        scanProgress = 0.0
        scanningStep = 0
        
        // Animate scanning line
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
            animationOffset = 200
        }
        
        // Simulate scanning process
        let timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            if scanningStep < scanningSteps.count - 1 {
                scanningStep += 1
                scanProgress = Double(scanningStep) / Double(scanningSteps.count - 1)
            } else {
                timer.invalidate()
                completeScanning()
            }
        }
    }
    
    private func completeScanning() {
        isScanning = false
        showingResult = true
        
        // Stop scanning line animation
        animationOffset = -200
        
        // Generate mock result after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockReceiptText = getMockReceipt()
            let items = parseReceiptText(mockReceiptText)
            
            let result = ScanResult(
                type: scanType == .barcode ? .barcode : .ocr,
                sourceId: "Camera_\(Date().timeIntervalSince1970)",
                items: items.isEmpty ? [ParsedItem(name: "Sample Item", price: 5.99)] : items,
                originalText: mockReceiptText
            )
            
            // Call completion handler first
            onComplete(result)
            
            // Then dismiss immediately
            dismiss()
        }
    }
    
    private func getMockReceipt() -> String {
        if scanType == .barcode {
            return """
Starbucks Coffee 4.95
Blueberry Muffin 3.50
Orange Juice 2.75
Total 11.20
"""
        } else {
            return """
Whole Foods Market
Organic Bananas 3.99
Greek Yogurt 5.49
Sourdough Bread 4.25
Avocados 2.99
Total 16.72
"""
        }
    }
    
    private func parseReceiptText(_ text: String) -> [ParsedItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [ParsedItem] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and total lines
            if trimmedLine.isEmpty || 
               trimmedLine.lowercased().contains("total") ||
               trimmedLine.lowercased().contains("market") {
                continue
            }
            
            // Parse line format: "Item Name Price"
            let components = trimmedLine.components(separatedBy: " ")
            
            if components.count >= 2,
               let priceString = components.last,
               let price = Double(priceString),
               price > 0 {
                
                let nameComponents = Array(components.dropLast())
                let itemName = nameComponents.joined(separator: " ")
                
                if !itemName.isEmpty {
                    items.append(ParsedItem(name: itemName, price: price))
                }
            }
        }
        
        return items
    }
}

// MARK: - Camera Scan Type
enum CameraScanType {
    case barcode
    case receipt
    
    var displayName: String {
        switch self {
        case .barcode: return "Barcode/QR Code"
        case .receipt: return "Receipt"
        }
    }
    
    var icon: String {
        switch self {
        case .barcode: return "qrcode"
        case .receipt: return "doc.text"
        }
    }
}

#Preview {
    CameraScannerView(scanType: .barcode) { _ in }
}