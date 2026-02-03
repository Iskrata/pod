# Pod - macOS iPod-style Music Player

## Tech Stack
- SwiftUI + AppKit hybrid (macOS 12+)
- AVFoundation for audio playback & metadata
- Combine for reactive state
- MediaPlayer for remote control/media keys
- TelemetryDeck for analytics

## Architecture
**MVVM with protocol-based navigation**
- `ProtocolView` protocol: common interface for all screen ViewModels (wheel interactions)
- `GlobalState.shared`: singleton for app-wide state & UserDefaults persistence
- `Screen` enum: simple view switching (onboarding → albums → song)

## Key Directories
```
Pod/
├── Album/        # Album carousel & selection
├── Song/         # Now playing, audio playback logic
├── Model/        # Data structures (Album, Song, Screen)
├── State/        # GlobalState singleton
├── Onboarding/   # Setup flow
├── Settings/     # Preferences & radio config
├── Wheel/        # ClickWheel gesture handling
└── Updates/      # Version checking
```

## Important Patterns

### Wheel Input
- `ClickWheel.swift`: drag gesture with angle tracking, 5-value rolling average for smoothing
- Delegates to active ViewModel via `ProtocolView` methods

### Audio
- Local: `AVAudioPlayer` for MP3s
- Radio: `AVPlayer` for streams
- Metadata from `AVAsset.commonMetadata`

### State Persistence
- All settings via `UserDefaults`
- Bookmark data for secure folder access
- Radio stations as JSON

### Window
- Fixed 400x600 size (set in AppDelegate)

## Build
Standard Xcode project, no Package.swift. TelemetryDeck via SPM.

## Commands
```bash
# Build
xcodebuild -project Pod.xcodeproj -scheme Pod build

# Test (if tests exist)
xcodebuild -project Pod.xcodeproj -scheme Pod test
```
