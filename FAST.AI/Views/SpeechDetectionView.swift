//
//  SpeechDetectionView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI
import Speech

struct SpeechDetectionView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var showingResults = false
    @State private var analysisResult: (clarityScore: Double, confidence: Double) = (0.0, 0.0)
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let testSentence = "The quick brown fox jumps over the lazy dog"
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Speech Test")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Please repeat this sentence clearly:")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Text(testSentence)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 50)
                
                Spacer()
                
                VStack(spacing: 20) {
                    if speechManager.isRecording {
                        VStack(spacing: 15) {
                            Image(systemName: "waveform")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: speechManager.isRecording)
                            
                            Text("Recording...")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            if !speechManager.transcribedText.isEmpty {
                                VStack(spacing: 10) {
                                    Text("You said:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(speechManager.transcribedText)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "mic.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Tap to start recording")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 30) {
                    Button("Cancel") {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Button("Reset") {
                        resetTest()
                    }
                    .foregroundColor(.orange)
                    .padding()

                    Button(speechManager.isRecording ? "Stop Recording" : "Start Recording") {
                        if speechManager.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(speechManager.isRecording ? Color.red : Color.green)
                    .cornerRadius(25)
                    .disabled(!speechManager.isMicrophoneAvailable)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            speechManager.requestMicrophonePermission()
        }
        .alert("Speech Recognition Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startRecording() {
        guard speechManager.isMicrophoneAvailable else {
            errorMessage = "Microphone access is required for speech testing. Please enable microphone permissions in Settings."
            showingError = true
            return
        }
        
        guard speechManager.isSpeechRecognitionSupported() else {
            errorMessage = "Speech recognition is not available or not authorized. Please check your device settings and try again."
            showingError = true
            return
        }
        
        guard !speechManager.isRecording else {
            print("Already recording, ignoring start request")
            return
        }
        
        print("Starting speech recognition for sentence: \(testSentence)")
        
        speechManager.startRecording(expectedText: testSentence) { clarityScore, confidence in
            print("Speech recognition completed - clarity: \(clarityScore), confidence: \(confidence)")
            
            DispatchQueue.main.async {
                guard clarityScore.isFinite && !clarityScore.isNaN &&
                      confidence.isFinite && !confidence.isNaN else {
                    print("Invalid speech recognition results received")
                    self.errorMessage = "Speech recognition failed. Please try again."
                    self.showingError = true
                    return
                }
                
                self.analysisResult = (clarityScore, confidence)
                
                let testResult: StrokeSession.TestResult
                if confidence < 0.3 || clarityScore < 0.6 {
                    testResult = .abnormal
                } else {
                    testResult = .normal
                }
                
                print("Speech test result: \(testResult.rawValue)")
                
                if var session = self.sessionManager.currentSession {
                    session.speechTestResult = testResult
                    session.speechClarityScore = clarityScore
                    self.sessionManager.currentSession = session
                    print("Updated session with speech test result")
                } else {
                    print("Warning: No current session available to update")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("Dismissing speech detection view")
                    self.dismiss()
                }
            }
        }
    }
    
    private func stopRecording() {
        print("Stopping speech recording from view")
        speechManager.stopRecording()
    }
    
    private func resetTest() {
        if speechManager.isRecording {
            speechManager.stopRecording()
        }
        
        if var session = sessionManager.currentSession {
            session.speechTestResult = nil
            session.speechClarityScore = nil
            sessionManager.currentSession = session
        }
        
        analysisResult = (0.0, 0.0)
        
        print("Speech test data reset")
    }
}

#Preview {
    SpeechDetectionView()
        .environmentObject(StrokeSessionManager())
}
