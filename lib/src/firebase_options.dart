import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for Grab&Go (project: grab-go-60f46).
///
/// Web values come from the Firebase console (public by design).
/// Android values come from android/app/google-services.json.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHozw19KIOvKxU5E9AL0JxRwt61TygYQY',
    appId: '1:1040963888833:android:70245aff7e2f0f09aa1640',
    messagingSenderId: '1040963888833',
    projectId: 'grab-go-60f46',
    storageBucket: 'grab-go-60f46.firebasestorage.app',
    databaseURL: 'https://grab-go-60f46-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZdymJOM22ejkSugc2UxyTPcSZ15Fwth8',
    appId: '1:1040963888833:web:7f78886036b4b0e2aa1640',
    messagingSenderId: '1040963888833',
    projectId: 'grab-go-60f46',
    authDomain: 'grab-go-60f46.firebaseapp.com',
    storageBucket: 'grab-go-60f46.firebasestorage.app',
  );
}
