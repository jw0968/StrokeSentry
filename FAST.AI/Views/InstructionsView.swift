//
//  InstructionsView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var hasAcceptedDisclaimer = false
    
    let instructions = [
        InstructionStep(
            title: "⚠️ DISCLAIMER",
            description: "StrokeSentry is NOT a medical device and cannot replace professional medical evaluation. This app is for educational and screening purposes only. Always seek professional medical attention for any concerning symptoms. The developers are not liable for any medical decisions made based on this app.",
            icon: "exclamationmark.triangle.fill",
            color: .red
        ),
        InstructionStep(
            title: "Welcome to StrokeSentry",
            description: "Your AI-powered stroke detection assistant. This app uses your device's camera and microphone to perform the StrokeSentry assessment.",
            icon: "heart.fill",
            color: .red
        ),
        InstructionStep(
            title: "Face Test",
            description: "The app will analyze your facial symmetry while you smile. Look directly at the camera and smile naturally. This detects facial drooping, a common stroke symptom.",
            icon: "face.smiling",
            color: .orange
        ),
        InstructionStep(
            title: "Arm Test", 
            description: "Hold both arms out to the sides at shoulder level. The app will detect if one arm drifts downward, which indicates muscle weakness from stroke.",
            icon: "hand.raised",
            color: .blue
        ),
        InstructionStep(
            title: "Speech Test",
            description: "Repeat a sentence clearly into your microphone. The app analyzes speech clarity and pronunciation to detect slurred speech, another stroke symptom.",
            icon: "mic.fill",
            color: .green
        ),
        InstructionStep(
            title: "Results & Next Steps",
            description: "Based on your results, the app will recommend whether to seek immediate medical attention. Remember: When in doubt, call 911 immediately.",
            icon: "exclamationmark.triangle.fill",
            color: .red
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Progress indicator
                    VStack(spacing: 10) {
                        HStack {
                            ForEach(0..<instructions.count, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentStep ? instructions[index].color : Color.gray)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Text("Step \(currentStep + 1) of \(instructions.count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Current instruction
                    VStack(spacing: 30) {
                        let safeStep = min(max(currentStep, 0), instructions.count - 1)
                        
                        Image(systemName: instructions[safeStep].icon)
                            .font(.system(size: 80))
                            .foregroundColor(instructions[safeStep].color)
                        
                        VStack(spacing: 16) {
                            Text(instructions[safeStep].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text(instructions[safeStep].description)
                                .font(.title3)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Disclaimer acceptance checkbox (only show on first step)
                            if currentStep == 0 {
                                HStack {
                                    Button(action: {
                                        hasAcceptedDisclaimer.toggle()
                                    }) {
                                        Image(systemName: hasAcceptedDisclaimer ? "checkmark.square.fill" : "square")
                                            .foregroundColor(hasAcceptedDisclaimer ? .green : .gray)
                                            .font(.title2)
                                    }
                                    
                                    Text("I understand this app is not a medical device and cannot replace professional medical evaluation")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                    
                    // Navigation buttons
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
                        
                        if currentStep == instructions.count - 1 {
                            Button("Get Started") {
                                dismiss()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.green)
                            .cornerRadius(25)
                        } else if currentStep == 0 {
                            // Disclaimer step - require acceptance
                            Button("I Accept & Understand") {
                                hasAcceptedDisclaimer = true
                                withAnimation {
                                    currentStep = min(currentStep + 1, instructions.count - 1)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(hasAcceptedDisclaimer ? Color.green : Color.gray)
                            .cornerRadius(25)
                            .disabled(!hasAcceptedDisclaimer)
                        } else {
                            Button("Next") {
                                withAnimation {
                                    currentStep = min(currentStep + 1, instructions.count - 1)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(instructions[currentStep].color)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
}

struct InstructionStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    InstructionsView()
} 
 
