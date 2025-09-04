//
//  HistoryView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack {
                    // Add prominent History title
                    Text("History")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    if sessionManager.previousSessions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "clock")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Assessment History")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Your completed assessments will appear here")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List(sessionManager.previousSessions, id: \.id) { session in
                            SessionRow(session: session)
                                .listRowBackground(Color.gray.opacity(0.1))
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !sessionManager.previousSessions.isEmpty {
                        Button("Clear All") {
                            sessionManager.clearAllSessions()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            sessionManager.loadPreviousSessions()
        }
    }
}

struct SessionRow: View {
    let session: StrokeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Assessment")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text(session.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(session.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(overallResult)
                        .font(.headline)
                        .foregroundColor(resultColor)
                    
                    Text("Overall")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 20) {
                TestResultIndicator(
                    title: "Face",
                    result: session.faceTestResult ?? .normal,
                    detail: getFaceDetail()
                )
                
                TestResultIndicator(
                    title: "Arms",
                    result: session.armTestResult ?? .normal,
                    detail: getArmDetail()
                )
                
                TestResultIndicator(
                    title: "Speech",
                    result: session.speechTestResult ?? .normal,
                    detail: getSpeechDetail()
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var overallResult: String {
        guard let overall = session.overallResult else {
            let faceResult = session.faceTestResult ?? .normal
            let armResult = session.armTestResult ?? .normal
            let speechResult = session.speechTestResult ?? .normal
            
            let abnormalCount = [faceResult, armResult, speechResult].filter { $0 == .abnormal }.count
            let inconclusiveCount = [faceResult, armResult, speechResult].filter { $0 == .inconclusive }.count
            
            if abnormalCount >= 2 {
                return "High Risk"
            } else if abnormalCount == 1 || inconclusiveCount >= 1 {
                return "Medium Risk"
            } else {
                return "Low Risk"
            }
        }
        
        switch overall {
        case .emergency: return "Emergency"
        case .possibleStroke: return "Medium Risk"
        case .noStroke: return "Low Risk"
        }
    }
    
    private var resultColor: Color {
        switch overallResult {
        case "Emergency", "High Risk": return .red
        case "Medium Risk": return .orange
        default: return .green
        }
    }
    
    private func getFaceDetail() -> String? {
        guard let asymmetryScore = session.faceAsymmetryScore else { return nil }
        let percentage = Int((1.0 - asymmetryScore) * 100)
        return "\(percentage)%"
    }
    
    private func getArmDetail() -> String? {
        guard let symmetryScore = session.armSymmetryScore,
              let strengthScore = session.armStrengthScore else { return nil }
        let stability = Int((1.0 - symmetryScore) * 100)
        return "\(stability)%"
    }
    
    private func getSpeechDetail() -> String? {
        guard let clarityScore = session.speechClarityScore else { return nil }
        let percentage = Int(clarityScore * 100)
        return "\(percentage)%"
    }
}

struct TestResultIndicator: View {
    let title: String
    let result: StrokeSession.TestResult
    let detail: String?
    
    init(title: String, result: StrokeSession.TestResult, detail: String? = nil) {
        self.title = title
        self.result = result
        self.detail = detail
    }
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: resultIcon)
                .font(.title3)
                .foregroundColor(resultColor)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(resultColor)
            }
        }
    }
    
    private var resultIcon: String {
        switch result {
        case .normal: return "checkmark.circle.fill"
        case .abnormal: return "xmark.circle.fill"
        case .inconclusive: return "questionmark.circle.fill"
        }
    }
    
    private var resultColor: Color {
        switch result {
        case .normal: return .green
        case .abnormal: return .red
        case .inconclusive: return .orange
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(StrokeSessionManager())
}
