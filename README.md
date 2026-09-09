# 🥗 NutriFit

NutriFit is a professional Flutter-based Nutrition and Fitness Web Application designed to help users manage their nutrition, workouts, fitness goals, and overall progress.

The application provides a clean and responsive interface with secure user authentication, nutrition management, workout tracking, personalized goals, progress tracking, and AI-powered assistance.

---

## 🔗 Live Demo

👉 [Check out the Live Demo Here!](https://nutrifit3005.web.app/)

---

## 🌟 Features

- **User Authentication** – Secure registration, login, and forgot password functionality using Firebase Authentication.
- **Nutrition Management** – Manage and track daily meals and nutrition activities.
- **Workout Tracking** – Track workouts and fitness activities.
- **Progress Tracking** – Monitor fitness and nutrition progress over time.
- **Personalized Goals** – Set and manage personal health and fitness goals.
- **AI-Powered Assistance** – Get AI-based guidance related to nutrition and fitness.
- **Firebase Integration** – Uses Firebase for authentication, database, storage, and hosting.
- **Modern UI/UX** – Clean, responsive, and user-friendly interface.
- **Cross-Platform** – Built with Flutter for multiple platforms.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Application framework |
| Dart | Programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | Database |
| Firebase Storage | File and image storage |
| Firebase Hosting | Web deployment |
| AI Integration | AI-powered assistance |

---

## 📋 Prerequisites

Before running NutriFit, make sure the following are installed:

- Flutter SDK
- Dart SDK
- Git
- Android Studio or Visual Studio Code
- Google Chrome
- Node.js and npm
- Firebase account

Check Flutter installation:

    flutter --version

Check Flutter environment:

    flutter doctor

---

## 📂 Project Structure

```text
nutrifit/
│
├── android/                    # Android-specific files
├── ios/                        # iOS-specific files
├── web/                        # Web application files
├── windows/                    # Windows-specific files
├── macos/                      # macOS-specific files
├── linux/                      # Linux-specific files
│
├── assets/                     # Images, icons, fonts, and other assets
│
├── lib/                        # Main Flutter source code
│   │
│   ├── main.dart               # Application entry point
│   │
│   ├── screens/                # Application screens
│   │
│   ├── widgets/                # Reusable UI components
│   │
│   ├── models/                 # Application data models
│   │
│   ├── services/               # Firebase and other services
│   │
│   ├── providers/              # State management
│   │
│   ├── utils/                  # Helper functions and utilities
│   │
│   └── theme/                  # Application theme and styling
│
├── firebase.json               # Firebase configuration
├── .firebaserc                 # Firebase project configuration
├── pubspec.yaml                # Flutter dependencies
├── pubspec.lock                # Locked dependency versions
├── analysis_options.yaml       # Dart analysis configuration
├── .gitignore                  # Git ignored files
└── README.md                   # Project documentation
```


---

## 🚀 Installation & Setup

### 1. Clone the Repository

Clone the NutriFit repository:

    git clone https://github.com/sangeetha302005/nutrifit.git

Go to the project folder:

    cd nutrifit

### 2. Install Dependencies

Install the required Flutter packages:

    flutter pub get

### 3. Configure Firebase

NutriFit uses Firebase for authentication, database, storage, and hosting.

Install Firebase CLI:

    npm install -g firebase-tools

Login to Firebase:

    firebase login

Check available Firebase projects:

    firebase projects:list

If FlutterFire configuration is required:

    dart pub global activate flutterfire_cli

Then run:

    flutterfire configure

Select the Firebase project used by NutriFit.

### 4. Configure Firebase Authentication

In the Firebase Console:

1. Open the NutriFit Firebase project.
2. Go to **Authentication**.
3. Open **Sign-in method**.
4. Enable the required authentication method.
5. Enable **Email/Password** if email authentication is used.

### 5. Configure Cloud Firestore

In the Firebase Console:

1. Open **Firestore Database**.
2. Create or select the database.
3. Configure the required collections.
4. Set appropriate Firestore security rules.

### 6. Configure Firebase Storage

If the application uses file or image uploads:

1. Open **Storage** in Firebase Console.
2. Enable Firebase Storage.
3. Configure the required Storage rules.

### 7. Run the Application

To run NutriFit:

    flutter run

To run the web version:

    flutter run -d chrome

### 8. Build the Web Application

Create a production web build:

    flutter build web --release

The generated files will be available in:

    build/web/

### 9. Deploy to Firebase Hosting

If Firebase Hosting is already configured:

    firebase deploy

If Hosting needs to be configured:

    firebase init hosting

Use:

    build/web

as the hosting directory.

Then build and deploy:

    flutter build web --release

    firebase deploy

---

## 💡 How to Use

1. Open the NutriFit application.
2. Create a new account.
3. Log in using your credentials.
4. Set your fitness and nutrition goals.
5. Add and manage your meals.
6. Track your workouts and fitness activities.
7. Monitor your nutrition and fitness progress.
8. Update your goals and activities regularly.
9. Use the AI-powered assistance for nutrition and fitness guidance.
10. Use the Live Demo link to access the deployed application.

---

## 📝 License

This project is developed for **educational and project demonstration purposes**.