# Eco Charge - EV Charging Station Locator

Eco Charge is a mobile application built using Flutter that helps electric vehicle (EV) users locate nearby charging stations and book slots for charging. The app integrates Firebase for backend services and Google Maps API for real-time location tracking.

## Features

- **User Authentication**: Register and log in using email/password or Google Sign-In.
- **Map Integration**: Displays nearby EV charging stations using Google Maps API.
- **Slot Booking**: Users can select a charging station and book a time slot.
- **Order Details**: View booked slots and reservation details.
- **Real-time Database**: Store user data and booking information in Firebase.

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase Authentication, Firestore Database
- **Maps & Location**: Google Maps API

## Installation

### Prerequisites
- Flutter SDK installed ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Firebase project setup ([Firebase Console](https://console.firebase.google.com/))
- Google Maps API key

### Steps
1. Clone the repository:
   ```sh
   git clone https://github.com/shyamsundars12/eco-charge
   cd eco-charge
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Configure Firebase:
   - Add `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) to the project.
4. Add Google Maps API Key in `AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY" />
   ```
5. Run the app:
   ```sh
   flutter run
   ```

## Project Structure
```
Eco-Charge/
│-- lib/
│   │-- main.dart  # Entry point of the application
│   │-- screens/  # UI screens (Login, Home, Booking, etc.)
│   │-- services/  # Firebase authentication and database functions
│   │-- widgets/  # Reusable UI components
│-- android/
│-- ios/
│-- pubspec.yaml  # Flutter dependencies
│-- README.md  # Project documentation
```

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
For any queries, contact:
- **Developer**: Shyam Sundar S
- **Developer**: Janani M
- **Email**: ecochargefinder.com

---
**Eco Charge** - Making EV Charging More Accessible 🚀

