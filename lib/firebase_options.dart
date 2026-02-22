import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Run flutterfire configure.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS. '
          'Add iOS config and run flutterfire configure.',
        );

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android in this project.',
        );

      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia is not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfmTC88Ug_-IDToJRyguxu9jEl3riBLKY',
    appId: '1:721342123364:android:8f78ef8c1d36d3d544be71',
    messagingSenderId: '721342123364',
    projectId: 'exam-2aaf1',
    storageBucket: 'exam-2aaf1.firebasestorage.app',
  );
}
