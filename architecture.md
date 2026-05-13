# CueBud Architecture

## High-Level Overview

```mermaid
flowchart TD
    subgraph Sensors["Raw Sensors (AVFoundation)"]
        MIC["Microphone\nAVAudioEngine"]
        CAM["Camera\nAVCaptureSession"]
    end

    subgraph Capture["Capture Services"]
        AAS["AudioAnalysisService\nSFSpeechRecognizer\n55s session recycle"]
        VAS["VideoAnalysisService\nVision Framework\n~3 fps background queue"]
    end

    subgraph Coaches["Coaches"]
        SC["SpeechCoach\npace · fillers · volume · rambling"]
        PC["PostureCoach\nslouch · gaze · expression · tilt"]
    end

    subgraph Policy["Tip Engine (Policy Layer)"]
        TE["TipEngine\n15s warmup · 90s cooldown per type\npriority queue · grace-timer dedup"]
    end

    subgraph ViewModels["View Models"]
        SVM["SessionViewModel\nsession lifecycle · aggregate metrics"]
        OVM["OverlayViewModel\nUI state for overlay"]
    end

    subgraph UI["Views (SwiftUI)"]
        OV["OverlayView\nfloating coaching overlay"]
        SSV["SessionSummaryView\npost-session report"]
        SV["SettingsView"]
    end

    subgraph Auth["Auth (Independent)"]
        AS["AuthService\nGoogle OAuth PKCE\nKeychain · Supabase sync"]
        LV["LoginView"]
        ONB["OnboardingView\npermissions walkthrough"]
    end

    MIC --> AAS
    CAM --> VAS

    AAS -- "segmentSubject\n(finalized, 55s)" --> SC
    AAS -- "partialTranscriptSubject\n(real-time, 1s throttle)" --> SC
    AAS -- "segmentSubject" --> SVM
    VAS -- "snapshotSubject" --> PC
    VAS -- "snapshotSubject" --> SVM

    SC -- "tipSubject" --> TE
    PC -- "tipSubject" --> TE

    TE -- "displayTipSubject" --> OVM
    SVM --> OVM

    OVM --> OV
    SVM --> SSV
    AS --> SV
    AS --> LV
    AS --> ONB
```

## App Launch Flow

```mermaid
flowchart TD
    APP["CueBudApp"] --> AUTH_CHECK{auth.currentUser?}
    AUTH_CHECK -- "nil" --> LOGIN["LoginView\nGoogle OAuth PKCE"]
    AUTH_CHECK -- "exists" --> ONBOARD_CHECK{hasCompletedOnboarding?}
    ONBOARD_CHECK -- "false" --> ONB["OnboardingView\nmic · camera · speech permissions"]
    ONBOARD_CHECK -- "true" --> OV["OverlayView\ncoaching session"]
    LOGIN --> AUTH_CHECK
    ONB --> OV
```

## Layer Summary

| Layer | Components | Responsibility |
|---|---|---|
| **Sensors** | `AVAudioEngine`, `AVCaptureSession` | Raw mic and camera input |
| **Capture Services** | `AudioAnalysisService`, `VideoAnalysisService` | On-device transcription (SFSpeechRecognizer) and pose/face detection (Vision) |
| **Coaches** | `SpeechCoach`, `PostureCoach` | Emit a `CoachingTip` whenever a condition is observed — no rate-limiting logic |
| **Policy** | `TipEngine` | All display policy: warmup, per-type cooldown, priority queue, grace-timer auto-dismiss |
| **View Models** | `SessionViewModel`, `OverlayViewModel` | Session lifecycle & aggregate metrics; UI state for the overlay |
| **Views** | `OverlayView`, `SessionSummaryView`, `SettingsView`, `LoginView`, `OnboardingView` | SwiftUI UI; overlay floats above all spaces including fullscreen |
| **Auth** | `AuthService`, `KeychainHelper` | Google OAuth PKCE, silent token refresh, Keychain storage, Supabase user upsert — independent of the coaching pipeline |
| **Utilities** | `FillerWordDetector`, `SpeechPaceCalculator`, `AudioLevelMeter`, `PermissionsManager` | Stateless helpers used by capture services and coaches |
