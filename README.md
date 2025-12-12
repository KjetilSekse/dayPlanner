# Day Planner - Flutter App

A meal planning and drink tracking mobile application built with Flutter.

## Features

- Weekly meal planning with customizable menus
- Recipe cookbook organized by meal categories (Breakfast, Lunch, Dinner)
- Drink tracking with calorie and macro information
- Daily drink counter with expandable view
- Ingredient checklist
- Meal notifications with custom times

## Prerequisites

- **Flutter SDK** (stable channel)
- **Android Studio** (for Android development)
- **Physical Android device** or Android emulator

## Installation Instructions

### 1. Install Flutter SDK

#### Windows:
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract the zip file to `C:\src\flutter` (avoid Program Files)
3. Add Flutter to PATH:
   - Search for "Environment Variables" in Windows
   - Edit "Path" under User variables
   - Add new entry: `C:\src\flutter\bin`
   - Click OK and restart your terminal

#### Linux:
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/linux
2. Extract to desired location (e.g., `~/development/flutter`)
3. Add to PATH in `~/.bashrc` or `~/.zshrc`:
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
4. Reload shell: `source ~/.bashrc`

### 2. Verify Flutter Installation

Open a new terminal and run:
```bash
flutter doctor
```

This checks your environment and shows what needs to be installed.

### 3. Install Android Studio

1. Download from: https://developer.android.com/studio
2. Install Android Studio
3. Complete the setup wizard (it will download Android SDK)

### 4. Install Required Android SDK Tools

1. Open Android Studio
2. Click **More Actions** → **SDK Manager**
3. Go to **SDK Tools** tab
4. Check **Android SDK Command-line Tools (latest)**
5. Click **Apply** → **OK**

### 5. Accept Android Licenses

Run in terminal:
```bash
flutter doctor --android-licenses
```

Type `y` for each license prompt.

### 6. Set Up Your Device

#### Physical Android Device (Recommended):
1. Go to **Settings → About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings → Developer Options**
4. Enable **USB Debugging**
5. Connect phone to computer via USB
6. Approve "Allow USB debugging" popup on phone

#### Android Emulator (Alternative):
1. In Android Studio, go to **More Actions** → **Virtual Device Manager**
2. Click **Create Device**
3. Select a phone model (e.g., Pixel 6)
4. Download a system image
5. Click Finish and start the emulator

### 7. Install Project Dependencies

Navigate to the project directory and run:
```bash
flutter pub get
```

### 8. Run the App

```bash
flutter run
```

If you have multiple devices connected, select your device from the list.

**First build takes 2-5 minutes.** Subsequent builds are much faster.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Meal, Recipe, Menu)
├── screens/                  # UI screens
│   └── home_screen.dart      # Main screen with day planner
├── services/                 # Storage and notification services
└── widgets/                  # Reusable UI components

assets/
├── drinks/                   # Drink recipes (JSON)
├── recipes/                  # Food recipes (JSON)
└── menus/                    # Weekly menu configurations (JSON)
```

## Adding New Recipes

### Food Recipes
Add JSON files to `assets/recipes/` or category-specific folders:
- `assets/breakfast/`
- `assets/lunch/`
- `assets/recipes/` (dinner)

### Drink Recipes
Add JSON files to `assets/drinks/`

**Recipe Format:**
```json
{
  "name": "Recipe Name",
  "ingredients": [
    "Ingredient 1",
    "Ingredient 2"
  ],
  "instructions": [
    "Step 1",
    "Step 2"
  ],
  "macros": {
    "per_100g": {
      "cals": "100",
      "carbs": "10",
      "fat": "5",
      "protein": "8"
    },
    "total": {
      "cals": "200",
      "carbs": "20",
      "fat": "10",
      "protein": "16"
    }
  }
}
```

## Troubleshooting

### "Java home supplied is invalid" error
The `android/gradle.properties` file should NOT contain a hardcoded Java path. It should look like:
```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
```

### Device not detected
- Make sure USB debugging is enabled
- Try unplugging and replugging the USB cable
- Select "File Transfer" mode on your phone
- Run `flutter devices` to check

### Build fails
- Run `flutter clean` then `flutter pub get`
- Make sure Android SDK Command-line Tools are installed
- Check that licenses are accepted: `flutter doctor --android-licenses`

## Platform Support

- ✅ Android (tested)
- ✅ iOS (requires macOS with Xcode)
- ⚠️ Web (partially supported)
- ⚠️ Windows desktop (requires Visual Studio)

## Development

To enable hot reload during development:
```bash
flutter run
```

Press `r` in terminal to hot reload changes.
Press `R` for hot restart.
Press `q` to quit.

## Contributing

1. Clone the repository
2. Create a feature branch
3. Make your changes
4. Test on a physical device
5. Submit a pull request

## License

[Add your license here]
