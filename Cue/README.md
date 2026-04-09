# CueBud — Real-Time Communication Coach for macOS

CueBud is a native macOS app that acts as a real-time communication coach during video calls. It listens and watches via your mic and camera, then surfaces gentle coaching tips — like "slow down", "sit up straight", or "speak up" — through a floating overlay that stays on top of Zoom, Google Meet, or any other app.

All processing happens **entirely on-device**. Audio and video never leave your Mac.

## Features

### Speech Coaching
| Signal | Ideal Range | Tip Trigger |
|---|---|---|
| **Speaking pace** | 140–160 WPM (green) | >160 WPM or <140 WPM sustained for 7s |
| **Filler words** | ≤3 per minute | >3 "um", "uh", "like", "you know", etc. in 60s |
| **Volume** | -12 to -6 dB (green) | Below -20 dB while speaking |
| **Rambling** | — | Continuous speech >10s without a 1s pause |

### Posture & Presence Coaching
| Signal | Detection Method | Tip Trigger |
|---|---|---|
| **Slouching** | Shoulder-to-nose ratio via body pose, face position fallback | Displayed in posture badge (no tip — always visible) |
| **Looking away** | Face bounding box position in frame | Face center >20% off-center for 3s |
| **Not smiling** | Mouth width-to-height ratio from face landmarks | Flat expression sustained for 5s |
| **Head tilt** | Face roll angle | >15° tilt sustained for 3s |
| **Too close/far** | Face bounding box size as fraction of frame | Shoulders not visible, or face too small |

### Tip Behavior
- **15-second warmup** — no tips fire in the first 15 seconds of a session
- **Persistent tips** — tips stay visible while the condition is active, then dismiss 2 seconds after the user corrects the issue
- **90-second cooldown** — the same tip type won't re-appear for 90 seconds after being dismissed
- **Priority queue** — only the highest-severity pending tip is shown at a time
- **Tap to dismiss** — any tip can be manually dismissed

### Live Metrics Overlay
The floating overlay displays real-time metrics:
- **WPM** — green when in the 140–160 ideal range, yellow otherwise
- **Fillers** — count of filler words in the current window
- **Volume** — bar that's green in the -12 to -6 dB ideal range, yellow below, red if clipping
- **Posture** — current posture status (Good, Slouching, Looking away, Head tilted)

### Session Summary
When you stop a session, CueBud shows a summary with:
- Average and peak WPM
- Filler word count and rate per minute
- Total words spoken
- Eye contact and good posture percentages
- Number of tips shown

## Tech Stack

- **SwiftUI** — native macOS app with floating overlay window
- **Apple Vision framework** — body pose + face landmark detection (no bundled ML models)
- **Apple Speech framework** — on-device transcription via `SFSpeechRecognizer`
- **AVFoundation** — `AVAudioEngine` for mic input, `AVCaptureSession` for camera
- **Combine** — reactive data flow with throttling to prevent UI flicker

## Requirements

- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Getting Started

1. **Install XcodeGen** (if you don't have it):
   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode project:**
   ```bash
   cd CueBud
   xcodegen generate
   ```

3. **Open and run:**
   ```bash
   open CueBud.xcodeproj
   ```
   Press **Cmd+R** to build and run. On first launch, CueBud will walk you through granting microphone, camera, and speech recognition permissions.

4. **Start coaching:**
   Click the **Play** button in the overlay (or use the menu bar icon) to start a session. The overlay floats above all apps, including fullscreen windows.

## Running Tests

```bash
xcodebuild test -scheme CueBud -destination 'platform=macOS'
```

30 unit tests covering filler word detection, posture snapshot logic, speech coach thresholds, and tip engine behavior.

## Permissions

CueBud requests three permissions, all used for on-device processing only:

| Permission | Purpose |
|---|---|
| Microphone | Analyze speech patterns, volume, and pace |
| Camera | Analyze posture and facial expressions |
| Speech Recognition | Detect filler words and calculate speaking pace |

## Project Structure

```
CueBud/
├── Models/          # CoachingTip, PostureSnapshot, SpeechSegment, SessionMetrics
├── Services/        # AudioAnalysisService, VideoAnalysisService, SpeechCoach, PostureCoach, TipEngine
├── Views/           # OverlayView, TipBubbleView, MetricsBadgeView, SettingsView, OnboardingView, SessionSummaryView
├── ViewModels/      # OverlayViewModel, SessionViewModel
├── Utilities/       # AudioLevelMeter, FillerWordDetector, SpeechPaceCalculator, PermissionsManager
└── CueBudTests/     # Unit tests
```
