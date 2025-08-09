import SwiftUI
import AVFoundation
import Vision
import VisionKit

// MARK: - Production Camera Scanner View
struct CameraScannerView: View {
    let scanType: CameraScanType
    let onComplete: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var scanProgress: Double = 0.0
    @State private var showingResult = false
    @State private var scanningStep = 0
    @State private var animationOffset: CGFloat = -200
    @StateObject private var cameraService = CameraService()
    @State private var showingDocumentCamera = false
    @State private var showingPhotosPicker = false
    @State private var showingPermissionAlert = false
    
    // Mock scanning steps
    private let scanningSteps = [
        "Initializing camera...",
        "Focusing on target...",
        "Detecting patterns...",
        "Processing data...",
        "Parsing information..."
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Real camera preview or fallback
                if cameraService.isCameraAvailable && !ProcessInfo.processInfo.isiOSAppOnMac {
                    CameraPreviewView(cameraService: cameraService)
                        .ignoresSafeArea()
                } else {
                    // Simulator fallback - black background with instructions
                    Color.black
                        .ignoresSafeArea()
                }
                
                VStack {
                    // Camera viewfinder overlay
                    ZStack {
                        // Target frame
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                isScanning ? Color.green : Color.white,
                                lineWidth: 3
                            )
                            .frame(width: 280, height: 180)
                            .overlay(
                                VStack {
                                    HStack {
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                        Spacer()
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                    }
                                    Spacer()
                                    HStack {
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                        Spacer()
                                        Rectangle()
                                            .fill(isScanning ? Color.green : Color.white)
                                            .frame(width: 20, height: 3)
                                    }
                                }
                                .padding(8)
                            )
                        
                        // Scanning line animation
                        if isScanning {
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 3)
                                .frame(width: 280)
                                .offset(y: animationOffset)
                                .opacity(0.8)
                                .clipped()
                        }
                        
                        // Instructions overlay
                        if !isScanning && !showingResult {
                            VStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: scanType.icon)
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                    
                                    Text("Position \(scanType.displayName.lowercased()) in the frame")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Tap to start scanning")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 400)
                    .onTapGesture {
                        if !isScanning && !showingResult {
                            startScanning()
                        }
                    }
                    
                    Spacer()
                    
                    // Scanning status and controls
                    VStack(spacing: 16) {
                        if isScanning {
                            VStack(spacing: 12) {
                                ProgressView(value: scanProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                    .frame(height: 8)
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                                
                                if scanningStep < scanningSteps.count {
                                    Text(scanningSteps[scanningStep])
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .animation(.easeInOut, value: scanningStep)
                                }
                                
                                Text("\(Int(scanProgress * 100))%")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        } else if showingResult {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                
                                Text("Scan Complete!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Processing results...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 12) {
                                Button(action: startScanning) {
                                    HStack {
                                        Image(systemName: "camera")
                                        Text("Start Scanning")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                                
                                // Alternative options for when camera isn't available
                                HStack(spacing: 12) {
                                    if scanType == .receipt && VNDocumentCameraViewController.isSupported {
                                        Button(action: { showingDocumentCamera = true }) {
                                            HStack {
                                                Image(systemName: "doc.badge.plus")
                                                Text("Document Scan")
                                            }
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.9))
                                            .cornerRadius(8)
                                        }
                                    }
                                    
                                    Button(action: { showingPhotosPicker = true }) {
                                        HStack {
                                            Image(systemName: "photo.on.rectangle")
                                            Text("Choose Photo")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Camera Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupCamera()
        }
        .sheet(isPresented: $showingDocumentCamera) {
            DocumentCameraView { images in
                processDocumentImages(images)
            }
        }
        .sheet(isPresented: $showingPhotosPicker) {
            PhotosPickerView { image in
                processSelectedImage(image)
            }
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("This app needs camera access to scan receipts and codes. Please enable camera permission in Settings.")
        }
    }
    
    // MARK: - Setup and Scanning Methods
    private func setupCamera() {
        Task {
            do {
                try await cameraService.requestPermission()
                if scanType == .barcode {
                    try await cameraService.startBarcodeSession()
                } else {
                    try await cameraService.startCameraSession()
                }
            } catch {
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func startScanning() {
        if cameraService.isCameraAvailable && !ProcessInfo.processInfo.isiOSAppOnMac {
            startRealScanning()
        } else {
            // Fallback for simulator - show photo picker
            showingPhotosPicker = true
        }
    }
    
    private func startRealScanning() {
        isScanning = true
        scanProgress = 0.0
        scanningStep = 0
        showingResult = false
        
        // Start scanning line animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
            animationOffset = 100
        }
        
        if scanType == .barcode {
            startBarcodeDetection()
        } else {
            startReceiptCapture()
        }
    }
    
    private func startBarcodeDetection() {
        // In production, this would use AVFoundation barcode detection
        // For now, we'll fall back to photo picker
        Task {
            await MainActor.run {
                isScanning = false
                animationOffset = -200
                showingPhotosPicker = true
            }
        }
    }
    
    private func startReceiptCapture() {
        // For receipt scanning, we'll simulate progress and then show document camera
        simulateProgressThenShowDocumentCamera()
    }
    
    private func simulateProgressThenShowDocumentCamera() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if scanningStep < scanningSteps.count - 1 {
                scanningStep += 1
                scanProgress = Double(scanningStep) / Double(scanningSteps.count - 1)
            } else {
                timer.invalidate()
                isScanning = false
                animationOffset = -200
                
                // Show document camera if available, otherwise show photo picker
                if VNDocumentCameraViewController.isSupported {
                    showingDocumentCamera = true
                } else {
                    showingPhotosPicker = true
                }
            }
        }
    }
    
    private func simulateScanningForFallback() async {
        // Fallback simulation for when real scanning isn't available
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if self.scanningStep < self.scanningSteps.count - 1 {
                self.scanningStep += 1
                self.scanProgress = Double(self.scanningStep) / Double(self.scanningSteps.count - 1)
            } else {
                timer.invalidate()
                Task {
                    await MainActor.run {
                        self.isScanning = false
                        self.animationOffset = -200
                        self.showingPhotosPicker = true
                    }
                }
            }
        }
    }
    
    private func completeScanning(with result: ScanResult) async {
        await MainActor.run {
            isScanning = false
            showingResult = true
            animationOffset = -200
        }
        
        // Brief delay to show success state
        try? await Task.sleep(for: .seconds(1))
        
        await MainActor.run {
            onComplete(result)
        }
        
        // Small delay before dismiss to allow parent to process
        try? await Task.sleep(for: .milliseconds(300))
        
        await MainActor.run {
            dismiss()
        }
    }
    
    private func processDocumentImages(_ images: [UIImage]) {
        guard let firstImage = images.first else { return }
        
        Task {
            do {
                let result = try await performOCR(on: firstImage)
                await completeScanning(with: result)
            } catch {
                await handleScanError(error)
            }
        }
    }
    
    private func processSelectedImage(_ image: UIImage) {
        Task {
            do {
                if scanType == .barcode {
                    let result = try await detectBarcodeInImage(image)
                    await completeScanning(with: result)
                } else {
                    let result = try await performOCR(on: image)
                    await completeScanning(with: result)
                }
            } catch {
                await handleScanError(error)
            }
        }
    }
    
    private func performOCR(on image: UIImage) async throws -> ScanResult {
        let scanningService = ScanningService()
        return try await scanningService.performOCR(on: image)
    }
    
    private func handleScanError(_ error: Error) async {
        await MainActor.run {
            isScanning = false
            animationOffset = -200
            showingResult = false
            
            // Show error and dismiss the scanner
            dismiss()
        }
    }
    
    private func detectBarcodeInImage(_ image: UIImage) async throws -> ScanResult {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ScanningError.invalidImage)
                return
            }
            
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation],
                      let firstBarcode = observations.first,
                      let payloadString = firstBarcode.payloadStringValue else {
                    continuation.resume(throwing: ScanningError.noReceiptFound)
                    return
                }
                
                // Use ScanningService to process the barcode payload
                Task {
                    do {
                        let scanningService = ScanningService()
                        let result = try await scanningService.scanCode(from: payloadString)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
}

// MARK: - Camera Scan Type
enum CameraScanType {
    case barcode
    case receipt
    
    var displayName: String {
        switch self {
        case .barcode: return "Barcode/QR Code"
        case .receipt: return "Receipt"
        }
    }
    
    var icon: String {
        switch self {
        case .barcode: return "qrcode"
        case .receipt: return "doc.text"
        }
    }
}

// MARK: - Supporting Components

// Camera Service for real camera integration
@MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isCameraAvailable = false
    @Published var isScanning = false
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        checkCameraAvailability()
    }
    
    func requestPermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isCameraAvailable = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                isCameraAvailable = true
            } else {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }
    }
    
    func startCameraSession() async throws {
        guard isCameraAvailable else { return }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              let session = captureSession else {
            throw CameraError.setupFailed
        }
        
        if session.canAddInput(input) {
            session.canAddInput(input)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func startBarcodeSession() async throws {
        try await startCameraSession()
        // Additional barcode-specific setup would go here
    }
    
    func detectBarcode() async throws -> String {
        // TODO: Implement real barcode/QR detection using AVFoundation
        // For now, this would need to be connected to actual camera barcode detection
        // This is a simplified version that would need proper AVCaptureSession setup
        throw CameraError.setupFailed
    }
    
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    private func checkCameraAvailability() {
        isCameraAvailable = AVCaptureDevice.default(for: .video) != nil
    }
}

enum CameraError: LocalizedError {
    case permissionDenied
    case setupFailed
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .setupFailed:
            return "Failed to setup camera"
        case .scanningFailed:
            return "Scanning failed"
        }
    }
}

// Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        if let session = cameraService.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Store reference for frame updates
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// Document Camera View
struct DocumentCameraView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }
            
            parent.completion(images)
            parent.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

// Photos Picker View
struct PhotosPickerView: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotosPickerView
        
        init(_ parent: PhotosPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraScannerView(scanType: .barcode) { _ in }
}