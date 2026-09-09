//
//  LabelScanView.swift
//  TrackTheLifts
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct LabelScanView: View {
    var barcode: String? = nil
    var onFoodPicked: (FoodEntryDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorized = false
    @State private var permissionDenied = false
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var captureTick: UInt = 0
    @State private var pickedItem: PhotosPickerItem?

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

                if isReading {
                    readingOverlay
                }
            }
            .navigationTitle("Scan Nutrition Facts")
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
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { await handlePickedItem(item) }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            LabelScanCameraRepresentable(
                captureTick: captureTick,
                onPhoto: { image in
                    Task { await handleImage(image) }
                }
            )
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 14) {
                if let errorMessage {
                    statusCard(title: "Not a Nutrition Facts label", message: errorMessage)
                } else {
                    Text("Align the Nutrition Facts panel")
                        .font(.appCaption)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                }

                Button {
                    errorMessage = nil
                    captureTick += 1
                } label: {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                }
                .disabled(isReading)
                .accessibilityLabel("Capture Nutrition Facts")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private var fallback: some View {
        VStack(spacing: 20) {
            IconTile(color: .appAccent, size: 52) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
            }

            Text(permissionDenied ? "Camera access is off" : "Camera isn't available")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.appTextPrimary)

            Text(
                permissionDenied
                    ? "Turn on camera access in Settings to scan a Nutrition Facts panel."
                    : "Choose a photo of the Nutrition Facts panel. This is also how the simulator tests label scanning."
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

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Text("Choose Photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(isReading)

            if let errorMessage {
                statusCard(title: "Not a Nutrition Facts label", message: errorMessage)
            }

            Spacer()
        }
        .padding(24)
    }

    private var readingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Reading Nutrition Facts…")
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

    private func statusCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
    private func handlePickedItem(_ item: PhotosPickerItem) async {
        pickedItem = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "That photo could not be opened."
                return
            }
            await handleImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleImage(_ image: UIImage) async {
        errorMessage = nil
        isReading = true
        defer { isReading = false }

        do {
            let lines = try await NutritionFactsLabelGate.recognizedLines(in: image)
            guard NutritionFactsLabelGate.looksLikeNutritionFacts(lines) else {
                errorMessage = NutritionFactsLabelGate.missingLabelMessage
                return
            }
            guard let jpeg = NutritionFactsLabelGate.preparedJPEG(image) else {
                errorMessage = "That photo could not be compressed."
                return
            }

            let food = try await ForgeLyteSession.shared.scanNutritionLabel(
                jpeg,
                barcode: barcode
            )
            var draft = food.draft
            if let barcode, draft.barcode == nil || draft.barcode?.isEmpty == true {
                draft.barcode = barcode
            }
            onFoodPicked(draft)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum LabelScanBox {
    static let cornerRadius: CGFloat = 12

    static func rect(in size: CGSize) -> CGRect {
        let inset: CGFloat = 36
        let width = min(max(size.width - inset * 2, 0), 280)
        let height = min(max(width * 1.52, 220), size.height * 0.58)
        let y = max((size.height - height) / 2 - 48, 28)
        return CGRect(
            x: (size.width - width) / 2,
            y: y,
            width: width,
            height: height
        )
    }
}

private struct LabelScanCameraRepresentable: UIViewControllerRepresentable {
    var captureTick: UInt
    var onPhoto: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto)
    }

    func makeUIViewController(context: Context) -> LabelScanCameraViewController {
        let controller = LabelScanCameraViewController()
        controller.delegate = context.coordinator
        controller.accentColor = UIColor(Color.appAccent)
        return controller
    }

    func updateUIViewController(_ controller: LabelScanCameraViewController, context: Context) {
        context.coordinator.onPhoto = onPhoto
        controller.accentColor = UIColor(Color.appAccent)
        if context.coordinator.lastCaptureTick != captureTick {
            context.coordinator.lastCaptureTick = captureTick
            if captureTick > 0 {
                controller.capturePhoto()
            }
        }
    }

    static func dismantleUIViewController(
        _ controller: LabelScanCameraViewController,
        coordinator: Coordinator
    ) {
        controller.stop()
    }

    final class Coordinator: NSObject, LabelScanCameraViewControllerDelegate {
        var onPhoto: (UIImage) -> Void
        var lastCaptureTick: UInt = 0

        init(onPhoto: @escaping (UIImage) -> Void) {
            self.onPhoto = onPhoto
        }

        func labelCamera(_ camera: LabelScanCameraViewController, didCapture image: UIImage) {
            onPhoto(image)
        }
    }
}

private protocol LabelScanCameraViewControllerDelegate: AnyObject {
    func labelCamera(_ camera: LabelScanCameraViewController, didCapture image: UIImage)
}

private final class LabelScanCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    weak var delegate: LabelScanCameraViewControllerDelegate?
    var accentColor: UIColor = .white {
        didSet { overlay.accentColor = accentColor }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ashkansdev.track-the-lifts.label-scan")
    private let photoOutput = AVCapturePhotoOutput()
    private let overlay = LabelScanOverlayView()
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

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.photoOutput.connection(with: .video) != nil else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession() {
        guard !hasConfiguredSession else { return }
        hasConfiguredSession = true

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

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
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                let preview = AVCaptureVideoPreviewLayer(session: self.session)
                preview.videoGravity = .resizeAspectFill
                preview.frame = self.view.bounds
                if let connection = preview.connection, connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                self.view.layer.insertSublayer(preview, at: 0)
                self.previewLayer = preview
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.labelCamera(self, didCapture: image)
        }
    }
}

private final class LabelScanOverlayView: UIView {
    var accentColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let box = LabelScanBox.rect(in: bounds.size)
        let radius = LabelScanBox.cornerRadius

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
        accentColor.setStroke()

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
