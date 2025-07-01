//
//  ArmDetectionView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI
import AVFoundation

struct ArmDetectionView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var poseManager = PoseDetectionManager()
    @State private var isAnalyzing = false
    @State private var showingResults = false
    @State private var analysisResult: (driftScore: Double, strengthScore: Double, confidence: Double) = (0.0, 0.0, 0.0)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                ZStack {
                    CameraPreviewView(session: poseManager.session)
                        .aspectRatio(9/16, contentMode: .fit)
                        .cornerRadius(20)
                        .padding()

                    VStack {
                        Spacer()
                        VStack(spacing: 15) {
                            Text("Arm Test")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)

                            Text("Face the camera and hold both arms out to the sides")
                                .font(.body)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            if isAnalyzing {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("Analyzing arm position and strength...")
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
                    .background(isAnalyzing ? Color.gray : Color.blue)
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

        poseManager.startArmDetection { driftScore, strengthScore, confidence in
            analysisResult = (driftScore, strengthScore, confidence)
            
            DispatchQueue.main.async {
                isAnalyzing = false
                
                let testResult: StrokeSession.TestResult
                if confidence < 0.3 || driftScore > 0.4 || strengthScore < 0.6 {
                    testResult = .abnormal
                } else {
                    testResult = .normal
                }
                
                if var session = sessionManager.currentSession {
                    session.armTestResult = testResult
                    session.armDriftScore = driftScore
                    session.armStrengthScore = strengthScore
                    sessionManager.currentSession = session
                }
                
                dismiss()
            }
        }
    }

    private func resetTest() {
        if var session = sessionManager.currentSession {
            session.armTestResult = nil
            session.armDriftScore = nil
            session.armStrengthScore = nil
            sessionManager.currentSession = session
        }
        
        isAnalyzing = false
        analysisResult = (0.0, 0.0, 0.0)
        
        print("Arm test data reset")
    }
}

#Preview {
    ArmDetectionView()
        .environmentObject(StrokeSessionManager())
}
