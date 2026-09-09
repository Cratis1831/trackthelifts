//
//  BarcodeScanView.swift
//  TrackTheLifts
//

import AVFoundation
import SwiftUI

struct BarcodeScanView: View {
    let customFoods: [CustomFood]
    var onFoodPicked: (FoodEntryDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorized = false
    @State private var permissionDenied = false
    @State private var isLookingUp = false
    @State private var handledCode: String?
    @State private var notFoundCode: String?
    @State private var errorMessage: String?
    @State private var manualCode = ""

    private var cameraReady: Bool {
        cameraAuthorized && AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                if cameraReady {
                    scanner
                } else {
                    fallback
                }

                if isLookingUp {
                    lookupOverlay
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .task {
                await requestCamera()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            BarcodeCameraRepresentable(
                isPaused: isLookingUp || notFoundCode != nil,
                onBarcode: { code in
                    Task { await handleScan(code) }
                }
            )
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                if let notFoundCode {
                    notFoundCard(notFoundCode)
                } else if let errorMessage {
                    statusCard(title: "Couldn't look that up", message: errorMessage)
                } else {
                    Text("Place the barcode inside the box")
                        .font(.appCaption)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                }
            }
            .padding(20)
        }
    }

    private var fallback: some View {
        VStack(spacing: 20) {
            IconTile(color: .appAccent, size: 52) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
            }

            Text(permissionDenied ? "Camera access is off" : "Camera isn't available")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.appTextPrimary)

            Text(
                permissionDenied
                    ? "Turn on camera access in Settings to scan packaged foods."
                    : "Type a UPC or EAN to look it up in the catalogue. This is also how the simulator tests barcode lookup."
            )
            .font(.appBody)
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if permissionDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Barcode")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                TextField("012345678901", text: $manualCode)
                    .keyboardType(.numberPad)
                    .foregroundColor(.appTextPrimary)
                    .appInputSurface()
            }

            Button("Look Up") {
                Task { await handleScan(manualCode) }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(Barcode.normalize(manualCode).count < 8 || isLookingUp)

            if let notFoundCode {
                notFoundCard(notFoundCode)
            } else if let errorMessage {
                statusCard(title: "Couldn't look that up", message: errorMessage)
            }

            Spacer()
        }
        .padding(24)
    }

    private var lookupOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Looking up product…")
                    .font(.appCaption)
                    .foregroundColor(.appTextPrimary)
            }
            .padding(20)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
        }
    }

    private func notFoundCard(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product not in the catalogue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextPrimary)
            Text("No USDA or Open Food Facts match for \(code). Enter it manually for now. Nutrition Facts scanning comes in a later update.")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Enter Manually") {
                onFoodPicked(.manualBarcode(code))
            }
            .buttonStyle(AppPrimaryButtonStyle())
            Button("Scan Again") {
                notFoundCode = nil
                handledCode = nil
                errorMessage = nil
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .appCard()
    }

    private func statusCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .appCard()
    }

    private func requestCamera() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !cameraAuthorized
        default:
            cameraAuthorized = false
            permissionDenied = true
        }
    }

    @MainActor
    private func handleScan(_ raw: String) async {
        let code = Barcode.normalize(raw)
        guard code.count >= 8 else {
            errorMessage = "That barcode does not look valid."
            return
        }
        guard handledCode != code else { return }

        handledCode = code
        notFoundCode = nil
        errorMessage = nil

        if let local = customFoods.first(where: { Barcode.matches($0.barcode, code) }) {
            onFoodPicked(local.draft)
            return
        }

        isLookingUp = true
        defer { isLookingUp = false }

        do {
            let result = try await ForgeLyteSession.shared.lookupBarcode(code)
            if let food = result.food, !result.needsLabelScan {
                onFoodPicked(food.draft)
            } else {
                notFoundCode = code
            }
        } catch {
            handledCode = nil
            errorMessage = error.localizedDescription
        }
    }
}

enum BarcodeScanBox {
    static let cornerRadius: CGFloat = 12

    static func rect(in size: CGSize) -> CGRect {
        let inset: CGFloat = 28
        let width = min(max(size.width - inset * 2, 0), 340)
        let height = max(128, width * 0.42)
        let y = max((size.height - height) / 2 - 36, 24)
        return CGRect(
            x: (size.width - width) / 2,
            y: y,
            width: width,
            height: height
        )
    }

    static func contains(_ barcodeBounds: CGRect, in size: CGSize) -> Bool {
        let box = rect(in: size)
        let intersection = barcodeBounds.intersection(box)
        guard !intersection.isNull, !barcodeBounds.isEmpty else { return false }
        let coverage =
            (intersection.width * intersection.height)
            / (barcodeBounds.width * barcodeBounds.height)
        return coverage >= 0.7
    }
}

private struct BarcodeCameraRepresentable: UIViewControllerRepresentable {
    var isPaused: Bool
    var onBarcode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let controller = BarcodeCameraViewController()
        controller.delegate = context.coordinator
        controller.accentColor = UIColor(Color.appAccent)
        return controller
    }

    func updateUIViewController(_ controller: BarcodeCameraViewController, context: Context) {
        context.coordinator.onBarcode = onBarcode
        controller.isPaused = isPaused
        controller.accentColor = UIColor(Color.appAccent)
    }

    static func dismantleUIViewController(
        _ controller: BarcodeCameraViewController,
        coordinator: Coordinator
    ) {
        controller.stop()
    }

    final class Coordinator: NSObject, BarcodeCameraViewControllerDelegate {
        var onBarcode: (String) -> Void

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func barcodeCamera(_ camera: BarcodeCameraViewController, didRead code: String) {
            onBarcode(code)
        }
    }
}

private protocol BarcodeCameraViewControllerDelegate: AnyObject {
    func barcodeCamera(_ camera: BarcodeCameraViewController, didRead code: String)
}

private final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeCameraViewControllerDelegate?
    var isPaused = false
    var accentColor: UIColor = .white {
        didSet { overlay.accentColor = accentColor }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ashkansdev.track-the-lifts.barcode")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let overlay = ScanBoxOverlayView()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasConfiguredSession = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overlay.backgroundColor = .clear
        overlay.isOpaque = false
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        overlay.frame = view.bounds
        overlay.setNeedsDisplay()
        updateInterestRect()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureSession() {
        guard !hasConfiguredSession else { return }
        hasConfiguredSession = true

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            if self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                let requested: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce]
                self.metadataOutput.metadataObjectTypes = requested.filter {
                    self.metadataOutput.availableMetadataObjectTypes.contains($0)
                }
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                let preview = AVCaptureVideoPreviewLayer(session: self.session)
                preview.videoGravity = .resizeAspectFill
                preview.frame = self.view.bounds
                if let connection = preview.connection, connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                self.view.layer.insertSublayer(preview, at: 0)
                self.previewLayer = preview
                self.updateInterestRect()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.updateInterestRect()
            }
        }
    }

    private func updateInterestRect() {
        guard let previewLayer, metadataOutput.connection(with: .metadata) != nil else { return }
        let box = BarcodeScanBox.rect(in: view.bounds.size)
        metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: box)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isPaused, let previewLayer else { return }

        for object in metadataObjects {
            guard
                let readable = object as? AVMetadataMachineReadableCodeObject,
                let code = readable.stringValue,
                !code.isEmpty,
                let transformed = previewLayer.transformedMetadataObject(for: object)
            else { continue }

            if BarcodeScanBox.contains(transformed.bounds, in: view.bounds.size) {
                delegate?.barcodeCamera(self, didRead: code)
                return
            }
        }
    }
}

private final class ScanBoxOverlayView: UIView {
    var accentColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let box = BarcodeScanBox.rect(in: bounds.size)
        let radius = BarcodeScanBox.cornerRadius

        context.saveGState()
        context.addRect(bounds)
        context.addPath(UIBezierPath(roundedRect: box, cornerRadius: radius).cgPath)
        context.setFillColor(UIColor.black.withAlphaComponent(0.58).cgColor)
        context.drawPath(using: .eoFill)
        context.restoreGState()

        let border = UIBezierPath(roundedRect: box, cornerRadius: radius)
        UIColor.white.withAlphaComponent(0.22).setStroke()
        border.lineWidth = 1
        border.stroke()

        drawCorners(in: box)
    }

    private func drawCorners(in box: CGRect) {
        let length: CGFloat = 22
        let thickness: CGFloat = 3
        let inset: CGFloat = 1
        let color = accentColor
        color.setStroke()

        func stroke(_ points: [CGPoint]) {
            let path = UIBezierPath()
            path.lineWidth = thickness
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.stroke()
        }

        let minX = box.minX + inset
        let minY = box.minY + inset
        let maxX = box.maxX - inset
        let maxY = box.maxY - inset

        stroke([CGPoint(x: minX, y: minY + length), CGPoint(x: minX, y: minY), CGPoint(x: minX + length, y: minY)])
        stroke([CGPoint(x: maxX - length, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: maxX, y: minY + length)])
        stroke([CGPoint(x: minX, y: maxY - length), CGPoint(x: minX, y: maxY), CGPoint(x: minX + length, y: maxY)])
        stroke([CGPoint(x: maxX - length, y: maxY), CGPoint(x: maxX, y: maxY), CGPoint(x: maxX, y: maxY - length)])
    }
}
