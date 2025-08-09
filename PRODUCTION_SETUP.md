# Production Setup Instructions

## Camera Permissions Configuration

Since the manual `Info.plist` file has been removed as part of the production implementation, camera permissions must now be configured via Xcode target settings.

### Required Permissions

Configure the following privacy usage descriptions in your Xcode target settings:

1. **NSCameraUsageDescription**
   - Value: `"This app uses the camera to scan QR codes and receipts for expense tracking."`
   - Purpose: Allows camera access for live scanning and receipt capture

2. **NSPhotoLibraryUsageDescription**  
   - Value: `"This app needs photo access to import receipt images for expense processing."`
   - Purpose: Allows users to select receipt images from photo library

3. **NSPhotoLibraryAddUsageDescription**
   - Value: `"Allow saving scanned receipts to your photo library for record keeping."`
   - Purpose: Optional - allows saving processed receipts back to photos

### How to Configure in Xcode

1. Open the project in Xcode
2. Select your app target
3. Go to the "Info" tab
4. Under "Custom iOS Target Properties", add the above keys and values
5. Alternatively, edit the Info.plist directly in the target settings

## Production Features Implemented

### ✅ Demo Functionality Removed
- Removed mock BarcodeService with hardcoded receipt database
- Removed BarcodeScannerView with simulated scanning
- Removed BarcodeScannerViewModel with demo data
- Cleaned up AddReceiptView from demo code paths

### ✅ Production Camera Integration  
- Enhanced CameraScannerView with robust AVFoundation integration
- Real barcode/QR code detection using Vision framework
- VNDocumentCameraViewController integration for receipt capture
- Proper fallback to photo picker for simulator compatibility

### ✅ Enhanced Scanning Services
- Production BarcodeService with Vision framework integration
- Support for both JSON QR data and simple transaction IDs  
- Robust receipt text parsing with multiple regex patterns
- Enhanced error handling and user feedback

### ✅ Data Models (SwiftData)
- Receipt model with sourceType, receiptID, rawText, imageData
- Enhanced Expense model with splitStatus, message, paymentMethod  
- SplitRequest model for tracking payment requests
- Proper relationships with cascade delete rules

### ✅ Inline Message System
- PreviewMessageSection component for inline editing
- MessageComposer helper with template-based generation (4 templates)
- Automatic message regeneration on split changes
- TextEditor-based editing with proper state management

## Testing Notes

- **Device vs Simulator**: Camera functionality works fully on device; simulator falls back to photo picker
- **Permissions**: App will request camera/photo permissions on first use
- **Error Handling**: Robust error states for all scanning failures
- **Accessibility**: Proper VoiceOver support throughout scanning flow

## File Structure

```
Grocery Split App/
├── Models.swift                 # Enhanced SwiftData models
├── AddReceiptView.swift         # Production receipt capture (demo code removed)
├── ScanningService.swift        # Vision framework OCR service  
├── BarcodeService.swift         # Production barcode/QR scanning
├── CameraScannerView.swift      # AVFoundation camera integration
├── MessageComposer.swift        # Template-based message generation  
├── SplitExpenseView.swift       # Inline PreviewMessageSection
└── [Other existing files...]
```

## Known Production Considerations

1. **Camera Permissions**: Must be configured in Xcode target settings (not manual plist)
2. **Real Device Testing**: Full camera functionality requires physical device
3. **Performance**: OCR processing is CPU-intensive; consider background processing for large images
4. **Error Recovery**: Users can always fall back to manual entry if scanning fails

This implementation provides a professional, production-ready receipt splitting app with no demo functionality.