# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RunningBuddy3 is an iOS application built with SwiftUI and Firebase, targeting iOS 17+ and designed for running tracking and social features. The project includes both an iPhone app and a watchOS companion app.

## Development Environment

- **IDE**: Xcode 16.4+ (required)
- **Language**: Swift 6+
- **Minimum iOS Version**: iOS 17
- **UI Framework**: SwiftUI
- **Backend**: Firebase (Authentication, Firestore, Realtime Database)

## Architecture Overview

### Directory Structure

The project follows a modular MVVM architecture with clear separation of concerns:

- **Application/** - App lifecycle and initialization
  - `RunningBuddy3App.swift` - Main app entry point with Firebase initialization
  - `ContentView.swift` - Root navigation view
  - `FirebaseManager.swift` - Singleton for Firebase service access
  - `Theme/ColorTheme.swift` - Fixed app color theme (Swedish/IKEA style: sky blue → lemon yellow)

- **View/** - SwiftUI views organized by feature
  - `Authentication/` - Modal-based authentication system
    - `SignUpview/` - Sequential signup flow with individual modals
    - `LoginView/` - Login interface
    - `FindEmailView/` - Email recovery by phone number
  - `Main/` - Main app navigation (MainAppView.swift)

- **Service/** - Business logic and external service integration
  - `Authentication/AuthenticationManager.swift` - Firebase Auth wrapper with state management
  - `Authentication/PhoneVerificationService.swift` - SMS verification for email recovery (not login)
  - `User/UserService.swift` - Firestore user data management, hashing coordination, and email recovery
  - `Config/` - Validation and security services
    - `SecurityService.swift` - Unified hashing service with type-safe DataType enum (salt/pepper integrated)
    - `EmailValidator.swift` - RFC-compliant email validation
    - `PhoneNumberValidator.swift` - Korean phone number validation and formatting
    - `PasswordValidator.swift` - Password policy enforcement

- **DataModel/** - Data models and entities
  - `User/UserData.swift` - User model with Firestore serialization (all sensitive data hashed)
  - `Sensor/SensorData.swift` - Watch sensor data model with dictionary serialization for WatchConnectivity

- **Resource/** - App-wide resources
  - `DesignSystem.swift` - Centralized design tokens (colors, spacing, typography, shadows)

### Key Architectural Patterns

1. **Modal-Based UI Flow**: Authentication uses sequential modals with state management through `SignUpViewModel`
   - Steps: Email → Password → Phone Number → Security Question → Completion
   - Each modal handles its own validation and real-time feedback
   - Debounced input validation (0.5s delay) for API calls

2. **Singleton Services**: Core services use singleton pattern for app-wide state management
   - `FirebaseManager` - Firebase service access
   - `UserService` - Data management with prepared-but-unused methods for future features
   - `SecurityService` - Type-safe hashing with `DataType` enum (`.securityAnswer`, `.phoneNumber`)
   - Individual validators for email, phone, and password

3. **Security-First Data Storage**: Selective hashing for optimal security and functionality
   - Emails stored in plaintext (Firebase Auth requirement), used as `publicdata` document IDs
   - Phone numbers and security answers hashed with SHA-512 + salt + pepper
   - `publicdata` collection for duplicate email checking (document ID = email)
   - `users` collection for full user profiles (document ID = Firebase Auth UID)

4. **Real-time Validation Pattern**: UI modals perform comprehensive validation
   - Format validation → API duplicate check → Visual feedback
   - ValidationFeedbackIcon shows status (none/checking/valid/invalid)
   - Form progression blocked until current step validates

5. **Async/Await**: All Firebase operations use Swift's modern concurrency model with proper error handling

6. **Watch-iPhone Communication**: Real-time sensor streaming using WatchConnectivity framework
   - `PhoneConnectivityManager` (iPhone) receives sensor data and GPS locations from Watch
   - `WatchConnectivityManager` (Watch) sends sensor data and receives workout commands
   - Bidirectional message passing: commands (iPhone → Watch), data (Watch → iPhone)
   - Event-driven architecture with `@Published` properties for reactive UI updates

7. **Sensor Data Processing**: iPhone processes raw sensor data from Watch
   - `CadenceCalculator.shared` - Real-time cadence (steps per minute) from accelerometer/gyroscope
   - `DistanceCalculator.shared` - GPS-based distance tracking with route polyline
   - `HeadingManager.shared` - Compass heading for map orientation
   - `SensorDataExporter` - CSV export functionality for workout data

8. **Design System**: Centralized design tokens in `DesignSystem.swift`
   - Colors, spacing, typography, corner radius, shadows defined as enums
   - View extensions (`.appGradientBackground()`, `.cardStyle()`, `.overlayCardStyle()`)
   - Theme consistency enforced across all UI components

## Firebase Integration

### Required Configuration Files
- `GoogleService-Info.plist` - Firebase configuration (gitignored for security)
- Must be placed in `/RunningBuddy3/` directory

### Firebase Services Used
- **Authentication**: Email/password authentication with APNs integration for phone verification
- **Firestore**: Two-collection design for security
  - `users` collection: Complete user profiles (email stored in plaintext, phone numbers hashed)
  - `publicdata` collection: Duplicate checking (document IDs are plaintext emails for efficient lookup)

### Data Flow Architecture
1. **UI Validation**: Modals perform real-time validation with debouncing
2. **Duplicate Checking**: Query `publicdata` collection by document ID (plaintext email)
3. **User Registration**: `AuthenticationManager` → `UserService` → `SecurityService` (selective hashing) → Firestore
4. **Security Layer**: Selective hashing in `UserService`
   - Emails: Stored in plaintext (used as document IDs in `publicdata`)
   - Phone numbers: SHA-512 hashed with salt/pepper
   - Security answers: SHA-512 hashed with salt/pepper
5. **State Management**: Reactive UI updates through `@Published` properties in `SignUpViewModel`
6. **Email Recovery**: FindEmailView → hash phone number → query `users` collection → return plaintext email

## Security Considerations

### Critical Security Constants
- **Salt/Pepper**: Defined as `private static let` in `SecurityService.swift`
- **⚠️ IMPORTANT**: Salt/pepper values are permanent after first deployment - cannot be changed without invalidating all existing user data
- **Before First Deployment**: Ensure salt/pepper are strong random strings (128+ characters recommended)
- `GoogleService-Info.plist` - Firebase API keys and configuration (gitignored)

### Data Security Model
- **Emails**: Stored in plaintext (Firebase Auth requirement, used for login)
- **Phone Numbers**: SHA-512 hashed with salt before storage
- **Security Answers**: SHA-512 hashed with pepper before storage
- **Passwords**: Managed by Firebase Authentication (never stored locally)
- **Password Validation**: Enforced client-side through `PasswordValidator`

### SecurityService Architecture
The unified `SecurityService` provides type-safe hashing:
```swift
enum DataType {
    case securityAnswer  // Uses pepper
    case phoneNumber     // Uses salt
}

// Hash any data type
SecurityService.shared.hash(data, type: .phoneNumber)

// Verify any data type
SecurityService.shared.verify(input, hashedValue: stored, type: .securityAnswer)
```

Key features:
- Single source of truth for all hashing operations
- Automatic salt/pepper selection based on data type
- Data normalization handled internally (lowercase for answers, remove hyphens for phone)
- Private salt/pepper constants prevent external access

### APNs and Phone Authentication
- APNs token registration required for Firebase Phone Authentication
- Silent push notifications used for device verification
- Real device required for testing phone auth flows (simulator lacks APNs)

## Working with the Codebase

### Authentication System Extension
When adding new signup steps or modifying the authentication flow:

1. **Update SignUpStep enum** in `SignUpViewModel` with new case
2. **Add validation state** to `ValidationStates` struct
3. **Create modal component** following existing pattern:
   - Validator service in `Service/Config/`
   - Modal view with real-time validation and debouncing
   - Integration with `ValidationFeedbackIcon`
4. **Update SignUpView** switch statement for new modal
5. **Modify UserService** if new data fields require storage
6. **Update CompletionModal** to display new information

### Validation Pattern Implementation
All input validation follows this pattern:
```swift
// Real-time format validation
guard validator.isBasicValidFormat(input) else {
    viewModel.validationStates.fieldStatus = .none
    return
}

// Set checking state
viewModel.validationStates.fieldStatus = .checking

// Debounced API validation (0.5s timer)
timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
    Task { @MainActor in
        // Detailed validation + duplicate check
        let result = validator.validateField(input)
        let exists = try await userService.checkFieldInPublicData(input)
        viewModel.validationStates.fieldStatus = result.isValid && !exists ? .valid : .invalid
    }
}
```

### Security Data Handling Rules
- **Email Storage**: Store in plaintext (Firebase Auth requirement)
  - Used as document IDs in `publicdata` collection for duplicate checking
  - Required for Firebase email/password authentication
- **Phone Number Storage**: Always hash before storage
  - Hash using `SecurityService.shared.hash(phoneNumber, type: .phoneNumber)`
  - Used for email recovery by phone number lookup
- **Security Answers**: Always hash before storage
  - Hash using `SecurityService.shared.hash(answer, type: .securityAnswer)`
- **Hashing Location**: All hashing occurs in `UserService` layer
  - Never hash in UI components or `AuthenticationManager`
- **Duplicate Checking Pattern**: Query `publicdata` by document ID
  - For emails: Use plaintext email as document ID
- **Salt + Pepper**: Integrated into `SecurityService` as private constants, automatically selected by `DataType`

### Code Style Conventions
- **Purpose comments**: Every property and function has a "Purpose:" comment explaining its role
- **Function list comments**: Every file has a `// MARK: - 함수 목록` section at the top documenting all public methods with brief descriptions
- **Step-by-step comments**: Complex functions break down logic with numbered steps
- **Korean text in UI**: User-facing strings are in Korean, code/comments in English
- **Modular structure**: One validator per input type, one modal per signup step

Example function list format:
```swift
// Purpose: 서비스 설명
// MARK: - 함수 목록
/*
 * Category Name
 * - methodName(): 간단한 설명
 * - anotherMethod(): 간단한 설명
 */
```

### Testing Authentication Flows
- Test all signup steps in sequence (email → password → phone → security → completion)
- Verify ValidationFeedbackIcon states (none → checking → valid/invalid)
- Test duplicate checking with existing data
- Validate that all hashing occurs properly before Firestore storage
- Check that `publicdata` collection entries are created for duplicate checking

## Current Development Status

### Implemented Features
- **Modal-based signup flow**: Sequential Email → Password → Phone Number → Security Question → Completion
- **Real-time validation**: Debounced (0.5s) API calls with `ValidationFeedbackIcon` states
- **Security architecture**: SHA-512 hashing for phone numbers and security answers
- **Duplicate prevention**: `publicdata` collection with email as document ID
- **Korean phone validation**: Support for 010/011/016/017/018/019 prefixes with formatting
- **Email recovery with password reset**:
  - Phone number-based email lookup via `UserService.findEmailsByPhoneNumber()` (supports multiple accounts)
  - SMS verification through `PhoneVerificationService` (not for login, only for email recovery)
  - Select found email and send password reset link without login
  - Firebase Auth `sendPasswordReset()` integration
- **APNs integration**: Phone authentication support with silent push notification handling
- **Alert-based error handling**: All authentication errors displayed via SwiftUI alerts (no inline error text)
- **Fixed color theme**: Swedish/IKEA style with sky blue (#3399DB) to lemon yellow (#FFDE33) gradient applied across all views via `ThemeManager.shared`

### Known Limitations
- Phone authentication requires real device (APNs unavailable in simulator)
- watchOS app fully functional for sensor data collection and iPhone communication

### Prepared-But-Unused Methods
Several methods in `UserService` are implemented but not currently used, marked with `STATUS: 🔜 준비 완료 (미사용)`:
- `verifySecurityAnswer()` - For password reset/account recovery flows
- `updateUserData()` - For profile editing, security question changes
- `deleteUserData()` - For account deletion (cleans both `users` and `publicdata` collections)

These methods are production-ready and waiting for UI implementation.

## Data Migration Strategy

The app uses **per-user progressive migration** executed during login:
- `AuthenticationManager.signIn()` calls `UserService.migrateUserData(userId:)` after successful authentication
- Migration runs once per user, updating their Firestore document structure
- Failures are logged but don't block login (non-destructive)
- Example: `hashedSecurityAnswer` → `securityAnswer` field rename

When adding new migrations:
1. Add migration logic to `UserService.migrateUserData()`
2. Check for old field existence before updating
3. Use `FieldValue.delete()` to remove deprecated fields
4. Always fail gracefully - never throw errors that block user access

## Error Message Handling Pattern

The app uses a **shared `AuthenticationManager.errorMessage`** property for error communication between Service and View layers. To prevent message pollution across views:

### Pattern: Defensive Message Cleanup
```swift
// In any View that uses AuthenticationManager
.onAppear {
    // Clear previous error messages when entering view
    authManager.errorMessage = ""
}

// After capturing error message locally
private func handleAction() async {
    await authManager.someAuthMethod()

    if !authManager.errorMessage.isEmpty {
        localAlertMessage = authManager.errorMessage
        showingAlert = true

        // Clear immediately to prevent cross-view pollution
        await MainActor.run {
            authManager.errorMessage = ""
        }
    }
}
```

### Key Points
- **Always use local `@State` for alerts**: Never directly bind `authManager.errorMessage` to UI
- **Clear in `.onAppear`**: Prevents leftover messages from other views
- **Clear after capture**: Prevents message from appearing in unrelated views
- **This is defensive coding**: Both clearing points may seem redundant but provide safety against unexpected navigation flows

## UI Theme System

### Color Theme Architecture
The app uses a **fixed color theme** system with Swedish/IKEA style colors applied consistently across all views:

- **Theme File**: `Application/Theme/ColorTheme.swift`
- **Manager**: `ThemeManager.shared` (singleton)
- **Colors**:
  - Gradient Start: Sky Blue `#3399DB` (RGB: 51, 153, 219)
  - Gradient End: Lemon Yellow `#FFDE33` (RGB: 255, 222, 51)

### Applying Theme to New Views
All views with background gradients should use the theme system:

```swift
@StateObject private var themeManager = ThemeManager.shared

var body: some View {
    ZStack {
        // Background gradient - Theme applied
        LinearGradient(
            colors: [
                themeManager.currentTheme.gradientStart.opacity(0.6),
                themeManager.currentTheme.gradientEnd.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        // Your view content here
    }
}
```

### Current Theme Coverage
- ✅ LoginView
- ✅ SignUpView (and all signup modals)
- ✅ FindEmailView
- ✅ MainAppView
- ✅ SensorDataView (uses DesignSystem for overlay cards)

## watchOS Companion App

### Directory Structure
- **RunningBuddy3Watch Watch App/** - watchOS app (separate target)
  - `WatchWorkoutView.swift` - Main workout interface
  - `Service/WatchSensorManager.swift` - Heart rate, accelerometer, gyroscope collection
  - `Service/WatchGPSManager.swift` - GPS location tracking
  - `Service/WatchConnectivityManager.swift` - Communication with iPhone

### Watch-to-iPhone Data Flow
1. Watch collects sensor data (heart rate, motion) at high frequency
2. Watch tracks GPS location with accuracy monitoring
3. `WatchConnectivityManager` sends data to iPhone via `WCSession.sendMessage()`
4. iPhone's `PhoneConnectivityManager` receives and processes data
5. iPhone displays real-time metrics and map visualization

### Workout Control Flow
1. User starts workout on iPhone (taps play button in SensorDataView toolbar)
2. iPhone sends "start" command to Watch via `PhoneConnectivityManager.sendCommand(.start)`
3. Watch receives command and activates `WatchSensorManager` and `WatchGPSManager`
4. Sensor data streams from Watch to iPhone during workout
5. User stops workout on iPhone, triggering "stop" command to Watch

## Sensor Data & Workout Tracking

### Real-time Sensor Architecture
The app uses a multi-layer architecture for processing Watch sensor data on iPhone:

1. **Data Collection (Watch)**:
   - `WatchSensorManager` - Collects heart rate, accelerometer, gyroscope data
   - `WatchGPSManager` - Tracks GPS location with accuracy monitoring
   - `WatchConnectivityManager` - Streams data to iPhone via WatchConnectivity

2. **Data Reception (iPhone)**:
   - `PhoneConnectivityManager.shared` - Receives sensor data and GPS locations
   - Updates `@Published` properties that trigger UI updates
   - Passes data to processing services

3. **Data Processing (iPhone)**:
   - `CadenceCalculator.shared` - Calculates steps per minute from accelerometer/gyroscope
   - `DistanceCalculator.shared` - Calculates total distance from GPS coordinates
   - `HeadingManager.shared` - Provides compass heading for map orientation
   - `SensorDataExporter` - Exports workout data to CSV format

### Map Modes in SensorDataView
The app supports three map camera modes for GPS tracking:

1. **Automatic Mode** (`MapMode.automatic`)
   - Shows entire route with dynamic region calculation
   - Camera automatically adjusts to fit all GPS points
   - Icon: `location.fill`

2. **Manual Mode** (`MapMode.manual`)
   - User can pan/zoom the map freely
   - Camera position preserved during workout
   - Activated when user touches/drags map
   - Icon: `hand.tap.fill`

3. **Heading Mode** (`MapMode.heading`)
   - Camera follows user's current heading (compass direction)
   - Uses `HeadingManager` for real-time compass updates
   - Fixed camera distance (1500m altitude)
   - Icon: `location.north.line.fill`

Users cycle through modes by tapping the distance metric card. Map mode changes trigger `handleDistanceTap()` in SensorDataView:358.

### GPS Accuracy Thresholds
- **Active GPS**: `horizontalAccuracy <= 50.0` meters (MapConstants.gpsAccuracyThreshold)
- **Signal Quality Levels**: Very Good (<10m), Good (<20m), Fair (<50m), Poor (>=50m)
- **Minimum Map Span**: 0.01 degrees (~1km) to prevent excessive zoom

## Design System Usage

### Applying Design Tokens
All UI components should use `DesignSystem` tokens instead of hardcoded values:

```swift
// ✅ Correct - Uses design tokens
Text("Hello")
    .foregroundColor(DesignSystem.Colors.textPrimary)
    .padding(DesignSystem.Spacing.md)

// ❌ Incorrect - Hardcoded values
Text("Hello")
    .foregroundColor(.white)
    .padding(16)
```

### Component Styling Patterns
```swift
// Background gradient
.appGradientBackground(opacity: 0.6)

// Card with material background
.cardStyle(
    cornerRadius: DesignSystem.CornerRadius.medium,
    shadow: DesignSystem.Shadow.card
)

// Overlay card (semi-transparent, for map overlays)
.overlayCardStyle(
    cornerRadius: DesignSystem.CornerRadius.small,
    shadow: DesignSystem.Shadow.subtle
)
```

### Factory Method Pattern for Components
Reusable components use static factory methods to encapsulate creation logic:

```swift
// Example: CompactStatusCard factory methods
CompactStatusCard.watchStatus(isReachable: true)
CompactStatusCard.gpsStatus(location: location, isActive: true)
```

This pattern is preferred over computed properties that simply wrap component initialization.
