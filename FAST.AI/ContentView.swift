//
//  ContentView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = StrokeSessionManager()
    @State private var shouldShowInstructions = false
    
    var body: some View {
        if sessionManager.hasCompletedOnboarding {
            HomeView()
                .environmentObject(sessionManager)
                .sheet(isPresented: $shouldShowInstructions) {
                    InstructionsView()
                        .onDisappear {
                            sessionManager.markInstructionsAsSeen()
                        }
                }
                .onAppear {
                    if !sessionManager.hasSeenInstructions {
                        shouldShowInstructions = true
                    }
                }
        } else {
            OnboardingView()
                .environmentObject(sessionManager)
        }
    }
}

class StrokeSessionManager: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var hasSeenInstructions = false
    @Published var activeSession: StrokeSession?
    @Published var previousSessions: [StrokeSession] = []
    
    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "hasCompletedOnboarding"
    private let instructionsKey = "hasSeenInstructions"
    
    init() {
        loadUserPreferences()
        loadPreviousSessions()
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
    }
    
    func markInstructionsAsSeen() {
        hasSeenInstructions = true
        userDefaults.set(true, forKey: instructionsKey)
    }
    
    func startNewSession() {
        activeSession = StrokeSession()
    }
    
    func saveCurrentSession() {
        guard let session = activeSession else { return }
        
        var completedSession = session
        completedSession.overallResult = determineStrokeRisk(for: session)
        
        SessionStorage.shared.saveSession(completedSession)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadPreviousSessions()
        }
        
        activeSession = nil
    }
    
    func resetCurrentSession() {
        activeSession = StrokeSession()
    }
    
    private func determineStrokeRisk(for session: StrokeSession) -> StrokeSession.OverallResult {
        let faceTest = session.faceTestResult ?? .normal
        let armTest = session.armTestResult ?? .normal
        let speechTest = session.speechTestResult ?? .normal
        
        let allTestResults = [faceTest, armTest, speechTest]
        let abnormalTests = allTestResults.filter { $0 == .abnormal }.count
        let inconclusiveTests = allTestResults.filter { $0 == .inconclusive }.count
        
        if abnormalTests >= 2 {
            return .emergency
        } else if abnormalTests == 1 {
            return .possibleStroke
        } else if inconclusiveTests >= 1 {
            return .possibleStroke
        } else {
            return .noStroke
        }
    }
    
    func loadPreviousSessions() {
        DispatchQueue.main.async {
            do {
                let sessions = SessionStorage.shared.loadSessions()
                self.previousSessions = sessions
            } catch {
                self.previousSessions = []
            }
        }
    }
    
    func clearAllSessions() {
        SessionStorage.shared.clearSessions()
        previousSessions.removeAll()
    }
    
    private func loadUserPreferences() {
        hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
        hasSeenInstructions = userDefaults.bool(forKey: instructionsKey)
    }
}

#Preview {
    ContentView()
}
