# Halal Scanner Backend Implementation Plan

Add a persistent Firebase Firestore backend to the Halal Scanner feature, ensuring all scans, history, and additive customizations are saved to the user's account according to the provided schema.

## User Review Required

> [!IMPORTANT]
> The implementation will link scanned products to the authenticated user's ID (`uid`). If the user is not logged in, history will not persist across sessions.

> [!TIP]
> I will use Firestore's offline persistence features to ensure that scans are queued for upload if the user has a poor internet connection.

## Proposed Changes

### [Halal Scanner Component]

I will introduce a new service and update the existing models and screens to transition from local static state to a Firebase-backed architecture.

#### [NEW] [halal_scanner_service.dart](file:///D:/DeenMate/lib/services/halal_scanner_service.dart)
- Implement `HalalScannerService` class.
- Methods for saving scans (`users/{uid}/halalScans`).
- Methods for fetching scan history.
- Methods for saving additive overrides (`users/{uid}/settings/halalPreferences`).
- Methods for syncing local counts (Halal/Haram/Mushbooh).

#### [MODIFY] [halal_scanner_home.dart](file:///D:/DeenMate/lib/screens/halal_scanner/halal_scanner_home.dart)
- Update `ScannedProduct` model with `toFirestore` and `fromFirestore` methods.
- Refactor `HalalScannerState` to interact with `HalalScannerService`.
- Update `HalalScannerHomeScreen` to fetch history from Firestore on initialization.
- Update `ScannedHistoryScreen` to load data from Firestore.
- Update `AdditiveDetailScreen` to save overrides to Firestore.

#### [MODIFY] [halal_analyzer_service.dart](file:///D:/DeenMate/lib/services/halal_analyzer_service.dart)
- Update `IngredientAnalysisResult` and `ProductAnalysisResult` to support Firestore serialization if necessary for detailed history.

## Verification Plan

### Automated Tests
- I will verify the Firestore structure by checking the Firebase Console after performing scans.
- I will check if the history persists after restarting the app.

### Manual Verification
- Perform a barcode scan and verify it appears in "Scanned History" and Firestore.
- Perform an ingredient scan (OCR) and verify it is saved.
- Edit an additive's status and verify it persists.
- Clear history and verify it is deleted from Firestore.
