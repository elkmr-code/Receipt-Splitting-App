# Camera Permissions Documentation

## iOS Camera Permission Requirements

This app requires camera access for scanning receipts and QR/barcodes.

### Info.plist Requirements

Add the following entries to your Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan receipts and QR codes for expense splitting.</string>
```

### Production Setup

1. Ensure camera permissions are properly configured in Xcode project settings
2. Test camera functionality on physical devices
3. Handle camera permission denials gracefully with appropriate user messaging

### Testing Notes

- Camera scanning requires physical device testing
- Simulator testing is limited for camera features
- Always test permission flows during app development