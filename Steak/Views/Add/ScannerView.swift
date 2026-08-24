import SwiftUI
import VisionKit
import Vision
import AVFoundation

// MARK: - Scanner representable

struct BarcodeScannerView: UIViewControllerRepresentable {
    let isActive: Bool
    let onCodeScanned: (String, VNBarcodeSymbology) -> Void
    let onScannerError: (String?) -> Void

    static let symbologies: [VNBarcodeSymbology] = [
        .ean13,
        .ean8,
        .upce,
        .itf14,
        .gs1DataBar
    ]

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCodeScanned
        context.coordinator.onError = onScannerError

        #if targetEnvironment(simulator)
        // Camera capture isn't available in the simulator; VisionKit would
        // present a spurious permission prompt if started.
        context.coordinator.scheduleError("Barcode scanning is unavailable in the simulator.")
        #else
        guard isActive else {
            context.coordinator.cancelPendingErrorDelivery()
            if controller.isScanning {
                controller.stopScanning()
            }
            return
        }

        guard DataScannerViewController.isSupported else {
            context.coordinator.scheduleError("Barcode scanning isn't supported on this device.")
            return
        }

        guard DataScannerViewController.isAvailable else {
            context.coordinator.scheduleError("Camera is unavailable. Close other camera apps and try again.")
            return
        }

        guard !controller.isScanning else {
            context.coordinator.scheduleError(nil)
            return
        }

        do {
            try controller.startScanning()
            context.coordinator.scheduleError(nil)
        } catch let error as DataScannerViewController.ScanningUnavailable {
            context.coordinator.scheduleError(Self.message(for: error))
        } catch {
            context.coordinator.scheduleError("Couldn't start the camera scanner. Try again.")
        }
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCodeScanned, onError: onScannerError)
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        coordinator.cancelPendingErrorDelivery()
        controller.stopScanning()
    }

    private static func message(for error: DataScannerViewController.ScanningUnavailable) -> String {
        switch error {
        case .unsupported:
            "Barcode scanning isn't supported on this device."
        case .cameraRestricted:
            "Camera access is restricted. Enable it in Settings to scan barcodes."
        @unknown default:
            "Barcode scanning is temporarily unavailable. Try again."
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String, VNBarcodeSymbology) -> Void
        var onError: (String?) -> Void
        private var lastCode: String?
        private var lastTime = Date.distantPast
        private var lastScheduledError: String?
        private var hasScheduledError = false
        private var errorDeliveryGeneration = 0

        init(onCode: @escaping (String, VNBarcodeSymbology) -> Void, onError: @escaping (String?) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(items: addedItems, scanner: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(items: updatedItems, scanner: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            errorDeliveryGeneration += 1
            lastScheduledError = BarcodeScannerView.message(for: error)
            hasScheduledError = true
            onError(BarcodeScannerView.message(for: error))
        }

        func scheduleError(_ error: String?) {
            guard !hasScheduledError || lastScheduledError != error else { return }

            lastScheduledError = error
            hasScheduledError = true
            errorDeliveryGeneration += 1
            let generation = errorDeliveryGeneration

            DispatchQueue.main.async { [weak self] in
                guard let self, self.errorDeliveryGeneration == generation else { return }
                self.onError(error)
            }
        }

        func cancelPendingErrorDelivery() {
            errorDeliveryGeneration += 1
            lastScheduledError = nil
            hasScheduledError = false
        }

        private func handle(items: [RecognizedItem], scanner: DataScannerViewController) {
            guard let (code, symbology) = items.compactMap(\.barcodePayload).first else { return }
            let normalized: String?
            if symbology == .upce {
                normalized = BarcodeValidator.expandedUPCE(code)
            } else {
                normalized = BarcodeValidator.canonicalGTIN(code)
            }
            guard let normalized else {
                onError("That barcode is not a supported product code.")
                return
            }
            let now = Date()
            guard normalized != lastCode || now.timeIntervalSince(lastTime) >= 2.5 else { return }

            lastCode = normalized
            lastTime = now
            scanner.stopScanning()
            onCode(normalized, symbology)
        }
    }
}

extension RecognizedItem {
    var barcodePayload: (String, VNBarcodeSymbology)? {
        if case .barcode(let barcode) = self {
            guard let payload = barcode.payloadStringValue else { return nil }
            return (payload, barcode.observation.symbology)
        }
        return nil
    }
}

// MARK: - Camera permission

enum CameraPermission {
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func request(_ completion: @escaping @MainActor (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in completion(granted) }
        }
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Torch button

struct TorchButton: View {
    @State private var isOn = false

    var body: some View {
        Button(action: toggleTorch) {
            Image(systemName: isOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .off : .on
            device.unlockForConfiguration()
            isOn.toggle()
        } catch {
            // Torch unavailable; ignore.
        }
    }
}
