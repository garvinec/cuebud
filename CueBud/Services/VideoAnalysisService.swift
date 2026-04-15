import AVFoundation
import Vision
import Combine

/// Manages AVCaptureSession + Vision framework pipeline for posture/face analysis
@MainActor
final class VideoAnalysisService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var latestSnapshot: PostureSnapshot?

    /// Publisher for new posture snapshots
    let snapshotSubject = PassthroughSubject<PostureSnapshot, Never>()

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.cuebud.video-processing", qos: .userInitiated)

    // Throttle: process every ~300ms (3 fps)
    private nonisolated(unsafe) var lastProcessTime: Date = .distantPast
    private let minProcessInterval: TimeInterval = 0.3

    func start() {
        guard !isRunning else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .medium // 640x480

        // Find front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to access front camera")
            return
        }

        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        videoOutput = output
        isRunning = true

        // Start capture on background thread
        processingQueue.async {
            session.startRunning()
        }
    }

    func stop() {
        isRunning = false
        processingQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        captureSession = nil
        videoOutput = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoAnalysisService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= minProcessInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        analyzeFrame(pixelBuffer: pixelBuffer, timestamp: now)
    }

    nonisolated private func analyzeFrame(pixelBuffer: CVPixelBuffer, timestamp: Date) {
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        let faceDetectRequest = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([bodyPoseRequest, faceLandmarksRequest, faceDetectRequest])
        } catch {
            return
        }

        let snapshot = buildSnapshot(
            bodyPose: bodyPoseRequest.results?.first,
            faceLandmarks: faceLandmarksRequest.results?.first,
            faceRect: faceDetectRequest.results?.first,
            timestamp: timestamp,
            imageSize: CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
        )

        Task { @MainActor in
            self.latestSnapshot = snapshot
            self.snapshotSubject.send(snapshot)
        }
    }

    nonisolated private func buildSnapshot(
        bodyPose: VNHumanBodyPoseObservation?,
        faceLandmarks: VNFaceObservation?,
        faceRect: VNFaceObservation?,
        timestamp: Date,
        imageSize: CGSize
    ) -> PostureSnapshot {
        // Shoulder-nose ratio for slouch detection
        var shoulderNoseRatio: Double?
        if let pose = bodyPose {
            let nosePoint = try? pose.recognizedPoint(.nose)
            let leftShoulder = try? pose.recognizedPoint(.leftShoulder)
            let rightShoulder = try? pose.recognizedPoint(.rightShoulder)

            if let nose = nosePoint, let ls = leftShoulder, let rs = rightShoulder,
               nose.confidence > 0.3 && ls.confidence > 0.3 && rs.confidence > 0.3 {
                let avgShoulderY = (ls.location.y + rs.location.y) / 2
                shoulderNoseRatio = nose.location.y - avgShoulderY
            }
        }

        // Gaze direction from face bounding box position in frame
        // (eye landmarks are relative to face box and don't change on head turn)
        var gazeH: Double?
        var gazeV: Double?
        if let rect = faceRect {
            // Face center in normalized image coordinates (0-1)
            gazeH = Double(rect.boundingBox.midX) - 0.5  // 0 = centered
            gazeV = Double(rect.boundingBox.midY) - 0.5
        }

        // Smile detection from mouth landmarks
        var smileConfidence: Double?
        if let face = faceLandmarks, let landmarks = face.landmarks,
           let outerLips = landmarks.outerLips {
            let points = outerLips.normalizedPoints
            if points.count >= 6 {
                // Simple smile heuristic: width-to-height ratio of mouth
                let xs = points.map { $0.x }
                let ys = points.map { $0.y }
                let width = (xs.max() ?? 0) - (xs.min() ?? 0)
                let height = (ys.max() ?? 0) - (ys.min() ?? 0)
                if height > 0 {
                    let ratio = width / height
                    // Wider mouth relative to height = more smile
                    smileConfidence = min(1.0, max(0, (ratio - 2.0) / 3.0))
                }
            }
        }

        // Head tilt from face observation roll angle
        // (body pose ears are often undetected at close range)
        var headTilt: Double?
        if let face = faceLandmarks {
            // roll is in radians, positive = counterclockwise
            headTilt = Double(face.roll?.doubleValue ?? 0) * 180 / .pi
        }

        // Face size and position
        var faceSizeFraction: Double?
        var faceVerticalCenter: Double?
        if let rect = faceRect {
            faceSizeFraction = Double(rect.boundingBox.width * rect.boundingBox.height)
            // Vision coordinates: Y=0 is bottom, Y=1 is top
            faceVerticalCenter = Double(rect.boundingBox.midY)
        }

        let personDetected = bodyPose != nil || faceLandmarks != nil

        return PostureSnapshot(
            timestamp: timestamp,
            shoulderNoseRatio: shoulderNoseRatio,
            gazeHorizontalOffset: gazeH,
            gazeVerticalOffset: gazeV,
            smileConfidence: smileConfidence,
            headTiltDegrees: headTilt,
            faceSizeFraction: faceSizeFraction,
            faceVerticalCenter: faceVerticalCenter,
            personDetected: personDetected
        )
    }
}
