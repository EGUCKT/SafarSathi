import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDHdL7GCuJ_GRCWJqsWvbGgd8EJBVbCwJI',
    appId: '1:1006768866634:web:55927f585cee14d1a66db3',
    messagingSenderId: '1006768866634',
    projectId: 'eguckt',
    authDomain: 'eguckt.firebaseapp.com',
    storageBucket: 'eguckt.firebasestorage.app',
    measurementId: 'G-1KNY3D1BWJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHdL7GCuJ_GRCWJqsWvbGgd8EJBVbCwJI',
    appId: '1:1006768866634:android:18b725cd97bf9f34a66db3', // READ NOTE BELOW
    messagingSenderId: '1006768866634',
    projectId: 'eguckt',
    storageBucket: 'eguckt.firebasestorage.app',
  );
}