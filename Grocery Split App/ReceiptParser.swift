import Foundation

struct ReceiptParser {
    static func parse(rawText: String) -> [(name: String, price: Double)] {
        let lines = rawText.components(separatedBy: .newlines)
        var parsedItems: [(name: String, price: Double)] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines or lines that are too short
            if trimmedLine.isEmpty || trimmedLine.count < 3 {
                continue
            }
            
            // Skip common receipt headers/footers
            let lowercaseLine = trimmedLine.lowercased()
            if lowercaseLine.contains("total") || 
               lowercaseLine.contains("subtotal") ||
               lowercaseLine.contains("tax") ||
               lowercaseLine.contains("change") ||
               lowercaseLine.contains("cash") ||
               lowercaseLine.contains("credit") ||
               lowercaseLine.contains("debit") ||
               lowercaseLine.contains("thank you") ||
               lowercaseLine.contains("receipt") ||
               lowercaseLine.hasPrefix("store") ||
               lowercaseLine.hasPrefix("address") ||
               lowercaseLine.contains("date") ||
               lowercaseLine.contains("time") {
                continue
            }
            
            // Look for price patterns (number with decimal point)
            let pricePattern = #"(\d+\.\d{2})"#
            let priceRegex = try? NSRegularExpression(pattern: pricePattern)
            let range = NSRange(location: 0, length: trimmedLine.utf16.count)
            
            if let matches = priceRegex?.matches(in: trimmedLine, range: range),
               let lastMatch = matches.last {
                let priceRange = Range(lastMatch.range, in: trimmedLine)
                if let priceRange = priceRange {
                    let priceString = String(trimmedLine[priceRange])
                    if let price = Double(priceString) {
                        // Extract the item name (everything before the price)
                        let priceStartIndex = trimmedLine.range(of: priceString)?.lowerBound ?? trimmedLine.endIndex
                        let itemName = String(trimmedLine[..<priceStartIndex])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "$"))
                        
                        // Only add if we have a meaningful item name and reasonable price
                        if !itemName.isEmpty && itemName.count > 1 && price > 0 && price < 1000 {
                            parsedItems.append((name: itemName, price: price))
                        }
                    }
                }
            }
        }
        
        return parsedItems
    }
}