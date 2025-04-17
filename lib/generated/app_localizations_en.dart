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
  String confirmDeleteRelative(String relativeName, String relativeRelationship) {
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

  @override
  String get chatbotTitle => 'Chatbot';

  @override
  String get predictTitle => 'Predict';

  @override
  String get connectDevice => 'Connect Device';

  @override
  String get predictPlaceholder => 'Prediction functionality is under development!';

  @override
  String get sendMessage => 'Send';

  @override
  String get enterMessage => 'Enter your message or question';

  @override
  String get imageUrlLabel => 'Enter image URL (optional)';

  @override
  String get errorSendingMessage => 'Error sending message';

  @override
  String get healthDisclaimer => 'This is general information, not medical advice. Consult a doctor for professional guidance.';

  @override
  String get relativesScreenTitle => 'Relatives';

  @override
  String get addRelativeTooltip => 'Add Relative';

  @override
  String get addRelativeDialogTitle => 'Add New Relative';

  @override
  String get relativeNameLabel => 'Name';

  @override
  String get relativeNameHint => 'Enter relative\'s full name';

  @override
  String get relativeNameValidation => 'Please enter a name';

  @override
  String get relationshipLabel => 'Relationship';

  @override
  String get relationshipHint => 'Select Relationship';

  @override
  String get relationshipValidation => 'Please select a relationship';

  @override
  String get addRelativeButton => 'Add Relative';

  @override
  String get deleteButton => 'Delete';

  @override
  String get deleteRelativeConfirmationTitle => 'Confirm Deletion';

  @override
  String relativeDeletedSnackbar(String relativeName) {
    return 'Relative \'$relativeName\' deleted.';
  }

  @override
  String get pleaseLoginRelatives => 'Please login to manage relatives.';

  @override
  String get noRelativesYet => 'No relatives added yet.';

  @override
  String get addFirstRelativeHint => 'Tap the + button above to add your first relative.';

  @override
  String get addRelativeEmptyButton => 'Add Relative';

  @override
  String deleteRelativeTooltip(String relativeName) {
    return 'Delete $relativeName';
  }

  @override
  String get editRelativeDialogTitle => 'Edit Relative';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get relativeUpdatedSuccess => 'Relative updated successfully!';

  @override
  String get relativeUpdatedError => 'Failed to update relative.';

  @override
  String editRelativeTooltip(String relativeName) {
    return 'Edit $relativeName';
  }

  @override
  String get relationFather => 'Father';

  @override
  String get relationMother => 'Mother';

  @override
  String get relationSon => 'Son';

  @override
  String get relationDaughter => 'Daughter';

  @override
  String get relationBrother => 'Brother';

  @override
  String get relationSister => 'Sister';

  @override
  String get relationGrandfather => 'Grandfather';

  @override
  String get relationGrandmother => 'Grandmother';

  @override
  String get relationFriend => 'Friend';

  @override
  String get relationSpouse => 'Spouse';

  @override
  String get relationPartner => 'Partner';

  @override
  String get relationGuardian => 'Guardian';

  @override
  String get relationDoctor => 'Doctor';

  @override
  String get relationCaregiver => 'Caregiver';

  @override
  String get relationOther => 'Other';

  @override
  String get sectionDeviceManagement => 'Device Management';

  @override
  String get sectionNetwork => 'Network';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get noDeviceConnected => 'No Device Connected';

  @override
  String get connectPrompt => 'Connect via \"Change Device\"';

  @override
  String get disconnectButton => 'Disconnect';

  @override
  String get changeForgetDevice => 'Change / Forget Device';

  @override
  String get connectDeviceFirstSnackbar => 'Connect to device first.';

  @override
  String get noEmail => 'No Email';
}
