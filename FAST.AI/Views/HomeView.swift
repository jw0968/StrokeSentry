//
//  HomeView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @State private var showingStrokeCheck = false
    @State private var showingHistory = false
    @State private var showingHospitals = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 10) {
                        Image("StrokeSentryLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                        
                        Text("StrokeSentry")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("Stroke Symptom Detection")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    Button(action: {
                        sessionManager.startNewSession()
                        showingStrokeCheck = true
                    }) {
                        VStack(spacing: 15) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Start Stroke Check")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            
                            Text("Complete StrokeSentry assessment")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                        )
                    }
                    .padding(.horizontal, 30)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showingHistory = true
                        }) {
                            VStack(spacing: 10) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                                
                                Text("History")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            )
                        }
                        
                        Button(action: {
                            showingHospitals = true
                        }) {
                            VStack(spacing: 10) {
                                Image(systemName: "cross.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.red)
                                
                                Text("Hospitals")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.red.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Remember: Time is critical in stroke treatment")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Text("If you suspect a stroke, call 911 immediately")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingStrokeCheck) {
            StrokeCheckView()
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showingHospitals) {
            HospitalsView()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(StrokeSessionManager())
}
