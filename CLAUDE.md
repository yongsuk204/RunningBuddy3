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
# Open project in Xcode
open RunningBuddy3.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -scheme RunningBuddy3 -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run on simulator
xcodebuild -scheme RunningBuddy3 -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### Testing
```bash
# Run unit tests
xcodebuild -scheme RunningBuddy3 test -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests (if available)
xcodebuild -scheme RunningBuddy3 -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UITests test
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

3. **Security-First Data Storage**: All PII is hashed before storage
   - Emails and phone numbers hashed with SHA-512 + salt + pepper
   - Hashed values used as Firestore document IDs for efficient duplicate checking
   - `publicdata` collection for duplicate checking without exposing actual values
   - `users` collection for full user profiles (all hashed)

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
- **Authentication**: Email/password authentication
- **Firestore**: Two-collection design for security
  - `users` collection: Complete user profiles (hashed data)
  - `publicdata` collection: Duplicate checking (document IDs are hashed emails/phones)

### Data Flow Architecture
1. **UI Validation**: Modals perform real-time validation with debouncing
2. **Duplicate Checking**: Hash input → query `publicdata` collection by document ID
3. **User Registration**: `AuthenticationManager` → `UserService` → `SecurityService` hashing → Firestore
4. **Security Layer**: All sensitive data hashed in `UserService` before storage
5. **State Management**: Reactive UI updates through `@Published` properties
6. **Email Recovery**: FindEmailView → hash phone number → query users collection → return original email

## Security Considerations

- `Config.swift` contains security constants (salt/pepper) - gitignored
- `GoogleService-Info.plist` contains API keys - gitignored
- Security answers are hashed before storage
- Password validation enforced through `PasswordValidator`

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

### Security Data Handling
- **Never store plaintext PII** - all emails, phones, security answers are hashed
- **Hashing happens in UserService** layer, not in UI or AuthenticationManager
- **Use document IDs for duplicate checking** - hash the input and query by document ID
- **Salt + Pepper pattern** - SecurityService handles cryptographic operations

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

- **Complete modal-based signup flow**: Email, password, phone number, security question
- **Real-time validation system**: Debounced API calls with visual feedback
- **Security-first data architecture**: SHA-512 hashing with salt/pepper
- **Duplicate checking system**: Efficient hash-based lookups in `publicdata` collection
- **Korean phone number support**: Formatting and validation for 010/011/016/017/018/019 numbers
- **Email recovery feature**: FindEmailView allows users to retrieve email by phone number verification