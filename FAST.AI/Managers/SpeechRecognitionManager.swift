//
//  SpeechRecognitionManager.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject, ObservableObject {
    @Published var isMicrophoneAvailable = false
    @Published var transcribedText = ""
    @Published var speechClarityScore: Double = 0.0
    @Published var speechConfidence: Double = 0.0
    @Published var isRecording = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var clarityHandler: ((Double, Double) -> Void)?
    private var expectedText = ""
    private var recordingStartTime: Date?
    private var speechSegments: [SpeechSegment] = []
    private var hasRequestedPermissions = false
    private var recordingTimer: Timer?
    private let speechSegmentsQueue = DispatchQueue(label: "speechSegments")
    private var hasCompletedAnalysis = false
    private var errorRetryCount = 0
    private let maxRetryCount = 2
    private var isResetting = false
    private var hasCalledCompletion = false
    private var isCompleting = false
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    deinit {
        print("SpeechRecognitionManager deallocated")
        cleanupRecording()
    }
    
    private func setupSpeechRecognizer() {
        // Initialize speech recognizer with proper locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // Check if speech recognition is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognition is not available on this device")
            return
        }
        
        print("Speech recognizer initialized successfully")
        requestPermissions()
    }
    
    private func requestPermissions() {
        guard !hasRequestedPermissions else { return }
        hasRequestedPermissions = true
        
        // Request microphone permission first
        requestMicrophonePermission()
        
        // Request speech recognition permission
        requestSpeechPermission()
    }
    
    func requestMicrophonePermission() {
        print("Requesting microphone permission...")
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                print("Microphone permission granted: \(granted)")
                self?.isMicrophoneAvailable = granted
                
                if granted {
                    print("Microphone is now available for recording")
                } else {
                    print("Microphone permission denied - speech recognition will not work")
                }
            }
        }
    }
    
    private func requestSpeechPermission() {
        print("Requesting speech recognition permission...")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied:
                    print("Speech recognition permission denied.")
                case .restricted:
                    print("Speech recognition permission restricted.")
                case .notDetermined:
                    print("Speech recognition permission not determined.")
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                }
            }
        }
    }
    
    func resetSpeechRecognizer() {
        print("Resetting speech recognizer...")
        
        // Prevent multiple simultaneous resets
        guard !isResetting else {
            print("Reset already in progress, skipping")
            return
        }
        
        isResetting = true
        
        // Reset state
        resetManagerState()
        
        // Clean up existing resources
        cleanupRecording()
        
        // Reset speech recognizer
        speechRecognizer = nil
        
        // Wait a moment then reinitialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupSpeechRecognizer()
            self.isResetting = false
        }
    }
    
    private func resetManagerState() {
        isRecording = false
        hasCompletedAnalysis = false
        hasCalledCompletion = false
        isCompleting = false
        errorRetryCount = 0
        transcribedText = ""
        speechClarityScore = 0.0
        speechConfidence = 0.0
        
        // Clear speech segments safely
        speechSegmentsQueue.async(flags: .barrier) {
            self.speechSegments.removeAll()
        }
        
        // Cancel timer
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func isSpeechRecognitionSupported() -> Bool {
        guard let speechRecognizer = speechRecognizer else { return false }
        return speechRecognizer.isAvailable && SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func startRecording(expectedText: String, completion: @escaping (Double, Double) -> Void) {
        // Check if already recording
        guard !isRecording else {
            print("Already recording, ignoring start request")
            return
        }
        
        // Check if reset is in progress
        guard !isResetting else {
            print("Speech recognizer is resetting, ignoring start request")
            completion(0.0, 0.0)
            return
        }
        
        // Check permissions
        guard isMicrophoneAvailable else {
            print("Microphone not available")
            completion(0.0, 0.0)
            return
        }
        
        // Check speech recognizer availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer is not available")
            completion(0.0, 0.0)
            return
        }
        
        // Check authorization status
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            print("Speech recognition not authorized. Status: \(authStatus.rawValue)")
            completion(0.0, 0.0)
            return
        }

        self.expectedText = expectedText.lowercased()
        self.clarityHandler = completion
        self.recordingStartTime = Date()
        self.hasCompletedAnalysis = false
        self.errorRetryCount = 0
        self.hasCalledCompletion = false
        
        // Clear speech segments safely
        speechSegmentsQueue.async(flags: .barrier) {
            self.speechSegments.removeAll()
        }
        self.transcribedText = ""
        self.isRecording = true

        // Configure audio session properly
        configureAudioSession()
        
        // Set up a timeout timer (30 seconds max recording time)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            print("Recording timeout reached")
            self?.stopRecording()
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            isRecording = false
            completion(0.0, 0.0)
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        
        // Check if audio engine is already running
        guard !audioEngine.isRunning else {
            print("Audio engine is already running, stopping first")
            stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startRecording(expectedText: expectedText, completion: completion)
            }
            return
        }
        
        print("Audio input node is available")

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("Recording format: \(recordingFormat)")
        
        // Safety check for audio input node
        guard audioEngine.inputNode.numberOfInputs > 0 else {
            print("Audio input node has no inputs available")
            cleanupRecording()
            isRecording = false
            completion(0.0, 0.0)
            return
        }
        
        // Safety check for recording format
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("Invalid recording format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
            cleanupRecording()
            isRecording = false
            completion(0.0, 0.0)
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        // Set up the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let bestString = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = bestString
                    print("Transcribed: \(bestString)")
                }
                
                // Analyze speech segments for clarity
                self.analyzeSpeechSegments(result.bestTranscription.segments)
            }

            if let error = error {
                print("Speech recognition error: \(error)")
                print("Error domain: \(error._domain), code: \(error._code)")
                
                // Handle specific error codes
                if error._domain == "kAFAssistantErrorDomain" && error._code == 1101 {
                    print("Local speech recognition service error - this is often a temporary issue")
                    
                    // Only retry if we haven't exceeded max retries and not already resetting
                    if self.errorRetryCount < self.maxRetryCount && !self.isResetting {
                        self.errorRetryCount += 1
                        print("Retry attempt \(self.errorRetryCount) of \(self.maxRetryCount)")
                        
                        // Try to reset the speech recognizer and retry once
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.resetSpeechRecognizer()
                        }
                    } else {
                        print("Max retries reached or reset in progress, stopping retries")
                    }
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                // Calculate final speech clarity score with a small delay to ensure segments are fully processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    // Check if self is still valid
                    guard let self = self else {
                        print("SpeechRecognitionManager deallocated, skipping completion")
                        return
                    }
                    
                    print("Calculating final speech clarity...")
                    
                    // Prevent multiple completions
                    guard !self.hasCompletedAnalysis else {
                        print("Analysis already completed, skipping")
                        return
                    }
                    
                    // Add additional safety check
                    guard !self.isRecording else {
                        print("Still recording, skipping calculation")
                        return
                    }
                    
                    // Check if we have any segments to analyze
                    var segmentCount = 0
                    self.speechSegmentsQueue.sync {
                        segmentCount = self.speechSegments.count
                    }
                    
                    guard segmentCount > 0 else {
                        print("No segments available for analysis")
                        self.hasCompletedAnalysis = true
                        self.isCompleting = false
                        completion(0.5, 0.0)
                        return
                    }
                    
                    self.hasCompletedAnalysis = true
                    self.isCompleting = true
                    
                    // Create a local copy of the completion handler to prevent issues during deallocation
                    let localCompletion = completion
                    
                    let (clarityScore, confidence) = self.calculateSpeechClarity()
                    self.speechClarityScore = clarityScore
                    self.speechConfidence = confidence
                    print("Final clarity: \(clarityScore), confidence: \(confidence)")
                    
                    self.isRecording = false
                    
                    // Now cleanup after analysis is complete
                    self.cleanupRecording()
                    
                    // Call completion on main thread with additional safety
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            print("SpeechRecognitionManager deallocated during completion")
                            return
                        }
                        
                        // Prevent multiple completion calls
                        guard !self.hasCalledCompletion else {
                            print("Completion already called, skipping")
                            return
                        }
                        self.hasCalledCompletion = true
                        self.isCompleting = false
                        localCompletion(clarityScore, confidence)
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("Audio engine started successfully")
        } catch {
            print("Audio engine couldn't start: \(error.localizedDescription)")
            print("Audio engine error details: \(error)")
            cleanupRecording()
            isRecording = false
            completion(0.0, 0.0)
        }
    }

    func stopRecording() {
        print("Stopping recording...")
        
        // Set recording to false first to prevent new operations
        isRecording = false
        
        // Only cleanup if not currently resetting, not already analyzing, and not completing
        if !isResetting && !hasCompletedAnalysis && !isCompleting {
            cleanupRecording()
        } else {
            print("Skipping cleanup during reset, analysis, or completion")
        }
    }
    
    private func cleanupRecording() {
        print("Cleaning up recording...")
        
        // Cancel the recording timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Safely stop the audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Safely end audio recognition
        recognitionRequest?.endAudio()
        
        // Remove tap if installed
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        
        // Deactivate audio session
        deactivateAudioSession()
        
        print("Recording cleanup completed")
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // First, deactivate any existing session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Set the category and mode
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            
            // Set preferred sample rate and I/O buffer duration
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("Audio session configured successfully")
            print("Audio session category: \(audioSession.category.rawValue)")
            print("Audio session mode: \(audioSession.mode.rawValue)")
            print("Audio session sample rate: \(audioSession.sampleRate)")
            print("Audio session I/O buffer duration: \(audioSession.ioBufferDuration)")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            print("Audio session error details: \(error)")
            
            // Try a simpler configuration as fallback
            do {
                try audioSession.setCategory(.record, mode: .default, options: [])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("Audio session configured with fallback settings")
            } catch {
                print("Failed to configure audio session even with fallback: \(error)")
            }
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated successfully")
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
    
    private func analyzeSpeechSegments(_ segments: [SFTranscriptionSegment]) {
        // Safety check for empty segments
        guard !segments.isEmpty else {
            print("No segments to analyze")
            return
        }
        
        // Additional safety check for valid segments
        let validSegments = segments.filter { segment in
            guard segment.confidence.isFinite && !segment.confidence.isNaN else {
                print("Skipping segment with invalid confidence")
                return false
            }
            guard segment.timestamp.isFinite && !segment.timestamp.isNaN else {
                print("Skipping segment with invalid timestamp")
                return false
            }
            guard segment.duration.isFinite && !segment.duration.isNaN else {
                print("Skipping segment with invalid duration")
                return false
            }
            return true
        }
        
        guard !validSegments.isEmpty else {
            print("No valid segments to analyze after filtering")
            return
        }
        
        print("Analyzing \(validSegments.count) valid segments out of \(segments.count) total")
        
        // Create a local copy of segments to avoid race conditions
        let segmentsCopy = validSegments
        
        speechSegmentsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                print("SpeechRecognitionManager deallocated during segment analysis")
                return
            }
            
            // Clear previous segments to avoid duplicates
            self.speechSegments.removeAll()
            
            // Use a local array first, then assign atomically
            var newSegments: [SpeechSegment] = []
            
            for segment in segmentsCopy {
                let speechSegment = SpeechSegment(
                    text: segment.substring,
                    confidence: segment.confidence,
                    timestamp: segment.timestamp,
                    duration: segment.duration,
                    voiceAnalytics: segment.voiceAnalytics
                )
                newSegments.append(speechSegment)
            }
            
            // Atomically replace the entire array
            self.speechSegments = newSegments
            
            print("Added \(self.speechSegments.count) segments to analysis")
        }
    }
    
    private func calculateSpeechClarity() -> (clarityScore: Double, confidence: Double) {
        var segments: [SpeechSegment] = []
        
        // Safely read the speech segments with a copy to prevent race conditions
        speechSegmentsQueue.sync {
            // Create a deep copy to ensure no race conditions
            segments = self.speechSegments.map { segment in
                SpeechSegment(
                    text: segment.text,
                    confidence: segment.confidence,
                    timestamp: segment.timestamp,
                    duration: segment.duration,
                    voiceAnalytics: segment.voiceAnalytics
                )
            }
        }
        
        print("Calculating speech clarity for \(segments.count) segments")
        
        guard !segments.isEmpty else {
            print("No speech segments to analyze")
            return (0.5, 0.0)
        }
        
        // Additional validation of segments before processing
        let filteredSegments = segments.filter { segment in
            guard segment.confidence.isFinite && !segment.confidence.isNaN else {
                print("Filtering out segment with invalid confidence: \(segment.confidence)")
                return false
            }
            guard segment.timestamp.isFinite && !segment.timestamp.isNaN else {
                print("Filtering out segment with invalid timestamp: \(segment.timestamp)")
                return false
            }
            guard segment.duration.isFinite && !segment.duration.isNaN else {
                print("Filtering out segment with invalid duration: \(segment.duration)")
                return false
            }
            return true
        }
        
        guard !filteredSegments.isEmpty else {
            print("No valid segments after filtering")
            return (0.5, 0.0)
        }
        
        print("Processing \(filteredSegments.count) valid segments out of \(segments.count) total")
        
        var totalClarity = 0.0
        var totalConfidence = 0.0
        var validSegments = 0
        
        // Calculate clarity based on multiple factors
        for segment in filteredSegments {
            let segmentClarity = calculateSegmentClarity(segment)
            guard segmentClarity.isFinite && !segmentClarity.isNaN else { 
                print("Invalid clarity value for segment, skipping")
                continue 
            }
            
            totalClarity += segmentClarity
            totalConfidence += Double(segment.confidence)
            validSegments += 1
        }
        
        print("Processed \(validSegments) valid segments out of \(filteredSegments.count)")
        
        guard validSegments > 0 else {
            print("No valid segments found after processing")
            return (0.5, 0.0)
        }
        
        let averageClarity = totalClarity / Double(validSegments)
        let averageConfidence = totalConfidence / Double(validSegments)
        
        // Ensure values are within valid ranges
        let clampedClarity = max(0.0, min(1.0, averageClarity))
        let clampedConfidence = max(0.0, min(1.0, averageConfidence))
        
        // Adjust clarity based on text similarity to expected text
        let textSimilarity = calculateTextSimilarity()
        let finalClarity = (clampedClarity + textSimilarity) / 2.0
        
        print("Final calculation: clarity=\(finalClarity), confidence=\(clampedConfidence)")
        
        return (finalClarity, clampedConfidence)
    }
    
    private func calculateSegmentClarity(_ segment: SpeechSegment) -> Double {
        guard segment.confidence.isFinite && !segment.confidence.isNaN else {
            return 0.5
        }
        
        var clarity = Double(segment.confidence)
        
        // Analyze voice analytics if available
        if let voiceAnalytics = segment.voiceAnalytics {
            // For now, we'll use a simplified approach that doesn't rely on specific properties
            // that might not be available on all devices
            
            // Use the confidence and duration to estimate speech quality
            let duration = segment.duration
            let textLength = segment.text.count
            
            // Calculate speaking rate (words per second approximation)
            let speakingRate: Double
            if duration > 0 && duration.isFinite && !duration.isNaN {
                speakingRate = Double(textLength) / duration
            } else {
                speakingRate = 1.0 // Default rate
            }
            
            // Normalize speaking rate (0.5-2.0 words per second is normal)
            let normalizedRate: Double
            if speakingRate.isNaN || speakingRate.isInfinite {
                normalizedRate = 0.5
            } else {
                normalizedRate = max(0.0, min(1.0, (speakingRate - 0.5) / 1.5))
            }
            
            // Use a combination of confidence and speaking rate
            let voiceClarity = (clarity + normalizedRate) / 2.0
            clarity = voiceClarity
        }
        
        // Ensure the result is within valid bounds
        return max(0.0, min(1.0, clarity))
    }
    
    private func calculateTextSimilarity() -> Double {
        let transcribed = transcribedText.lowercased()
        let expected = expectedText.lowercased()
        
        // Simple word-based similarity
        let transcribedWords = Set(transcribed.components(separatedBy: .whitespacesAndNewlines))
        let expectedWords = Set(expected.components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = transcribedWords.intersection(expectedWords)
        let union = transcribedWords.union(expectedWords)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
}

struct SpeechSegment {
    let text: String
    let confidence: Float
    let timestamp: TimeInterval
    let duration: TimeInterval
    let voiceAnalytics: Any?
    
    init(text: String, confidence: Float, timestamp: TimeInterval, duration: TimeInterval, voiceAnalytics: Any?) {
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
        self.duration = duration
        self.voiceAnalytics = voiceAnalytics
    }
}
