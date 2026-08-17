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

## SOS incident database

The SOS button now writes an owner-private document to `sosIncidents`, keeps
its latest GPS point updated while the alert is active, and marks it resolved
when the user selects **I'm Safe Now**. If the app's offline simulation is
enabled, the alert is stored on-device and is synchronized once the simulation
is disabled. Deploy the updated rules before testing:

```powershell
firebase deploy --only firestore:rules
```

The database deliberately contains no medical profile or emergency contact
numbers. Those details remain on the device and are used only to compose the
system SMS fallback.
