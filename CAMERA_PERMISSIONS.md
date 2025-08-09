# Camera Permissions Setup

## Required Permission Strings for Xcode Target Settings

Add the following permission strings to your app's target settings in Xcode (not Info.plist file):

1. **NSCameraUsageDescription**:
   ```
   This app uses the camera to scan QR codes and receipts.
   ```

2. **NSPhotoLibraryUsageDescription**:
   ```
   This app needs photo access to import receipt images.
   ```

3. **NSPhotoLibraryAddUsageDescription**:
   ```
   Allow saving scanned receipts to your library.
   ```

## How to Add These Permissions in Xcode:

1. Open the Xcode project file: `Grocery Split App.xcodeproj`
2. Select your app target in the project navigator
3. Go to the "Info" tab
4. Under "Custom iOS Target Properties", add each key-value pair above
5. Build and run the app

These permissions ensure that the production camera scanning functionality works properly on real devices.

## Production Camera Features Implemented:

- ✅ Live camera preview with AVFoundation
- ✅ QR/Barcode detection with Vision framework
- ✅ Document camera integration with VisionKit
- ✅ Photo picker fallback for simulator compatibility
- ✅ OCR text recognition for receipt scanning
- ✅ Robust error handling and user guidance