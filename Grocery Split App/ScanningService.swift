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
    
    // Mock barcode/QR code database
    private let mockReceipts: [String: String] = [
        "TXN12345": """
        Milk 2.50
        Bread 1.20
        Apples 3.00
        Total 6.70
        """,
        "TXN67890": """
        Coca-Cola 2.50
        Chips 3.00
        Bananas 1.20
        Ice Cream 4.00
        Total 10.70
        """,
        "QR001": """
        Coffee 4.50
        Muffin 3.25
        Orange Juice 2.75
        Total 10.50
        """
    ]
    
    // Fallback receipt for OCR demo when image fails
    private let fallbackReceipt = """
    Coca-Cola 2.50
    Chips 3.00
    Apples 1.20
    Sandwich 5.50
    Water 1.00
    Total 12.20
    """
    
    // MARK: - Barcode/QR Scanning
    func scanCode() async throws -> ScanResult {
        await MainActor.run {
            isScanning = true
            error = nil
            scanResult = nil
        }
        
        // Simulate scanning delay
        try await Task.sleep(for: .seconds(2))
        
        // Use hardcoded barcode ID
        let barcodeID = "TXN12345"
        
        await MainActor.run {
            isScanning = false
        }
        
        if let receiptText = mockReceipts[barcodeID] {
            let items = parseReceiptText(receiptText)
            let result = ScanResult(
                type: .barcode,
                sourceId: barcodeID,
                items: items,
                originalText: receiptText
            )
            
            await MainActor.run {
                self.scanResult = result
            }
            
            return result
        } else {
            throw ScanningError.noReceiptFound
        }
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
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: ScanningError.ocrFailed)
                        return
                    }
                    
                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")
                    
                    let items: [ParsedItem]
                    let finalText: String
                    
                    // Check if image seems to contain receipt/barcode content
                    let isValidReceiptImage = self.validateReceiptImage(recognizedText)
                    
                    if recognizedText.isEmpty {
                        continuation.resume(throwing: ScanningError.noTextFound)
                        return
                    } else if !isValidReceiptImage {
                        continuation.resume(throwing: ScanningError.invalidImageType)
                        return
                    } else {
                        items = self.parseReceiptText(recognizedText)
                        finalText = recognizedText
                        
                        // If still no items found after parsing valid text
                        if items.isEmpty {
                            continuation.resume(throwing: ScanningError.noItemsFound)
                            return
                        }
                    }
                    
                    let result = ScanResult(
                        type: .ocr,
                        sourceId: "OCR_\(Date().timeIntervalSince1970)",
                        items: items,
                        originalText: finalText
                    )
                    
                    self.scanResult = result
                    continuation.resume(returning: result)
                }
            }
            
            // Configure OCR for better receipt recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self.isScanning = false
                }
                continuation.resume(throwing: error)
            }
        }
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
    
    private func validateReceiptImage(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        // Keywords that suggest this is a receipt or purchase-related document
        let receiptKeywords = [
            "total", "subtotal", "tax", "receipt", "purchase", "sale", "store", "shop", "market",
            "price", "cost", "$", "usd", "amount", "qty", "quantity", "item", "product",
            "visa", "mastercard", "cash", "card", "payment", "paid", "change", "tender",
            "walmart", "target", "costco", "safeway", "kroger", "publix", "whole foods",
            "starbucks", "mcdonald", "subway", "pizza", "restaurant", "cafe", "coffee"
        ]
        
        // Check if text contains currency symbols or numbers that look like prices
        let hasNumbers = text.range(of: #"\d+\.\d{2}"#, options: .regularExpression) != nil
        let hasCurrency = text.contains("$") || text.contains("USD") || text.contains("¢")
        
        // Check for receipt-like keywords
        let hasReceiptKeywords = receiptKeywords.contains { keyword in
            lowercaseText.contains(keyword)
        }
        
        // Must have either currency/numbers OR receipt keywords
        return hasNumbers || hasCurrency || hasReceiptKeywords
    }
}

// MARK: - Data Models
// Note: Using ParsedItem from ReceiptParser.swift

struct ScanResult {
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
        }
    }
}

// MARK: - Image Picker
// Note: Using ImagePicker from AddReceiptView.swift