import Foundation
import Vision
import UIKit

@MainActor
class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    func recognizeText(from image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.isProcessing = true
                self.lastError = nil
            }
            
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.lastError = "Failed to process image"
                }
                continuation.resume(throwing: OCRError.invalidImage)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.lastError = "OCR failed: \(error.localizedDescription)"
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }
            
            // Configure the request for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.lastError = "OCR processing failed: \(error.localizedDescription)"
                }
                continuation.resume(throwing: error)
            }
        }
    }
    
    // Simulate OCR processing with delay for demo purposes
    func simulateOCRProcessing() async throws -> String {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        DispatchQueue.main.async {
            self.isProcessing = false
        }
        
        // Return sample receipt text
        return getSampleReceiptText()
    }
    
    private func getSampleReceiptText() -> String {
        return """
        WHOLE FOODS MARKET
        123 Main Street
        San Francisco, CA 94105
        
        Date: 08/04/2025
        Time: 2:45 PM
        
        Organic Bananas          $3.99
        Almond Milk 64oz         $4.59
        Greek Yogurt             $5.49
        Sourdough Bread          $4.29
        Chicken Breast 2lb       $12.99
        Baby Spinach             $3.99
        Cherry Tomatoes          $4.99
        Olive Oil                $8.99
        Pasta Penne              $2.49
        Parmesan Cheese          $7.99
        
        Subtotal:               $59.80
        Tax:                     $4.78
        Total:                  $64.58
        
        Thank you for shopping!
        """
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in the image"
        case .processingFailed:
            return "Failed to process the image"
        }
    }
}
