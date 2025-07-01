//
//  PoseDetectionManager.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import Foundation
import AVFoundation
import Vision
import UIKit

class PoseDetectionManager: NSObject, ObservableObject {
    @Published var isCameraAvailable = false
    @Published var isDetecting = false
    @Published var faceAsymmetryScore: Double = 0.0
    @Published var armDriftScore: Double = 0.0
    @Published var armStrengthScore: Double = 0.0

    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()

    private var poseDetectionRequest: VNDetectHumanBodyPoseRequest?
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    
    // Analysis state
    private var faceObservations: [VNFaceObservation] = []
    private var poseObservations: [VNHumanBodyPoseObservation] = []
    private var analysisStartTime: Date?
    private var analysisDuration: TimeInterval = 3.0

    override init() {
        super.init()
        configureSession()
        setupPoseDetection()
        setupFaceDetection()
    }

    func requestCameraPermission() {
        print("Requesting camera permission...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera already authorized")
            startSession()
            isCameraAvailable = true
        case .notDetermined:
            print("Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    print("Camera permission granted: \(granted)")
                    self?.isCameraAvailable = granted
                    if granted {
                        self?.startSession()
                    }
                }
            }
        case .denied:
            print("Camera permission denied")
            isCameraAvailable = false
        case .restricted:
            print("Camera permission restricted")
            isCameraAvailable = false
        @unknown default:
            print("Unknown camera authorization status")
            isCameraAvailable = false
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else {
            print("Failed to configure camera input.")
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        print("Camera input added successfully")

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("Video output added successfully")
        } else {
            print("Unable to add video output.")
        }

        session.commitConfiguration()
        print("Camera session configured successfully")
    }

    private func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                DispatchQueue.main.async {
                    print("Camera session started successfully")
                }
            }
        }
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    print("Camera session stopped")
                }
            }
        }
    }

    private func setupPoseDetection() {
        poseDetectionRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            self?.handlePoseDetection(request: request, error: error)
        }
    }

    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
    }

    func startFaceDetection(completion: @escaping (Double, Double) -> Void) {
        isDetecting = true
        faceObservations.removeAll()
        analysisStartTime = Date()
        
        // Start analysis timer
        DispatchQueue.main.asyncAfter(deadline: .now() + analysisDuration) { [weak self] in
            guard let self = self else { return }
            self.isDetecting = false
            
            let (asymmetryScore, confidence) = self.calculateFaceAsymmetry()
            self.faceAsymmetryScore = asymmetryScore
            
            DispatchQueue.main.async {
                completion(asymmetryScore, confidence)
            }
        }
    }

    func startArmDetection(completion: @escaping (Double, Double, Double) -> Void) {
        isDetecting = true
        poseObservations.removeAll()
        analysisStartTime = Date()
        
        // Start analysis timer
        DispatchQueue.main.asyncAfter(deadline: .now() + analysisDuration) { [weak self] in
            guard let self = self else { return }
            self.isDetecting = false
            
            let (driftScore, strengthScore, confidence) = self.calculateArmMetrics()
            self.armDriftScore = driftScore
            self.armStrengthScore = strengthScore
            
            DispatchQueue.main.async {
                completion(driftScore, strengthScore, confidence)
            }
        }
    }

    func stopDetection() {
        isDetecting = false
    }

    private func handlePoseDetection(request: VNRequest, error: Error?) {
        if let error = error {
            print("Pose detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNHumanBodyPoseObservation] else { return }
        for observation in observations {
            poseObservations.append(observation)
        }
    }

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        if let error = error {
            print("Face detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNFaceObservation] else { return }
        for observation in observations {
            faceObservations.append(observation)
        }
    }

    private func calculateFaceAsymmetry() -> (asymmetryScore: Double, confidence: Double) {
        guard !faceObservations.isEmpty else {
            return (0.5, 0.0) // Neutral score with no confidence
        }
        
        var totalAsymmetry = 0.0
        var validObservations = 0
        
        for observation in faceObservations {
            guard let landmarks = observation.landmarks else { continue }
            
            // Calculate facial asymmetry using multiple landmarks
            let asymmetry = calculateFacialLandmarkAsymmetry(landmarks: landmarks)
            totalAsymmetry += asymmetry
            validObservations += 1
        }
        
        let averageAsymmetry = validObservations > 0 ? totalAsymmetry / Double(validObservations) : 0.5
        let confidence = min(Double(validObservations) / 10.0, 1.0) // Confidence based on number of observations
        
        return (averageAsymmetry, confidence)
    }
    
    private func calculateFacialLandmarkAsymmetry(landmarks: VNFaceLandmarks2D) -> Double {
        var asymmetryScore = 0.0
        var landmarkCount = 0
        
        // Check eye landmarks for asymmetry
        if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
            let eyeAsymmetry = calculateEyeAsymmetry(leftEye: leftEye, rightEye: rightEye)
            asymmetryScore += eyeAsymmetry
            landmarkCount += 1
        }
        
        // Check mouth landmarks for asymmetry
        if let outerLips = landmarks.outerLips {
            let mouthAsymmetry = calculateMouthAsymmetry(lips: outerLips)
            asymmetryScore += mouthAsymmetry
            landmarkCount += 1
        }
        
        // Check eyebrow landmarks for asymmetry
        if let leftEyebrow = landmarks.leftEyebrow, let rightEyebrow = landmarks.rightEyebrow {
            let eyebrowAsymmetry = calculateEyebrowAsymmetry(leftEyebrow: leftEyebrow, rightEyebrow: rightEyebrow)
            asymmetryScore += eyebrowAsymmetry
            landmarkCount += 1
        }
        
        return landmarkCount > 0 ? asymmetryScore / Double(landmarkCount) : 0.5
    }
    
    private func calculateEyeAsymmetry(leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D) -> Double {
        let leftEyeHeight = calculateRegionHeight(region: leftEye)
        let rightEyeHeight = calculateRegionHeight(region: rightEye)
        
        let heightDifference = abs(leftEyeHeight - rightEyeHeight)
        let averageHeight = (leftEyeHeight + rightEyeHeight) / 2.0
        
        return averageHeight > 0 ? min(heightDifference / averageHeight, 1.0) : 0.5
    }
    
    private func calculateMouthAsymmetry(lips: VNFaceLandmarkRegion2D) -> Double {
        let points = lips.normalizedPoints
        guard points.count >= 4 else { return 0.5 }
        
        // Calculate mouth corner asymmetry
        let leftCorner = points[0]
        let rightCorner = points[points.count / 2]
        
        let cornerHeightDifference = abs(leftCorner.y - rightCorner.y)
        return min(cornerHeightDifference * 2.0, 1.0) // Scale factor for better sensitivity
    }
    
    private func calculateEyebrowAsymmetry(leftEyebrow: VNFaceLandmarkRegion2D, rightEyebrow: VNFaceLandmarkRegion2D) -> Double {
        let leftHeight = calculateRegionHeight(region: leftEyebrow)
        let rightHeight = calculateRegionHeight(region: rightEyebrow)
        
        let heightDifference = abs(leftHeight - rightHeight)
        let averageHeight = (leftHeight + rightHeight) / 2.0
        
        return averageHeight > 0 ? min(heightDifference / averageHeight, 1.0) : 0.5
    }
    
    private func calculateRegionHeight(region: VNFaceLandmarkRegion2D) -> Double {
        let points = region.normalizedPoints
        guard !points.isEmpty else { return 0.0 }
        
        let minY = points.map { $0.y }.min() ?? 0.0
        let maxY = points.map { $0.y }.max() ?? 0.0
        
        return maxY - minY
    }

    private func calculateArmMetrics() -> (driftScore: Double, strengthScore: Double, confidence: Double) {
        guard !poseObservations.isEmpty else {
            return (0.5, 0.5, 0.0) // Neutral scores with no confidence
        }
        
        var totalDriftScore = 0.0
        var totalStrengthScore = 0.0
        var validObservations = 0
        
        for observation in poseObservations {
            let (drift, strength) = analyzeArmPosition(observation: observation)
            totalDriftScore += drift
            totalStrengthScore += strength
            validObservations += 1
        }
        
        let averageDrift = validObservations > 0 ? totalDriftScore / Double(validObservations) : 0.5
        let averageStrength = validObservations > 0 ? totalStrengthScore / Double(validObservations) : 0.5
        let confidence = min(Double(validObservations) / 10.0, 1.0)
        
        return (averageDrift, averageStrength, confidence)
    }

    private func analyzeArmPosition(observation: VNHumanBodyPoseObservation) -> (driftScore: Double, strengthScore: Double) {
        var driftScore = 0.5
        var strengthScore = 0.5
        
        do {
            // Get arm joint positions with confidence checks
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            let leftWrist = try observation.recognizedPoint(.leftWrist)
            let rightWrist = try observation.recognizedPoint(.rightWrist)
            let leftElbow = try observation.recognizedPoint(.leftElbow)
            let rightElbow = try observation.recognizedPoint(.rightElbow)
            
            // Check if points have sufficient confidence
            let minConfidence: Float = 0.3
            guard leftShoulder.confidence > minConfidence && rightShoulder.confidence > minConfidence &&
                  leftWrist.confidence > minConfidence && rightWrist.confidence > minConfidence &&
                  leftElbow.confidence > minConfidence && rightElbow.confidence > minConfidence else {
                return (driftScore, strengthScore)
            }
            
            // Calculate arm drift (vertical position difference)
            let leftArmHeight = leftWrist.location.y
            let rightArmHeight = rightWrist.location.y
            let heightDifference = abs(leftArmHeight - rightArmHeight)
            
            // Drift score: higher difference = higher drift (more abnormal)
            driftScore = min(heightDifference * 2.0, 1.0)
            
            // Calculate arm strength based on arm extension and stability
            let leftArmExtension = calculateArmExtension(wrist: leftWrist, elbow: leftElbow, shoulder: leftShoulder)
            let rightArmExtension = calculateArmExtension(wrist: rightWrist, elbow: rightElbow, shoulder: rightShoulder)
            
            // Strength score: lower extension = lower strength (more abnormal)
            let averageExtension = (leftArmExtension + rightArmExtension) / 2.0
            strengthScore = averageExtension
            
        } catch {
            print("Error analyzing arm position: \(error)")
        }
        
        return (driftScore, strengthScore)
    }
    
    private func calculateArmExtension(wrist: VNRecognizedPoint, elbow: VNRecognizedPoint, shoulder: VNRecognizedPoint) -> Double {
        // Calculate how extended the arm is (0 = fully bent, 1 = fully extended)
        let wristToElbow = distance(from: wrist.location, to: elbow.location)
        let elbowToShoulder = distance(from: elbow.location, to: shoulder.location)
        let wristToShoulder = distance(from: wrist.location, to: shoulder.location)
        
        // Arm extension ratio (should be close to 1.0 when fully extended)
        let extensionRatio = wristToShoulder / (wristToElbow + elbowToShoulder)
        
        return min(max(extensionRatio, 0.0), 1.0)
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension PoseDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isDetecting,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let requests = [poseDetectionRequest, faceDetectionRequest].compactMap { $0 }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform(requests)
        } catch {
            print("Detection error: \(error)")
        }
    }
}
