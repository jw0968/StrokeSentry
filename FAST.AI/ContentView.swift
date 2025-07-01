//
//  ContentView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = StrokeSessionManager()
    
    var body: some View {
        if sessionManager.hasCompletedOnboarding {
            HomeView()
                .environmentObject(sessionManager)
        } else {
            OnboardingView()
                .environmentObject(sessionManager)
        }
    }
}

class StrokeSessionManager: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var currentSession: StrokeSession?
    @Published var savedSessions: [StrokeSession] = []
    
    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        loadSessions()
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func startNewSession() {
        currentSession = StrokeSession()
    }
    
    func saveCurrentSession() {
        guard let session = currentSession else { return }
        
        print("Saving current session...")
        
        var updatedSession = session
        updatedSession.overallResult = calculateOverallResult(for: session)
        
        SessionStorage.shared.saveSession(updatedSession)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Loading sessions after save...")
            self.loadSessions()
        }
        
        currentSession = nil
        print("Session saved and cleared")
    }
    
    func resetCurrentSession() {
        print("Resetting current session...")
        currentSession = StrokeSession()
        print("Current session reset to new session")
    }
    
    private func calculateOverallResult(for session: StrokeSession) -> StrokeSession.OverallResult {
        let faceResult = session.faceTestResult ?? .normal
        let armResult = session.armTestResult ?? .normal
        let speechResult = session.speechTestResult ?? .normal
        
        let abnormalCount = [faceResult, armResult, speechResult].filter { $0 == .abnormal }.count
        
        if abnormalCount >= 2 {
            return .emergency
        } else if abnormalCount == 1 {
            return .possibleStroke
        } else {
            return .noStroke
        }
    }
    
    func loadSessions() {
        print("Loading sessions...")
        DispatchQueue.main.async {
            do {
                let sessions = SessionStorage.shared.loadSessions()
                print("Loaded \(sessions.count) sessions")
                self.savedSessions = sessions
            } catch {
                print("Error loading sessions: \(error)")
                self.savedSessions = []
            }
        }
    }
    
    func clearAllSessions() {
        SessionStorage.shared.clearSessions()
        savedSessions.removeAll()
    }
}

#Preview {
    ContentView()
}
