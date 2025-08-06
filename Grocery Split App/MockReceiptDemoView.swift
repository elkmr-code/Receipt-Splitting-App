import SwiftUI

// MARK: - Demo View showing how to integrate MockReceiptScannerView
struct MockReceiptDemoView: View {
    @State private var showingScanner = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Receipt Scanner Demo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("This demonstrates the mock barcode scanning functionality")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Open Receipt Scanner") {
                    showingScanner = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Demo")
            .sheet(isPresented: $showingScanner) {
                MockReceiptScannerView()
            }
        }
    }
}

// MARK: - Integration Example for AddReceiptView
extension AddExpenseView {
    // You can add this button to your existing AddReceiptView
    private var mockScannerButton: some View {
        Button(action: { 
            // Add @State private var showingMockScanner = false to AddReceiptView
            // showingMockScanner = true 
        }) {
            VStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 30))
                Text("Mock Scanner")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        // Then add: .sheet(isPresented: $showingMockScanner) { MockReceiptScannerView() }
    }
}

#Preview {
    MockReceiptDemoView()
}