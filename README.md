# Grab-go

Grab&Go — break-time meal reservation and express pickup app for campus cafeterias.

Flutter + Firebase (Firestore + Auth). Live pickup windows, stall prep lists,
receipt verification with QR claim flow, counter payments only.

## Features
- Customer self-registration; stall and main-admin accounts created by the canteen office
- Pickup windows generated per stall operating hours (7 AM–7 PM default), 10-minute slots, per-stall order limits
- Pay at counter only (GCash/QRPh coming soon)
- Claim flow with expiry; claimed receipts cannot be reused
- Store profile with storefront photo; dish photos
- Role-scoped Firestore rules (see `firestore.rules`)

## Setup
1. Install Flutter (stable channel)
2. `flutter pub get`
3. `flutter run` (Android/Web) — requires `google-services.json` (Android) and `lib/src/firebase_options.dart` for the `grab-go-60f46` project
4. Publish `firestore.rules` from the Firebase Console before real use

## Release
- `flutter build apk --release` (signs with the release keystore — not committed)
- `flutter test` / `flutter analyze` clean
