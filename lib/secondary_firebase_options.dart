// lib/secondary_firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class SecondaryFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'SecondaryFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDHBb6dL9DoW94Uhuzg0p05dNCAJOg1gQ0',
    appId: '1:140280390014:web:37758017a0238231d0532f',
    messagingSenderId: '140280390014',
    projectId: 'ez8testdb',
    authDomain: 'ez8testdb.firebaseapp.com',
    storageBucket: 'ez8testdb.firebasestorage.app',
    measurementId: 'G-2HPHW4ZXLH',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBxwIIfbshUK6f9qwzE7S_kG_xqpMHdugY',
    appId: '1:517860411324:web:1e01f2b357f2cc5fea0db9',
    messagingSenderId: '517860411324',
    projectId: 'e8delevery',
    authDomain: 'e8delevery.firebaseapp.com',
    storageBucket: 'e8delevery.firebasestorage.app',
    measurementId: 'G-PVCPTL903V',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUlTNhzkTcVQiHXNaiotPR6TooWMqTcIM',
    appId: '1:525508908544:ios:4c456e6728d2b44ed42ae5',
    messagingSenderId: '525508908544',
    projectId: 'quicktime-d85b1',
    storageBucket: 'quicktime-d85b1.firebasestorage.app',
    iosClientId: '525508908544-ihvchlgeclq15jkhc5t18rlkagfdi620.apps.googleusercontent.com',
    iosBundleId: 'com.example.ez8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTofwkqWMO2pq0TIJtEBfS7BLlA7R2OVA',
    appId: '1:525508908544:android:9e101de38697bc5ed42ae5',
    messagingSenderId: '525508908544',
    projectId: 'quicktime-d85b1',
    storageBucket: 'quicktime-d85b1.firebasestorage.app',
  );

}