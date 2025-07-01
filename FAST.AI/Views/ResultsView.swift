//
//  ResultsView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmergency = false
    @State private var showingDetailedResults = false
    
    var body: some View {
        let overallResult = calculateOverallResult()

        return ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 15) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Assessment Complete")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("Your FAST assessment results")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 30)
                    
                    VStack(spacing: 20) {
                        Text("Test Results")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        VStack(spacing: 15) {
                            ResultCard(
                                title: "Face Test",
                                result: sessionManager.currentSession?.faceTestResult ?? .normal,
                                icon: "face.smiling",
                                detailText: getFaceDetailText()
                            )
                            
                            ResultCard(
                                title: "Arm Test",
                                result: sessionManager.currentSession?.armTestResult ?? .normal,
                                icon: "hand.raised",
                                detailText: getArmDetailText()
                            )
                            
                            ResultCard(
                                title: "Speech Test",
                                result: sessionManager.currentSession?.speechTestResult ?? .normal,
                                icon: "mic.fill",
                                detailText: getSpeechDetailText()
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 20) {
                        Text("Overall Assessment")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        VStack(spacing: 15) {
                            Image(systemName: overallResult.icon)
                                .font(.system(size: 50))
                                .foregroundColor(overallResult.color)
                            
                            Text(overallResult.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(overallResult.color)
                            
                            Text(overallResult.description)
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding()
                        .background(overallResult.color.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                    }
                    
                    VStack(spacing: 15) {
                        if overallResult.severity == .high {
                            Button("Call 911 Emergency") {
                                showingEmergency = true
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.red)
                            .cornerRadius(15)
                            .padding(.horizontal, 20)
                        }
                        
                        Button("Save Results") {
                            saveResults()
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.gray)
                        .padding()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Emergency Call", isPresented: $showingEmergency) {
            Button("Call 911") {
                if let url = URL(string: "tel:911") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("If you're experiencing stroke symptoms, call 911 immediately. Time is critical for stroke treatment.")
        }
    }

    private func calculateOverallResult() -> (title: String, description: String, color: Color, icon: String, severity: Severity) {
        let faceResult = sessionManager.currentSession?.faceTestResult ?? .normal
        let armResult = sessionManager.currentSession?.armTestResult ?? .normal
        let speechResult = sessionManager.currentSession?.speechTestResult ?? .normal
        
        let abnormalCount = [faceResult, armResult, speechResult].filter { $0 == .abnormal }.count
        
        if abnormalCount >= 2 {
            return (
                title: "High Risk - Seek Immediate Medical Attention",
                description: "Multiple stroke symptoms detected. Please call 911 or go to the nearest emergency room immediately.",
                color: .red,
                icon: "exclamationmark.triangle.fill",
                severity: .high
            )
        } else if abnormalCount == 1 {
            return (
                title: "Medium Risk - Monitor Closely",
                description: "One stroke symptom detected. Monitor for additional symptoms and consider seeking medical evaluation.",
                color: .orange,
                icon: "exclamationmark.circle.fill",
                severity: .medium
            )
        } else {
            return (
                title: "No Stroke Symptoms Detected",
                description: "No obvious stroke symptoms were detected in this assessment. Continue to monitor for any changes.",
                color: .green,
                icon: "checkmark.circle.fill",
                severity: .low
            )
        }
    }
    
    private func getFaceDetailText() -> String? {
        guard let session = sessionManager.currentSession,
              let asymmetryScore = session.faceAsymmetryScore else { return nil }
        
        let percentage = Int((1.0 - asymmetryScore) * 100)
        return "Symmetry: \(percentage)%"
    }
    
    private func getArmDetailText() -> String? {
        guard let session = sessionManager.currentSession,
              let driftScore = session.armDriftScore,
              let strengthScore = session.armStrengthScore else { return nil }
        
        let driftPercentage = Int((1.0 - driftScore) * 100)
        let strengthPercentage = Int(strengthScore * 100)
        return "Stability: \(driftPercentage)%, Strength: \(strengthPercentage)%"
    }
    
    private func getSpeechDetailText() -> String? {
        guard let session = sessionManager.currentSession,
              let clarityScore = session.speechClarityScore else { return nil }
        
        let percentage = Int(clarityScore * 100)
        return "Clarity: \(percentage)%"
    }
    
    private func saveResults() {
        sessionManager.saveCurrentSession()
    }
}

enum Severity {
    case low, medium, high
}

struct ResultCard: View {
    let title: String
    let result: StrokeSession.TestResult
    let icon: String
    let detailText: String?
    
    init(title: String, result: StrokeSession.TestResult, icon: String, detailText: String? = nil) {
        self.title = title
        self.result = result
        self.icon = icon
        self.detailText = detailText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(resultColor)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(result.rawValue)
                        .font(.body)
                        .foregroundColor(resultColor)
                }
                
                Spacer()
                
                Image(systemName: resultIcon)
                    .font(.title2)
                    .foregroundColor(resultColor)
            }
            
            if let detailText = detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 35)
            }
        }
        .padding()
        .background(resultColor.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var resultColor: Color {
        switch result {
        case .normal: return .green
        case .abnormal: return .red
        }
    }
    
    private var resultIcon: String {
        switch result {
        case .normal: return "checkmark.circle.fill"
        case .abnormal: return "xmark.circle.fill"
        }
    }
}

#Preview {
    ResultsView()
        .environmentObject(StrokeSessionManager())
}
