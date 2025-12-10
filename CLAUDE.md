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

The project follows a **feature-based modular architecture** where related components are grouped by functionality:

- **Application/** - App lifecycle and initialization
  - `RunningBuddy3App.swift` - Main app entry point with Firebase initialization
  - `RootView.swift` - Root navigation view
  - `FirebaseManager.swift` - Singleton for Firebase service access

- **Authentication/** - Authentication feature module
  - `AuthenticationManager.swift` - Firebase Auth wrapper with state management
  - `Service/` - Authentication services and validators
    - `UserService.swift` - Firestore user data management and ID recovery
    - `SecurityService.swift` - Hashing service for security answers (SHA-512 + pepper)
    - `PhoneVerificationService.swift` - SMS verification for ID recovery
    - `EmailValidator.swift` - RFC-compliant email validation
    - `PhoneNumberValidator.swift` - Korean phone number validation and formatting
    - `PasswordValidator.swift` - Password policy enforcement
    - `UsernameValidator.swift` - Username validation
  - `View/` - Authentication UI components
    - `SignUp/` - Sequential signup flow (SignUpView + SignUpViewModel + Modals)
    - `Login/` - Login interface (LoginView)
    - `FindEmail/` - ID recovery (FindEmailView + FindEmailViewModel)
    - `Components/` - Reusable UI components (ProgressIndicator, ValidationFeedbackIcon, etc.)

- **Workout/** - Workout and calibration feature module
  - `Service/` - Workout-related services
    - `StrideCalibratorService.swift` - 100m stride calibration logic
  - `View/` - Workout UI components
    - `MainAppView.swift` - Main app navigation and workout dashboard
    - `SettingsView.swift` - User settings and profile management
    - `CalibrationView.swift` - 100m stride calibration measurement screen
    - `CalibrationHistoryView.swift` - Calibration records history

- **Sensor/** - Sensor data processing module
  - `Service/` - Sensor data processing services
    - `CadenceCalculator.swift` - Real-time cadence calculation from accelerometer/gyroscope
    - `DistanceCalculator.swift` - GPS-based distance tracking with route polyline
    - `HeadingManager.swift` - Compass heading for map orientation
    - `SensorDataExporter.swift` - CSV export functionality for workout data
    - `StrideModelCalculator.swift` - Stride length calculation from calibration data
  - `View/` - Sensor UI components
    - `SensorDataView.swift` - Main sensor dashboard with map
    - `Components/` - Reusable sensor UI components
      - `CompactStatusCardView.swift` - Watch/GPS status indicators
      - `UnifiedMetricsCardView.swift` - Heart rate, cadence, distance metrics display

- **Connectivity/** - Watch-iPhone communication module
  - `PhoneConnectivityManager.swift` - iPhone-side Watch communication via WatchConnectivity

- **DataModel/** - Data models organized by domain
  - `User/` - User-related models
    - `UserData.swift` - User model with Firestore serialization
  - `Sensor/` - Sensor and workout models
    - `SensorData.swift` - Watch sensor data model (shared with watchOS target)
    - `GPSData.swift` - GPS location data model (shared with watchOS target)
    - `WorkoutData.swift` - Workout session data model
  - `Calibration/` - Calibration-related models
    - `CalibrationData.swift` - Stride calibration measurement data
    - `StrideData.swift` - Stride model parameters

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
   - `PhoneConnectivityManager` (Connectivity module) receives sensor data and GPS locations from Watch
   - `WatchConnectivityManager` (Watch) sends sensor data and receives workout commands
   - Bidirectional message passing: commands (iPhone → Watch), data (Watch → iPhone)
   - Event-driven architecture with `@Published` properties for reactive UI updates
   - CalibrationView monitors Watch connectivity with `.onChange(of: isWatchReachable)` for automatic GPS activation
   - **Data Models**: `SensorData` and `GPSData` use `.toDictionary()` / `.fromDictionary()` pattern for WatchConnectivity serialization

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
- **Firestore**: Single-collection design
  - `users` collection: Complete user profiles (email and phone numbers in plaintext, security answers hashed)

### Data Flow Architecture
1. **UI Validation**: Modals perform real-time validation with debouncing
2. **Duplicate Checking**: Firebase Auth `fetchSignInMethods()` API (no Firestore query needed)
3. **User Registration**: `AuthenticationManager` → `UserService` → `SecurityService` (security answer hashing) → Firestore
4. **Security Layer**: Minimal hashing in `UserService`
   - Emails: Stored in plaintext (Firebase Auth requirement)
   - Phone numbers: Stored in plaintext (enables efficient Firestore queries)
   - Security answers: SHA-512 hashed with pepper (comparison only, never retrieved)
5. **State Management**: Reactive UI updates through `@Published` properties in `SignUpViewModel`
6. **ID Recovery**: FindEmailView → query `users` collection by phone number → return plaintext ID (email)

## Security Considerations

### Critical Security Constants
- **Pepper**: Defined as `private static let` in `SecurityService.swift`
- **⚠️ IMPORTANT**: Pepper value is permanent after first deployment - cannot be changed without invalidating all existing user data
- **Before First Deployment**: Ensure pepper is a strong random string (200 characters, alphanumeric mix)
- `GoogleService-Info.plist` - Firebase API keys and configuration (gitignored)

### Data Security Model
- **Emails**: Stored in plaintext (Firebase Auth requirement, used as ID for login)
- **Phone Numbers**: Stored in plaintext (enables Firestore queries for ID recovery)
- **Security Answers**: SHA-512 hashed with pepper before storage (comparison only)
- **Passwords**: Managed by Firebase Authentication (never stored locally)
- **Password Validation**: Enforced client-side through `PasswordValidator`
- **Access Control**: Firestore Security Rules restrict data access to authenticated users only

### SecurityService Architecture
The `SecurityService` provides secure hashing for security answers only:
```swift
// Hash security answer
SecurityService.shared.hash(answer)

// Verify security answer
SecurityService.shared.verify(inputAnswer, hashedValue: storedHash)
```

Key features:
- Single source of truth for security answer hashing
- Data normalization handled internally (lowercase + whitespace trim)
- Private pepper constant prevents external access
- SHA-512 algorithm with pepper for strong one-way hashing

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
   - Validator service in `Authentication/Service/`
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
  - Duplicate checking via Firebase Auth `fetchSignInMethods()` API
  - Required for Firebase email/password authentication
- **Phone Number Storage**: Store in plaintext (enables efficient queries)
  - Used for ID recovery: `whereField("phoneNumber", isEqualTo: phoneNumber)`
  - Firestore Security Rules prevent unauthorized access
- **Security Answers**: Always hash before storage
  - Hash using `SecurityService.shared.hash(answer)`
  - Only for verification, never retrieved in plaintext
- **Hashing Location**: All hashing occurs in `UserService` layer
  - Never hash in UI components or `AuthenticationManager`
- **Duplicate Checking**: Use `AuthenticationManager.checkEmailExists()`
  - Firebase Auth manages email uniqueness internally
  - No separate Firestore collection needed
- **Pepper**: Integrated into `SecurityService` as private constant (200 characters)

### Code Style Conventions
- **Purpose comments**: Every property and function has a "Purpose:" comment explaining its role
- **Function list comments**: Every file has a `// MARK: - 함수 목록` section at the top documenting all public methods with brief descriptions
- **Step-by-step comments**: Complex functions break down logic with numbered steps
- **Korean text in UI**: User-facing strings are in Korean, code/comments in English
- **Modular structure**: One validator per input type, one modal per signup step
- **Visual separators**: Use decorative separators to clearly distinguish code sections
  - Apply to functions, computed properties, and any logically distinct code blocks
  - Not limited to functions - use wherever clear separation improves readability
- **Developer emoji annotations**: 👈 emoji and following comments are written by developer
  - **NEVER remove, modify, or add these annotations** - they are manual markers
  - Example: `private var isListenerEnabled: Bool = true  // 👈 리스너는 Auth의 변화가 있을때만 자동감지함`
- **Print statements**: DO NOT add print() statements unless explicitly requested by the developer
  - Includes debug logs, success messages, error messages, etc.
  - Exception: Developer may request specific logging for debugging purposes

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

Example visual separator (applies to all code sections):
```swift
// For functions
// ═══════════════════════════════════════
// PURPOSE: 함수의 주요 목적 설명
// ═══════════════════════════════════════
func functionName() {
    // Implementation
}

// For computed properties
// ═══════════════════════════════════════
// PURPOSE: 다음 버튼 제목 반환
// ═══════════════════════════════════════
private var nextButtonTitle: String {
    // Implementation
}

// For View properties (SwiftUI)
// MARK: - Navigation Section
// ═══════════════════════════════════════
// PURPOSE: 네비게이션 버튼 섹션
// ═══════════════════════════════════════
private var navigationSection: some View {
    // Implementation
}
```

This separator pattern provides:
- Clear visual boundaries between all code sections (functions, properties, computed properties)
- Easy scanning when reviewing code
- Consistent documentation style across the codebase
- PURPOSE comment in all caps for better visibility
- Apply to any logically distinct code block that benefits from visual separation

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
- **ID recovery with password reset**:
  - Phone number-based ID lookup via `UserService.findEmailByPhoneNumber()` (single account per phone)
  - SMS verification through `PhoneVerificationService` (not for login, only for ID recovery)
  - Send password reset link without login
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

## Design System

The app uses a comprehensive **DesignSystem** defined in `Resource/DesignSystem.swift` for consistent UI styling across all views.

### Architecture
- **Design File**: `Resource/DesignSystem.swift`
- **Theme Manager**: `ThemeManager.shared` (singleton for quick access)
- **Pattern**: Centralized design tokens with SwiftUI View extensions

### Color Palette

**Background Gradient** (Neutral Dark Gray):
- Gradient Start: `#2C2C2E` (RGB: 0.17, 0.17, 0.18)
- Gradient End: `#48484A` (RGB: 0.28, 0.28, 0.29)

**Status Colors**:
- Success: Green
- Error: Red
- Warning: Orange
- Info: Blue
- Neutral: Gray

**Metric Icon Colors**:
- Heart Rate: Red
- Cadence: Orange
- Distance: Blue

### Design Tokens

**Spacing** (4px grid):
- xs: 4, sm: 8, md: 16, lg: 20, xl: 40, xxl: 60

**Corner Radius**:
- small: 12, medium: 16, large: 20

**Opacity Levels**:
- subtle: 0.1, light: 0.2, medium: 0.3, semiMedium: 0.6, strong: 0.8, veryStrong: 0.9

**Typography**:
- Large Value: 32pt bold rounded
- Medium Value: 24pt semibold rounded
- Icon sizes: Large (60pt), Medium (title2), Small (title3)

### View Extensions Usage

**Background Gradient**:
```swift
@StateObject private var themeManager = ThemeManager.shared

var body: some View {
    ZStack {
        LinearGradient(
            colors: [
                themeManager.gradientStart.opacity(0.6),
                themeManager.gradientEnd.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        // Content
    }
}
```

**Card Styles**:
```swift
// Standard card with material background
VStack {
    // Content
}
.cardStyle(
    cornerRadius: DesignSystem.CornerRadius.medium,
    shadow: DesignSystem.Shadow.card
)

// Overlay card for map (semi-transparent)
VStack {
    // Content
}
.overlayCardStyle(
    cornerRadius: DesignSystem.CornerRadius.small,
    shadow: DesignSystem.Shadow.subtle
)
```

**Button Styles**:
```swift
// Primary button
Text("확인")
    .primaryButtonStyle(backgroundColor: DesignSystem.Colors.buttonSuccess)

// Secondary button
Text("취소")
    .secondaryButtonStyle()

// Modal buttons
Text("다음")
    .modalPrimaryButtonStyle(isDisabled: !isValid)
```

### Current Coverage
- ✅ LoginView
- ✅ SignUpView (and all signup modals with Glass UI)
- ✅ FindEmailView
- ✅ MainAppView
- ✅ SensorDataView (overlay cards on map)
- ✅ CalibrationView
- ✅ CalibrationHistoryView

## watchOS Companion App

### Apple Watch Mounting Specification

**Mounting Position**: 왼쪽 발목 안쪽 복사뼈 바로 위쪽 (Left ankle, just above the medial malleolus)

**Coordinate System** (Device Frame):
- **+X axis**: Points toward the ground (발바닥 방향) - Horizontal plane rotation axis
- **+Y axis**: Points forward (정면 방향) - Coronal plane rotation axis
- **+Z axis**: Points toward the right foot (오른쪽 발 방향) - Sagittal plane rotation axis

**Physical Interpretation During Running**:
- **Accelerometer X**: Vertical acceleration (ground impact detection)
- **Accelerometer Y**: Forward/backward swing acceleration (used in cadence detection)
- **Gyroscope Z**: Foot rotation (primary axis for cadence peak detection)

### Directory Structure
- **RunningBuddy3Watch Watch App/** - watchOS app (separate target)
  - `WatchWorkoutView.swift` - Main workout interface
  - `Service/WatchSensorManager.swift` - Heart rate, accelerometer, gyroscope collection
  - `Service/WatchGPSManager.swift` - GPS location tracking
  - `Service/WatchConnectivityManager.swift` - Communication with iPhone

### Shared Data Models (Multi-Target)
Both `SensorData` and `GPSData` are shared between iPhone and Watch targets:

**SensorData** - Accelerometer, gyroscope, heart rate data
- Properties: `heartRate` (optional), `accelerometerX/Y/Z`, `gyroscopeX/Y/Z`, `timestamp`
- Serialization: `.toDictionary()` → WatchConnectivity → `.fromDictionary()`
- Target Membership: RunningBuddy3 + RunningBuddy3Watch Watch App

**GPSData** - GPS location data
- Properties: `latitude`, `longitude`, `altitude`, `horizontalAccuracy`, `verticalAccuracy`, `speed`, `course`, `timestamp`
- Initializers: `init(location: CLLocation)` for Watch → `init(latitude:longitude:...)` for dictionary parsing
- Conversion: `.toCLLocation()` converts back to CLLocation on iPhone
- **Important**: Uses `init(location:)` not `init(from:)` to avoid conflict with `Codable` protocol
- Target Membership: RunningBuddy3 + RunningBuddy3Watch Watch App

### Watch-to-iPhone Data Flow
1. Watch collects sensor data (heart rate, motion) at high frequency (20Hz)
2. Watch tracks GPS location with accuracy monitoring (3m distance filter)
3. `WatchConnectivityManager` serializes data models to dictionaries via `.toDictionary()`
4. Data sent to iPhone via `WCSession.sendMessage()` (requires Watch reachability)
5. iPhone's `PhoneConnectivityManager` receives dictionaries and deserializes via `.fromDictionary()`
6. iPhone processes data through `CadenceCalculator`, `DistanceCalculator`, etc.
7. iPhone displays real-time metrics and map visualization

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

## Data Sharing Architecture (iPhone ↔ Watch)

### Single-Source Data Flow Pattern
The app uses an efficient **single data stream** architecture where GPS and sensor data are collected once and shared across features:

**GPS Data Sharing** (Already Implemented):
```swift
// Watch sends GPS → iPhone receives → Single processor
Watch: WatchGPSManager → WatchConnectivityManager.sendLocation()
iPhone: PhoneConnectivityManager receives → DistanceCalculator.shared.addLocation()
```
- ✅ `DistanceCalculator.shared` is the **single source** for GPS distance calculations
- ✅ Both real-time workout and calibration use the same `totalDistance` property
- ✅ No duplicate GPS processing - efficient and consistent

**Sensor Data Sharing** (Already Implemented):
```swift
// Watch sends sensor data → iPhone receives → Multiple processors
Watch: WatchSensorManager → WatchConnectivityManager.sendSensorData()
iPhone: PhoneConnectivityManager receives → {
    1. receivedSensorData (@Published) for UI updates
    2. CalibrationSession.addSensorData() for 100m calibration storage
    3. CadenceCalculator.addSensorData() for real-time cadence (10s sliding window)
}
```

**Why Separate Processing Paths**:
- `CadenceCalculator`: **Memory efficient** (10s sliding window, 3s update cycle)
- `CalibrationSession`: **Accuracy focused** (stores all data for 100m, single calculation at end)
- Different purposes require different data retention strategies

### Best Practices for Data Sharing
1. **Push Model (Current)**: Direct function calls for immediate data transfer
   - ✅ Zero latency, no data loss at 20Hz sensor rate
   - ✅ Minimal memory overhead
   - Used for: `CalibrationSession.addSensorData(sensorData)`

2. **Avoid @Published Subscription** for high-frequency data:
   - ❌ 20Hz updates would trigger excessive UI re-renders
   - ❌ Combine pipeline overhead for every sensor reading
   - ❌ Risk of data loss if main thread is busy
   - **Exception**: `receivedSensorData` is @Published for **display only** (latest value)

3. **Shared Singleton Pattern**:
   - `DistanceCalculator.shared` - GPS distance (shared by workout & calibration)
   - `CadenceCalculator.shared` - Real-time cadence (shared by all workout views)
   - Single instance = consistent state across app
