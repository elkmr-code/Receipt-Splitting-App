import Foundation
import Vision

struct ParsedItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let price: Double
    let quantity: Int
    let confidence: Float // OCR confidence level
    
    init(name: String, price: Double, quantity: Int = 1, confidence: Float = 1.0) {
        self.name = name
        self.price = price
        self.quantity = quantity
        self.confidence = confidence
    }
    
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
    
    var totalPrice: Double {
        return price * Double(quantity)
    }
    
    var asTuple: (name: String, price: Double) {
        return (name: name, price: totalPrice)
    }
}

// MARK: - QR/Barcode Payload Structures
struct QRPayload: Codable {
    let id: String
    let items: [QRItem]?
    let total: Double?
    let timestamp: String?
    let location: String?
    
    struct QRItem: Codable {
        let name: String
        let price: Double
        let qty: Int?
        let category: String?
    }
}

// MARK: - Receipt Metadata
struct ReceiptMetadata {
    var storeName: String?
    var date: Date?
    var time: String?
    var address: String?
    var phoneNumber: String?
    var receiptNumber: String?
}

class ReceiptParser {
    
    // MARK: - Enhanced Currency Patterns
    private static let currencyPatterns = [
        // $12.99, $1,299.99
        #"\$\d{1,3}(?:,\d{3})*(?:\.\d{2})?"#,
        // 12.99, 1,299.99
        #"\d{1,3}(?:,\d{3})*\.\d{2}"#,
        // USD 12.99
        #"USD\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})?"#
    ]
    
    // MARK: - Enhanced Item Patterns
    private static let itemPatterns = [
        // Quantity patterns: "2x Apple $1.25", "3 × Banana $2.50"
        #"(\d+)\s*[x×]\s*(.+?)\s+(\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#,
        // Standard item: "Apple Juice  $3.99"
        #"^([A-Za-z][\w\s\-&',\.]+?)\s{2,}(\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})?)$"#,
        // Tab-separated: "Apple\t$3.99"
        #"^([A-Za-z][\w\s\-&',\.]+?)\t+(\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})?)$"#,
        // Dash-separated: "Apple Juice - $3.99"
        #"^([A-Za-z][\w\s\-&',\.]+?)\s*-\s*(\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})?)$"#,
        // Right-aligned price: "Apple Juice           3.99"
        #"^([A-Za-z][\w\s\-&',\.]{3,}?)\s{3,}(\d{1,3}(?:,\d{3})*\.\d{2})$"#
    ]
    
    // MARK: - Skip Patterns (enhanced)
    private static let skipPatterns = [
        // Store information
        #"(?i)(store|market|grocery|supermarket|walmart|target|costco|safeway)"#,
        // Contact/Address
        #"(?i)(address|phone|tel|email|www\.|\.com)"#,
        // Receipt metadata
        #"(?i)(cashier|register|receipt|invoice|transaction)"#,
        // Totals and calculations
        #"(?i)(total|subtotal|tax|discount|change|balance|due)"#,
        // Payment information
        #"(?i)(cash|credit|debit|visa|mastercard|amex|discover)"#,
        // Thank you messages
        #"(?i)(thank\s+you|thanks|have\s+a|come\s+again)"#,
        // Savings/Membership
        #"(?i)(member|savings|reward|point|loyalty)"#,
        // Date/Time patterns
        #"\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}"#,
        #"\d{1,2}:\d{2}\s*(?:AM|PM)?"#
    ]
    
    // MARK: - Legacy Compatibility Methods
    // Method that returns tuples for compatibility with AddReceiptView
    func parseItems(from text: String) -> [(name: String, price: Double)] {
        let result = ReceiptParser.parseReceiptTextEnhanced(text)
        return result.items.map { $0.asTuple }
    }
    
    static func parseReceiptText(_ text: String) -> [ParsedItem] {
        let result = parseReceiptTextEnhanced(text)
        return result.items
    }

    
    // MARK: - QR Code Processing
    static func processQRPayload(_ payload: String) -> (items: [ParsedItem], sourceId: String) {
        // Try to parse as JSON QR payload
        if let qrPayload = parseJSONPayload(payload) {
            let items = qrPayload.items?.compactMap { qrItem in
                ParsedItem(
                    name: qrItem.name,
                    price: qrItem.price,
                    quantity: qrItem.qty ?? 1,
                    confidence: 1.0
                )
            } ?? []
            
            return (items: items, sourceId: qrPayload.id)
        }
        
        // Treat as simple transaction ID
        return (items: [], sourceId: payload)
    }
    
    private static func parseJSONPayload(_ payload: String) -> QRPayload? {
        guard let data = payload.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(QRPayload.self, from: data)
        } catch {
            // Try parsing loose JSON format
            return parseLooseJSONFormat(payload)
        }
    }
    
    private static func parseLooseJSONFormat(_ payload: String) -> QRPayload? {
        // Handle common QR code variations like:
        // "id: TXN123, items: [{name: 'Coffee', price: 4.50}], total: 4.50"
        
        var components: [String: Any] = [:]
        
        // Extract ID
        if let idRange = payload.range(of: #"id\s*:\s*['""]?([^,'"\]]+)['""]?"#, options: .regularExpression) {
            let idMatch = String(payload[idRange])
            if let match = idMatch.firstMatch(of: #"id\s*:\s*['""]?([^,'"\]]+)['""]?"#) {
                components["id"] = String(match.1)
            }
        }
        
        // For now, return basic structure - could be enhanced further
        if let id = components["id"] as? String {
            return QRPayload(id: id, items: nil, total: nil, timestamp: nil, location: nil)
        }
        
        return nil
    }
    
    // MARK: - Enhanced Receipt Text Parsing
    static func parseReceiptTextEnhanced(_ text: String, confidence: Float = 0.8) -> (items: [ParsedItem], total: Double?, metadata: ReceiptMetadata) {
        let lines = preprocessText(text)
        var parsedItems: [ParsedItem] = []
        var detectedTotal: Double?
        var metadata = ReceiptMetadata()
        
        for line in lines {
            // Skip lines that match skip patterns
            if shouldSkipLine(line) {
                continue
            }
            
            // Check for total lines first
            if let total = extractTotal(from: line) {
                detectedTotal = total
                continue
            }
            
            // Extract store information
            extractMetadata(from: line, into: &metadata)
            
            // Try to parse as item
            if let item = parseLineItemEnhanced(line, confidence: confidence) {
                parsedItems.append(item)
            }
        }
        
        // Validate and clean up items
        parsedItems = validateAndCleanItems(parsedItems, detectedTotal: detectedTotal)
        
        return (items: parsedItems, total: detectedTotal, metadata: metadata)
    }
    
    private static func preprocessText(_ text: String) -> [String] {
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private static func parseLineItemEnhanced(_ line: String, confidence: Float) -> ParsedItem? {
        // Try each pattern in order of specificity
        for pattern in itemPatterns {
            if let item = tryParseWithPattern(line, pattern: pattern, confidence: confidence) {
                return item
            }
        }
        
        return nil
    }
    
    private static func tryParseWithPattern(_ line: String, pattern: String, confidence: Float) -> ParsedItem? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                return extractItemFromMatch(line: line, match: match, confidence: confidence)
            }
        } catch {
            // Pattern failed, continue to next
        }
        
        return nil
    }
    
    private static func extractItemFromMatch(line: String, match: NSTextCheckingResult, confidence: Float) -> ParsedItem? {
        let numGroups = match.numberOfRanges
        
        if numGroups >= 3 {
            // Quantity pattern match
            guard let qtyRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let priceRange = Range(match.range(at: 3), in: line) else { return nil }
            
            let qtyString = String(line[qtyRange])
            let name = cleanItemName(String(line[nameRange]))
            let priceString = cleanPriceString(String(line[priceRange]))
            
            guard let quantity = Int(qtyString),
                  let price = Double(priceString),
                  isValidItem(name: name, price: price) else { return nil }
            
            return ParsedItem(name: name, price: price, quantity: quantity, confidence: confidence)
            
        } else if numGroups >= 2 {
            // Standard item pattern match
            guard let nameRange = Range(match.range(at: 1), in: line),
                  let priceRange = Range(match.range(at: 2), in: line) else { return nil }
            
            let name = cleanItemName(String(line[nameRange]))
            let priceString = cleanPriceString(String(line[priceRange]))
            
            guard let price = Double(priceString),
                  isValidItem(name: name, price: price) else { return nil }
            
            return ParsedItem(name: name, price: price, quantity: 1, confidence: confidence)
        }
        
        return nil
    }
    
    private static func cleanItemName(_ name: String) -> String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .capitalized
    }
    
    private static func cleanPriceString(_ priceString: String) -> String {
        return priceString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func isValidItem(name: String, price: Double) -> Bool {
        // Validate item name
        guard name.count >= 2,
              name.count <= 50,
              price > 0.01,
              price < 1000.0 else { return false }
        
        // Check for invalid item names
        let invalidNames = ["total", "tax", "subtotal", "change", "cash", "credit", "debit"]
        let lowercaseName = name.lowercased()
        
        for invalid in invalidNames {
            if lowercaseName.contains(invalid) {
                return false
            }
        }
        
        return true
    }
    
    private static func shouldSkipLine(_ line: String) -> Bool {
        for pattern in skipPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: line.utf16.count)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private static func extractTotal(from line: String) -> Double? {
        // Enhanced total extraction patterns
        let totalPatterns = [
            #"(?i)(?:^|\s)total\s*:?\s*\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#,
            #"(?i)(?:^|\s)amount\s*due\s*:?\s*\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#,
            #"(?i)(?:^|\s)balance\s*:?\s*\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        ]
        
        for pattern in totalPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let totalRange = Range(match.range(at: 1), in: line) {
                    let totalString = String(line[totalRange]).replacingOccurrences(of: ",", with: "")
                    return Double(totalString)
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private static func extractMetadata(from line: String, into metadata: inout ReceiptMetadata) {
        // Extract store name, date, time, etc.
        // This could be expanded based on needs
        
        // Store name patterns
        let storePatterns = [
            #"(?i)(walmart|target|costco|safeway|kroger|publix|whole\s*foods|trader\s*joe)"#
        ]
        
        for pattern in storePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let storeRange = Range(match.range(at: 1), in: line) {
                    metadata.storeName = String(line[storeRange])
                    break
                }
            } catch {
                continue
            }
        }
    }
    
    private static func validateAndCleanItems(_ items: [ParsedItem], detectedTotal: Double?) -> [ParsedItem] {
        var cleanItems = items
        
        // Remove duplicates based on name similarity
        cleanItems = removeDuplicates(cleanItems)
        
        // Validate against detected total if available
        if let total = detectedTotal {
            let itemsTotal = cleanItems.reduce(0) { $0 + $1.totalPrice }
            
            // If items total is significantly different from receipt total, flag for review
            let difference = abs(itemsTotal - total)
            if difference > 0.50 && difference / total > 0.1 {
                // Could add a warning or confidence reduction here
            }
        }
        
        return cleanItems
    }
    
    private static func removeDuplicates(_ items: [ParsedItem]) -> [ParsedItem] {
        var uniqueItems: [ParsedItem] = []
        
        for item in items {
            let isDuplicate = uniqueItems.contains { existingItem in
                let nameDistance = levenshteinDistance(item.name, existingItem.name)
                let similarity = 1.0 - (Double(nameDistance) / Double(max(item.name.count, existingItem.name.count)))
                return similarity > 0.8 && abs(item.price - existingItem.price) < 0.50
            }
            
            if !isDuplicate {
                uniqueItems.append(item)
            }
        }
        
        return uniqueItems
    }
    
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1.lowercased())
        let s2Array = Array(s2.lowercased())
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
}
