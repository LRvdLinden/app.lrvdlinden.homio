import AVFoundation
import Vision
import SwiftUI

/// Kijkt met de frontcamera of er iemand dichtbij staat. Alles gebeurt op het apparaat;
/// er wordt geen beeld bewaard of verstuurd. Zonder camera telt een aanraking 30 s als "dichtbij".
final class ProximityMonitor: NSObject, ObservableObject {
    @Published private(set) var isNear = true
    @Published private(set) var facePoint: CGPoint?   // 0...1, gespiegeld zoals een spiegel
    @Published private(set) var isRunning = false

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "nl.lrvdlinden.homio.proximity")
    private var configured = false
    private var lastAnalysis = Date.distantPast
    private var touchUntil = Date.distantPast
    private var faceNear = false
    private var lastFaceSeen = Date.distantPast

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self, granted else { return }
            self.queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    self.isRunning = running
                    self.update()
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isRunning = false
                self.facePoint = nil
                self.faceNear = false
                self.update()
            }
        }
    }

    /// Na een aanraking 30 seconden "dichtbij".
    func registerTouch() {
        touchUntil = Date().addingTimeInterval(30)
        update()
    }

    /// Elke seconde vanuit RootView.
    func tick() { update() }

    private func update() {
        let recentFace = faceNear || Date().timeIntervalSince(lastFaceSeen) < 8
        let near = !isRunning || recentFace || Date() < touchUntil
        if near != isNear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { isNear = near }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .low
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }
}

extension ProximityMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) > 0.4,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
        let biggest = (request.results ?? []).max {
            max($0.boundingBox.width, $0.boundingBox.height) < max($1.boundingBox.width, $1.boundingBox.height)
        }

        DispatchQueue.main.async {
            if let face = biggest {
                let size = max(face.boundingBox.width, face.boundingBox.height)
                self.faceNear = size > 0.22
                self.lastFaceSeen = self.faceNear ? Date() : self.lastFaceSeen
                self.facePoint = CGPoint(x: 1 - face.boundingBox.midX, y: 1 - face.boundingBox.midY)
            } else {
                self.faceNear = false
                self.facePoint = nil
            }
            self.update()
        }
    }
}
