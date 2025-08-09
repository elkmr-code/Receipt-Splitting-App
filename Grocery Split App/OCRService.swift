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
                    self.lastError = "Failed to process image - invalid image format"
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
                    DispatchQueue.main.async {
                        self.lastError = "No text could be detected in the image"
                    }
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.async {
                        self.lastError = "No readable text found in the image"
                    }
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
