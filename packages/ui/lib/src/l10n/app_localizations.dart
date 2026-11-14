import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @couldNotLoadProfiles.
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles.'**
  String get couldNotLoadProfiles;

  /// No description provided for @profilesOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Profiles on this device'**
  String get profilesOnThisDevice;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @signInToOpen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to open'**
  String get signInToOpen;

  /// No description provided for @switchLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchLabel;

  /// No description provided for @deleteValue.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{value}\"?'**
  String deleteValue(Object value);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @loadingProfiles.
  ///
  /// In en, this message translates to:
  /// **'Loading profiles'**
  String get loadingProfiles;

  /// No description provided for @deleteValue2.
  ///
  /// In en, this message translates to:
  /// **'Delete {value}'**
  String deleteValue2(Object value);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @movingATaskWithSubtasksTo.
  ///
  /// In en, this message translates to:
  /// **'Moving a task with subtasks to the trash'**
  String get movingATaskWithSubtasksTo;

  /// No description provided for @keptSubtasksMoveUpOneLevel.
  ///
  /// In en, this message translates to:
  /// **'Kept subtasks move up one level.'**
  String get keptSubtasksMoveUpOneLevel;

  /// No description provided for @thisSettingCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be loaded.'**
  String get thisSettingCouldNotBeLoaded;

  /// No description provided for @askEveryTime.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get askEveryTime;

  /// No description provided for @moveTheSubtasksToTheTrash.
  ///
  /// In en, this message translates to:
  /// **'Move the subtasks to the trash too'**
  String get moveTheSubtasksToTheTrash;

  /// No description provided for @keepTheSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Keep the subtasks'**
  String get keepTheSubtasks;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @theLicensesOfTheSoftwareLifeflow.
  ///
  /// In en, this message translates to:
  /// **'The licenses of the software LifeFlow is built with.'**
  String get theLicensesOfTheSoftwareLifeflow;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @theseSettingsCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'These settings could not be loaded.'**
  String get theseSettingsCouldNotBeLoaded;

  /// No description provided for @weekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStartsOn;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @newMonthlyRepeatsInAMonth.
  ///
  /// In en, this message translates to:
  /// **'New monthly repeats in a month without that day'**
  String get newMonthlyRepeatsInAMonth;

  /// No description provided for @forExampleThe31stInApril.
  ///
  /// In en, this message translates to:
  /// **'For example the 31st in April. Existing repeats keep their choice.'**
  String get forExampleThe31stInApril;

  /// No description provided for @skipThatMonth.
  ///
  /// In en, this message translates to:
  /// **'Skip that month'**
  String get skipThatMonth;

  /// No description provided for @useTheLastDayOfThe.
  ///
  /// In en, this message translates to:
  /// **'Use the last day of the month'**
  String get useTheLastDayOfThe;

  /// No description provided for @mostItemsInOneView.
  ///
  /// In en, this message translates to:
  /// **'Most items in one view'**
  String get mostItemsInOneView;

  /// No description provided for @settingMaxOccurrences.
  ///
  /// In en, this message translates to:
  /// **'{maxOccurrences}'**
  String settingMaxOccurrences(Object maxOccurrences);

  /// No description provided for @longestRangeInDays.
  ///
  /// In en, this message translates to:
  /// **'Longest range in days'**
  String get longestRangeInDays;

  /// No description provided for @settingMaxWindowDays.
  ///
  /// In en, this message translates to:
  /// **'{maxWindowDays}'**
  String settingMaxWindowDays(Object maxWindowDays);

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @theReminderStatusCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The reminder status could not be read.'**
  String get theReminderStatusCouldNotBe;

  /// No description provided for @thisDeviceDoesNotShowReminders.
  ///
  /// In en, this message translates to:
  /// **'This device does not show reminders.'**
  String get thisDeviceDoesNotShowReminders;

  /// No description provided for @notificationsAreOffForLifeflow.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for LifeFlow'**
  String get notificationsAreOffForLifeflow;

  /// No description provided for @turnLifeflowOnInYourSystem.
  ///
  /// In en, this message translates to:
  /// **'Turn LifeFlow on in your system\'s notification settings to see reminders.'**
  String get turnLifeflowOnInYourSystem;

  /// No description provided for @remindersWillNotShowUntilYou.
  ///
  /// In en, this message translates to:
  /// **'Reminders will not show until you allow them.'**
  String get remindersWillNotShowUntilYou;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @remindersAreOn.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on'**
  String get remindersAreOn;

  /// No description provided for @remindersMayArriveAFewMinutes.
  ///
  /// In en, this message translates to:
  /// **'Reminders may arrive a few minutes late'**
  String get remindersMayArriveAFewMinutes;

  /// No description provided for @allowExactRemindersToGetThem.
  ///
  /// In en, this message translates to:
  /// **'Allow exact reminders to get them at the minute.'**
  String get allowExactRemindersToGetThem;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @fromMinToMax.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String fromMinToMax(Object min, Object max);

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInIsNotConfiguredIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not configured in this build.'**
  String get signInIsNotConfiguredIn;

  /// No description provided for @signOut2.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOut2;

  /// No description provided for @moveYourDataToThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Move your data to this account?'**
  String get moveYourDataToThisAccount;

  /// No description provided for @newSpace.
  ///
  /// In en, this message translates to:
  /// **'New space'**
  String get newSpace;

  /// No description provided for @moveMyData.
  ///
  /// In en, this message translates to:
  /// **'Move my data'**
  String get moveMyData;

  /// No description provided for @continueWithGithub.
  ///
  /// In en, this message translates to:
  /// **'Continue with GitHub'**
  String get continueWithGithub;

  /// No description provided for @orUseEmail.
  ///
  /// In en, this message translates to:
  /// **'or use email'**
  String get orUseEmail;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get signingIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// No description provided for @exportThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Export this profile'**
  String get exportThisProfile;

  /// No description provided for @restoreFromAFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get restoreFromAFile;

  /// No description provided for @undoLastRestore.
  ///
  /// In en, this message translates to:
  /// **'Undo last restore'**
  String get undoLastRestore;

  /// No description provided for @exportThisProfile2.
  ///
  /// In en, this message translates to:
  /// **'Export this profile?'**
  String get exportThisProfile2;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @thisFileDiffersFromThisProfile.
  ///
  /// In en, this message translates to:
  /// **'This file differs from this profile'**
  String get thisFileDiffersFromThisProfile;

  /// No description provided for @restoreOnlyInFile.
  ///
  /// In en, this message translates to:
  /// **'Only in the file: {onlyInFile}'**
  String restoreOnlyInFile(Object onlyInFile);

  /// No description provided for @restoreOnlyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Only on this device: {onlyOnDevice}'**
  String restoreOnlyOnDevice(Object onlyOnDevice);

  /// No description provided for @overwriteEverything.
  ///
  /// In en, this message translates to:
  /// **'Overwrite everything'**
  String get overwriteEverything;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @useTheNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'Use the newer version'**
  String get useTheNewerVersion;

  /// No description provided for @addWhatIsOnlyInThe.
  ///
  /// In en, this message translates to:
  /// **'Add what is only in the file'**
  String get addWhatIsOnlyInThe;

  /// No description provided for @someSubtasksWouldNotFit.
  ///
  /// In en, this message translates to:
  /// **'Some subtasks would not fit'**
  String get someSubtasksWouldNotFit;

  /// No description provided for @keepThisDeviceSParents.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s parents'**
  String get keepThisDeviceSParents;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @aFocusSessionIsRunning.
  ///
  /// In en, this message translates to:
  /// **'A focus session is running'**
  String get aFocusSessionIsRunning;

  /// No description provided for @endItFirstOnlyOneSession.
  ///
  /// In en, this message translates to:
  /// **'End it first: only one session can run at a time.'**
  String get endItFirstOnlyOneSession;

  /// No description provided for @openIt.
  ///
  /// In en, this message translates to:
  /// **'Open it'**
  String get openIt;

  /// No description provided for @endTheSession.
  ///
  /// In en, this message translates to:
  /// **'End the session?'**
  String get endTheSession;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoing;

  /// No description provided for @pomodoro.
  ///
  /// In en, this message translates to:
  /// **'Pomodoro'**
  String get pomodoro;

  /// No description provided for @stopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatch;

  /// No description provided for @countsUpUntilYouEndIt.
  ///
  /// In en, this message translates to:
  /// **'Counts up until you end it.'**
  String get countsUpUntilYouEndIt;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @focus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focus;

  /// No description provided for @timeIsUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up'**
  String get timeIsUp;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @focusedValue.
  ///
  /// In en, this message translates to:
  /// **'Focused {value}'**
  String focusedValue(Object value);

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @cancelTheSession.
  ///
  /// In en, this message translates to:
  /// **'Cancel the session?'**
  String get cancelTheSession;

  /// No description provided for @nothingIsRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing is recorded.'**
  String get nothingIsRecorded;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @cancelIt.
  ///
  /// In en, this message translates to:
  /// **'Cancel it'**
  String get cancelIt;

  /// No description provided for @cancelSession.
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get cancelSession;

  /// No description provided for @yourStopwatchIsStillRunning.
  ///
  /// In en, this message translates to:
  /// **'Your stopwatch is still running'**
  String get yourStopwatchIsStillRunning;

  /// No description provided for @endNow.
  ///
  /// In en, this message translates to:
  /// **'End now'**
  String get endNow;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @yourPomodoroEndedWhileLifeflowWas.
  ///
  /// In en, this message translates to:
  /// **'Your pomodoro ended while LifeFlow was closed'**
  String get yourPomodoroEndedWhileLifeflowWas;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @countUntilNow.
  ///
  /// In en, this message translates to:
  /// **'Count until now'**
  String get countUntilNow;

  /// No description provided for @countUntilItEnded.
  ///
  /// In en, this message translates to:
  /// **'Count until it ended'**
  String get countUntilItEnded;

  /// No description provided for @aFocusSessionCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'A focus session could not be recovered'**
  String get aFocusSessionCouldNotBe;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @endFocus.
  ///
  /// In en, this message translates to:
  /// **'End focus'**
  String get endFocus;

  /// No description provided for @changeAClosedPeriod.
  ///
  /// In en, this message translates to:
  /// **'Change a closed period?'**
  String get changeAClosedPeriod;

  /// No description provided for @changeIt.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get changeIt;

  /// No description provided for @habitPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit and target: {taskTitle}'**
  String habitPageTitle(Object taskTitle);

  /// No description provided for @couldNotLoadThisTask.
  ///
  /// In en, this message translates to:
  /// **'Could not load this task.'**
  String get couldNotLoadThisTask;

  /// No description provided for @thisTaskNoLongerExists.
  ///
  /// In en, this message translates to:
  /// **'This task no longer exists.'**
  String get thisTaskNoLongerExists;

  /// No description provided for @trackAsAHabit.
  ///
  /// In en, this message translates to:
  /// **'Track as a habit'**
  String get trackAsAHabit;

  /// No description provided for @eachPeriodIsSavedAsDone.
  ///
  /// In en, this message translates to:
  /// **'Each period is saved as done or missed (or achieved, with a target).'**
  String get eachPeriodIsSavedAsDone;

  /// No description provided for @habitsUsuallyRepeat.
  ///
  /// In en, this message translates to:
  /// **'Habits usually repeat'**
  String get habitsUsuallyRepeat;

  /// No description provided for @withoutARepeatThisHabitHas.
  ///
  /// In en, this message translates to:
  /// **'Without a repeat, this habit has one period.'**
  String get withoutARepeatThisHabitHas;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @addATargetToMeasureProgress.
  ///
  /// In en, this message translates to:
  /// **'Add a target to measure progress.'**
  String get addATargetToMeasureProgress;

  /// No description provided for @iTickIt.
  ///
  /// In en, this message translates to:
  /// **'I tick it'**
  String get iTickIt;

  /// No description provided for @fromMeasurements.
  ///
  /// In en, this message translates to:
  /// **'From measurements'**
  String get fromMeasurements;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @noRunningPeriod.
  ///
  /// In en, this message translates to:
  /// **'No running period'**
  String get noRunningPeriod;

  /// No description provided for @addAPastValue.
  ///
  /// In en, this message translates to:
  /// **'Add a past value'**
  String get addAPastValue;

  /// No description provided for @noEndedPeriodsYet.
  ///
  /// In en, this message translates to:
  /// **'No ended periods yet.'**
  String get noEndedPeriodsYet;

  /// No description provided for @noMeasurementsYet.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet.'**
  String get noMeasurementsYet;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct…'**
  String get correct;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @theDayItCountsFor.
  ///
  /// In en, this message translates to:
  /// **'The day it counts for'**
  String get theDayItCountsFor;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @removeTarget.
  ///
  /// In en, this message translates to:
  /// **'Remove target'**
  String get removeTarget;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentStreak;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @labelValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String labelValue(Object label, Object value);

  /// No description provided for @measurementActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for the value {value} of {value2}'**
  String measurementActions(Object value, Object value2);

  /// No description provided for @correctTheValue.
  ///
  /// In en, this message translates to:
  /// **'Correct the value'**
  String get correctTheValue;

  /// No description provided for @value2.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value2;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @eachPeriodCountsThe.
  ///
  /// In en, this message translates to:
  /// **'Each period counts the'**
  String get eachPeriodCountsThe;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @couldNotLoadTheGoals.
  ///
  /// In en, this message translates to:
  /// **'Could not load the goals.'**
  String get couldNotLoadTheGoals;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit…'**
  String get edit;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markAsDone;

  /// No description provided for @markAsActive.
  ///
  /// In en, this message translates to:
  /// **'Mark as active'**
  String get markAsActive;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @thisGoalIsInTheTrash.
  ///
  /// In en, this message translates to:
  /// **'This goal is in the trash or no longer exists.'**
  String get thisGoalIsInTheTrash;

  /// No description provided for @archivedUnarchiveItToChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Archived: unarchive it to change it.'**
  String get archivedUnarchiveItToChangeIt;

  /// No description provided for @withMilestonesProgressCountsTheMilestones.
  ///
  /// In en, this message translates to:
  /// **'With milestones, progress counts the milestones you have ticked.'**
  String get withMilestonesProgressCountsTheMilestones;

  /// No description provided for @noMilestonesWithoutThemProgressComes.
  ///
  /// In en, this message translates to:
  /// **'No milestones. Without them, progress comes from the linked tasks and habits.'**
  String get noMilestonesWithoutThemProgressComes;

  /// No description provided for @dueValue.
  ///
  /// In en, this message translates to:
  /// **'Due {value}'**
  String dueValue(Object value);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addMilestone.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get addMilestone;

  /// No description provided for @nothingLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing linked yet.'**
  String get nothingLinkedYet;

  /// No description provided for @linkATaskOrHabit.
  ///
  /// In en, this message translates to:
  /// **'Link a task or habit'**
  String get linkATaskOrHabit;

  /// No description provided for @linkAnEvent.
  ///
  /// In en, this message translates to:
  /// **'Link an event'**
  String get linkAnEvent;

  /// No description provided for @goalsForTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals for {title}'**
  String goalsForTitle(Object title);

  /// No description provided for @noGoalsYetAddOneIn.
  ///
  /// In en, this message translates to:
  /// **'No goals yet. Add one in the Goals tab.'**
  String get noGoalsYetAddOneIn;

  /// No description provided for @twoPartsDot.
  ///
  /// In en, this message translates to:
  /// **'{value} · {value2}'**
  String twoPartsDot(Object value, Object value2);

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @newGoalOrProject.
  ///
  /// In en, this message translates to:
  /// **'New goal or project'**
  String get newGoalOrProject;

  /// No description provided for @loadingGoals.
  ///
  /// In en, this message translates to:
  /// **'Loading goals'**
  String get loadingGoals;

  /// No description provided for @progressValue.
  ///
  /// In en, this message translates to:
  /// **'Progress: {value}'**
  String progressValue(Object value);

  /// No description provided for @actionsForTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions for {title}'**
  String actionsForTitle(Object title);

  /// No description provided for @actionsForTheMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions for the milestone {title}'**
  String actionsForTheMilestoneTitle(Object title);

  /// No description provided for @clearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear {label}'**
  String clearLabel(Object label);

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDate;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @goalTrashedKeepsItems.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" moved to the trash. Its tasks and events are kept.'**
  String goalTrashedKeepsItems(Object title);

  /// No description provided for @eventSavedRemindersFailed.
  ///
  /// In en, this message translates to:
  /// **'Event saved; its reminders were not: {value}'**
  String eventSavedRemindersFailed(Object value);

  /// No description provided for @eventMovedToTheTrash.
  ///
  /// In en, this message translates to:
  /// **'Event moved to the trash.'**
  String get eventMovedToTheTrash;

  /// No description provided for @allDayAllDayEventsNever.
  ///
  /// In en, this message translates to:
  /// **'All day. All-day events never count as overlapping.'**
  String get allDayAllDayEventsNever;

  /// No description provided for @noCalendar.
  ///
  /// In en, this message translates to:
  /// **'No calendar'**
  String get noCalendar;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @locationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get locationOptional;

  /// No description provided for @schedulePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule: {taskTitle}'**
  String schedulePageTitle(Object taskTitle);

  /// No description provided for @removeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get removeSchedule;

  /// No description provided for @calendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get calendars;

  /// No description provided for @couldNotLoadTheCalendars.
  ///
  /// In en, this message translates to:
  /// **'Could not load the calendars.'**
  String get couldNotLoadTheCalendars;

  /// No description provided for @noCalendarsYetEventsCanAlso.
  ///
  /// In en, this message translates to:
  /// **'No calendars yet. Events can also be without a calendar.'**
  String get noCalendarsYetEventsCanAlso;

  /// No description provided for @moveNameToTheTrash.
  ///
  /// In en, this message translates to:
  /// **'Move \"{name}\" to the trash?'**
  String moveNameToTheTrash(Object name);

  /// No description provided for @itsEventsStayWithoutACalendar.
  ///
  /// In en, this message translates to:
  /// **'Its events stay, without a calendar.'**
  String get itsEventsStayWithoutACalendar;

  /// No description provided for @newCalendar.
  ///
  /// In en, this message translates to:
  /// **'New calendar'**
  String get newCalendar;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editName(Object name);

  /// No description provided for @editCalendar.
  ///
  /// In en, this message translates to:
  /// **'Edit calendar'**
  String get editCalendar;

  /// No description provided for @moveNameToTheTrash2.
  ///
  /// In en, this message translates to:
  /// **'Move {name} to the trash'**
  String moveNameToTheTrash2(Object name);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZone;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @withNoDayChosenItRepeats.
  ///
  /// In en, this message translates to:
  /// **'With no day chosen it repeats on the start\'s weekday.'**
  String get withNoDayChosenItRepeats;

  /// No description provided for @lastDate.
  ///
  /// In en, this message translates to:
  /// **'Last date'**
  String get lastDate;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get custom;

  /// No description provided for @atADateAndTime.
  ///
  /// In en, this message translates to:
  /// **'At a date and time…'**
  String get atADateAndTime;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminder;

  /// No description provided for @setADateToBeReminded.
  ///
  /// In en, this message translates to:
  /// **'Set a date to be reminded before it.'**
  String get setADateToBeReminded;

  /// No description provided for @remindBefore.
  ///
  /// In en, this message translates to:
  /// **'Remind before'**
  String get remindBefore;

  /// No description provided for @labelTime.
  ///
  /// In en, this message translates to:
  /// **'{label} time'**
  String labelTime(Object label);

  /// No description provided for @removeLabelTime.
  ///
  /// In en, this message translates to:
  /// **'Remove {label} time'**
  String removeLabelTime(Object label);

  /// No description provided for @removeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String removeLabel(Object label);

  /// No description provided for @number.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get number;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @remindAt.
  ///
  /// In en, this message translates to:
  /// **'Remind at'**
  String get remindAt;

  /// No description provided for @openNavigationMenu.
  ///
  /// In en, this message translates to:
  /// **'Open navigation menu'**
  String get openNavigationMenu;

  /// No description provided for @storageWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Storage warning. {message}'**
  String storageWarningMessage(Object message);

  /// No description provided for @restoreInBothDifferent.
  ///
  /// In en, this message translates to:
  /// **'In both, but different: {differing} (newer in the file: {newerInFile})'**
  String restoreInBothDifferent(Object differing, Object newerInFile);

  /// No description provided for @restoreOverwriteHint.
  ///
  /// In en, this message translates to:
  /// **'This profile becomes exactly the file. Items only on this device move to the trash.'**
  String get restoreOverwriteHint;

  /// No description provided for @restoreMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s data and take from the file what you choose below.'**
  String get restoreMergeHint;

  /// No description provided for @restoreNewerHint.
  ///
  /// In en, this message translates to:
  /// **'For items in both, keep the one changed most recently.'**
  String get restoreNewerHint;

  /// No description provided for @restoreUndoHint.
  ///
  /// In en, this message translates to:
  /// **'The current data is kept, so you can undo this restore afterwards.'**
  String get restoreUndoHint;

  /// No description provided for @focusEndQuestion.
  ///
  /// In en, this message translates to:
  /// **'Focused for {duration}. Saving it records the time you worked; it does not complete the task.'**
  String focusEndQuestion(Object duration);

  /// No description provided for @timeIsUpLower.
  ///
  /// In en, this message translates to:
  /// **'time is up'**
  String get timeIsUpLower;

  /// No description provided for @focusBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Focus: {what}, {time}. Open'**
  String focusBarLabel(Object what, Object time);

  /// No description provided for @focusBarLabelPaused.
  ///
  /// In en, this message translates to:
  /// **'Focus: {what}, {time}, paused. Open'**
  String focusBarLabelPaused(Object what, Object time);

  /// No description provided for @focusBarText.
  ///
  /// In en, this message translates to:
  /// **'{time} · {what}'**
  String focusBarText(Object time, Object what);

  /// No description provided for @focusBarTextPaused.
  ///
  /// In en, this message translates to:
  /// **'{time} · {what} · paused'**
  String focusBarTextPaused(Object time, Object what);

  /// No description provided for @focusOverdueContent.
  ///
  /// In en, this message translates to:
  /// **'{title}: {minutes} minutes. How should it be saved?'**
  String focusOverdueContent(Object title, Object minutes);

  /// No description provided for @focusUnrecoverableContent.
  ///
  /// In en, this message translates to:
  /// **'It is kept as it was stored, and nothing was recorded for it ({reason}). You can start a new session.'**
  String focusUnrecoverableContent(Object reason);

  /// No description provided for @eventRepeatHint.
  ///
  /// In en, this message translates to:
  /// **'Changes here apply to every time this event repeats. To change one time only, use its actions in the calendar.'**
  String get eventRepeatHint;

  /// No description provided for @closedPeriodContent.
  ///
  /// In en, this message translates to:
  /// **'This period has ended and its result is saved. The change will be judged with the target it had, and the change is recorded.'**
  String get closedPeriodContent;

  /// No description provided for @goalUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink {item}'**
  String goalUnlink(Object item);

  /// No description provided for @goalUnlinkItem.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get goalUnlinkItem;

  /// No description provided for @drawerProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}. Open profiles'**
  String drawerProfileLabel(Object name);

  /// No description provided for @drawerProfileLabelWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}, {status}. Open profiles'**
  String drawerProfileLabelWithStatus(Object name, Object status);

  /// No description provided for @ovEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Use the + button to add your first one.'**
  String get ovEmpty;

  /// No description provided for @ovLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tasks'**
  String get ovLoading;

  /// No description provided for @ovLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load tasks.'**
  String get ovLoadError;

  /// No description provided for @ovNotInAList.
  ///
  /// In en, this message translates to:
  /// **'Not in a list'**
  String get ovNotInAList;

  /// No description provided for @ovAddMenu.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ovAddMenu;

  /// No description provided for @ovCloseAddMenu.
  ///
  /// In en, this message translates to:
  /// **'Close the add menu'**
  String get ovCloseAddMenu;

  /// No description provided for @ovAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get ovAddTask;

  /// No description provided for @ovNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get ovNewList;

  /// No description provided for @ovNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get ovNewEvent;

  /// No description provided for @ovNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get ovNewTask;

  /// No description provided for @ovNewSubtask.
  ///
  /// In en, this message translates to:
  /// **'New subtask'**
  String get ovNewSubtask;

  /// No description provided for @ovRenameTask.
  ///
  /// In en, this message translates to:
  /// **'Rename task'**
  String get ovRenameTask;

  /// No description provided for @ovRenameList.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get ovRenameList;

  /// No description provided for @ovRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get ovRename;

  /// No description provided for @ovFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus…'**
  String get ovFocus;

  /// No description provided for @ovSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule…'**
  String get ovSchedule;

  /// No description provided for @ovHabitAndTarget.
  ///
  /// In en, this message translates to:
  /// **'Habit and target…'**
  String get ovHabitAndTarget;

  /// No description provided for @ovGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals…'**
  String get ovGoals;

  /// No description provided for @ovAddSubtask.
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get ovAddSubtask;

  /// No description provided for @ovAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get ovAddEvent;

  /// No description provided for @ovColour.
  ///
  /// In en, this message translates to:
  /// **'Colour…'**
  String get ovColour;

  /// No description provided for @ovMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get ovMoveUp;

  /// No description provided for @ovMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get ovMoveDown;

  /// No description provided for @ovIndent.
  ///
  /// In en, this message translates to:
  /// **'Make it a subtask of the task above'**
  String get ovIndent;

  /// No description provided for @ovOutdent.
  ///
  /// In en, this message translates to:
  /// **'Move it up a level'**
  String get ovOutdent;

  /// No description provided for @ovMoveToList.
  ///
  /// In en, this message translates to:
  /// **'Move to list…'**
  String get ovMoveToList;

  /// No description provided for @ovMoveToListTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to list'**
  String get ovMoveToListTitle;

  /// No description provided for @ovNoList.
  ///
  /// In en, this message translates to:
  /// **'No list'**
  String get ovNoList;

  /// No description provided for @ovColourTitle.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get ovColourTitle;

  /// No description provided for @ovNoColour.
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get ovNoColour;

  /// No description provided for @ovColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get ovColorRed;

  /// No description provided for @ovColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get ovColorOrange;

  /// No description provided for @ovColorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get ovColorAmber;

  /// No description provided for @ovColorOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get ovColorOlive;

  /// No description provided for @ovColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get ovColorGreen;

  /// No description provided for @ovColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get ovColorTeal;

  /// No description provided for @ovColorCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get ovColorCyan;

  /// No description provided for @ovColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get ovColorBlue;

  /// No description provided for @ovColorIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get ovColorIndigo;

  /// No description provided for @ovColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get ovColorPurple;

  /// No description provided for @ovColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get ovColorPink;

  /// No description provided for @ovColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get ovColorBrown;

  /// No description provided for @ovComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete {title}'**
  String ovComplete(Object title);

  /// No description provided for @ovMarkNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done: {title}'**
  String ovMarkNotDone(Object title);

  /// No description provided for @ovDoneFromMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Done from measurements: {title}'**
  String ovDoneFromMeasurements(Object title);

  /// No description provided for @ovExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand {title}'**
  String ovExpand(Object title);

  /// No description provided for @ovCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse {title}'**
  String ovCollapse(Object title);

  /// No description provided for @ovDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag {title} to move it'**
  String ovDragHandle(Object title);

  /// No description provided for @ovListTrashed.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" moved to the trash with its tasks and events.'**
  String ovListTrashed(Object title);

  /// No description provided for @ovColourSwatch.
  ///
  /// In en, this message translates to:
  /// **'{name}'**
  String ovColourSwatch(Object name);

  /// No description provided for @ovEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event: {title}'**
  String ovEventLabel(Object title);

  /// No description provided for @ovItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 item} other{{count} items}}'**
  String ovItemCount(int count);

  /// No description provided for @tlTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get tlTimeline;

  /// No description provided for @tlGoToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get tlGoToToday;

  /// No description provided for @tlAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get tlAllDay;

  /// No description provided for @tlNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet. Tasks and events you plan show up here.'**
  String get tlNothingPlanned;

  /// No description provided for @tlNothingThisDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned.'**
  String get tlNothingThisDay;

  /// No description provided for @tlShowMonth.
  ///
  /// In en, this message translates to:
  /// **'Show the month calendar'**
  String get tlShowMonth;

  /// No description provided for @tlHideMonth.
  ///
  /// In en, this message translates to:
  /// **'Hide the month calendar'**
  String get tlHideMonth;

  /// No description provided for @tlTruncated.
  ///
  /// In en, this message translates to:
  /// **'Not everything is shown'**
  String get tlTruncated;

  /// No description provided for @tlTruncatedHint.
  ///
  /// In en, this message translates to:
  /// **'There are more items than the limit in Settings → Calendar.'**
  String get tlTruncatedHint;

  /// No description provided for @tlLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the timeline'**
  String get tlLoading;

  /// No description provided for @tlOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue ({count})'**
  String tlOverdue(int count);

  /// No description provided for @tlShowOverdue.
  ///
  /// In en, this message translates to:
  /// **'Show the overdue tasks'**
  String get tlShowOverdue;

  /// No description provided for @tlHideOverdue.
  ///
  /// In en, this message translates to:
  /// **'Hide the overdue tasks'**
  String get tlHideOverdue;

  /// No description provided for @tlDayHeader.
  ///
  /// In en, this message translates to:
  /// **'{relative} · {date}'**
  String tlDayHeader(Object relative, Object date);

  /// No description provided for @calDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calDay;

  /// No description provided for @calWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calWeek;

  /// No description provided for @calMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calMonth;

  /// No description provided for @calYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get calYear;

  /// No description provided for @calGoToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get calGoToToday;

  /// No description provided for @calPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calPrevious;

  /// No description provided for @calNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calNext;

  /// No description provided for @calZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get calZoomIn;

  /// No description provided for @calZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get calZoomOut;

  /// No description provided for @calShowNight.
  ///
  /// In en, this message translates to:
  /// **'Show the night hours'**
  String get calShowNight;

  /// No description provided for @calHideNight.
  ///
  /// In en, this message translates to:
  /// **'Hide the night hours'**
  String get calHideNight;

  /// No description provided for @calNightFold.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} hidden. Show'**
  String calNightFold(Object from, Object to);

  /// No description provided for @calOpenTimeline.
  ///
  /// In en, this message translates to:
  /// **'Open the Timeline'**
  String get calOpenTimeline;

  /// No description provided for @calMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get calMore;

  /// No description provided for @calManageCalendars.
  ///
  /// In en, this message translates to:
  /// **'Manage calendars'**
  String get calManageCalendars;

  /// No description provided for @calNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get calNewEvent;

  /// No description provided for @calNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get calNewTask;

  /// No description provided for @calScheduleTask.
  ///
  /// In en, this message translates to:
  /// **'Schedule a task here…'**
  String get calScheduleTask;

  /// No description provided for @calSlotTitle.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String calSlotTitle(Object date, Object time);

  /// No description provided for @calPickTask.
  ///
  /// In en, this message translates to:
  /// **'Schedule which task?'**
  String get calPickTask;

  /// No description provided for @calNoUnscheduled.
  ///
  /// In en, this message translates to:
  /// **'Every open task already has a schedule.'**
  String get calNoUnscheduled;

  /// No description provided for @calNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get calNow;

  /// No description provided for @calLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the calendar'**
  String get calLoading;

  /// No description provided for @calLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the calendar.'**
  String get calLoadError;

  /// No description provided for @calDayItems.
  ///
  /// In en, this message translates to:
  /// **'{date}, {count, plural, =0{nothing planned} =1{1 item} other{{count} items}}'**
  String calDayItems(Object date, int count);

  /// No description provided for @calAllDayMore.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String calAllDayMore(int count);

  /// No description provided for @calNightHours.
  ///
  /// In en, this message translates to:
  /// **'Night hours'**
  String get calNightHours;

  /// No description provided for @calNightHoursHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden in the day and week grids until you show them.'**
  String get calNightHoursHint;

  /// No description provided for @calNightFrom.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String calNightFrom(Object time);

  /// No description provided for @calNightTo.
  ///
  /// In en, this message translates to:
  /// **'To {time}'**
  String calNightTo(Object time);

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get navHabits;

  /// No description provided for @navGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoals;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get navProfiles;

  /// No description provided for @habitsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add habit'**
  String get habitsAdd;

  /// No description provided for @habitsNew.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get habitsNew;

  /// No description provided for @habitsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the habits.'**
  String get habitsLoadError;

  /// No description provided for @habitsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading habits'**
  String get habitsLoading;

  /// No description provided for @habitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No habits yet. Add one with +, or open a task\'s menu and choose \"Habit and target…\".'**
  String get habitsEmpty;

  /// No description provided for @habitsNoRepeat.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get habitsNoRepeat;

  /// No description provided for @habitsAddMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Add a measurement for {title}'**
  String habitsAddMeasurement(Object title);

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Measured tasks you tick yourself'**
  String get resultsTitle;

  /// No description provided for @resultsHint.
  ///
  /// In en, this message translates to:
  /// **'What is kept for each period. Periods that end after a change follow it; what is kept already stays.'**
  String get resultsHint;

  /// No description provided for @resultsTarget.
  ///
  /// In en, this message translates to:
  /// **'Judge by the target'**
  String get resultsTarget;

  /// No description provided for @resultsTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Achieved, not achieved, or no data.'**
  String get resultsTargetHint;

  /// No description provided for @resultsTick.
  ///
  /// In en, this message translates to:
  /// **'Count the tick'**
  String get resultsTick;

  /// No description provided for @resultsTickHint.
  ///
  /// In en, this message translates to:
  /// **'Done when ticked, otherwise missed.'**
  String get resultsTickHint;

  /// No description provided for @resultsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be loaded.'**
  String get resultsCouldNotLoad;

  /// No description provided for @calNewAllDayEvent.
  ///
  /// In en, this message translates to:
  /// **'New all-day event'**
  String get calNewAllDayEvent;

  /// No description provided for @apDragHandles.
  ///
  /// In en, this message translates to:
  /// **'Drag handles'**
  String get apDragHandles;

  /// No description provided for @apDragHandlesHint.
  ///
  /// In en, this message translates to:
  /// **'In the Overview. Without them, press and hold a row to move it.'**
  String get apDragHandlesHint;

  /// No description provided for @apAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get apAuto;

  /// No description provided for @apAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get apAlways;

  /// No description provided for @apNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get apNever;

  /// No description provided for @apFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get apFont;

  /// No description provided for @apFontSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get apFontSystem;

  /// No description provided for @apTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get apTextSize;

  /// No description provided for @apTextSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String apTextSizeValue(int percent);

  /// No description provided for @apTextSizeHint.
  ///
  /// In en, this message translates to:
  /// **'On top of the text size of your device.'**
  String get apTextSizeHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
