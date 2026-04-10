# Family Task Manager 🏡✅

A smart, real-time Flutter application designed to help families organize daily chores, manage private tasks, and build interactive shopping lists. Powered by a Supabase backend, the app syncs instantly across all family members' devices.

## ✨ Key Features

### 📋 Task Management
* **Multiple Task Types:** Create standard free-text tasks or interactive Shopping Lists.
* **Visibility Controls:** Mark tasks as **Family** (visible to everyone) or **Private** (visible only to the assigned member).
* **Assignees:** Quickly assign tasks to specific family members.
* **Hard Deletion:** Permanently remove tasks from the database with a built-in safety confirmation dialog to prevent accidental clicks.

### 🛒 Smart Shopping Lists
* **Smart Multiline Pasting:** Paste a block of text (e.g., a recipe or a WhatsApp message) directly into the input field. The app intelligently splits the text by line breaks, removes duplicates, and generates individual checklist items automatically.
* **Dynamic Checkboxes:** Check off items one by one. The entire task is only marked as "Completed" once all sub-items are checked.

### 🏦 Task Bank (Templates)
* Save recurring or common tasks (like weekly cleaning or standard grocery lists) to the "Task Bank."
* Quickly pull tasks from the bank and assign them to members without typing them out from scratch.

### 📊 Weekly Dashboard & Gamification
* **Personal Progress:** A dynamic progress bar tracks the current user's completed private tasks for the week.
* **Family Leaderboard:** Tracks completed shared tasks. The dashboard automatically resets every Saturday at 23:59 and awards a 🏆 icon to the most productive family member of the week.

### 🛠 Robust UI/UX
* **Keyboard-Safe Dialogs:** Bottom sheets are locked to 90% of the screen height, preventing annoying UI jumps when the mobile keyboard opens and closes.
* **Scrollable Forms:** `SingleChildScrollView` implementation prevents "Bottom Overflowed" pixel errors when adding long lists of items.
* **Memory Management:** Controllers are properly disposed of when dialogs close to prevent memory leaks.

### ℹ️ Version & Build Tracking
* Built-in **About Dialog** (accessible via the AppBar info icon) that reads the app version from `pubspec.yaml` and displays the exact **Build Time** (date and hour) the APK was generated.

---

## 💻 Tech Stack
* **Frontend:** Flutter (Dart)
* **Backend:** Supabase (PostgreSQL, Realtime Subscriptions)
* **Packages:** `supabase_flutter`, `shared_preferences`, `package_info_plus`, `flutter_localizations`

---

## 🚀 Getting Started

### Prerequisites
1. Install [Flutter](https://flutter.dev/docs/get-started/install).
2. Ensure you have an Android emulator running or a physical device connected.
3. Run `flutter pub get` to install all required dependencies.

---

## 🏗️ Building and Releasing the App

To ensure that the **Build Time** is accurately injected into the app's "About" dialog, you should use the custom build script rather than the standard Flutter build commands.

### For Android (APK) via Windows PowerShell
We use a custom PowerShell script that grabs the current system time, injects it into the Dart code using `--dart-define`, and compiles the APK.

1. In the root directory of the project, ensure you have the `build_my_app.ps1` file. If not, create it with the following content:
    ```powershell
    $time = Get-Date -Format "dd/MM/yyyy HH:mm"
    flutter build apk --dart-define=BUILD_TIME="$time"
    Write-Host "Done! Your APK is ready in build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    ```
2. Open the Terminal in your IDE (Cursor/VS Code) and run:
    ```powershell
    .\build_my_app.ps1
    ```
3. *Note: If Windows blocks the script from running due to execution policies, run this command once to bypass it: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`*
4. Grab your compiled APK from `build\app\outputs\flutter-apk\app-release.apk` and share it!

### How to Manually Bump the App Version
If you added a major feature and want to change the version number (e.g., from `1.0.0` to `1.0.1`):
1. Open `pubspec.yaml`.
2. Locate the `version:` line.
3. Update it (e.g., `version: 1.0.1+2`). 
4. Run the `build_my_app.ps1` script. The new version and the new timestamp will automatically appear in the app!

---

## 🍏 iOS Deployment (The PWA Workaround)

Because native iOS compilation (`.ipa`) requires a Mac and a paid $99/year Apple Developer account, the best way to distribute this app to iOS users (like family members with iPhones) for free is via **Flutter Web (Progressive Web App)**.

**Steps to deploy for iOS:**
1. Compile the app for the web:
   ```bash
   flutter build web
   ```
2. Host the generated `build/web` folder on a free hosting service like **Vercel**, **Firebase Hosting**, or **GitHub Pages**.
3. Send the URL to the iPhone user.
4. The user opens the link in Safari, taps the **Share** button, and selects **Add to Home Screen**. 
5. The app will now act like a native iOS application, opening in full screen and updating automatically whenever you push new web builds!