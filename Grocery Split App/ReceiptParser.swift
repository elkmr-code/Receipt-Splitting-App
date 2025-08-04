import Foundation

struct ParsedItem {
    let name: String
    let price: Double
    let quantity: Int
}

class ReceiptParser {
    
    // Add the method that AddReceiptView expects
    func parseItems(from text: String) -> [ParsedItem] {
        return ReceiptParser.parseReceiptText(text)
    }
    
    static func parseReceiptText(_ text: String) -> [ParsedItem] {
        let lines = text.components(separatedBy: .newlines)
        var parsedItems: [ParsedItem] = []
        
        for line in lines {
            if let item = parseLineItem(line) {
                parsedItems.append(item)
            }
        }
        
        return parsedItems
    }
    
    private static func parseLineItem(_ line: String) -> ParsedItem? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines and common non-item lines
        guard !trimmedLine.isEmpty,
              !isSkippableLine(trimmedLine) else {
            return nil
        }
        
        // Try different parsing patterns
        if let item = parseWithQuantity(trimmedLine) {
            return item
        } else if let item = parseSimpleFormat(trimmedLine) {
            return item
        }
        
        return nil
    }
    
    private static func parseWithQuantity(_ line: String) -> ParsedItem? {
        // Pattern: "2x Apple 1.25" or "3 x Banana $2.50"
        let quantityPattern = "(\\d+)\\s*x?\\s*(.+?)\\s+\\$?(\\d+\\.?\\d*)"
        
        if let regex = try? NSRegularExpression(pattern: quantityPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
            
            let quantityRange = Range(match.range(at: 1), in: line)
            let nameRange = Range(match.range(at: 2), in: line)
            let priceRange = Range(match.range(at: 3), in: line)
            
            if let quantityRange = quantityRange,
               let nameRange = nameRange,
               let priceRange = priceRange,
               let quantity = Int(String(line[quantityRange])),
               let price = Double(String(line[priceRange])) {
                
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return ParsedItem(name: name, price: price, quantity: quantity)
            }
        }
        
        return nil
    }
    
    private static func parseSimpleFormat(_ line: String) -> ParsedItem? {
        // Pattern: "Item Name    $12.99" or "Item Name 12.99"
        let simplePattern = "(.+?)\\s+\\$?(\\d+\\.?\\d*)\\s*$"
        
        if let regex = try? NSRegularExpression(pattern: simplePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
            
            let nameRange = Range(match.range(at: 1), in: line)
            let priceRange = Range(match.range(at: 2), in: line)
            
            if let nameRange = nameRange,
               let priceRange = priceRange,
               let price = Double(String(line[priceRange])) {
                
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Additional validation to ensure this looks like a valid item
                guard name.count > 1,
                      price > 0,
                      price < 1000, // Reasonable upper limit for grocery items
                      !name.lowercased().contains("total"),
                      !name.lowercased().contains("tax"),
                      !name.lowercased().contains("subtotal"),
                      !name.lowercased().contains("change"),
                      !name.lowercased().contains("cash"),
                      !name.lowercased().contains("card") else {
                    return nil
                }
                
                return ParsedItem(name: name, price: price, quantity: 1)
            }
        }
        
        return nil
    }
    
    private static func isSkippableLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip common receipt header/footer lines
        let skipPatterns = [
            "store", "market", "grocery", "supermarket",
            "address", "street", "phone", "tel:",
            "date:", "time:", "cashier", "register",
            "total", "subtotal", "tax", "change",
            "cash", "credit", "card", "visa", "mastercard",
            "thank you", "thanks", "receipt", "invoice",
            "member", "savings", "discount",
            "*", "=", "-", "_", "."
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip lines that are just numbers or currency - using NSRegularExpression for compatibility
        let numberPattern = "^\\$?\\d+\\.?\\d*\\s*$"
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) != nil {
            return true
        }
        
        // Skip very short lines (likely not item names)
        if line.count < 3 {
            return true
        }
        
        return false
    }
    
    // Enhanced parsing for better accuracy
    static func parseReceiptTextEnhanced(_ text: String) -> (items: [ParsedItem], total: Double?) {
        let items = parseReceiptText(text)
        let total = extractTotal(from: text)
        
        return (items: items, total: total)
    }
    
    private static func extractTotal(from text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines.reversed() { // Start from bottom
            let lowercased = line.lowercased()
            if lowercased.contains("total") && !lowercased.contains("subtotal") {
                // Look for price pattern in this line using NSRegularExpression
                let totalPattern = "total\\s*:?\\s*\\$?(\\d+\\.?\\d*)"
                if let regex = try? NSRegularExpression(pattern: totalPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)),
                   let range = Range(match.range(at: 1), in: line) {
                    return Double(String(line[range]))
                }
            }
        }
        
        return nil
    }
    
    // Legacy compatibility method
    static func parse(rawText: String) -> [(name: String, price: Double)] {
        let parsedItems = parseReceiptText(rawText)
        return parsedItems.map { (name: $0.name, price: $0.price) }
    }
}
