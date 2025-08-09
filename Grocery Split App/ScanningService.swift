import Foundation
import SwiftUI
import Vision
import UIKit

// MARK: - Scanning Service
@MainActor
class ScanningService: ObservableObject {
    @Published var isScanning = false
    @Published var scanResult: ScanResult?
    @Published var error: String?
    

    
    // MARK: - Barcode/QR Scanning
    func scanCode(from scannedData: String) async throws -> ScanResult {
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
        
        // Parse the scanned data - could be QR JSON or simple transaction ID
        let result: ScanResult
        
        // Try to parse as JSON first (structured QR code)
        if let jsonData = scannedData.data(using: .utf8),
           let qrData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let receiptId = qrData["receiptId"] as? String {
            
            // Structured QR code with JSON data
            let items = parseQRItems(from: qrData)
            result = ScanResult(
                type: .barcode,
                sourceId: receiptId,
                items: items,
                originalText: scannedData
            )
            
        } else if isValidTransactionId(scannedData) {
            // Simple transaction ID - treat as receipt identifier
            result = ScanResult(
                type: .barcode,
                sourceId: scannedData.trimmingCharacters(in: .whitespacesAndNewlines),
                items: [], // Items will need to be entered manually or retrieved from external service
                originalText: scannedData
            )
            
        } else {
            // Unrecognized format
            throw ScanningError.noReceiptFound
        }
        
        await MainActor.run {
            self.scanResult = result
        }
        
        return result
    }
    
    // MARK: - OCR Scanning
    func performOCR(on image: UIImage) async throws -> ScanResult {
        await MainActor.run {
            isScanning = true
            error = nil
            scanResult = nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                Task { @MainActor in
                    self.isScanning = false
                    
                    if let error = error {
                        self.error = "OCR failed: \(error.localizedDescription)"
                        continuation.resume(throwing: ScanningError.ocrFailed)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        self.error = "No text detected in image"
                        continuation.resume(throwing: ScanningError.noTextFound)
                        return
                    }
                    
                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")
                    
                    if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.error = "No readable text found"
                        continuation.resume(throwing: ScanningError.noTextFound)
                        return
                    }
                    
                    let items = self.parseReceiptText(recognizedText)
                    
                    if items.isEmpty {
                        self.error = "No valid items found in text"
                        continuation.resume(throwing: ScanningError.noItemsFound)
                        return
                    }
                    
                    let result = ScanResult(
                        type: .ocr,
                        sourceId: "OCR_\(Date().timeIntervalSince1970)",
                        items: items,
                        originalText: recognizedText
                    )
                    
                    self.scanResult = result
                    continuation.resume(returning: result)
                }
            }
            
            // Configure OCR for better receipt recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            guard let cgImage = image.cgImage else {
                Task { @MainActor in
                    self.isScanning = false
                    self.error = "Invalid image format"
                }
                continuation.resume(throwing: ScanningError.invalidImage)
                return
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self.isScanning = false
                    self.error = "OCR processing failed: \(error.localizedDescription)"
                }
                continuation.resume(throwing: ScanningError.ocrFailed)
            }
        }
    }
    
    // MARK: - Helper Methods for QR Processing
    private func parseQRItems(from qrData: [String: Any]) -> [ParsedItem] {
        var items: [ParsedItem] = []
        
        // Look for items array in QR JSON
        if let itemsArray = qrData["items"] as? [[String: Any]] {
            for itemData in itemsArray {
                if let name = itemData["name"] as? String,
                   let price = itemData["price"] as? Double {
                    items.append(ParsedItem(name: name, price: price))
                }
            }
        }
        
        return items
    }
    
    private func isValidTransactionId(_ data: String) -> Bool {
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation for transaction IDs
        // Could be numeric, alphanumeric, or specific patterns
        let transactionIdPattern = try! NSRegularExpression(
            pattern: #"^[A-Z0-9]{3,20}$"#,
            options: []
        )
        
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        return transactionIdPattern.firstMatch(in: trimmed, options: [], range: range) != nil
    }
        let fallbackItems = [
            ParsedItem(name: "Coffee", price: 4.50),
            ParsedItem(name: "Pastry", price: 3.25)
        ]
        return ScanResult(
            type: .ocr,
            sourceId: "OCR_Fallback_\(Date().timeIntervalSince1970)",
            items: fallbackItems,
            originalText: "Coffee 4.50\nPastry 3.25\nTotal 7.75"
        )
    }
    
    // MARK: - Parsing Logic
    private func parseReceiptText(_ text: String) -> [ParsedItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [ParsedItem] = []
        
        // Regex to match item lines: "Name Price" format
        let regex = try! NSRegularExpression(
            pattern: #"^([A-Za-z\s\-]+)\s+(\d+\.\d{2})$"#,
            options: []
        )
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and lines with keywords to ignore
            if trimmedLine.isEmpty || shouldIgnoreLine(trimmedLine) {
                continue
            }
            
            let range = NSRange(location: 0, length: trimmedLine.utf16.count)
            
            if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                let nameRange = Range(match.range(at: 1), in: trimmedLine)!
                let priceRange = Range(match.range(at: 2), in: trimmedLine)!
                
                let name = String(trimmedLine[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let priceString = String(trimmedLine[priceRange])
                
                if let price = Double(priceString), !name.isEmpty {
                    items.append(ParsedItem(name: name, price: price))
                }
            } else {
                // Fallback parsing for lines that don't match regex
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 2,
                   let priceString = components.last,
                   let price = Double(priceString),
                   price > 0 {
                    
                    let nameComponents = Array(components.dropLast())
                    let itemName = nameComponents.joined(separator: " ")
                    
                    if !itemName.isEmpty && !shouldIgnoreLine(itemName) {
                        items.append(ParsedItem(name: itemName, price: price))
                    }
                }
            }
        }
        
        return items
    }
    
    private func shouldIgnoreLine(_ line: String) -> Bool {
        let lowercaseLine = line.lowercased()
        let ignoreKeywords = ["total", "subtotal", "tax", "discount", "change", "cash", "card", "receipt", "thank you", "store", "date", "time"]
        
        return ignoreKeywords.contains { keyword in
            lowercaseLine.contains(keyword)
        }
}

// MARK: - Data Models
// Note: Using ParsedItem from ReceiptParser.swift

struct ScanResult: Identifiable {
    var id: String { sourceId }
    let type: ScanType
    let sourceId: String
    let items: [ParsedItem]
    let originalText: String
    
    var total: Double {
        return items.reduce(0) { $0 + $1.price }
    }
}

enum ScanType {
    case barcode
    case ocr
    
    var displayName: String {
        switch self {
        case .barcode: return "Barcode/QR"
        case .ocr: return "OCR Scan"
        }
    }
    
    var icon: String {
        switch self {
        case .barcode: return "qrcode"
        case .ocr: return "doc.text.viewfinder"
        }
    }
}

enum ScanningError: LocalizedError {
    case noReceiptFound
    case ocrFailed
    case invalidImage
    case noTextFound
    case invalidImageType
    case noItemsFound
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .noReceiptFound:
            return "No receipt found for this code"
        case .ocrFailed:
            return "Failed to read text from image"
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "Sorry, can't scan this image. No text was detected. Please try a clearer image of a receipt or barcode."
        case .invalidImageType:
            return "Sorry, can't scan this image. This doesn't appear to be a receipt or barcode. Please select an image with purchase details."
        case .noItemsFound:
            return "Sorry, can't scan this image. No valid items with prices were found. Please try a different receipt image."
        case .scanningFailed:
            return "Scanning failed. Please try again or use a different method."
        }
    }
}

// MARK: - Image Picker
// Note: Using ImagePicker from AddReceiptView.swift