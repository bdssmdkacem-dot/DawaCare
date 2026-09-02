// File generated from the Firebase Android app configuration.
// Android is the currently configured DawaCare Firebase platform.
// The values below are Firebase app identifiers/configuration and are not
// service-account secrets.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }

    throw UnsupportedError(
      'DawaCare Firebase is currently configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsMr1M14BEkkJMV6aipa6TLSLpHuPdTiA',
    appId: '1:875948507490:android:af7f62fba44d2e40f2ec3b',
    messagingSenderId: '875948507490',
    projectId: 'dawacare-bc4ac',
    storageBucket: 'dawacare-bc4ac.firebasestorage.app',
  );
}
