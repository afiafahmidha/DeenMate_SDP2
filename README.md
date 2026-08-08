# deenmate_sdp2

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Emergency SOS production setup

The SOS group tracker uses Firebase Authentication and Cloud Firestore. Before
testing with more than one phone, deploy the included Firestore rules to the
Firebase project configured in `firebase_options.dart`:

```powershell
firebase login
firebase use deenmate-be588
firebase deploy --only firestore:rules
```

Every member must sign in, grant precise location permission, create or join
the same SOS group code, and keep the app open while testing live tracking.
The phone's normal SMS and dialler apps are used for contacts and emergency
calls; add real contact names and numbers in the Medical tab.
