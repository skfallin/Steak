import SwiftUI
import VisionKit
import Vision
import AVFoundation

// MARK: - Scanner representable

struct BarcodeScannerView: UIViewControllerRepresentable {
    let isActive: Bool
    let regionOfInterest: CGRect
    let onCodeScanned: (String, VNBarcodeSymbology) -> Void
    let onScannerError: (String?) -> Void

    static let symbologies: [VNBarcodeSymbology] = [
        .ean13,
        .ean8,
        .upce,
        .itf14,
        .gs1DataBar,
        .code128
    ]

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.symbologies)],
            qualityLevel: .accurate,
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
        context.coordinator.update(scanner: controller, regionOfInterest: regionOfInterest, isActive: false)
        Self.log("scanner unavailable: simulator")
        context.coordinator.scheduleError("Barcode scanning is unavailable in the simulator.")
        #else
        context.coordinator.update(scanner: controller, regionOfInterest: regionOfInterest, isActive: isActive)
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCodeScanned, onError: onScannerError)
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        coordinator.deactivate(scanner: controller)
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

    private static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[BarcodeScanner] \(message())")
        #endif
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String, VNBarcodeSymbology) -> Void
        var onError: (String?) -> Void
        private var lastScheduledError: String?
        private var hasScheduledError = false
        private var errorDeliveryGeneration = 0
        private weak var scanner: DataScannerViewController?
        private var latestRegionOfInterest: CGRect = .zero
        private var lastAppliedRegionOfInterest: CGRect?
        private var isUsingFullFrameFallback = false
        private var isScannerRequested = false
        private var roiRetryScheduled = false
        private var roiRetryGeneration = 0
        private var lastROILog: String?

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
            guard isScannerRequested, scanner === dataScanner else { return }

            errorDeliveryGeneration += 1
            let message = BarcodeScannerView.message(for: error)
            BarcodeScannerView.log("scanner unavailable: \(String(describing: error))")
            lastScheduledError = message
            hasScheduledError = true
            onError(message)
        }

        func update(
            scanner: DataScannerViewController,
            regionOfInterest: CGRect,
            isActive: Bool
        ) {
            guard isActive else {
                deactivate(scanner: scanner)
                return
            }

            let becameActive = !isScannerRequested
            self.scanner = scanner
            latestRegionOfInterest = regionOfInterest
            isScannerRequested = true
            if becameActive {
                invalidateRegionOfInterestRetry()
                resetRegionOfInterestState()
            }

            applyRegionOfInterest(to: scanner)
            startScanningIfPossible(scanner)
        }

        func deactivate(scanner: DataScannerViewController? = nil) {
            let scannerToStop = scanner ?? self.scanner
            isScannerRequested = false
            self.scanner = nil
            invalidateRegionOfInterestRetry()
            cancelPendingErrorDelivery()
            if let scannerToStop {
                stopScanning(scannerToStop)
            }
            resetRegionOfInterestState()
        }

        func stopScanning(_ scanner: DataScannerViewController) {
            guard scanner.isScanning else { return }
            scanner.stopScanning()
            BarcodeScannerView.log("scanner stopped")
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

        private func applyRegionOfInterest(to scanner: DataScannerViewController) {
            guard latestRegionOfInterest.width > 0, latestRegionOfInterest.height > 0 else {
                logROI("ROI deferred: guide frame is unavailable")
                useFullFrameFallback(on: scanner)
                return
            }

            guard let scannerView = scanner.viewIfLoaded,
                  scannerView.window != nil,
                  !scannerView.bounds.isEmpty else {
                logROI("ROI deferred: scanner view is not attached or laid out")
                useFullFrameFallback(on: scanner)
                scheduleRegionOfInterestRetry()
                return
            }

            let convertedFrame = scannerView.convert(latestRegionOfInterest, from: nil)
            let visibleRegion = convertedFrame.intersection(scannerView.bounds)
            guard !visibleRegion.isNull, !visibleRegion.isEmpty else {
                logROI("ROI rejected: guide frame is outside scanner bounds")
                useFullFrameFallback(on: scanner)
                return
            }

            guard isUsingFullFrameFallback || visibleRegion != lastAppliedRegionOfInterest else { return }

            scanner.regionOfInterest = visibleRegion
            lastAppliedRegionOfInterest = visibleRegion
            isUsingFullFrameFallback = false
            invalidateRegionOfInterestRetry()
            logROI("ROI applied: \(visibleRegion.debugDescription)")
        }

        private func useFullFrameFallback(on scanner: DataScannerViewController) {
            guard !isUsingFullFrameFallback else { return }

            scanner.regionOfInterest = nil
            lastAppliedRegionOfInterest = nil
            isUsingFullFrameFallback = true
        }

        private func resetRegionOfInterestState() {
            lastAppliedRegionOfInterest = nil
            isUsingFullFrameFallback = false
        }

        private func scheduleRegionOfInterestRetry() {
            guard isScannerRequested, !roiRetryScheduled else { return }
            roiRetryScheduled = true
            let generation = roiRetryGeneration

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self,
                      self.roiRetryGeneration == generation,
                      self.isScannerRequested else {
                    return
                }
                self.roiRetryScheduled = false
                guard let scanner = self.scanner else {
                    return
                }
                self.applyRegionOfInterest(to: scanner)
                guard self.isScannerRequested,
                      self.scanner === scanner else {
                    return
                }
                self.startScanningIfPossible(scanner)
            }
        }

        private func invalidateRegionOfInterestRetry() {
            roiRetryGeneration += 1
            roiRetryScheduled = false
        }

        private func startScanningIfPossible(_ scanner: DataScannerViewController) {
            guard DataScannerViewController.isSupported else {
                BarcodeScannerView.log("scanner unavailable: unsupported device")
                scheduleError("Barcode scanning isn't supported on this device.")
                return
            }

            guard DataScannerViewController.isAvailable else {
                BarcodeScannerView.log("scanner unavailable: camera unavailable")
                scheduleError("Camera is unavailable. Close other camera apps and try again.")
                return
            }

            guard !scanner.isScanning else {
                scheduleError(nil)
                return
            }

            do {
                try scanner.startScanning()
                BarcodeScannerView.log("scanner started")
                scheduleError(nil)
            } catch let error as DataScannerViewController.ScanningUnavailable {
                BarcodeScannerView.log("scanner unavailable: \(String(describing: error))")
                scheduleError(BarcodeScannerView.message(for: error))
            } catch {
                BarcodeScannerView.log("scanner unavailable: \(String(reflecting: type(of: error))): \(String(describing: error))")
                scheduleError("Couldn't start the camera scanner. Try again.")
            }
        }

        private func logROI(_ message: String) {
            guard message != lastROILog else { return }
            lastROILog = message
            BarcodeScannerView.log(message)
        }

        private func handle(items: [RecognizedItem], scanner: DataScannerViewController) {
            guard isScannerRequested, self.scanner === scanner else { return }

            for item in items {
                guard case .barcode(let barcode) = item else { continue }

                let symbology = barcode.observation.symbology
                guard let code = barcode.payloadStringValue else {
                    BarcodeScannerView.log("nil payload for symbology: \(String(describing: symbology))")
                    continue
                }

                BarcodeScannerView.log("recognized candidate: \(code), symbology: \(String(describing: symbology))")
                let normalized = symbology == .upce
                    ? BarcodeValidator.expandedUPCE(code)
                    : BarcodeValidator.canonicalGTIN(code)
                guard let normalized else {
                    let reason = symbology == .upce
                        ? "UPC-E expansion or GTIN checksum validation failed"
                        : "canonical GTIN checksum validation failed"
                    BarcodeScannerView.log("candidate rejected: \(code), reason: \(reason)")
                    onError("That barcode is not a supported product code.")
                    return
                }

                BarcodeScannerView.log("accepted candidate: \(normalized)")
                deactivate(scanner: scanner)
                onCode(normalized, symbology)
                return
            }
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
