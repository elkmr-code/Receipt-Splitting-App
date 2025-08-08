import SwiftUI

// MARK: - Pre-Scan Helper Modal
struct PreScanHelperView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenScanHelp") private var hasSeenScanHelp: Bool = false
    
    @State private var selectedTab: ScanHelpTab = .scanCode
    
    enum ScanHelpTab: String, CaseIterable {
        case scanCode = "Scan Code"
        case scanReceipt = "Scan Receipt"
        
        var icon: String {
            switch self {
            case .scanCode: return "qrcode"
            case .scanReceipt: return "doc.text.viewfinder"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selection
                Picker("Scan Type", selection: $selectedTab) {
                    ForEach(ScanHelpTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == .scanCode {
                            scanCodeHelpContent
                        } else {
                            scanReceiptHelpContent
                        }
                    }
                    .padding()
                }
                
                // Don't show again option
                VStack(spacing: 16) {
                    Toggle("Don't show this again", isOn: $hasSeenScanHelp)
                        .font(.subheadline)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Got It!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Scanning Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var scanCodeHelpContent: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Scanning QR Codes & Barcodes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Get expense data instantly from QR codes or barcodes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 16) {
                tipRow(
                    icon: "camera.viewfinder",
                    title: "Perfect Positioning",
                    description: "Hold your device 6-12 inches from the code"
                )
                
                tipRow(
                    icon: "lightbulb.fill",
                    title: "Good Lighting",
                    description: "Use adequate lighting - avoid shadows and glare"
                )
                
                tipRow(
                    icon: "hand.raised.fill",
                    title: "Keep Steady",
                    description: "Hold still for a moment to let the camera focus"
                )
                
                tipRow(
                    icon: "checkmark.circle.fill",
                    title: "Supported Formats",
                    description: "Works with QR codes, barcodes, and transaction IDs"
                )
            }
            .padding(.vertical)
            
            // Example
            exampleSection(
                title: "QR Code Example",
                description: "Restaurant receipts and bills often have QR codes with itemized data",
                imageName: "qrcode"
            )
        }
    }
    
    private var scanReceiptHelpContent: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Scanning Receipts with OCR")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Extract items and prices automatically from receipt photos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 16) {
                tipRow(
                    icon: "doc.fill",
                    title: "Clear Text",
                    description: "Ensure all text is readable and not blurred"
                )
                
                tipRow(
                    icon: "rectangle.portrait",
                    title: "Full Receipt",
                    description: "Capture the entire receipt including items and prices"
                )
                
                tipRow(
                    icon: "sun.max.fill",
                    title: "Even Lighting",
                    description: "Avoid shadows, reflections, and low-light conditions"
                )
                
                tipRow(
                    icon: "crop",
                    title: "Crop Properly",
                    description: "Focus on the itemized section of the receipt"
                )
            }
            .padding(.vertical)
            
            // Best Practices
            VStack(alignment: .leading, spacing: 12) {
                Text("Best Results With:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    practiceRow("✅", "Grocery store receipts")
                    practiceRow("✅", "Restaurant itemized bills")
                    practiceRow("✅", "Retail shopping receipts")
                    practiceRow("❌", "Handwritten notes")
                    practiceRow("❌", "Faded or thermal receipts")
                    practiceRow("❌", "Crumpled receipts")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func practiceRow(_ icon: String, _ text: String) -> some View {
        HStack {
            Text(icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func exampleSection(title: String, description: String, imageName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 120)
                .overlay(
                    Image(systemName: imageName)
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Extension for UserDefaults
extension UserDefaults {
    static func shouldShowScanHelp() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasSeenScanHelp")
    }
}

#Preview {
    PreScanHelperView()
}