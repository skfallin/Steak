import SwiftUI
import SwiftData
import AVFoundation

@MainActor
@Observable
final class AddViewModel {
    var searchText = ""
    var results: [OFFProduct] = []
    var isSearching = false
    var searchError: String?
    var selectedProduct: OFFProduct?
    var showManualForm = false
    var notFoundBarcode: String?
    var isLookingUpBarcode = false
    var scannerError: String?

    private var searchTask: Task<Void, Never>?
    private let service = OpenFoodFactsService.shared

    func submitSearch() {
        searchTask?.cancel()
        let term = searchText
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            searchError = nil
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            await self?.runSearch(term)
        }
    }

    func clearSearch() {
        searchText = ""
        results = []
        isSearching = false
        searchError = nil
        searchTask?.cancel()
    }

    func handleScannedCode(_ code: String) {
        guard !isLookingUpBarcode, selectedProduct == nil else { return }
        isLookingUpBarcode = true
        Task { [weak self] in
            await self?.lookup(code)
        }
    }

    func setScannerError(_ error: String?) {
        guard scannerError != error else { return }
        scannerError = error
    }

    func resumeScanner() {
        isLookingUpBarcode = false
    }

    private func runSearch(_ term: String) async {
        do {
            let products = try await service.search(term)
            guard !Task.isCancelled else { return }
            results = products.filter(\.hasNutrition)
            searchError = results.isEmpty ? "No foods found for “\(term)”." : nil
            isSearching = false
        } catch is CancellationError {
            // Superseded by a newer query.
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchError = (error as? OFFError)?.errorDescription ?? "Search failed."
            isSearching = false
        }
    }

    private func lookup(_ barcode: String) async {
        barcodeLog("lookup started: \(barcode)")
        do {
            let product = try await service.product(barcode: barcode)
            if product.hasNutrition {
                selectedProduct = product
                barcodeLog("lookup succeeded: \(barcode)")
            } else {
                notFoundBarcode = barcode
                isLookingUpBarcode = false
                barcodeLog("lookup no nutrition: \(barcode)")
            }
        } catch {
            notFoundBarcode = barcode
            isLookingUpBarcode = false
            barcodeLog("lookup failed: \(String(reflecting: type(of: error))): \(String(describing: error))")
        }
    }

    private func barcodeLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[BarcodeScanner] \(message())")
        #endif
    }
}

struct AddView: View {
    @State private var vm = AddViewModel()
    @State private var cameraStatus: AVAuthorizationStatus = CameraPermission.status
    @State private var panelExpanded = ProcessInfo.processInfo.arguments.contains("-uitest-expand-search")
    @State private var scannerGuideFrame: CGRect = .zero
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                switch cameraStatus {
                case .authorized:
                    BarcodeScannerView(
                        isActive: !vm.isLookingUpBarcode
                            && vm.selectedProduct == nil
                            && vm.notFoundBarcode == nil
                            && !vm.showManualForm
                            && scenePhase == .active,
                        regionOfInterest: scannerGuideFrame,
                        onCodeScanned: { code, _ in vm.handleScannedCode(code) },
                        onScannerError: vm.setScannerError
                    )
                        .ignoresSafeArea()
                case .notDetermined:
                    permissionPrompt
                default:
                    deniedView
                }

                if cameraStatus == .authorized {
                    scannerGuide
                        .allowsHitTesting(false)
                }

                VStack {
                    HStack {
                        Text("Scan")
                            .font(.title2.weight(.bold))
                        Spacer()
                        if cameraStatus == .authorized {
                            TorchButton()
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }

                searchMenu(maxHeight: geo.size.height)
            }
        }
        .onAppear(perform: ensureCameraPermission)
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let arg = args.first(where: { $0.hasPrefix("-uitest-search=") }) {
                vm.searchText = String(arg.dropFirst("-uitest-search=".count))
                vm.submitSearch()
            }
        }
        .onChange(of: searchFocused) { _, focused in
            if focused { panelExpanded = true }
        }
        .sheet(item: $vm.selectedProduct) { product in
            PortionPickerSheet(product: product)
                .presentationDetents([.medium, .large])
                .onDisappear {
                    vm.clearSearch()
                    vm.resumeScanner()
                }
        }
        .sheet(isPresented: $vm.showManualForm) {
            ManualFoodForm()
                .presentationDetents([.large])
        }
        .alert(
            "No nutrition data",
            isPresented: Binding(
                get: { vm.notFoundBarcode != nil },
                set: { _ in vm.notFoundBarcode = nil }
            )
        ) {
            Button("Add manually") {
                vm.showManualForm = true
                vm.notFoundBarcode = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We couldn't find nutrition info for this product. You can log it manually.")
        }
    }

    // MARK: - Scrollable bottom menu

    private var scannerGuide: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 320, height: 118)
                .onGeometryChange(for: CGRect.self, of: { proxy in
                    proxy.frame(in: .global)
                }) { frame in
                    scannerGuideFrame = frame
                }
                .shadow(color: .black.opacity(0.35), radius: 8)

            scannerStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 72)
    }

    @ViewBuilder
    private var scannerStatus: some View {
        if vm.isLookingUpBarcode {
            Label {
                Text("Looking up barcode…")
            } icon: {
                ProgressView()
                    .controlSize(.small)
            }
            .scannerStatusStyle
        } else if let scannerError = vm.scannerError {
            Label(scannerError, systemImage: "exclamationmark.triangle.fill")
                .scannerStatusStyle
        } else {
            Label("Align the barcode inside the frame", systemImage: "barcode.viewfinder")
                .scannerStatusStyle
        }
    }

    private func searchMenu(maxHeight: CGFloat) -> some View {
        let expandedHeight = maxHeight * 0.58
        let collapsedHeight: CGFloat = 120

        return VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
                .onTapGesture { togglePanel() }

            searchBar
                .padding(.horizontal, 16)

            if panelExpanded {
                menuContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelExpanded ? expandedHeight : collapsedHeight, alignment: .top)
        .background {
            Color.clear
                .glassEffect(
                    .regular,
                    in: ConcentricRectangle(corners: .concentric(minimum: .fixed(32)))
                )
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .animation(.smooth(duration: 0.35), value: panelExpanded)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < -20 && !panelExpanded {
                        panelExpanded = true
                    } else if value.translation.height > 20 && panelExpanded {
                        collapsePanel()
                    }
                }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search Open Food Facts…", text: Bindable(vm).searchText)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit(vm.submitSearch)
            if !vm.searchText.isEmpty {
                Button {
                    vm.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                vm.showManualForm = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.quinary.opacity(0.6), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var menuContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if vm.isSearching && vm.results.isEmpty {
                    ProgressView()
                        .padding(.vertical, 28)
                } else if vm.results.isEmpty {
                    VStack(spacing: 8) {
                        Text(vm.searchError ?? "Point the camera at a barcode,\nor type to search foods.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 26)
                } else {
                    ForEach(vm.results) { product in
                        SearchResultRow(product: product) {
                            searchFocused = false
                            collapsePanel()
                            vm.selectedProduct = product
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func togglePanel() {
        if panelExpanded {
            collapsePanel()
        } else {
            panelExpanded = true
        }
    }

    private func collapsePanel() {
        searchFocused = false
        panelExpanded = false
    }

    // MARK: - Permission states

    private var permissionPrompt: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .padding(24)
                .glassEffect(.regular, in: .circle)
            Text("Camera access needed")
                .font(.title3.weight(.semibold))
            Text("Allow camera access to scan barcodes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Allow camera") {
                CameraPermission.request { granted in
                    cameraStatus = granted ? .authorized : .denied
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 40))
                .padding(24)
                .glassEffect(.regular, in: .circle)
            Text("Camera unavailable")
                .font(.title3.weight(.semibold))
            Text("Steak needs the camera to scan barcodes.\nEnable it in Settings to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                CameraPermission.openSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureCameraPermission() {
        switch CameraPermission.status {
        case .notDetermined:
            CameraPermission.request { granted in
                cameraStatus = granted ? .authorized : .denied
            }
        case .authorized:
            cameraStatus = .authorized
        default:
            cameraStatus = .denied
        }
    }
}

// MARK: - Result row

struct SearchResultRow: View {
    let product: OFFProduct
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let kcal = product.kcalPer100g {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(kcal.kcalText)
                            .font(.headline.monospacedDigit())
                        Text("kcal/100g")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.quinary.opacity(0.5), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    var scannerStatusStyle: some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.52), in: .capsule)
    }
}
