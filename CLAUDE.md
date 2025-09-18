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
  - `Authentication/` - Login and signup views
  - `Main/` - Main app navigation
  - `Profile/` - User profile views
  - `Running/` - Running-related views

- **Service/** - Business logic and external service integration
  - `Authentication/AuthenticationManager.swift` - Firebase Auth wrapper with state management
  - `User/UserService.swift` - Firestore user data management
  - `Config/` - Security and configuration services
    - `Config.swift` - App configuration constants
    - `SecurityService.swift` - Password hashing and security
    - `PasswordValidator.swift` - Password validation logic

- **DataModel/** - Data models and entities
  - `User/UserData.swift` - User model with Firestore serialization

### Key Architectural Patterns

1. **Singleton Services**: Core services (`FirebaseManager`, `UserService`, `SecurityService`) use singleton pattern for app-wide state management

2. **Observable Objects**: Authentication and state management use `@Published` properties with Combine for reactive UI updates

3. **Async/Await**: All Firebase operations use Swift's modern concurrency model

4. **Security Layer**: Custom security service handles password hashing with salt/pepper before storage

## Firebase Integration

### Required Configuration Files
- `GoogleService-Info.plist` - Firebase configuration (gitignored for security)
- Must be placed in `/RunningBuddy3/` directory

### Firebase Services Used
- **Authentication**: Email/password authentication
- **Firestore**: User data and profile storage
- **Realtime Database**: Available for real-time features

### Data Flow
1. User authentication through `AuthenticationManager`
2. User data persistence through `UserService`
3. Security validation through `SecurityService`
4. All Firebase access centralized through `FirebaseManager`

## Security Considerations

- `Config.swift` contains security constants (salt/pepper) - gitignored
- `GoogleService-Info.plist` contains API keys - gitignored
- Security answers are hashed before storage
- Password validation enforced through `PasswordValidator`

## Working with the Codebase

### Adding New Features
1. Create view files in appropriate `View/` subdirectory
2. Add service logic in `Service/` layer
3. Define data models in `DataModel/`
4. Follow existing patterns for Firebase integration

### Code Style
- Single responsibility principle: One function per file where appropriate
- Comprehensive inline comments explaining purpose and logic flow
- SwiftUI declarative style with property wrappers
- Async/await for all asynchronous operations

### Testing Approach
- Test in Xcode 16.4 before committing changes
- Verify Firebase operations in development environment
- Check authentication flows end-to-end
- Validate security service hashing functions

## Current Development Status

- Basic authentication (login/signup) implemented
- User data model and Firestore integration complete
- Security service with hashing implemented
- watchOS app structure initialized