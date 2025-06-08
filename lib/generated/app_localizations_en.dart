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
  String get selectDeviceTitle => 'Select Device';

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
  String confirmDeleteRelative(Object relativeName, Object relativeRelationship) {
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
  String get confirmLogoutMessage => 'Are you sure you want to logout?';

  @override
  String get confirm => 'Confirm';

  @override
  String get chatbotTitle => 'Chat with AI';

  @override
  String get predictTitle => 'Predict';

  @override
  String get connectDevice => 'Connect Device';

  @override
  String get predictPlaceholder => 'Prediction functionality coming soon!';

  @override
  String get sendMessage => 'Send';

  @override
  String get enterMessage => 'Enter your message or question';

  @override
  String get imageUrlLabel => 'Enter image URL (optional)';

  @override
  String get errorSendingMessage => 'Error sending message';

  @override
  String get healthDisclaimer => 'This is general information, not medical advice. Please consult a doctor for professional advice.';

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
  String get relationshipHint => 'Select relationship';

  @override
  String get relationshipValidation => 'Please select a relationship';

  @override
  String get addRelativeButton => 'Add Relative';

  @override
  String get deleteButton => 'Delete';

  @override
  String get deleteRelativeConfirmationTitle => 'Confirm Deletion';

  @override
  String relativeDeletedSnackbar(Object relativeName) {
    return 'Deleted relative \'$relativeName\'.';
  }

  @override
  String get pleaseLoginRelatives => 'Please login to manage relatives.';

  @override
  String get noRelativesYet => 'No relatives yet.';

  @override
  String get addFirstRelativeHint => 'Press the + button above to add your first relative.';

  @override
  String get addRelativeEmptyButton => 'Add Relative';

  @override
  String deleteRelativeTooltip(Object relativeName) {
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
  String editRelativeTooltip(Object relativeName) {
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
  String get noDeviceConnected => 'No Device Connected';

  @override
  String get connectPrompt => 'Connect via \"Change Device\"';

  @override
  String get disconnectButton => 'Disconnect';

  @override
  String get changeForgetDevice => 'Change / Forget Device';

  @override
  String get connectDeviceFirstSnackbar => 'Please connect to a device first.';

  @override
  String get noEmail => 'No Email';

  @override
  String welcomeUser(Object userName) {
    return 'Welcome, $userName!';
  }

  @override
  String get defaultUser => 'User';

  @override
  String get bleStatusConnected => 'BLE: Connected';

  @override
  String get bleStatusConnecting => 'BLE: Connecting';

  @override
  String get bleStatusDisconnected => 'BLE: Disconnected';

  @override
  String get bleStatusScanning => 'BLE: Scanning';

  @override
  String get bleStatusError => 'BLE: Error';

  @override
  String get bleStatusUnknown => 'BLE: Unknown';

  @override
  String get wifiStatusOn => 'WiFi On';

  @override
  String get wifiStatusOff => 'WiFi Off';

  @override
  String get testNotificationButton => 'Test Notification';

  @override
  String get testNotificationSent => 'Test notification sent! Check system.';

  @override
  String get goalProgressTitle => 'Daily Goal Progress';

  @override
  String get goalLoading => 'Loading goal...';

  @override
  String get stepsCalculating => 'Calculating steps...';

  @override
  String stepsProgress(Object steps, Object goal) {
    return 'Steps: $steps / $goal';
  }

  @override
  String get errorNavigateGoals => 'Could not navigate to Goals screen.';

  @override
  String get realtimeMetricsTitle => 'Realtime Metrics';

  @override
  String get heartRateLabel => 'Heart Rate';

  @override
  String get spo2Label => 'SpO2';

  @override
  String get stepsLabel => 'Steps';

  @override
  String get lastUpdatedPrefix => 'Updated:';

  @override
  String get waitingForData => 'Connected. Waiting for data...';

  @override
  String get connectingStatus => 'Connecting...';

  @override
  String get connectionErrorStatus => 'Connection error.';

  @override
  String get disconnectedStatus => 'Device disconnected.';

  @override
  String get hrHistoryTitle => 'Heart Rate History (Last 24h)';

  @override
  String get spo2HistoryTitle => 'SpO₂ History (Last 24h)';

  @override
  String get stepsHistoryTitle => 'Hourly Steps (Last 24h)';

  @override
  String get chartErrorPrefix => 'Error:';

  @override
  String get chartCouldNotLoad => 'Could not load history';

  @override
  String get chartNoDataPeriod => 'No history data for this period.';

  @override
  String get chartNoValidHr => 'No valid heart rate data found in this period.';

  @override
  String chartNoValidSpo2(Object minSpo2) {
    return 'No valid SpO₂ data (>= $minSpo2%) found in this period.';
  }

  @override
  String get chartNoStepsCalculated => 'No step data calculated for this period.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailValidation => 'Please enter a valid email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordValidation => 'Password must be at least 6 characters';

  @override
  String get signInButton => 'Sign In';

  @override
  String get signInWithGoogleButton => 'Sign In with Google';

  @override
  String get signUpPrompt => 'Don\'t have an account? Sign Up';

  @override
  String get forgotPasswordPrompt => 'Forgot password?';

  @override
  String loginFailedError(Object errorDetails) {
    return 'Login Failed: $errorDetails';
  }

  @override
  String get signUpTitle => 'Sign Up';

  @override
  String get displayNameLabel => 'Display Name';

  @override
  String get displayNameValidation => 'Please enter your name';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordValidationEmpty => 'Please confirm your password';

  @override
  String get confirmPasswordValidationMatch => 'Passwords do not match';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get loginPrompt => 'Already have an account? Login';

  @override
  String get resetPasswordDialogTitle => 'Reset Password';

  @override
  String get enterYourEmailHint => 'Enter your account email';

  @override
  String get sendResetEmailButton => 'Send Reset Email';

  @override
  String resetEmailSentSuccess(Object email) {
    return 'Password reset email sent to $email. Please check your inbox (and spam folder).';
  }

  @override
  String resetEmailSentError(Object errorDetails) {
    return 'Failed to send reset email: $errorDetails';
  }

  @override
  String get wifiConfigInstruction => 'Enter the WiFi network information for your ESP32 device.';

  @override
  String get wifiSsidLabel => 'WiFi Network Name (SSID)';

  @override
  String get wifiSsidHint => 'E.g. MyHomeWiFi';

  @override
  String get wifiSsidValidation => 'Please enter the WiFi network name';

  @override
  String get wifiPasswordLabel => 'WiFi Password';

  @override
  String get wifiPasswordValidationLength => 'Password needs at least 8 characters';

  @override
  String get wifiOpenNetworkCheckbox => 'This is an open network (no password)';

  @override
  String get sendWifiConfigButton => 'Send Configuration';

  @override
  String get deviceNotConnectedToSend => 'Device needs to be connected to send configuration.';

  @override
  String get wifiConfigSentSuccess => 'WiFi configuration sent!';

  @override
  String get wifiConfigSentError => 'Failed to send configuration.';

  @override
  String get scanDevicesButton => 'Scan Devices';

  @override
  String get stopScanButton => 'Stop Scan';

  @override
  String get scanningTooltip => 'Scanning...';

  @override
  String get scanTooltip => 'Scan for devices';

  @override
  String get scanningStatus => 'Scanning for devices...';

  @override
  String get statusDisconnectedScan => 'Disconnected. Tap to scan.';

  @override
  String get statusConnecting => 'Connecting...';

  @override
  String get statusSettingUp => 'Setting up device...';

  @override
  String get statusConnected => 'Connected!';

  @override
  String get statusErrorPermissions => 'Error. Check Permissions/Bluetooth.';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get noDevicesFound => 'No devices found.';

  @override
  String get ensureDeviceNearby => 'Ensure your device is turned on and nearby.';

  @override
  String get pullToScan => 'Pull down to scan again.';

  @override
  String get availableDevices => 'Available Devices';

  @override
  String get unknownDeviceName => 'Unknown Device';

  @override
  String get deviceIdPrefix => 'ID:';

  @override
  String get connectButton => 'Connect';

  @override
  String get enableBluetoothPrompt => 'Please enable Bluetooth to scan for devices.';

  @override
  String get permissionRequiredPrompt => 'Location and Bluetooth permissions are required to find nearby devices. Please grant permissions in app settings.';

  @override
  String get permissionDeniedSnackbar => 'Required permissions denied. Please grant in settings.';

  @override
  String get connectionFailedTitle => 'Connection Failed';

  @override
  String connectionFailedMessage(Object deviceName) {
    return 'Could not connect to $deviceName. Please ensure the device is nearby and try again.';
  }

  @override
  String get connectionFailedSnackbar => 'Failed to connect to device. Please try again.';

  @override
  String get connectionTimeout => 'Connection timed out. Please try again.';

  @override
  String get deviceDisconnectedUnexpectedly => 'Device disconnected unexpectedly.';

  @override
  String get bluetoothRequiredTitle => 'Bluetooth Required';

  @override
  String get bluetoothRequiredMessage => 'This app requires Bluetooth to be enabled to scan for devices.';

  @override
  String get turnOnButton => 'Turn On';

  @override
  String get enableBluetoothIOS => 'Please enable Bluetooth in system settings.';

  @override
  String get dailyStepGoalCardTitle => 'Daily Step Goal';

  @override
  String get setNewGoalTooltip => 'Set New Goal';

  @override
  String get stepsUnit => 'steps';

  @override
  String get goalAchievedMessage => 'Goal Achieved! Well done! 🎉';

  @override
  String goalRemainingMessage(Object remainingSteps) {
    return '$remainingSteps steps remaining';
  }

  @override
  String get setGoalDialogTitle => 'Set Daily Step Goal';

  @override
  String get newGoalLabel => 'New Goal (E.g. 10000)';

  @override
  String get pleaseEnterNumber => 'Please enter a number';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get goalGreaterThanZero => 'Goal must be > 0';

  @override
  String get goalTooHigh => 'Goal seems too high!';

  @override
  String get saveGoalButton => 'Save Goal';

  @override
  String get goalSavedSuccess => 'New step goal saved!';

  @override
  String get goalSavedError => 'Failed to save new goal.';

  @override
  String get activityTimeGoalTitle => 'Activity Time Goal';

  @override
  String get activityTimeGoalProgress => 'Progress: ... / ... minutes';

  @override
  String get calculatingStepsStatus => 'Calculating steps...';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get enableHealthAlerts => 'Enable Health Alerts';

  @override
  String get receiveAbnormalNotifications => 'Receive notifications for abnormal readings';

  @override
  String get loadingMessage => 'Loading...';

  @override
  String get notificationChannelHealthAlertsName => 'Health Alerts';

  @override
  String get notificationChannelHealthAlertsDesc => 'Notifications for abnormal health readings';

  @override
  String get notificationChannelHrHighName => 'High Heart Rate Alert';

  @override
  String get notificationChannelHrHighDesc => 'Alerts for excessively high heart rate';

  @override
  String get notificationChannelHrLowName => 'Low Heart Rate Alert';

  @override
  String get notificationChannelHrLowDesc => 'Alerts for excessively low heart rate';

  @override
  String get notificationChannelSpo2LowName => 'Low SpO2 Alert';

  @override
  String get notificationChannelSpo2LowDesc => 'Alerts for excessively low SpO2 levels';

  @override
  String get notificationChannelTestName => 'Test Notifications';

  @override
  String get notificationChannelTestDesc => 'Channel for manual test notifications';

  @override
  String get alertHrHighTitle => 'High Heart Rate Alert!';

  @override
  String alertHrHighBody(Object hrValue, Object threshold) {
    return 'Current heart rate is $hrValue bpm, which is above the threshold of $threshold bpm.';
  }

  @override
  String get channelNameHrHigh => 'High Heart Rate Alerts';

  @override
  String get alertHrLowTitle => 'Low Heart Rate Alert!';

  @override
  String alertHrLowBody(Object hrValue, Object threshold) {
    return 'Current heart rate is $hrValue bpm, which is below the threshold of $threshold bpm.';
  }

  @override
  String get channelNameHrLow => 'Low Heart Rate Alerts';

  @override
  String get alertSpo2LowTitle => 'Low SpO2 Alert!';

  @override
  String alertSpo2LowBody(Object spo2Value, Object threshold) {
    return 'Current SpO2 is $spo2Value%, which is below the threshold of $threshold%.';
  }

  @override
  String get channelNameSpo2Low => 'Low SpO2 Alerts';

  @override
  String get loginWelcomeTitle => 'Welcome Back!';

  @override
  String get loginSubtitle => 'Login to continue';

  @override
  String get orDividerText => 'OR';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get signUpLinkText => 'Sign up now';

  @override
  String get temperatureLabel => 'Temperature';

  @override
  String get pressureLabel => 'Pressure';

  @override
  String get tempUnit => '°C';

  @override
  String get pressureUnitHpa => 'hPa';

  @override
  String get connectingStatusDevice => 'Connecting...';

  @override
  String get currentActivityTitle => 'Current Activity';

  @override
  String get activityInitializing => 'Initializing...';

  @override
  String get activityCycling => 'Cycling';

  @override
  String get activityAscendingStairs => 'Ascending Stairs';

  @override
  String get activityDescendingStairs => 'Descending Stairs';

  @override
  String get recordActivityTitle => 'Record Activity Data';

  @override
  String get selectActivityLabel => 'Select Activity to Record';

  @override
  String get startRecordingButton => 'Start Recording';

  @override
  String get stopRecordingButton => 'Stop Recording';

  @override
  String get statusLabel => 'Status:';

  @override
  String get samplesRecordedLabel => 'Samples Recorded:';

  @override
  String get viewRecordedDataHint => 'Recorded data path (tap to copy)';

  @override
  String pathCopiedSnackbar(String filePath) {
    return 'Path copied (simulated): $filePath';
  }

  @override
  String get statusReconnecting => 'Reconnecting...';

  @override
  String get reconnectingTooltip => 'Attempting to reconnect...';

  @override
  String get reconnectAttemptTitle => 'Reconnecting to Device';

  @override
  String get reconnectAttemptBody => 'Attempting to reconnect to your device...';

  @override
  String get reconnectSuccessTitle => 'Reconnect Successful';

  @override
  String get reconnectSuccessBody => 'Successfully reconnected to your device.';

  @override
  String get reconnectFailedTitle => 'Reconnect Failed';

  @override
  String reconnectFailedBody(Object attempts) {
    return 'Could not reconnect to device after $attempts attempts.';
  }

  @override
  String get bleReconnectChannelName => 'BLE Reconnect';

  @override
  String get activityWarningTitle => 'Activity Alert';

  @override
  String get prolongedSittingWarningTitle => 'Prolonged Sitting Alert';

  @override
  String get prolongedLyingWarningTitle => 'Prolonged Lying Alert (Daytime)';

  @override
  String get smartReminderTitle => 'Smart Movement Reminder';

  @override
  String get positiveFeedbackTitle => 'Great Job!';

  @override
  String get activityAlertsChannelName => 'Activity Alerts';

  @override
  String get activityAlertsChannelDescription => 'Notifications related to activity alerts';

  @override
  String get sittingAlertsChannelName => 'Sitting Time Alerts';

  @override
  String get lyingAlertsChannelName => 'Lying Time Alerts';

  @override
  String get smartReminderChannelName => 'Smart Movement Reminders';

  @override
  String get positiveFeedbackChannelName => 'Positive Feedback';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get errorLoadingData => 'Could not load device data. Please try again.';

  @override
  String get bluetoothRequestTitle => 'Enable Bluetooth';

  @override
  String get bluetoothRequestMessage => 'Please enable Bluetooth to scan for devices.';

  @override
  String get turnOn => 'Turn On';

  @override
  String get recordScreenInitialStatus => 'Select an activity and press Start.';

  @override
  String get recordScreenSelectActivityFirst => 'Please select an activity before starting.';

  @override
  String get recordScreenAlreadyRecording => 'Recording is already in progress.';

  @override
  String get permissionDeniedStorage => 'Storage permission denied. Cannot record data.';

  @override
  String errorGettingPath(String error) {
    return 'Error getting file path: $error';
  }

  @override
  String recordScreenRecordingTo(String filePath) {
    return 'Recording to:\n$filePath';
  }

  @override
  String recordScreenSamplesRecorded(String activityName, String count) {
    return 'Recording $activityName: $count samples (saved).';
  }

  @override
  String recordScreenStreamError(String error) {
    return 'Error on data stream: $error. Recording stopped.';
  }

  @override
  String get recordScreenStreamEnded => 'Data stream ended. Recording stopped.';

  @override
  String recordScreenStartError(String error) {
    return 'Error starting recording: $error';
  }

  @override
  String recordScreenStopMessage(String count, String filePath) {
    return 'Recording stopped. $count samples recorded to:\n$filePath';
  }

  @override
  String get recordScreenSelectActivityValidation => 'Please select an activity.';

  @override
  String get copyFilePathButton => 'Copy File Path';

  @override
  String filePathCopiedSuccess(String filePath) {
    return 'File path copied: $filePath';
  }

  @override
  String get wifiConfigDeviceNotConnectedError => 'Device not connected. Please connect to the wearable first.';

  @override
  String get activityStanding => 'Standing';

  @override
  String get activityLying => 'Lying';

  @override
  String get activitySitting => 'Sitting';

  @override
  String get activityWalking => 'Walking';

  @override
  String get activityRunning => 'Running';

  @override
  String get activityUnknown => 'Unknown Activity';

  @override
  String get activityError => 'Activity Error';
}
