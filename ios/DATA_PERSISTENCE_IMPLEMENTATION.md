# Data Persistence Implementation

## Overview
Implemented centralized data management to prevent reloading data every time users switch tabs. Data is now loaded once per session and persists across all tab views.

## Changes Made

### 1. Created `UserDataViewModel.swift`
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/ViewModels/UserDataViewModel.swift`

A singleton view model that centralizes all user data management:

**Features**:
- **Singleton Pattern**: Single shared instance across the entire app
- **User-Specific Data**: All data is tied to the authenticated user's ID
- **Smart Loading**: Only loads data once per session unless explicitly refreshed
- **Published Properties**: All UI updates automatically via SwiftUI's @Published
- **Parallel Loading**: Loads profile, health score, analyses, and chat history in parallel for better performance

**Published Properties**:
```swift
@Published var userName: String?
@Published var healthScore: Double
@Published var animatedProgress: Double
@Published var topBiomarkers: [HealthScoreService.BiomarkerAttention]
@Published var hasAnalyses: Bool
@Published var analyses: [Analysis]
@Published var chatMessages: [ChatMessageDTO]
@Published var isLoadingProfile: Bool
@Published var isLoadingHealthScore: Bool
@Published var isLoadingAnalyses: Bool
@Published var isLoadingChat: Bool
@Published var healthScoreError: String?
@Published var analysesError: String?
```

**Public Methods**:
- `loadAllUserData()`: Loads all user data (called once on login/app launch)
- `refreshUserProfile()`: Force refresh user profile
- `refreshHealthScore()`: Force refresh health score
- `refreshAnalyses()`: Force refresh analyses list
- `refreshChat()`: Force refresh chat history
- `addChatMessage(_:)`: Add a new chat message (optimistic update)
- `clearAllData()`: Clear all data (called on logout)

### 2. Updated `HomeTabView`
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/HomeView.swift`

**Changes**:
- Removed all local @State properties for user data
- Now uses `@StateObject private var userData = UserDataViewModel.shared`
- Removed `loadUserProfile()` and `loadHealthScore()` methods
- Removed `onAppear` data loading logic
- All data now comes from the shared view model

**Before**:
```swift
@State private var healthScore: Double = 0.0
@State private var userName: String? = nil
@State private var topBiomarkers: [...]
// ... etc

.onAppear {
    loadUserProfile()
    loadHealthScore()
}
```

**After**:
```swift
@StateObject private var userData = UserDataViewModel.shared

// Data is loaded centrally, no need to reload here
```

### 3. Updated `HistoryTabView`
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/HomeView.swift`

**Changes**:
- Removed local analyses state
- Now uses shared `userData.analyses`
- Removed `loadAnalyses()` method
- Removed `onAppear` loading logic
- Pull-to-refresh now calls `userData.refreshAnalyses()`

### 4. Updated `ChatTabView`
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/HomeView.swift`

**Changes**:
- Removed local `messages` and `userName` state
- Now uses `userData.chatMessages` and `userData.userName`
- Removed complex `initializeChat()` profile loading logic
- Optimistic updates now use `userData.addChatMessage()`
- Simplified to only get userId on appear

### 5. Updated `AppState` and `RootView`
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/appApp.swift`

**Changes**:
- `checkAuthentication()` now loads user data after finding a valid session
- `signOut()` now calls `UserDataViewModel.shared.clearAllData()`
- Data loading happens automatically on app launch if user is authenticated

### 6. Updated Sign-In/Sign-Up Flows
**Files Modified**:
- `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/OnboardingView.swift` (already had data loading)
- `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/SignUpCredentialsView.swift`
- `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/SignUpPersonalView.swift`

**Changes**:
- All successful authentication flows now call `UserDataViewModel.shared.loadAllUserData()`
- Ensures data is available immediately after login/signup

### 7. Updated Theme Colors
**Location**: `/Users/marwansorour/Desktop/Lumo/ios/app/app/Views/HomeView.swift`

**Fixed System Theme Issue**:
- Progress bar stroke color now uses `AppColors.text(themeManager.colorScheme)`
- "Your trends" button now uses proper adaptive colors
- Colors now work correctly in System, Light, and Dark modes

## How It Works

### Data Loading Flow

1. **App Launch**:
   ```
   App Starts → Check Authentication → If Authenticated → Load All User Data
   ```

2. **Sign In/Sign Up**:
   ```
   User Signs In → Set isAuthenticated = true → Load All User Data
   ```

3. **Tab Switching**:
   ```
   User Switches Tabs → Data Already Loaded → No Reload → Instant Display
   ```

4. **Sign Out**:
   ```
   User Signs Out → Clear All Data → Set isAuthenticated = false
   ```

### Benefits

1. **Better Performance**: Data loads once instead of on every tab switch
2. **Better UX**: No loading indicators when switching tabs
3. **Centralized Logic**: All data management in one place
4. **User-Specific**: Data is tied to the logged-in user
5. **Memory Efficient**: Single instance shared across all views
6. **Type-Safe**: All data is properly typed and published

### Pull-to-Refresh

Users can still manually refresh data on specific tabs:
- **History Tab**: Pull down to refresh analyses
- Each tab can call the appropriate refresh method when needed

### User Isolation

The view model tracks the current user ID and automatically reloads data if the user changes (e.g., after logout and login with a different account).

## Testing Recommendations

1. **Test Tab Switching**: Verify no reloading occurs when switching between tabs
2. **Test Fresh Login**: Ensure all data loads correctly after sign-in
3. **Test Logout**: Verify all data is cleared after sign-out
4. **Test Different Users**: Switch between accounts and verify data isolation
5. **Test System Theme**: Verify colors work correctly in Light, Dark, and System modes
6. **Test Pull-to-Refresh**: Verify manual refresh works on History tab

## Future Enhancements

Potential improvements for the future:
1. Add data caching with timestamps for offline support
2. Implement incremental updates for chat messages (WebSocket/polling)
3. Add data expiration and automatic refresh after X minutes
4. Implement optimistic UI updates for all mutations
5. Add error recovery mechanisms for failed data loads
