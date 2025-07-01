//
//  FaceDetectionView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI
import AVFoundation

struct FaceDetectionView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var poseManager = PoseDetectionManager()
    @State private var isAnalyzing = false
    @State private var showingResults = false
    @State private var analysisResult: (asymmetryScore: Double, confidence: Double) = (0.0, 0.0)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                ZStack {
                    // ✅ Live camera feed
                    CameraPreviewView(session: poseManager.session)
                        .aspectRatio(9/16, contentMode: .fit)
                        .cornerRadius(20)
                        .padding()

                    VStack {
                        Spacer()

                        VStack(spacing: 15) {
                            Text("Face Test")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)

                            Text("Please smile naturally and look directly at the camera")
                                .font(.body)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            if isAnalyzing {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("Analyzing facial symmetry...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }

                HStack(spacing: 30) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()

                    Button("Reset") {
                        resetTest()
                    }
                    .foregroundColor(.orange)
                    .padding()

                    Button(isAnalyzing ? "Analyzing..." : "Start Analysis") {
                        startAnalysis()
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(isAnalyzing ? Color.gray : Color.white)
                    .cornerRadius(25)
                    .disabled(isAnalyzing)


                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            poseManager.requestCameraPermission()
        }
        .onDisappear {
            poseManager.stopSession()
        }
    }

    private func startAnalysis() {
        isAnalyzing = true

        poseManager.startFaceDetection { asymmetryScore, confidence in
            analysisResult = (asymmetryScore, confidence)
            
            DispatchQueue.main.async {
                isAnalyzing = false
                
                // Determine test result based on asymmetry score
                let testResult: StrokeSession.TestResult
                if confidence < 0.3 || asymmetryScore > 0.3 {
                    testResult = .abnormal
                } else {
                    testResult = .normal
                }
                
                // Update session with result and analysis score
                if var session = sessionManager.currentSession {
                    session.faceTestResult = testResult
                    session.faceAsymmetryScore = asymmetryScore
                    sessionManager.currentSession = session
                }
                
                dismiss()
            }
        }
    }



    private func resetTest() {
        // Reset the face test data
        if var session = sessionManager.currentSession {
            session.faceTestResult = nil
            session.faceAsymmetryScore = nil
            sessionManager.currentSession = session
        }
        
        // Reset local state
        isAnalyzing = false
        analysisResult = (0.0, 0.0)
        
        print("Face test data reset")
    }
}
