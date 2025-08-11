# Camera Permissions Setup

## Required Info.plist Entries

Add the following keys to your Info.plist file:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to scan receipts and QR codes for easy expense splitting.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to process receipt images for expense splitting.</string>
```

## Permission Handling

The app requests camera permissions when:
- User selects "Scan Receipt" option
- User selects "Scan Code" option
- User opens camera from image picker

Permissions are handled gracefully with:
- Clear explanation of why permissions are needed
- Alternative manual entry options if permissions are denied
- Proper error messages for denied permissions

## Privacy Compliance

- Camera access is only used for receipt/QR code scanning
- No images are stored without user consent
- All data processing happens locally on device
- No personal data is transmitted to external servers