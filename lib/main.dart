import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/services/locale_service.dart';
import 'core/services/user_profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleService.init();
  await UserProfileService.init();

  // Set system UI overlay style for emergency readability
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const SurakshaPathApp());
}
