//
//  StrokeSession.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import Foundation

struct StrokeSession: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    var faceTestResult: TestResult?
    var armTestResult: TestResult?
    var speechTestResult: TestResult?
    var overallResult: OverallResult?
    
    // Analysis scores for detailed results
    var faceAsymmetryScore: Double?
    var armSymmetryScore: Double?
    var armStrengthScore: Double?
    var speechClarityScore: Double?
    
    init() {
        self.timestamp = Date()
    }
    
    enum TestResult: String, CaseIterable, Codable {
        case normal = "Normal"
        case abnormal = "Abnormal"
        case inconclusive = "Inconclusive"
        
        var color: String {
            switch self {
            case .normal: return "green"
            case .abnormal: return "red"
            case .inconclusive: return "orange"
            }
        }
    }
    
    enum OverallResult: String, CaseIterable, Codable {
        case noStroke = "No Stroke Detected"
        case possibleStroke = "Possible Stroke - Seek Medical Attention"
        case emergency = "Emergency - Call 911 Immediately"
        
        var color: String {
            switch self {
            case .noStroke: return "green"
            case .possibleStroke: return "orange"
            case .emergency: return "red"
            }
        }
    }
}

// Session storage manager
class SessionStorage {
    static let shared = SessionStorage()
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "stroke_sessions"
    
    private init() {}
    
    func saveSession(_ session: StrokeSession) {
        print("SessionStorage: Saving session with ID \(session.id)")
        
        do {
        var sessions = loadSessions()
            
            // Safety check: ensure sessions is a valid array
            guard sessions.count >= 0 else {
                print("SessionStorage: Invalid sessions array, resetting")
                sessions = []
                return
            }
            
        sessions.append(session)
        
        // Keep only last 50 sessions
        if sessions.count > 50 {
            sessions = Array(sessions.suffix(50))
        }
        
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
            userDefaults.synchronize()
            
            print("SessionStorage: Successfully saved session. Total sessions: \(sessions.count)")
        } catch {
            print("SessionStorage: Error saving session: \(error)")
        }
    }
    
    func loadSessions() -> [StrokeSession] {
        print("SessionStorage: Loading sessions...")
        
        guard let data = userDefaults.data(forKey: sessionsKey) else {
            print("SessionStorage: No saved sessions found")
            return []
        }
        
        do {
            let sessions = try JSONDecoder().decode([StrokeSession].self, from: data)
            
            // Safety check: ensure we have a valid array
            guard sessions.count >= 0 else {
                print("SessionStorage: Invalid sessions array detected, returning empty array")
                return []
            }
            
            let sortedSessions = sessions.sorted { $0.timestamp > $1.timestamp }
            print("SessionStorage: Successfully loaded \(sortedSessions.count) sessions")
            return sortedSessions
        } catch {
            print("SessionStorage: Error loading sessions: \(error)")
            return []
        }
    }
    
    func clearSessions() {
        print("SessionStorage: Clearing all sessions")
        userDefaults.removeObject(forKey: sessionsKey)
        userDefaults.synchronize()
    }
    
    func resetCorruptedData() {
        print("SessionStorage: Resetting corrupted data")
        clearSessions()
    }
}
