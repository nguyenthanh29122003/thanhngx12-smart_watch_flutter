import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Smart Wearable App'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @relativesTitle.
  ///
  /// In en, this message translates to:
  /// **'Relatives'**
  String get relativesTitle;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @selectDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Your Device'**
  String get selectDeviceTitle;

  /// No description provided for @configureWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Device WiFi'**
  String get configureWifiTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @addRelative.
  ///
  /// In en, this message translates to:
  /// **'Add Relative'**
  String get addRelative;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletion;

  /// Confirmation message for deleting a relative.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {relativeName} ({relativeRelationship})?'**
  String confirmDeleteRelative(String relativeName, String relativeRelationship);

  /// No description provided for @relativeAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Relative added successfully!'**
  String get relativeAddedSuccess;

  /// No description provided for @relativeAddedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to add relative.'**
  String get relativeAddedError;

  /// No description provided for @relativeDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Relative deleted.'**
  String get relativeDeletedSuccess;

  /// No description provided for @relativeDeletedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete relative.'**
  String get relativeDeletedError;

  /// Title for logout confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get confirmLogoutTitle;

  /// Confirmation message shown when the user wants to log out.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get confirmLogoutMessage;

  /// Label for confirm butto n in dialogs.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @chatbotTitle.
  ///
  /// In en, this message translates to:
  /// **'Chatbot'**
  String get chatbotTitle;

  /// No description provided for @predictTitle.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get predictTitle;

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect Device'**
  String get connectDevice;

  /// No description provided for @predictPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Prediction functionality is under development!'**
  String get predictPlaceholder;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your message or question'**
  String get enterMessage;

  /// No description provided for @imageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter image URL (optional)'**
  String get imageUrlLabel;

  /// No description provided for @errorSendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Error sending message'**
  String get errorSendingMessage;

  /// No description provided for @healthDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is general information, not medical advice. Consult a doctor for professional guidance.'**
  String get healthDisclaimer;

  /// No description provided for @relativesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Relatives'**
  String get relativesScreenTitle;

  /// No description provided for @addRelativeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Relative'**
  String get addRelativeTooltip;

  /// No description provided for @addRelativeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Relative'**
  String get addRelativeDialogTitle;

  /// No description provided for @relativeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get relativeNameLabel;

  /// No description provided for @relativeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter relative\'s full name'**
  String get relativeNameHint;

  /// No description provided for @relativeNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get relativeNameValidation;

  /// No description provided for @relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationshipLabel;

  /// No description provided for @relationshipHint.
  ///
  /// In en, this message translates to:
  /// **'Select Relationship'**
  String get relationshipHint;

  /// No description provided for @relationshipValidation.
  ///
  /// In en, this message translates to:
  /// **'Please select a relationship'**
  String get relationshipValidation;

  /// No description provided for @addRelativeButton.
  ///
  /// In en, this message translates to:
  /// **'Add Relative'**
  String get addRelativeButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @deleteRelativeConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get deleteRelativeConfirmationTitle;

  /// Snackbar message shown after successfully deleting a relative.
  ///
  /// In en, this message translates to:
  /// **'Relative \'{relativeName}\' deleted.'**
  String relativeDeletedSnackbar(String relativeName);

  /// No description provided for @pleaseLoginRelatives.
  ///
  /// In en, this message translates to:
  /// **'Please login to manage relatives.'**
  String get pleaseLoginRelatives;

  /// No description provided for @noRelativesYet.
  ///
  /// In en, this message translates to:
  /// **'No relatives added yet.'**
  String get noRelativesYet;

  /// No description provided for @addFirstRelativeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button above to add your first relative.'**
  String get addFirstRelativeHint;

  /// No description provided for @addRelativeEmptyButton.
  ///
  /// In en, this message translates to:
  /// **'Add Relative'**
  String get addRelativeEmptyButton;

  /// Tooltip for the delete icon next to a relative's name.
  ///
  /// In en, this message translates to:
  /// **'Delete {relativeName}'**
  String deleteRelativeTooltip(String relativeName);

  /// No description provided for @editRelativeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Relative'**
  String get editRelativeDialogTitle;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @relativeUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Relative updated successfully!'**
  String get relativeUpdatedSuccess;

  /// No description provided for @relativeUpdatedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update relative.'**
  String get relativeUpdatedError;

  /// Tooltip for the edit icon next to a relative's name.
  ///
  /// In en, this message translates to:
  /// **'Edit {relativeName}'**
  String editRelativeTooltip(String relativeName);

  /// No description provided for @relationFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get relationFather;

  /// No description provided for @relationMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get relationMother;

  /// No description provided for @relationSon.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get relationSon;

  /// No description provided for @relationDaughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get relationDaughter;

  /// No description provided for @relationBrother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get relationBrother;

  /// No description provided for @relationSister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get relationSister;

  /// No description provided for @relationGrandfather.
  ///
  /// In en, this message translates to:
  /// **'Grandfather'**
  String get relationGrandfather;

  /// No description provided for @relationGrandmother.
  ///
  /// In en, this message translates to:
  /// **'Grandmother'**
  String get relationGrandmother;

  /// No description provided for @relationFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get relationFriend;

  /// No description provided for @relationSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get relationSpouse;

  /// No description provided for @relationPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get relationPartner;

  /// No description provided for @relationGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get relationGuardian;

  /// No description provided for @relationDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get relationDoctor;

  /// No description provided for @relationCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get relationCaregiver;

  /// No description provided for @relationOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get relationOther;

  /// No description provided for @sectionDeviceManagement.
  ///
  /// In en, this message translates to:
  /// **'Device Management'**
  String get sectionDeviceManagement;

  /// No description provided for @sectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get sectionNetwork;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// No description provided for @noDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'No Device Connected'**
  String get noDeviceConnected;

  /// No description provided for @connectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect via \"Change Device\"'**
  String get connectPrompt;

  /// No description provided for @disconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectButton;

  /// No description provided for @changeForgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Change / Forget Device'**
  String get changeForgetDevice;

  /// No description provided for @connectDeviceFirstSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Connect to device first.'**
  String get connectDeviceFirstSnackbar;

  /// No description provided for @noEmail.
  ///
  /// In en, this message translates to:
  /// **'No Email'**
  String get noEmail;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {userName}!'**
  String welcomeUser(String userName);

  /// No description provided for @defaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUser;

  /// No description provided for @bleStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'BLE: Connected'**
  String get bleStatusConnected;

  /// No description provided for @bleStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'BLE: Connecting'**
  String get bleStatusConnecting;

  /// No description provided for @bleStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'BLE: Disconnected'**
  String get bleStatusDisconnected;

  /// No description provided for @bleStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'BLE: Scanning'**
  String get bleStatusScanning;

  /// No description provided for @bleStatusError.
  ///
  /// In en, this message translates to:
  /// **'BLE: Error'**
  String get bleStatusError;

  /// No description provided for @bleStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'BLE: Unknown'**
  String get bleStatusUnknown;

  /// No description provided for @wifiStatusOn.
  ///
  /// In en, this message translates to:
  /// **'WiFi On'**
  String get wifiStatusOn;

  /// No description provided for @wifiStatusOff.
  ///
  /// In en, this message translates to:
  /// **'WiFi Off'**
  String get wifiStatusOff;

  /// No description provided for @testNotificationButton.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get testNotificationButton;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Sent test notification! Check system tray.'**
  String get testNotificationSent;

  /// No description provided for @goalProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Goal Progress'**
  String get goalProgressTitle;

  /// No description provided for @goalLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading goal...'**
  String get goalLoading;

  /// No description provided for @stepsCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating steps...'**
  String get stepsCalculating;

  /// No description provided for @stepsProgress.
  ///
  /// In en, this message translates to:
  /// **'Steps: {steps} / {goal}'**
  String stepsProgress(String steps, String goal);

  /// No description provided for @errorNavigateGoals.
  ///
  /// In en, this message translates to:
  /// **'Could not navigate to Goals screen.'**
  String get errorNavigateGoals;

  /// No description provided for @realtimeMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Realtime Metrics'**
  String get realtimeMetricsTitle;

  /// No description provided for @heartRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRateLabel;

  /// No description provided for @spo2Label.
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get spo2Label;

  /// No description provided for @stepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get stepsLabel;

  /// No description provided for @lastUpdatedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Last updated:'**
  String get lastUpdatedPrefix;

  /// No description provided for @waitingForData.
  ///
  /// In en, this message translates to:
  /// **'Connected. Waiting for first data packet...'**
  String get waitingForData;

  /// No description provided for @connectingStatus.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectingStatus;

  /// No description provided for @connectionErrorStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection error.'**
  String get connectionErrorStatus;

  /// No description provided for @disconnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Device disconnected.'**
  String get disconnectedStatus;

  /// No description provided for @hrHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate History (Last 24h)'**
  String get hrHistoryTitle;

  /// No description provided for @spo2HistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'SpO₂ History (Last 24h)'**
  String get spo2HistoryTitle;

  /// No description provided for @stepsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Hourly Steps (Last 24h)'**
  String get stepsHistoryTitle;

  /// No description provided for @chartErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error:'**
  String get chartErrorPrefix;

  /// No description provided for @chartCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get chartCouldNotLoad;

  /// No description provided for @chartNoDataPeriod.
  ///
  /// In en, this message translates to:
  /// **'No history data available for the selected period.'**
  String get chartNoDataPeriod;

  /// No description provided for @chartNoValidHr.
  ///
  /// In en, this message translates to:
  /// **'No valid heart rate data found in this period.'**
  String get chartNoValidHr;

  /// Message shown when no valid SpO2 readings are found in the history.
  ///
  /// In en, this message translates to:
  /// **'No valid SpO₂ data (>= {minSpo2}%) found in this period.'**
  String chartNoValidSpo2(int minSpo2);

  /// No description provided for @chartNoStepsCalculated.
  ///
  /// In en, this message translates to:
  /// **'No step data calculated for the selected period.'**
  String get chartNoStepsCalculated;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailValidation;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordValidation.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordValidation;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @signInWithGoogleButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get signInWithGoogleButton;

  /// No description provided for @signUpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get signUpPrompt;

  /// No description provided for @forgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordPrompt;

  /// No description provided for @loginFailedError.
  ///
  /// In en, this message translates to:
  /// **'Login Failed: {errorDetails}'**
  String loginFailedError(String errorDetails);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'vi': return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
