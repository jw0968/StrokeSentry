//
//  StrokeCheckView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct StrokeCheckView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var showingFaceTest = false
    @State private var showingArmTest = false
    @State private var showingSpeechTest = false
    @State private var showingResults = false
    
    let steps = [
        TestStep(title: "Face Test", description: "Detect facial asymmetry", icon: "face.smiling", color: .orange),
        TestStep(title: "Arm Test", description: "Check arm strength and symmetry", icon: "hand.raised", color: .blue),
        TestStep(title: "Speech Test", description: "Analyze speech clarity", icon: "mic.fill", color: .green)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 10) {
                        HStack {
                            ForEach(0..<steps.count, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentStep ? steps[index].color : Color.gray)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Text("Step \(currentStep + 1) of \(steps.count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 30) {
                        let safeStep = min(max(currentStep, 0), steps.count - 1)
                        
                        Image(systemName: steps[safeStep].icon)
                            .font(.system(size: 80))
                            .foregroundColor(steps[safeStep].color)
                        
                        VStack(spacing: 16) {
                            Text(steps[safeStep].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text(steps[safeStep].description)
                                .font(.title3)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            startCurrentTest()
                        }) {
                            Text("Start \(steps[safeStep].title)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(steps[safeStep].color)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                    
                    HStack {
                        if currentStep > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentStep = max(currentStep - 1, 0)
                                }
                            }
                            .foregroundColor(.black)
                            .padding()
                        }
                        
                        Spacer()
                        
                        if currentStep == steps.count - 1 {
                            Button("View Results") {
                                showingResults = true
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Stroke Check")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .sheet(isPresented: $showingFaceTest) {
            FaceDetectionView()
                .environmentObject(sessionManager)
                .onDisappear {
                    if currentStep == 0 {
                        withAnimation {
                            currentStep = min(currentStep + 1, steps.count - 1)
                        }
                    }
                }
        }
        .sheet(isPresented: $showingArmTest) {
            ArmDetectionView()
                .environmentObject(sessionManager)
                .onDisappear {
                    if currentStep == 1 {
                        withAnimation {
                            currentStep = min(currentStep + 1, steps.count - 1)
                        }
                    }
                }
        }
        .sheet(isPresented: $showingSpeechTest) {
            SpeechDetectionView()
                .environmentObject(sessionManager)
                .onDisappear {
                    if currentStep == 2 {
                        withAnimation {
                            currentStep = min(currentStep + 1, steps.count - 1)
                        }
                    }
                }
        }
        .sheet(isPresented: $showingResults) {
            ResultsView()
                .environmentObject(sessionManager)
        }
    }
    
    private func startCurrentTest() {
        let safeStep = min(max(currentStep, 0), steps.count - 1)
        
        switch safeStep {
        case 0:
            showingFaceTest = true
        case 1:
            showingArmTest = true
        case 2:
            showingSpeechTest = true
        default:
            print("Invalid step index: \(safeStep)")
            break
        }
    }
}

struct TestStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    StrokeCheckView()
        .environmentObject(StrokeSessionManager())
}
