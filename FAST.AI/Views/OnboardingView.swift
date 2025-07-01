//
//  OnboardingView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var sessionManager: StrokeSessionManager
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to StrokeSentry",
            subtitle: "Your AI-powered stroke detection companion",
            description: "Get instant assessment of stroke symptoms using the StrokeSentry method: Face, Arms, Speech, and Time.",
            imageName: "StrokeSentryLogo",
            color: .red
        ),
        OnboardingPage(
            title: "Face Detection",
            subtitle: "Detect facial asymmetry",
            description: "Our AI analyzes your facial expressions to detect any signs of facial drooping or asymmetry.",
            imageName: "face.smiling",
            color: .blue
        ),
        OnboardingPage(
            title: "Arm Assessment",
            subtitle: "Check arm weakness",
            description: "We'll guide you through arm positioning tests to detect any weakness or drift.",
            imageName: "hand.raised",
            color: .green
        ),
        OnboardingPage(
            title: "Speech Analysis",
            subtitle: "Evaluate speech clarity",
            description: "Speak clearly into your device as we analyze your speech for any slurring or difficulty.",
            imageName: "mic.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Emergency Ready",
            subtitle: "Quick access to help",
            description: "If stroke symptoms are detected, we'll help you find nearby hospitals immediately.",
            imageName: "cross.fill",
            color: .red
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 20)
                    
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    HStack {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                        }
                        
                        Spacer()
                        
                        if currentPage < pages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                        } else {
                            Button("Get Started") {
                                sessionManager.completeOnboarding()
                            }
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(25)
                            .padding()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(page.color)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(StrokeSessionManager())
}
