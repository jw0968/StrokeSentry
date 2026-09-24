# StrokeSentry

An iOS app that walks you through the FAST stroke screen (Face, Arms, Speech, Time) using the phone's camera and microphone, then points you to nearby hospitals.

> **StrokeSentry is not a medical device.** It is an educational screening tool built with on-device heuristics. It has not been clinically validated and can produce false positives and false negatives. If you or someone near you may be having a stroke, **call 911 (or your local emergency number) immediately.** Do not wait for the app. See [Terms of Service](FAST.AI/TERMS_OF_SERVICE.md).

## What it does

StrokeSentry guides the user through three short tests and combines the results into a risk summary.

| Test | What the user does | What the app measures |
|------|--------------------|-----------------------|
| **Face** | Smile at the front camera for 3 seconds | Left/right differences in eye, eyebrow, and mouth-corner position from Vision face landmarks |
| **Arms** | Hold both arms out for 3 seconds | Left/right arm extension asymmetry and elbow extension from Vision body-pose joints |
| **Speech** | Read a sentence aloud | Speech-recognizer segment confidence and word overlap with the target sentence |

After the tests, the results screen shows a per-test verdict (normal, abnormal, or inconclusive) and an overall risk level. High-risk results surface a one-tap "Call 911" button. The app also includes:

- **Nearby hospitals**: a MapKit search around the user's location with distance, phone number, and directions.
- **History**: past assessments saved on the device.
- **Onboarding and instructions**: an explanation of each test and a required disclaimer acknowledgement.

All processing runs on-device. No data leaves the phone.

## Requirements

- Xcode 16 or later
- iOS 18.5 or later
- A physical iPhone. The simulator has no camera, and speech recognition needs a microphone.

## Building and running

1. Clone the repo and open `StrokeSentry.xcodeproj` in Xcode.
2. Select the `StrokeSentry` target and set your own team under **Signing & Capabilities**.
3. Pick your iPhone as the run destination and press Run.
4. On first launch, grant the camera, microphone, speech recognition, and location permissions when prompted. Each test needs its permission to work.

There are no third-party dependencies. Everything uses Apple frameworks: SwiftUI, AVFoundation, Vision, Speech, MapKit, and CoreLocation.

## How it works

```
StrokeSentryApp
└── ContentView            gates onboarding, owns StrokeSessionManager
    ├── OnboardingView
    ├── InstructionsView   disclaimer + how each test works
    └── HomeView
        ├── StrokeCheckView          3-step wizard
        │   ├── FaceDetectionView    ─┐ PoseDetectionManager
        │   ├── ArmDetectionView     ─┘ (AVCaptureSession + Vision)
        │   ├── SpeechDetectionView  ── SpeechRecognitionManager
        │   └── ResultsView          combines results, offers 911 + save
        ├── HistoryView              saved sessions
        └── HospitalsView            MapKit local search
```

**Session model.** A `StrokeSession` holds the three test verdicts, their raw scores, and an overall result. Sessions are encoded as JSON and stored in `UserDefaults`, capped at the most recent 50.

**Face and arm analysis.** `PoseDetectionManager` runs the front camera and submits each frame to a `VNDetectFaceLandmarksRequest` and a `VNDetectHumanBodyPoseRequest`. Observations are collected for a 3-second window, then averaged into an asymmetry score (face) or symmetry and strength scores (arms). A confidence value based on how many frames produced a usable observation determines whether the result is inconclusive.

**Speech analysis.** `SpeechRecognitionManager` streams microphone audio into an `SFSpeechAudioBufferRecognitionRequest`. When recognition finishes, the per-segment confidence is averaged with a Jaccard word-overlap score against the target sentence to produce a clarity score.

**Risk rules.** Two or more abnormal tests is high risk. One abnormal test, or any inconclusive test, is medium risk. Otherwise the assessment reports no symptoms detected.

## Project layout

```
FAST.AI/                      app sources (the original project name)
├── FAST_AIApp.swift          @main entry point
├── ContentView.swift         root view + StrokeSessionManager
├── Models/StrokeSession.swift
├── Managers/
│   ├── PoseDetectionManager.swift
│   └── SpeechRecognitionManager.swift
├── Views/                    one file per screen
├── Assets.xcassets/
└── TERMS_OF_SERVICE.md
FAST-AI-Info.plist            usage-description strings
StrokeSentry.xcodeproj/
```

## Known limitations

This started as a hackathon project and the analysis is heuristic. Before relying on it for anything, be aware of the following.

- Detection thresholds (for example, face asymmetry above 0.3 is "abnormal") were chosen by hand and have not been tuned against any dataset.
- A test that is cancelled or skipped is currently treated as normal in the results screen.
- Camera frames are sent to Vision without correcting for device orientation, which can reduce landmark accuracy in portrait.
- The arm test measures horizontal wrist offset, so it works best with arms held out to the sides rather than straight toward the camera.
- Results are stored only when the user taps "Save Results".

Issues and pull requests that improve any of these are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Privacy

Camera, microphone, speech, and location data are processed on the device and never uploaded. Assessment history is stored locally and can be cleared from the History screen. Speech recognition may use Apple's on-device or server-side recognizer depending on the device and language settings, which is governed by Apple's privacy policy.

## License

[MIT](LICENSE)
