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
    @State private var analysisResult: (symmetryScore: Double, strengthScore: Double, confidence: Double) = (0.0, 0.0, 0.0)

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

                            Text("Face the camera and hold both arms out in front")
                                .font(.body)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            if isAnalyzing {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("Analyzing arm position and symmetry...")
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
                    .foregroundColor(.black)
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

        poseManager.startArmDetection { symmetryScore, strengthScore, confidence in
            analysisResult = (symmetryScore, strengthScore, confidence)
            
            DispatchQueue.main.async {
                isAnalyzing = false
                
                let testResult: StrokeSession.TestResult
                if confidence < 0.3 {
                    testResult = .inconclusive
                } else if symmetryScore > 0.4 || strengthScore < 0.6 {
                    testResult = .abnormal
                } else {
                    testResult = .normal
                }
                
                if var session = sessionManager.activeSession {
                    session.armTestResult = testResult
                    session.armSymmetryScore = symmetryScore
                    session.armStrengthScore = strengthScore
                    sessionManager.activeSession = session
                }
                
                dismiss()
            }
        }
    }

    private func resetTest() {
        if var session = sessionManager.activeSession {
            session.armTestResult = nil
            session.armSymmetryScore = nil
            session.armStrengthScore = nil
            sessionManager.activeSession = session
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
