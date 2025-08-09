import SwiftUI
import Foundation

// MARK: - Comprehensive Error Handling System

/// Central error handling utility for the Receipt Splitting App
struct ErrorHandler {
    
    /// Log and display user-friendly error messages
    static func handle(error: Error, context: String = "", userMessage: String? = nil) -> ErrorDisplayInfo {
        // Log error for debugging
        print("❌ Error in \(context): \(error.localizedDescription)")
        print("   Details: \(error)")
        
        // Generate user-friendly message
        let displayMessage = userMessage ?? generateUserFriendlyMessage(for: error, context: context)
        
        return ErrorDisplayInfo(
            title: getErrorTitle(for: error),
            message: displayMessage,
            recoveryAction: getRecoveryAction(for: error, context: context),
            severity: getErrorSeverity(for: error)
        )
    }
    
    private static func generateUserFriendlyMessage(for error: Error, context: String) -> String {
        switch error {
        case is ScanningError:
            return handleScanningError(error as! ScanningError)
        case is BarcodeServiceError:
            return handleBarcodeError(error as! BarcodeServiceError)
        case is OCRError:
            return handleOCRError(error as! OCRError)
        case is CameraError:
            return handleCameraError(error as! CameraError)
        case is NetworkError:
            return handleNetworkError(error as! NetworkError)
        default:
            return "Something went wrong. Please try again or contact support if the issue persists."
        }
    }
    
    private static func handleScanningError(_ error: ScanningError) -> String {
        switch error {
        case .noReceiptFound:
            return "We couldn't find any receipt information in this code. Please verify the QR code or barcode is from a supported merchant."
        case .ocrFailed:
            return "We had trouble reading the text in your image. Try taking a clearer photo with better lighting."
        case .invalidImage:
            return "The image format isn't supported. Please try again with a different photo."
        case .noTextFound:
            return "No text could be detected in your image. Make sure the receipt is clearly visible and well-lit."
        case .invalidImageType:
            return "This doesn't appear to be a receipt image. Please select an image that shows purchase details."
        case .noItemsFound:
            return "We couldn't find any items with prices in this image. You can add items manually instead."
        case .scanningFailed:
            return "Scanning failed. Please check your camera permissions and try again."
        }
    }
    
    private static func handleBarcodeError(_ error: BarcodeServiceError) -> String {
        switch error {
        case .invalidImage:
            return "The image format isn't supported for barcode scanning. Please try a different image."
        case .noBarcodeFound:
            return "No barcode or QR code was found in this image. Make sure the code is clearly visible."
        case .invalidBarcodeData:
            return "The barcode data couldn't be processed. This might not be a supported receipt code."
        }
    }
    
    private static func handleOCRError(_ error: OCRError) -> String {
        switch error {
        case .invalidImage:
            return "The image format isn't supported. Please try again with a JPEG or PNG image."
        case .noTextFound:
            return "No text could be detected. Try taking a clearer photo with better lighting and focus."
        case .processingFailed:
            return "Text processing failed. Please try again or use manual entry."
        }
    }
    
    private static func handleCameraError(_ error: CameraError) -> String {
        switch error {
        case .permissionDenied:
            return "Camera permission is required to scan receipts. Please enable camera access in Settings."
        case .setupFailed:
            return "Camera setup failed. Please restart the app and try again."
        case .scanningFailed:
            return "Camera scanning failed. You can try using photos from your gallery instead."
        }
    }
    
    private static func handleNetworkError(_ error: NetworkError) -> String {
        switch error {
        case .noConnection:
            return "No internet connection. Some features may be limited."
        case .timeout:
            return "The request timed out. Please check your connection and try again."
        case .serverError:
            return "Server error. Please try again in a few moments."
        }
    }
    
    private static func getErrorTitle(for error: Error) -> String {
        switch error {
        case is ScanningError, is BarcodeServiceError, is OCRError:
            return "Scanning Error"
        case is CameraError:
            return "Camera Error" 
        case is NetworkError:
            return "Connection Error"
        default:
            return "Error"
        }
    }
    
    private static func getRecoveryAction(for error: Error, context: String) -> RecoveryAction? {
        switch error {
        case is CameraError:
            return .openSettings
        case is ScanningError, is OCRError:
            return .tryManualEntry
        case is NetworkError:
            return .retry
        default:
            return .dismiss
        }
    }
    
    private static func getErrorSeverity(for error: Error) -> ErrorSeverity {
        switch error {
        case is CameraError:
            return .high // Blocks core functionality
        case is NetworkError:
            return .medium // Limits some features
        case is ScanningError, is OCRError, is BarcodeServiceError:
            return .low // Has fallback options
        default:
            return .medium
        }
    }
}

// MARK: - Error Display Models

struct ErrorDisplayInfo {
    let title: String
    let message: String
    let recoveryAction: RecoveryAction?
    let severity: ErrorSeverity
}

enum RecoveryAction {
    case retry
    case openSettings
    case tryManualEntry
    case dismiss
    
    var title: String {
        switch self {
        case .retry: return "Try Again"
        case .openSettings: return "Open Settings"
        case .tryManualEntry: return "Manual Entry"
        case .dismiss: return "OK"
        }
    }
}

enum ErrorSeverity {
    case low, medium, high
}

// MARK: - Additional Error Types

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .noConnection: return "No internet connection"
        case .timeout: return "Request timed out"
        case .serverError: return "Server error"
        }
    }
}

// MARK: - Error Alert View

struct ErrorAlert: ViewModifier {
    @Binding var errorInfo: ErrorDisplayInfo?
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorInfo?.title ?? "Error",
                isPresented: Binding(
                    get: { errorInfo != nil },
                    set: { if !$0 { errorInfo = nil } }
                )
            ) {
                if let recoveryAction = errorInfo?.recoveryAction {
                    Button(recoveryAction.title) {
                        handleRecoveryAction(recoveryAction)
                    }
                    
                    if recoveryAction != .dismiss {
                        Button("Cancel", role: .cancel) {
                            errorInfo = nil
                        }
                    }
                } else {
                    Button("OK", role: .cancel) {
                        errorInfo = nil
                    }
                }
            } message: {
                Text(errorInfo?.message ?? "An unexpected error occurred.")
            }
    }
    
    private func handleRecoveryAction(_ action: RecoveryAction) {
        switch action {
        case .openSettings:
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .retry:
            // Let the parent view handle retry logic
            break
        case .tryManualEntry:
            // Let the parent view handle manual entry
            break
        case .dismiss:
            break
        }
        errorInfo = nil
    }
}

extension View {
    func errorAlert(_ errorInfo: Binding<ErrorDisplayInfo?>) -> some View {
        modifier(ErrorAlert(errorInfo: errorInfo))
    }
}

// MARK: - Accessibility Helpers

struct AccessibilityHelper {
    
    /// Standard accessibility labels for common UI elements
    static let scanButton = "Scan receipt with camera"
    static let galleryButton = "Select receipt image from photo library"
    static let manualEntryButton = "Add expense items manually"
    static let addItemButton = "Add new expense item"
    static let deleteItemButton = "Delete expense item"
    static let editItemButton = "Edit expense item"
    static let saveExpenseButton = "Save expense to your records"
    static let shareExpenseButton = "Share expense split with participants"
    
    /// Dynamic accessibility labels for context-specific elements
    static func expenseItemLabel(name: String, price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let priceString = formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
        return "Item: \(name), price: \(priceString)"
    }
    
    static func participantLabel(name: String, amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return "\(name) owes \(amountString)"
    }
    
    static func expenseLabel(name: String, total: Double, date: Date) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let totalString = formatter.string(from: NSNumber(value: total)) ?? "$\(total)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: date)
        
        return "Expense: \(name), total: \(totalString), date: \(dateString)"
    }
    
    /// Accessibility hints for complex interactions
    static let scanHint = "Double-tap to start camera scanning, or swipe up for more options"
    static let editHint = "Double-tap to edit, swipe left to delete"
    static let messageHint = "Double-tap to expand message editor"
    static let splitHint = "Adjustable. Swipe up or down to change the split amount"
}

// MARK: - Accessibility View Modifiers

struct AccessibleButton: ViewModifier {
    let label: String
    let hint: String?
    let action: () -> Void
    
    func body(content: Content) -> some View {
        Button(action: action) {
            content
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

struct AccessibleListItem: ViewModifier {
    let label: String
    let value: String?
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
    }
}

extension View {
    func accessibleButton(label: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        modifier(AccessibleButton(label: label, hint: hint, action: action))
    }
    
    func accessibleListItem(label: String, value: String? = nil, hint: String? = nil) -> some View {
        modifier(AccessibleListItem(label: label, value: value, hint: hint))
    }
}

// MARK: - Loading States

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    func loadingOverlay(isShowing: Bool, message: String) -> some View {
        ZStack {
            self
            
            if isShowing {
                LoadingOverlay(message: message)
            }
        }
    }
}