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

## Common Development Commands

### Building and Running
```bash
# Open project in Xcode (primary development method)
open RunningBuddy3.xcodeproj

# Build for iPhone simulator
xcodebuild -scheme RunningBuddy3 -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for watchOS simulator
xcodebuild -scheme "RunningBuddy3Watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

### Testing
Note: Firebase Phone Authentication requires a real device with APNs token. Simulator testing will fail for phone auth flows.

```bash
# Run unit tests (if available)
xcodebuild -scheme RunningBuddy3 test -destination 'platform=iOS Simulator,name=iPhone 16'

# Test authentication flows on real device (required for APNs)
# Use Xcode GUI: Product > Run on connected device
```

## Architecture Overview

### Directory Structure

The project follows a modular MVVM architecture with clear separation of concerns:

- **Application/** - App lifecycle and initialization
  - `RunningBuddy3App.swift` - Main app entry point with Firebase initialization
  - `ContentView.swift` - Root navigation view
  - `FirebaseManager.swift` - Singleton for Firebase service access

- **View/** - SwiftUI views organized by feature
  - `Authentication/` - Modal-based authentication system
    - `SignUpview/` - Sequential signup flow with individual modals
    - `LoginView/` - Login interface
    - `FindEmailView/` - Email recovery by phone number
  - `Main/` - Main app navigation (MainAppView.swift)

- **Service/** - Business logic and external service integration
  - `Authentication/AuthenticationManager.swift` - Firebase Auth wrapper with state management
  - `User/UserService.swift` - Firestore user data management, hashing coordination, and email recovery
  - `Config/` - Validation and security services
    - `SecurityService.swift` - SHA-512 hashing with salt/pepper
    - `EmailValidator.swift` - RFC-compliant email validation
    - `PhoneNumberValidator.swift` - Korean phone number validation and formatting
    - `PasswordValidator.swift` - Password policy enforcement
    - `Config.swift` - Security constants (salt/pepper values, gitignored)

- **DataModel/** - Data models and entities
  - `User/UserData.swift` - User model with Firestore serialization (all sensitive data hashed)

### Key Architectural Patterns

1. **Modal-Based UI Flow**: Authentication uses sequential modals with state management through `SignUpViewModel`
   - Steps: Email → Password → Phone Number → Security Question → Completion
   - Each modal handles its own validation and real-time feedback
   - Debounced input validation (0.5s delay) for API calls

2. **Singleton Services**: Core services use singleton pattern for app-wide state management
   - `FirebaseManager` - Firebase service access
   - `UserService` - Data management and hashing coordination
   - `SecurityService` - Cryptographic operations
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

### Critical Security Files (gitignored)
- `Config.swift` - Contains salt/pepper values for SHA-512 hashing
- `GoogleService-Info.plist` - Firebase API keys and configuration

### Data Security Model
- **Emails**: Stored in plaintext (Firebase Auth requirement, used for login)
- **Phone Numbers**: SHA-512 hashed with salt/pepper before storage
- **Security Answers**: SHA-512 hashed with salt/pepper before storage
- **Passwords**: Managed by Firebase Authentication (never stored locally)
- **Password Validation**: Enforced client-side through `PasswordValidator`

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
  - Hash using `SecurityService.shared.hashPhoneNumber()`
  - Used for email recovery by phone number lookup
- **Security Answers**: Always hash before storage
  - Hash using `SecurityService.shared.hashSecurityAnswer()`
- **Hashing Location**: All hashing occurs in `UserService` layer
  - Never hash in UI components or `AuthenticationManager`
- **Duplicate Checking Pattern**: Query `publicdata` by document ID
  - For emails: Use plaintext email as document ID
- **Salt + Pepper**: `SecurityService` handles all cryptographic operations

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
  - Phone number-based email lookup via `UserService.findEmailByPhoneNumber()`
  - Select found email and send password reset link without login
  - Firebase Auth `sendPasswordReset()` integration
- **APNs integration**: Phone authentication support with silent push notification handling
- **Alert-based error handling**: All authentication errors displayed via SwiftUI alerts (no inline error text)

### Known Limitations
- Phone authentication requires real device (APNs unavailable in simulator)
- watchOS app structure exists but features not yet implemented

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