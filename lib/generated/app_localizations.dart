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

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpTitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @displayNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get displayNameValidation;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordValidationEmpty;

  /// No description provided for @confirmPasswordValidationMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get confirmPasswordValidationMatch;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @loginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get loginPrompt;

  /// No description provided for @resetPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordDialogTitle;

  /// No description provided for @enterYourEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email'**
  String get enterYourEmailHint;

  /// No description provided for @sendResetEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get sendResetEmailButton;

  /// No description provided for @resetEmailSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}. Please check your inbox (and spam folder).'**
  String resetEmailSentSuccess(String email);

  /// No description provided for @resetEmailSentError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email: {errorDetails}'**
  String resetEmailSentError(String errorDetails);

  /// No description provided for @wifiConfigInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter the WiFi network details for your ESP32 device.'**
  String get wifiConfigInstruction;

  /// No description provided for @wifiSsidLabel.
  ///
  /// In en, this message translates to:
  /// **'WiFi Network Name (SSID)'**
  String get wifiSsidLabel;

  /// No description provided for @wifiSsidHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., MyHomeWiFi'**
  String get wifiSsidHint;

  /// No description provided for @wifiSsidValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter the WiFi network name'**
  String get wifiSsidValidation;

  /// No description provided for @wifiPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'WiFi Password'**
  String get wifiPasswordLabel;

  /// No description provided for @wifiPasswordValidationLength.
  ///
  /// In en, this message translates to:
  /// **'Password should be at least 8 characters'**
  String get wifiPasswordValidationLength;

  /// No description provided for @wifiOpenNetworkCheckbox.
  ///
  /// In en, this message translates to:
  /// **'This is an open network (no password)'**
  String get wifiOpenNetworkCheckbox;

  /// No description provided for @sendWifiConfigButton.
  ///
  /// In en, this message translates to:
  /// **'Send Configuration'**
  String get sendWifiConfigButton;

  /// No description provided for @deviceNotConnectedToSend.
  ///
  /// In en, this message translates to:
  /// **'Device must be connected to send configuration.'**
  String get deviceNotConnectedToSend;

  /// No description provided for @wifiConfigSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'WiFi configuration sent!'**
  String get wifiConfigSentSuccess;

  /// No description provided for @wifiConfigSentError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send configuration.'**
  String get wifiConfigSentError;

  /// No description provided for @wifiConfigDeviceNotConnectedError.
  ///
  /// In en, this message translates to:
  /// **'Device not connected. Please connect first.'**
  String get wifiConfigDeviceNotConnectedError;

  /// No description provided for @scanDevicesButton.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanDevicesButton;

  /// No description provided for @stopScanButton.
  ///
  /// In en, this message translates to:
  /// **'Stop Scan'**
  String get stopScanButton;

  /// No description provided for @scanningTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanningTooltip;

  /// No description provided for @scanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan for devices'**
  String get scanTooltip;

  /// No description provided for @scanningStatus.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices...'**
  String get scanningStatus;

  /// No description provided for @statusDisconnectedScan.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Tap scan.'**
  String get statusDisconnectedScan;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get statusConnecting;

  /// No description provided for @statusSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up...'**
  String get statusSettingUp;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected!'**
  String get statusConnected;

  /// No description provided for @statusErrorPermissions.
  ///
  /// In en, this message translates to:
  /// **'Error. Check permissions/BT.'**
  String get statusErrorPermissions;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found.'**
  String get noDevicesFound;

  /// No description provided for @ensureDeviceNearby.
  ///
  /// In en, this message translates to:
  /// **'Ensure your device is powered on and nearby.'**
  String get ensureDeviceNearby;

  /// No description provided for @pullToScan.
  ///
  /// In en, this message translates to:
  /// **'Pull down to scan again.'**
  String get pullToScan;

  /// No description provided for @availableDevices.
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get availableDevices;

  /// No description provided for @unknownDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDeviceName;

  /// No description provided for @deviceIdPrefix.
  ///
  /// In en, this message translates to:
  /// **'ID:'**
  String get deviceIdPrefix;

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectButton;

  /// No description provided for @connectingStatusDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectingStatusDevice;

  /// No description provided for @enableBluetoothPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enable Bluetooth to scan for devices.'**
  String get enableBluetoothPrompt;

  /// No description provided for @permissionRequiredPrompt.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth and Location permissions are required to find nearby devices. Please grant permissions in app settings.'**
  String get permissionRequiredPrompt;

  /// No description provided for @permissionDeniedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Required permissions were denied. Please grant permissions in settings.'**
  String get permissionDeniedSnackbar;

  /// No description provided for @connectionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailedTitle;

  /// No description provided for @connectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to {deviceName}. Please ensure it\'s nearby and try again.'**
  String connectionFailedMessage(String deviceName);

  /// No description provided for @connectionFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to the device. Please try again.'**
  String get connectionFailedSnackbar;

  /// No description provided for @connectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please try again.'**
  String get connectionTimeout;

  /// No description provided for @deviceDisconnectedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'Device disconnected unexpectedly.'**
  String get deviceDisconnectedUnexpectedly;

  /// No description provided for @bluetoothRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Required'**
  String get bluetoothRequiredTitle;

  /// No description provided for @bluetoothRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This app requires Bluetooth to be enabled to scan for devices.'**
  String get bluetoothRequiredMessage;

  /// No description provided for @turnOnButton.
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get turnOnButton;

  /// No description provided for @enableBluetoothIOS.
  ///
  /// In en, this message translates to:
  /// **'Please enable Bluetooth in system settings.'**
  String get enableBluetoothIOS;

  /// No description provided for @dailyStepGoalCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Step Goal'**
  String get dailyStepGoalCardTitle;

  /// No description provided for @setNewGoalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set New Goal'**
  String get setNewGoalTooltip;

  /// No description provided for @stepsUnit.
  ///
  /// In en, this message translates to:
  /// **'steps'**
  String get stepsUnit;

  /// No description provided for @goalAchievedMessage.
  ///
  /// In en, this message translates to:
  /// **'Goal Achieved! Great job! 🎉'**
  String get goalAchievedMessage;

  /// No description provided for @goalRemainingMessage.
  ///
  /// In en, this message translates to:
  /// **'{remainingSteps} steps remaining'**
  String goalRemainingMessage(String remainingSteps);

  /// No description provided for @setGoalDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Daily Step Goal'**
  String get setGoalDialogTitle;

  /// No description provided for @newGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'New Goal (e.g., 10000)'**
  String get newGoalLabel;

  /// No description provided for @pleaseEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number'**
  String get pleaseEnterNumber;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @goalGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Goal must be > 0'**
  String get goalGreaterThanZero;

  /// No description provided for @goalTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Goal seems too high!'**
  String get goalTooHigh;

  /// No description provided for @saveGoalButton.
  ///
  /// In en, this message translates to:
  /// **'Save Goal'**
  String get saveGoalButton;

  /// No description provided for @goalSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'New step goal saved!'**
  String get goalSavedSuccess;

  /// No description provided for @goalSavedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save new goal.'**
  String get goalSavedError;

  /// No description provided for @activityTimeGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Time Goal'**
  String get activityTimeGoalTitle;

  /// No description provided for @activityTimeGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress: ... / ... minutes'**
  String get activityTimeGoalProgress;

  /// No description provided for @calculatingStepsStatus.
  ///
  /// In en, this message translates to:
  /// **'Calculating steps...'**
  String get calculatingStepsStatus;

  /// No description provided for @enableHealthAlerts.
  ///
  /// In en, this message translates to:
  /// **'Enable Health Alerts'**
  String get enableHealthAlerts;

  /// No description provided for @receiveAbnormalNotifications.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications for abnormal readings'**
  String get receiveAbnormalNotifications;

  /// No description provided for @loadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingMessage;

  /// No description provided for @notificationChannelHealthAlertsName.
  ///
  /// In en, this message translates to:
  /// **'Health Alerts'**
  String get notificationChannelHealthAlertsName;

  /// No description provided for @notificationChannelHealthAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Notifications for abnormal health readings'**
  String get notificationChannelHealthAlertsDesc;

  /// No description provided for @notificationChannelHrHighName.
  ///
  /// In en, this message translates to:
  /// **'High Heart Rate Alerts'**
  String get notificationChannelHrHighName;

  /// No description provided for @notificationChannelHrHighDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts when heart rate is too high'**
  String get notificationChannelHrHighDesc;

  /// No description provided for @notificationChannelHrLowName.
  ///
  /// In en, this message translates to:
  /// **'Low Heart Rate Alerts'**
  String get notificationChannelHrLowName;

  /// No description provided for @notificationChannelHrLowDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts when heart rate is too low'**
  String get notificationChannelHrLowDesc;

  /// No description provided for @notificationChannelSpo2LowName.
  ///
  /// In en, this message translates to:
  /// **'Low SpO2 Alerts'**
  String get notificationChannelSpo2LowName;

  /// No description provided for @notificationChannelSpo2LowDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts when SpO2 level is too low'**
  String get notificationChannelSpo2LowDesc;

  /// No description provided for @notificationChannelTestName.
  ///
  /// In en, this message translates to:
  /// **'Test Notifications'**
  String get notificationChannelTestName;

  /// No description provided for @notificationChannelTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Channel for testing notifications manually'**
  String get notificationChannelTestDesc;

  /// No description provided for @alertHrHighTitle.
  ///
  /// In en, this message translates to:
  /// **'High Heart Rate Alert!'**
  String get alertHrHighTitle;

  /// No description provided for @alertHrHighBody.
  ///
  /// In en, this message translates to:
  /// **'Current heart rate is {hrValue} bpm, above threshold {threshold} bpm.'**
  String alertHrHighBody(Object hrValue, Object threshold);

  /// No description provided for @channelNameHrHigh.
  ///
  /// In en, this message translates to:
  /// **'High Heart Rate Alerts'**
  String get channelNameHrHigh;

  /// No description provided for @alertHrLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Heart Rate Alert!'**
  String get alertHrLowTitle;

  /// No description provided for @alertHrLowBody.
  ///
  /// In en, this message translates to:
  /// **'Current heart rate is {hrValue} bpm, below threshold {threshold} bpm.'**
  String alertHrLowBody(Object hrValue, Object threshold);

  /// No description provided for @channelNameHrLow.
  ///
  /// In en, this message translates to:
  /// **'Low Heart Rate Alerts'**
  String get channelNameHrLow;

  /// No description provided for @alertSpo2LowTitle.
  ///
  /// In en, this message translates to:
  /// **'Low SpO2 Alert!'**
  String get alertSpo2LowTitle;

  /// No description provided for @alertSpo2LowBody.
  ///
  /// In en, this message translates to:
  /// **'Current SpO2 is {spo2Value}%, below threshold {threshold}%.'**
  String alertSpo2LowBody(Object spo2Value, Object threshold);

  /// No description provided for @channelNameSpo2Low.
  ///
  /// In en, this message translates to:
  /// **'Low SpO2 Alerts'**
  String get channelNameSpo2Low;

  /// Main title on the login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get loginWelcomeTitle;

  /// Subtitle below the main title on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// Text used as a divider between login methods (e.g., Email / Google)
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDividerText;

  /// Text prompting the user to sign up if they don't have an account
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// The text for the link/button that takes the user to the sign-up screen
  ///
  /// In en, this message translates to:
  /// **'Sign Up Now'**
  String get signUpLinkText;

  /// No description provided for @temperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperatureLabel;

  /// No description provided for @pressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get pressureLabel;

  /// No description provided for @tempUnit.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get tempUnit;

  /// No description provided for @pressureUnitHpa.
  ///
  /// In en, this message translates to:
  /// **'hPa'**
  String get pressureUnitHpa;

  /// Title for the section displaying the user's current activity.
  ///
  /// In en, this message translates to:
  /// **'Current Activity'**
  String get currentActivityTitle;

  /// Text shown when the activity recognition is starting up or waiting for the first data.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get activityInitializing;

  /// Text shown when the current activity cannot be determined or is not one of the recognized types.
  ///
  /// In en, this message translates to:
  /// **'Unknown Activity'**
  String get activityUnknown;

  /// Text shown if there's an error in the activity recognition stream.
  ///
  /// In en, this message translates to:
  /// **'Activity Error'**
  String get activityError;

  /// Name for the 'Lying' activity.
  ///
  /// In en, this message translates to:
  /// **'Lying'**
  String get activityLying;

  /// Name for the 'Sitting' activity.
  ///
  /// In en, this message translates to:
  /// **'Sitting'**
  String get activitySitting;

  /// Name for the 'Standing' activity.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get activityStanding;

  /// Name for the 'Walking' activity.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get activityWalking;

  /// Name for the 'Running' activity.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get activityRunning;

  /// Name for the 'Cycling' activity.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get activityCycling;

  /// Name for the 'Ascending Stairs' activity.
  ///
  /// In en, this message translates to:
  /// **'Ascending Stairs'**
  String get activityAscendingStairs;

  /// Name for the 'Descending Stairs' activity.
  ///
  /// In en, this message translates to:
  /// **'Descending Stairs'**
  String get activityDescendingStairs;

  /// Title for the activity data recording screen
  ///
  /// In en, this message translates to:
  /// **'Record Activity Data'**
  String get recordActivityTitle;

  /// Label for the dropdown to select an activity
  ///
  /// In en, this message translates to:
  /// **'Select Activity to Record'**
  String get selectActivityLabel;

  /// Label for the button to start recording data
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecordingButton;

  /// Label for the button to stop recording data
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecordingButton;

  /// Label for the status message area
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get statusLabel;

  /// Label for the count of recorded data samples
  ///
  /// In en, this message translates to:
  /// **'Samples Recorded:'**
  String get samplesRecordedLabel;

  /// Hint text showing where data is/was saved
  ///
  /// In en, this message translates to:
  /// **'Recorded data path (info)'**
  String get viewRecordedDataHint;

  /// Snackbar message after tapping the data path hint
  ///
  /// In en, this message translates to:
  /// **'Path information shown in console.'**
  String get pathCopiedSnackbar;

  /// Text displayed when the app is attempting to reconnect to a Bluetooth device
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get statusReconnecting;

  /// Text displayed in the tooltip of the scan button when reconnecting
  ///
  /// In en, this message translates to:
  /// **'Attempting to reconnect...'**
  String get reconnectingTooltip;
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
