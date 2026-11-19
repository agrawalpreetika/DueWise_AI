# 🌟 DueWise – Smart Subscription & Bill Tracker

> Never miss a payment again! **DueWise** is a cross-platform subscription and bill management application that helps users track recurring subscriptions, manage upcoming bills, monitor free trials, and keep track of monthly expenses — all with seamless cloud synchronization.

---

## ✨ Key Features

- **🔄 Real-Time Multi-Device Sync:** Synchronizes user data across mobile devices and web clients using Firebase Firestore.
- **🔔 Smart Payment Reminders:** Sends local notifications 3 days before, 1 day before, and on the due date (at 9:00 AM and 6:00 PM).
- **🎁 Free Trial Tracking:** Highlights active free trials with dedicated visual indicators to help users avoid unexpected charges.
- **📊 Analytics & Payment History:** Provides monthly expense breakdowns, financial insights, and a detailed payment audit history.
- **🌙 Dark & Light Theme:** Offers an adaptive user interface with smooth theme switching, built using Flutter and Riverpod.

---

## 📱 App Screenshots

<p align="center">
  <img src="screenshots/dashboard.jpeg" width="28%" alt="Dashboard" />
  <img src="screenshots/analytics_light.jpeg" width="28%" alt="Analytics - Light Theme" />
  <img src="screenshots/analytics_dark.jpeg" width="28%" alt="Analytics - Dark Theme" />
  <img src="screenshots/calender.jpeg" width="28%" alt="Calendar" />
  <img src="screenshots/history.jpeg" width="28%" alt="Payment History" />
  <img src="screenshots/profile.jpeg" width="28%" alt="Payment History" />
  
  
</p>

---

## 🛠️ Tech Stack

| Category | Technologies |
|---|---|
| Frontend | Flutter (Android, iOS & Web) |
| State Management | Flutter Riverpod |
| Backend & Authentication | Firebase Authentication |
| Cloud Database | Cloud Firestore |
| Local Storage | Hive |
| Notifications | `flutter_local_notifications`, `timezone` |

---

## 🚀 Getting Started

Follow these steps to set up and run **DueWise** on your local machine.

### Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Git](https://git-scm.com/downloads)
- An IDE such as [VS Code](https://code.visualstudio.com/) or Android Studio

### 1. Clone the Repository

Open your terminal and run:

```bash
git clone https://github.com/agrawalpreetika/DueWise.git
```

### 2. Navigate to the Project Directory

Move into the Flutter application folder:

```bash
cd DueWise/flutter_application_1
```

### 3. Install Dependencies

Fetch all the required Flutter packages:

```bash
flutter pub get
```

### 4. Configure Firebase

Configure your Firebase project before running the application.

- Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
- Register your application and configure the required platform-specific Firebase settings.
- Enable Firebase Authentication and Cloud Firestore.
- Ensure the Firebase configuration files are placed in the appropriate project directories.

* **Note:** Since `lib/firebase_options.dart` is git-ignored for security, you must run `flutterfire configure` in your terminal inside the `flutter_application_1` folder to generate your own Firebase configuration file before running the app.

### 5. Run the Application

Start the application using:

```bash
flutter run
```

To run the application on a specific device, first check the available devices:

```bash
flutter devices
```

Then specify the target device:

```bash
flutter run -d <device_id>
```

---

## 💡 Built With Love & Code

Made with 💖 by **Preetika**.
