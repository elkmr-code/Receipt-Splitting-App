import Foundation
import SwiftUI
import AVFoundation
import Vision

// MARK: - Production Barcode Service
class BarcodeService: ObservableObject {
    @Published var isScanning = false
    @Published var scanResult: String?
    @Published var error: String?
    
    // Production barcode scanning using real camera/image processing
    func scanBarcode(from image: UIImage) async throws -> String {
        await MainActor.run {
            isScanning = true
            error = nil
            scanResult = nil
        }
        
        defer {
            Task { @MainActor in
                isScanning = false
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let resumeLock = NSLock()
            var didResume = false
            func resumeOnce(_ action: () -> Void) {
                resumeLock.lock(); defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                action()
            }
            guard let cgImage = image.cgImage ?? BarcodeService.rasterizeToCGImage(image) else {
                continuation.resume(throwing: BarcodeServiceError.invalidImage)
                return
            }
            
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    resumeOnce { continuation.resume(throwing: error) }
                    return
                }
                guard let observations = request.results as? [VNBarcodeObservation],
                      let firstBarcode = observations.first,
                      let payloadString = firstBarcode.payloadStringValue else {
                    resumeOnce { continuation.resume(throwing: BarcodeServiceError.noBarcodeFound) }
                    return
                }
                Task { @MainActor in
                    self.scanResult = payloadString
                }
                resumeOnce { continuation.resume(returning: payloadString) }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                // Some Vision failures can also invoke the request callback; protect against double-resume
                resumeOnce { continuation.resume(throwing: error) }
            }
        }
    }

    // Fallback for images that don't have a CGImage backing (e.g., PDFs, vector assets)
    private static func rasterizeToCGImage(_ image: UIImage) -> CGImage? {
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
    
    // Parse barcode payload for receipt information
    func parseReceiptData(from payload: String) -> ReceiptData? {
        // Try to parse as JSON first (structured QR codes)
        if let jsonData = payload.data(using: .utf8),
           let qrData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            return parseQRCodeData(qrData)
        }
        
        // Otherwise treat as simple transaction ID
        if isValidTransactionId(payload) {
            return ReceiptData(transactionId: payload, items: [], vendorName: nil)
        }
        
        return nil
    }
    
    private func parseQRCodeData(_ qrData: [String: Any]) -> ReceiptData? {
        guard let transactionId = qrData["transactionId"] as? String ?? qrData["receiptId"] as? String else {
            return nil
        }
        
        var items: [ReceiptItem] = []
        if let itemsArray = qrData["items"] as? [[String: Any]] {
            for itemData in itemsArray {
                if let name = itemData["name"] as? String,
                   let price = itemData["price"] as? Double {
                    items.append(ReceiptItem(name: name, price: price))
                }
            }
        }
        
        let vendorName = qrData["vendor"] as? String ?? qrData["store"] as? String
        
        return ReceiptData(transactionId: transactionId, items: items, vendorName: vendorName)
    }
    
    private func isValidTransactionId(_ payload: String) -> Bool {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation for transaction IDs
        let transactionIdPattern = try! NSRegularExpression(
            pattern: #"^[A-Z0-9]{3,20}$"#,
            options: []
        )
        
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        return transactionIdPattern.firstMatch(in: trimmed, options: [], range: range) != nil
    }
}

// MARK: - Supporting Data Models
struct ReceiptData {
    let transactionId: String
    let items: [ReceiptItem]
    let vendorName: String?
}

struct ReceiptItem {
    let name: String
    let price: Double
}

enum BarcodeServiceError: LocalizedError {
    case invalidImage
    case noBarcodeFound
    case invalidBarcodeData
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noBarcodeFound:
            return "No barcode or QR code found in image"
        case .invalidBarcodeData:
            return "Barcode data could not be parsed"
        }
    }
}

// MARK: - Production Receipt Parser
struct ProductionReceiptParser {
    
    func parseItems(from receiptData: ReceiptData) -> [ParsedItem] {
        return receiptData.items.map { item in
            ParsedItem(name: item.name, price: item.price)
        }
    }
    
    func parseItemsFromText(_ text: String) -> [ParsedItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [ParsedItem] = []
        
        // Enhanced parsing with multiple regex patterns for different receipt formats
        let patterns = [
            // Pattern 1: "Item Name $XX.XX" or "Item Name XX.XX"
            #"^(.+?)\s+\$?(\d+\.\d{2})$"#,
            // Pattern 2: "Item Name - $XX.XX" 
            #"^(.+?)\s*-\s*\$?(\d+\.\d{2})$"#,
            // Pattern 3: "XX.XX Item Name"
            #"^(\d+\.\d{2})\s+(.+)$"#
        ]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and lines with common receipt keywords
            if shouldIgnoreLine(trimmedLine) {
                continue
            }
            
            // Try each pattern
            for pattern in patterns {
                if let item = parseLineWithPattern(trimmedLine, pattern: pattern) {
                    items.append(item)
                    break
                }
            }
        }
        
        return items
    }
    
    private func parseLineWithPattern(_ line: String, pattern: String) -> ParsedItem? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: line.utf16.count)
        
        if let match = regex.firstMatch(in: line, options: [], range: range) {
            let nameRange = Range(match.range(at: 1), in: line)
            let priceRange = Range(match.range(at: 2), in: line)
            
            if let nameRange = nameRange, let priceRange = priceRange {
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let priceString = String(line[priceRange])
                
                if let price = Double(priceString), !name.isEmpty, price > 0 {
                    return ParsedItem(name: name, price: price)
                }
            }
        }
        
        return nil
    }
    
    private func shouldIgnoreLine(_ line: String) -> Bool {
        if line.isEmpty { return true }
        
        let lowercaseLine = line.lowercased()
        let ignoreKeywords = [
            "total", "subtotal", "tax", "discount", "change", "cash", "card", 
            "receipt", "thank you", "store", "date", "time", "phone", "address",
            "welcome", "cashier", "customer", "transaction"
        ]
        
        return ignoreKeywords.contains { keyword in
            lowercaseLine.contains(keyword)
        }
    }
}

