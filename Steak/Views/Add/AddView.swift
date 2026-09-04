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
    @State private var panelProgress: CGFloat = ProcessInfo.processInfo.arguments.contains("-uitest-expand-search") ? 1 : 0
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3, bounce: 0.12)))
    private var panelDragTranslation: CGFloat = 0
    @ScaledMetric(relativeTo: .headline) private var panelHeaderHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var searchControlHeight: CGFloat = 52
    @State private var scannerGuideFrame: CGRect = .zero
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if cameraStatus == .authorized {
                    Color.black.ignoresSafeArea()
                } else {
                    AtmosphericBackground()
                }

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
                        Text("Scan & snack")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(cameraStatus == .authorized ? Color.white : Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(cameraStatus == .authorized ? Color.steakAccent : .clear, in: RoundedRectangle(cornerRadius: 16))
                        Spacer()
                        if cameraStatus == .authorized {
                            TorchButton()
                        }
                    }
                    .padding(.horizontal, Layout.xLarge)
                    .padding(.bottom, 12)
                    .background(Theme.paper.ignoresSafeArea(edges: .top))
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
            if focused { setPanelProgress(1) }
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
                .strokeBorder(.white, lineWidth: 5)
                .frame(maxWidth: 320)
                .frame(height: 118)
                .padding(.horizontal, 24)
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
        let collapsedHeight = min(maxHeight, panelHeaderHeight + searchControlHeight + 36)
        let expandedHeight = max(collapsedHeight, maxHeight * 0.78)
        let travel = expandedHeight - collapsedHeight
        let offset = SearchPanelAnchors.displayOffset(
            travel * panelProgress - panelDragTranslation, travel: travel)
        let height = collapsedHeight + max(0, offset)
        let isOpen = height > collapsedHeight + 1
        let panelShape = ConcentricRectangle(
            uniformTopCorners: .concentric(minimum: .fixed(Layout.largeCornerRadius)),
            uniformBottomCorners: .concentric
        )

        return VStack(spacing: 0) {
            Button(action: togglePanel) {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Theme.muted.opacity(0.5))
                        .frame(width: 36, height: 4)
                        .accessibilityHidden(true)
                    HStack {
                        Text("Find your food").font(.headline.weight(.heavy))
                        Spacer()
                        Image(systemName: isOpen ? "chevron.down" : "chevron.up")
                            .font(.subheadline.weight(.heavy))
                    }
                    .frame(minHeight: panelHeaderHeight)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Collapse food search" : "Expand food search")
            .accessibilityValue("\(Int(panelProgress * 100)) percent expanded")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: setPanelProgress(min(1, panelProgress + 0.25))
                case .decrement:
                    let progress = max(0, panelProgress - 0.25)
                    if progress == 0 { searchFocused = false }
                    setPanelProgress(progress)
                @unknown default: break
                }
            }
            .highPriorityGesture(panelDrag(travel: travel))

            searchBar
                .padding(.horizontal, Layout.large)

            menuContent
                .frame(maxHeight: .infinity)
                .clipped()
                .allowsHitTesting(isOpen)
                .accessibilityHidden(!isOpen)
        }
        .padding(.bottom, Layout.large)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .clipped()
        .background {
            Color.clear
                .glassEffect(.regular, in: panelShape)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .offset(y: max(0, -offset))
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }

    private func panelDrag(travel: CGFloat) -> some Gesture {
        // Global coordinates keep the drag stable while the header itself moves.
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($panelDragTranslation) { value, translation, transaction in
                transaction.animation = nil
                translation = value.translation.height
            }
            .onEnded { value in
                guard travel > 0 else { return }
                let progress = SearchPanelAnchors.restingProgress(
                    panelProgress * travel - value.translation.height, travel: travel)
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.12)) {
                    panelProgress = progress
                }
                if panelProgress == 0 { searchFocused = false }
            }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search food…", text: Bindable(vm).searchText)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit(vm.submitSearch)
            if !vm.searchText.isEmpty {
                Button {
                    vm.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
            Button {
                vm.showManualForm = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Add food manually")
        }
        .padding(.horizontal, Layout.medium)
        .frame(minHeight: searchControlHeight)
        .steakPanel(radius: 14)
    }

    @ViewBuilder
    private var menuContent: some View {
        ScrollView {
            LazyVStack(spacing: Layout.small) {
                if vm.isSearching && vm.results.isEmpty {
                    ProgressView()
                        .padding(.vertical, 28)
                } else if vm.results.isEmpty {
                    VStack(spacing: 8) {
                        Text(vm.searchError ?? "Point the camera at a barcode,\nor type to search foods.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
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
            .padding(.horizontal, Layout.large)
            .padding(.vertical, Layout.medium)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func togglePanel() {
        if panelProgress > 0 {
            collapsePanel()
        } else {
            setPanelProgress(1)
        }
    }

    private func collapsePanel() {
        searchFocused = false
        setPanelProgress(0)
    }

    private func setPanelProgress(_ progress: CGFloat) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            panelProgress = progress
        }
    }

    // MARK: - Permission states

    private var permissionPrompt: some View {
        Group {
            VStack(spacing: Layout.xLarge) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .padding(Layout.xxLarge)
                    .foregroundStyle(Color.steakTint)
                    .steakPanel(fill: Theme.blush, radius: 24, raised: true)
                Text("Camera access needed")
                    .font(.title3.weight(.semibold))
                Text("Allow camera access to scan barcodes.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Button("Allow camera") {
                    CameraPermission.request { granted in
                        cameraStatus = granted ? .authorized : .denied
                    }
                }
                .buttonStyle(SteakButtonStyle())
                .tint(.steakTint)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        Group {
            VStack(spacing: Layout.xLarge) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 40))
                    .padding(Layout.xxLarge)
                    .foregroundStyle(Color.steakTint)
                    .steakPanel(fill: Theme.blush, radius: 24, raised: true)
                Text("Camera unavailable")
                    .font(.title3.weight(.semibold))
                Text("Steak needs the camera to scan barcodes.\nEnable it in Settings to continue.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    CameraPermission.openSettings()
                }
                .buttonStyle(SteakButtonStyle())
                .tint(.steakTint)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 140)
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

private enum SearchPanelAnchors {
    static func displayOffset(_ offset: CGFloat, travel: CGFloat) -> CGFloat {
        guard travel > 0 else { return 0 }
        if offset < 0 { return -resistedDistance(-offset) }
        if offset > travel { return travel + resistedDistance(offset - travel) }

        let range = min(24, travel / 4)
        let distance = min(offset, travel - offset)
        guard distance < range else { return offset }
        let fraction = distance / range
        // Ease into each anchor without changing movement in the middle of the panel's travel.
        let attractedDistance = range * fraction * fraction * (2 - fraction)
        return offset < travel / 2 ? attractedDistance : travel - attractedDistance
    }

    static func restingProgress(_ offset: CGFloat, travel: CGFloat) -> CGFloat {
        guard travel > 0 else { return 0 }
        let range = min(24, travel / 4)
        if offset <= range { return 0 }
        if offset >= travel - range { return 1 }
        return offset / travel
    }

    private static func resistedDistance(_ distance: CGFloat) -> CGFloat {
        // Overpull approaches 12 points, even when the finger travels far past an anchor.
        12 * (distance / (distance + 48))
    }
}

// MARK: - Result row

struct SearchResultRow: View {
    let product: OFFProduct
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.medium) {
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
            .padding(.horizontal, Layout.medium)
            .padding(.vertical, Layout.medium)
            .steakPanel(radius: 14)
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
