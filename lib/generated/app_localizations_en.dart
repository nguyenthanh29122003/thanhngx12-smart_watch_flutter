// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Wearable App';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get relativesTitle => 'Relatives';

  @override
  String get goalsTitle => 'Goals';

  @override
  String get loginTitle => 'Login';

  @override
  String get selectDeviceTitle => 'Select Your Device';

  @override
  String get configureWifiTitle => 'Configure Device WiFi';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get systemDefault => 'System Default';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get logout => 'Logout';

  @override
  String get addRelative => 'Add Relative';

  @override
  String get name => 'Name';

  @override
  String get relationship => 'Relationship';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDeletion => 'Confirm Deletion';

  @override
  String confirmDeleteRelative(
      String relativeName, String relativeRelationship) {
    return 'Are you sure you want to delete $relativeName ($relativeRelationship)?';
  }

  @override
  String get relativeAddedSuccess => 'Relative added successfully!';

  @override
  String get relativeAddedError => 'Failed to add relative.';

  @override
  String get relativeDeletedSuccess => 'Relative deleted.';

  @override
  String get relativeDeletedError => 'Failed to delete relative.';

  @override
  String get confirmLogoutTitle => 'Confirm Logout';

  @override
  String get confirmLogoutMessage => 'Are you sure you want to log out?';

  @override
  String get confirm => 'Confirm';
}
