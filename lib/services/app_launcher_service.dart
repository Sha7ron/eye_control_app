import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class AppLauncherService {
  static Future<void> launchPhone() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.DIAL',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  static Future<void> launchMessages() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.APP_MESSAGING',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  static Future<void> launchCamera() async {
    final intent = AndroidIntent(
      action: 'android.media.action.IMAGE_CAPTURE',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  static Future<void> launchSettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.SETTINGS',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }
}