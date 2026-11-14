// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profiles => 'Profiles';

  @override
  String get couldNotLoadProfiles => 'Could not load profiles.';

  @override
  String get profilesOnThisDevice => 'Profiles on this device';

  @override
  String get active => 'Active';

  @override
  String get signInToOpen => 'Sign in to open';

  @override
  String get switchLabel => 'Switch';

  @override
  String deleteValue(Object value) {
    return 'Delete \"$value\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String get loadingProfiles => 'Loading profiles';

  @override
  String deleteValue2(Object value) {
    return 'Delete $value';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get settings => 'Settings';

  @override
  String get tasks => 'Tasks';

  @override
  String get movingATaskWithSubtasksTo =>
      'Moving a task with subtasks to the trash';

  @override
  String get keptSubtasksMoveUpOneLevel => 'Kept subtasks move up one level.';

  @override
  String get thisSettingCouldNotBeLoaded => 'This setting could not be loaded.';

  @override
  String get askEveryTime => 'Ask every time';

  @override
  String get moveTheSubtasksToTheTrash => 'Move the subtasks to the trash too';

  @override
  String get keepTheSubtasks => 'Keep the subtasks';

  @override
  String get about => 'About';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get theLicensesOfTheSoftwareLifeflow =>
      'The licenses of the software LifeFlow is built with.';

  @override
  String get calendar => 'Calendar';

  @override
  String get theseSettingsCouldNotBeLoaded =>
      'These settings could not be loaded.';

  @override
  String get weekStartsOn => 'Week starts on';

  @override
  String get monday => 'Monday';

  @override
  String get sunday => 'Sunday';

  @override
  String get newMonthlyRepeatsInAMonth =>
      'New monthly repeats in a month without that day';

  @override
  String get forExampleThe31stInApril =>
      'For example the 31st in April. Existing repeats keep their choice.';

  @override
  String get skipThatMonth => 'Skip that month';

  @override
  String get useTheLastDayOfThe => 'Use the last day of the month';

  @override
  String get mostItemsInOneView => 'Most items in one view';

  @override
  String settingMaxOccurrences(Object maxOccurrences) {
    return '$maxOccurrences';
  }

  @override
  String get longestRangeInDays => 'Longest range in days';

  @override
  String settingMaxWindowDays(Object maxWindowDays) {
    return '$maxWindowDays';
  }

  @override
  String get reminders => 'Reminders';

  @override
  String get theReminderStatusCouldNotBe =>
      'The reminder status could not be read.';

  @override
  String get thisDeviceDoesNotShowReminders =>
      'This device does not show reminders.';

  @override
  String get notificationsAreOffForLifeflow =>
      'Notifications are off for LifeFlow';

  @override
  String get turnLifeflowOnInYourSystem =>
      'Turn LifeFlow on in your system\'s notification settings to see reminders.';

  @override
  String get remindersWillNotShowUntilYou =>
      'Reminders will not show until you allow them.';

  @override
  String get allow => 'Allow';

  @override
  String get remindersAreOn => 'Reminders are on';

  @override
  String get remindersMayArriveAFewMinutes =>
      'Reminders may arrive a few minutes late';

  @override
  String get allowExactRemindersToGetThem =>
      'Allow exact reminders to get them at the minute.';

  @override
  String get save => 'Save';

  @override
  String fromMinToMax(Object min, Object max) {
    return 'From $min to $max';
  }

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInIsNotConfiguredIn =>
      'Sign-in is not configured in this build.';

  @override
  String get signOut2 => 'Sign out?';

  @override
  String get moveYourDataToThisAccount => 'Move your data to this account?';

  @override
  String get newSpace => 'New space';

  @override
  String get moveMyData => 'Move my data';

  @override
  String get continueWithGithub => 'Continue with GitHub';

  @override
  String get orUseEmail => 'or use email';

  @override
  String get signingIn => 'Signing in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get yourData => 'Your data';

  @override
  String get exportThisProfile => 'Export this profile';

  @override
  String get restoreFromAFile => 'Restore from a file';

  @override
  String get undoLastRestore => 'Undo last restore';

  @override
  String get exportThisProfile2 => 'Export this profile?';

  @override
  String get exportLabel => 'Export';

  @override
  String get thisFileDiffersFromThisProfile =>
      'This file differs from this profile';

  @override
  String restoreOnlyInFile(Object onlyInFile) {
    return 'Only in the file: $onlyInFile';
  }

  @override
  String restoreOnlyOnDevice(Object onlyOnDevice) {
    return 'Only on this device: $onlyOnDevice';
  }

  @override
  String get overwriteEverything => 'Overwrite everything';

  @override
  String get merge => 'Merge';

  @override
  String get useTheNewerVersion => 'Use the newer version';

  @override
  String get addWhatIsOnlyInThe => 'Add what is only in the file';

  @override
  String get someSubtasksWouldNotFit => 'Some subtasks would not fit';

  @override
  String get keepThisDeviceSParents => 'Keep this device\'s parents';

  @override
  String get ok => 'OK';

  @override
  String get aFocusSessionIsRunning => 'A focus session is running';

  @override
  String get endItFirstOnlyOneSession =>
      'End it first: only one session can run at a time.';

  @override
  String get openIt => 'Open it';

  @override
  String get endTheSession => 'End the session?';

  @override
  String get keepGoing => 'Keep going';

  @override
  String get pomodoro => 'Pomodoro';

  @override
  String get stopwatch => 'Stopwatch';

  @override
  String get countsUpUntilYouEndIt => 'Counts up until you end it.';

  @override
  String get start => 'Start';

  @override
  String get focus => 'Focus';

  @override
  String get timeIsUp => 'Time is up';

  @override
  String get paused => 'Paused';

  @override
  String focusedValue(Object value) {
    return 'Focused $value';
  }

  @override
  String get end => 'End';

  @override
  String get cancelTheSession => 'Cancel the session?';

  @override
  String get nothingIsRecorded => 'Nothing is recorded.';

  @override
  String get keepIt => 'Keep it';

  @override
  String get cancelIt => 'Cancel it';

  @override
  String get cancelSession => 'Cancel session';

  @override
  String get yourStopwatchIsStillRunning => 'Your stopwatch is still running';

  @override
  String get endNow => 'End now';

  @override
  String get resume => 'Resume';

  @override
  String get yourPomodoroEndedWhileLifeflowWas =>
      'Your pomodoro ended while LifeFlow was closed';

  @override
  String get discard => 'Discard';

  @override
  String get countUntilNow => 'Count until now';

  @override
  String get countUntilItEnded => 'Count until it ended';

  @override
  String get aFocusSessionCouldNotBe =>
      'A focus session could not be recovered';

  @override
  String get minutes => 'Minutes';

  @override
  String get close => 'Close';

  @override
  String get endFocus => 'End focus';

  @override
  String get changeAClosedPeriod => 'Change a closed period?';

  @override
  String get changeIt => 'Change it';

  @override
  String habitPageTitle(Object taskTitle) {
    return 'Habit and target: $taskTitle';
  }

  @override
  String get couldNotLoadThisTask => 'Could not load this task.';

  @override
  String get thisTaskNoLongerExists => 'This task no longer exists.';

  @override
  String get trackAsAHabit => 'Track as a habit';

  @override
  String get eachPeriodIsSavedAsDone =>
      'Each period is saved as done or missed (or achieved, with a target).';

  @override
  String get habitsUsuallyRepeat => 'Habits usually repeat';

  @override
  String get withoutARepeatThisHabitHas =>
      'Without a repeat, this habit has one period.';

  @override
  String get everyDay => 'Every day';

  @override
  String get addATargetToMeasureProgress => 'Add a target to measure progress.';

  @override
  String get iTickIt => 'I tick it';

  @override
  String get fromMeasurements => 'From measurements';

  @override
  String get add => 'Add';

  @override
  String get noRunningPeriod => 'No running period';

  @override
  String get addAPastValue => 'Add a past value';

  @override
  String get noEndedPeriodsYet => 'No ended periods yet.';

  @override
  String get noMeasurementsYet => 'No measurements yet.';

  @override
  String get correct => 'Correct…';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get theDayItCountsFor => 'The day it counts for';

  @override
  String get target => 'Target';

  @override
  String get loading => 'Loading';

  @override
  String get removeTarget => 'Remove target';

  @override
  String get currentStreak => 'Current streak';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get allTime => 'All time';

  @override
  String labelValue(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String measurementActions(Object value, Object value2) {
    return 'Actions for the value $value of $value2';
  }

  @override
  String get correctTheValue => 'Correct the value';

  @override
  String get value2 => 'Value';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get typeLabel => 'Type';

  @override
  String get unit => 'Unit';

  @override
  String get eachPeriodCountsThe => 'Each period counts the';

  @override
  String get goals => 'Goals';

  @override
  String get archived => 'Archived';

  @override
  String get trash => 'Trash';

  @override
  String get couldNotLoadTheGoals => 'Could not load the goals.';

  @override
  String get restore => 'Restore';

  @override
  String get edit => 'Edit…';

  @override
  String get markAsDone => 'Mark as done';

  @override
  String get markAsActive => 'Mark as active';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get thisGoalIsInTheTrash =>
      'This goal is in the trash or no longer exists.';

  @override
  String get archivedUnarchiveItToChangeIt =>
      'Archived: unarchive it to change it.';

  @override
  String get withMilestonesProgressCountsTheMilestones =>
      'With milestones, progress counts the milestones you have ticked.';

  @override
  String get noMilestonesWithoutThemProgressComes =>
      'No milestones. Without them, progress comes from the linked tasks and habits.';

  @override
  String dueValue(Object value) {
    return 'Due $value';
  }

  @override
  String get remove => 'Remove';

  @override
  String get addMilestone => 'Add milestone';

  @override
  String get nothingLinkedYet => 'Nothing linked yet.';

  @override
  String get linkATaskOrHabit => 'Link a task or habit';

  @override
  String get linkAnEvent => 'Link an event';

  @override
  String goalsForTitle(Object title) {
    return 'Goals for $title';
  }

  @override
  String get noGoalsYetAddOneIn => 'No goals yet. Add one in the Goals tab.';

  @override
  String twoPartsDot(Object value, Object value2) {
    return '$value · $value2';
  }

  @override
  String get goal => 'Goal';

  @override
  String get project => 'Project';

  @override
  String get newGoalOrProject => 'New goal or project';

  @override
  String get loadingGoals => 'Loading goals';

  @override
  String progressValue(Object value) {
    return 'Progress: $value';
  }

  @override
  String actionsForTitle(Object title) {
    return 'Actions for $title';
  }

  @override
  String actionsForTheMilestoneTitle(Object title) {
    return 'Actions for the milestone $title';
  }

  @override
  String clearLabel(Object label) {
    return 'Clear $label';
  }

  @override
  String get title => 'Title';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get targetDate => 'Target date';

  @override
  String get due => 'Due';

  @override
  String goalTrashedKeepsItems(Object title) {
    return '\"$title\" moved to the trash. Its tasks and events are kept.';
  }

  @override
  String eventSavedRemindersFailed(Object value) {
    return 'Event saved; its reminders were not: $value';
  }

  @override
  String get eventMovedToTheTrash => 'Event moved to the trash.';

  @override
  String get allDayAllDayEventsNever =>
      'All day. All-day events never count as overlapping.';

  @override
  String get noCalendar => 'No calendar';

  @override
  String get undo => 'Undo';

  @override
  String get locationOptional => 'Location (optional)';

  @override
  String schedulePageTitle(Object taskTitle) {
    return 'Schedule: $taskTitle';
  }

  @override
  String get removeSchedule => 'Remove schedule';

  @override
  String get calendars => 'Calendars';

  @override
  String get couldNotLoadTheCalendars => 'Could not load the calendars.';

  @override
  String get noCalendarsYetEventsCanAlso =>
      'No calendars yet. Events can also be without a calendar.';

  @override
  String moveNameToTheTrash(Object name) {
    return 'Move \"$name\" to the trash?';
  }

  @override
  String get itsEventsStayWithoutACalendar =>
      'Its events stay, without a calendar.';

  @override
  String get newCalendar => 'New calendar';

  @override
  String editName(Object name) {
    return 'Edit $name';
  }

  @override
  String get editCalendar => 'Edit calendar';

  @override
  String moveNameToTheTrash2(Object name) {
    return 'Move $name to the trash';
  }

  @override
  String get name => 'Name';

  @override
  String get timeZone => 'Time zone';

  @override
  String get repeat => 'Repeat';

  @override
  String get every => 'Every';

  @override
  String get withNoDayChosenItRepeats =>
      'With no day chosen it repeats on the start\'s weekday.';

  @override
  String get lastDate => 'Last date';

  @override
  String get thisDevice => 'This device';

  @override
  String get custom => 'Custom…';

  @override
  String get atADateAndTime => 'At a date and time…';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get setADateToBeReminded => 'Set a date to be reminded before it.';

  @override
  String get remindBefore => 'Remind before';

  @override
  String labelTime(Object label) {
    return '$label time';
  }

  @override
  String removeLabelTime(Object label) {
    return 'Remove $label time';
  }

  @override
  String removeLabel(Object label) {
    return 'Remove $label';
  }

  @override
  String get number => 'Number';

  @override
  String get times => 'Times';

  @override
  String get search => 'Search';

  @override
  String get remindAt => 'Remind at';

  @override
  String get openNavigationMenu => 'Open navigation menu';

  @override
  String storageWarningMessage(Object message) {
    return 'Storage warning. $message';
  }

  @override
  String restoreInBothDifferent(Object differing, Object newerInFile) {
    return 'In both, but different: $differing (newer in the file: $newerInFile)';
  }

  @override
  String get restoreOverwriteHint =>
      'This profile becomes exactly the file. Items only on this device move to the trash.';

  @override
  String get restoreMergeHint =>
      'Keep this device\'s data and take from the file what you choose below.';

  @override
  String get restoreNewerHint =>
      'For items in both, keep the one changed most recently.';

  @override
  String get restoreUndoHint =>
      'The current data is kept, so you can undo this restore afterwards.';

  @override
  String focusEndQuestion(Object duration) {
    return 'Focused for $duration. Saving it records the time you worked; it does not complete the task.';
  }

  @override
  String get timeIsUpLower => 'time is up';

  @override
  String focusBarLabel(Object what, Object time) {
    return 'Focus: $what, $time. Open';
  }

  @override
  String focusBarLabelPaused(Object what, Object time) {
    return 'Focus: $what, $time, paused. Open';
  }

  @override
  String focusBarText(Object time, Object what) {
    return '$time · $what';
  }

  @override
  String focusBarTextPaused(Object time, Object what) {
    return '$time · $what · paused';
  }

  @override
  String focusOverdueContent(Object title, Object minutes) {
    return '$title: $minutes minutes. How should it be saved?';
  }

  @override
  String focusUnrecoverableContent(Object reason) {
    return 'It is kept as it was stored, and nothing was recorded for it ($reason). You can start a new session.';
  }

  @override
  String get eventRepeatHint =>
      'Changes here apply to every time this event repeats. To change one time only, use its actions in the calendar.';

  @override
  String get closedPeriodContent =>
      'This period has ended and its result is saved. The change will be judged with the target it had, and the change is recorded.';

  @override
  String goalUnlink(Object item) {
    return 'Unlink $item';
  }

  @override
  String get goalUnlinkItem => 'item';

  @override
  String drawerProfileLabel(Object name) {
    return 'Profile: $name. Open profiles';
  }

  @override
  String drawerProfileLabelWithStatus(Object name, Object status) {
    return 'Profile: $name, $status. Open profiles';
  }

  @override
  String get ovEmpty => 'No tasks yet. Use the + button to add your first one.';

  @override
  String get ovLoading => 'Loading tasks';

  @override
  String get ovLoadError => 'Could not load tasks.';

  @override
  String get ovNotInAList => 'Not in a list';

  @override
  String get ovAddMenu => 'Add';

  @override
  String get ovCloseAddMenu => 'Close the add menu';

  @override
  String get ovAddTask => 'Add task';

  @override
  String get ovNewList => 'New list';

  @override
  String get ovNewEvent => 'New event';

  @override
  String get ovNewTask => 'New task';

  @override
  String get ovNewSubtask => 'New subtask';

  @override
  String get ovRenameTask => 'Rename task';

  @override
  String get ovRenameList => 'Rename list';

  @override
  String get ovRename => 'Rename';

  @override
  String get ovFocus => 'Focus…';

  @override
  String get ovSchedule => 'Schedule…';

  @override
  String get ovHabitAndTarget => 'Habit and target…';

  @override
  String get ovGoals => 'Goals…';

  @override
  String get ovAddSubtask => 'Add subtask';

  @override
  String get ovAddEvent => 'Add event';

  @override
  String get ovColour => 'Colour…';

  @override
  String get ovMoveUp => 'Move up';

  @override
  String get ovMoveDown => 'Move down';

  @override
  String get ovIndent => 'Make it a subtask of the task above';

  @override
  String get ovOutdent => 'Move it up a level';

  @override
  String get ovMoveToList => 'Move to list…';

  @override
  String get ovMoveToListTitle => 'Move to list';

  @override
  String get ovNoList => 'No list';

  @override
  String get ovColourTitle => 'Colour';

  @override
  String get ovNoColour => 'No colour';

  @override
  String get ovColorRed => 'Red';

  @override
  String get ovColorOrange => 'Orange';

  @override
  String get ovColorAmber => 'Amber';

  @override
  String get ovColorOlive => 'Olive';

  @override
  String get ovColorGreen => 'Green';

  @override
  String get ovColorTeal => 'Teal';

  @override
  String get ovColorCyan => 'Cyan';

  @override
  String get ovColorBlue => 'Blue';

  @override
  String get ovColorIndigo => 'Indigo';

  @override
  String get ovColorPurple => 'Purple';

  @override
  String get ovColorPink => 'Pink';

  @override
  String get ovColorBrown => 'Brown';

  @override
  String ovComplete(Object title) {
    return 'Complete $title';
  }

  @override
  String ovMarkNotDone(Object title) {
    return 'Mark as not done: $title';
  }

  @override
  String ovDoneFromMeasurements(Object title) {
    return 'Done from measurements: $title';
  }

  @override
  String ovExpand(Object title) {
    return 'Expand $title';
  }

  @override
  String ovCollapse(Object title) {
    return 'Collapse $title';
  }

  @override
  String ovDragHandle(Object title) {
    return 'Drag $title to move it';
  }

  @override
  String ovListTrashed(Object title) {
    return '\"$title\" moved to the trash with its tasks and events.';
  }

  @override
  String ovColourSwatch(Object name) {
    return '$name';
  }

  @override
  String ovEventLabel(Object title) {
    return 'Event: $title';
  }

  @override
  String ovItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get tlTimeline => 'Timeline';

  @override
  String get tlGoToToday => 'Go to today';

  @override
  String get tlAllDay => 'All day';

  @override
  String get tlNothingPlanned =>
      'Nothing planned yet. Tasks and events you plan show up here.';

  @override
  String get tlNothingThisDay => 'Nothing planned.';

  @override
  String get tlShowMonth => 'Show the month calendar';

  @override
  String get tlHideMonth => 'Hide the month calendar';

  @override
  String get tlTruncated => 'Not everything is shown';

  @override
  String get tlTruncatedHint =>
      'There are more items than the limit in Settings → Calendar.';

  @override
  String get tlLoading => 'Loading the timeline';

  @override
  String tlOverdue(int count) {
    return 'Overdue ($count)';
  }

  @override
  String get tlShowOverdue => 'Show the overdue tasks';

  @override
  String get tlHideOverdue => 'Hide the overdue tasks';

  @override
  String tlDayHeader(Object relative, Object date) {
    return '$relative · $date';
  }

  @override
  String get calDay => 'Day';

  @override
  String get calWeek => 'Week';

  @override
  String get calMonth => 'Month';

  @override
  String get calYear => 'Year';

  @override
  String get calGoToToday => 'Go to today';

  @override
  String get calPrevious => 'Previous';

  @override
  String get calNext => 'Next';

  @override
  String get calZoomIn => 'Zoom in';

  @override
  String get calZoomOut => 'Zoom out';

  @override
  String get calShowNight => 'Show the night hours';

  @override
  String get calHideNight => 'Hide the night hours';

  @override
  String calNightFold(Object from, Object to) {
    return '$from–$to hidden. Show';
  }

  @override
  String get calOpenTimeline => 'Open the Timeline';

  @override
  String get calMore => 'More';

  @override
  String get calManageCalendars => 'Manage calendars';

  @override
  String get calNewEvent => 'New event';

  @override
  String get calNewTask => 'New task';

  @override
  String get calScheduleTask => 'Schedule a task here…';

  @override
  String calSlotTitle(Object date, Object time) {
    return '$date at $time';
  }

  @override
  String get calPickTask => 'Schedule which task?';

  @override
  String get calNoUnscheduled => 'Every open task already has a schedule.';

  @override
  String get calNow => 'Now';

  @override
  String get calLoading => 'Loading the calendar';

  @override
  String get calLoadError => 'Could not load the calendar.';

  @override
  String calDayItems(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'nothing planned',
    );
    return '$date, $_temp0';
  }

  @override
  String calAllDayMore(int count) {
    return '+$count';
  }

  @override
  String get calNightHours => 'Night hours';

  @override
  String get calNightHoursHint =>
      'Hidden in the day and week grids until you show them.';

  @override
  String calNightFrom(Object time) {
    return 'From $time';
  }

  @override
  String calNightTo(Object time) {
    return 'To $time';
  }

  @override
  String get navOverview => 'Overview';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navHabits => 'Habits';

  @override
  String get navGoals => 'Goals';

  @override
  String get navSettings => 'Settings';

  @override
  String get navProfiles => 'Profiles';

  @override
  String get habitsAdd => 'Add habit';

  @override
  String get habitsNew => 'New habit';

  @override
  String get habitsLoadError => 'Could not load the habits.';

  @override
  String get habitsLoading => 'Loading habits';

  @override
  String get habitsEmpty =>
      'No habits yet. Add one with +, or open a task\'s menu and choose \"Habit and target…\".';

  @override
  String get habitsNoRepeat => 'No repeat';

  @override
  String habitsAddMeasurement(Object title) {
    return 'Add a measurement for $title';
  }

  @override
  String get resultsTitle => 'Measured tasks you tick yourself';

  @override
  String get resultsHint =>
      'What is kept for each period. Periods that end after a change follow it; what is kept already stays.';

  @override
  String get resultsTarget => 'Judge by the target';

  @override
  String get resultsTargetHint => 'Achieved, not achieved, or no data.';

  @override
  String get resultsTick => 'Count the tick';

  @override
  String get resultsTickHint => 'Done when ticked, otherwise missed.';

  @override
  String get resultsCouldNotLoad => 'This setting could not be loaded.';

  @override
  String get calNewAllDayEvent => 'New all-day event';

  @override
  String get apDragHandles => 'Drag handles';

  @override
  String get apDragHandlesHint =>
      'In the Overview. Without them, press and hold a row to move it.';

  @override
  String get apAuto => 'Auto';

  @override
  String get apAlways => 'Always';

  @override
  String get apNever => 'Never';

  @override
  String get apFont => 'Font';

  @override
  String get apFontSystem => 'System';

  @override
  String get apTextSize => 'Text size';

  @override
  String apTextSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get apTextSizeHint => 'On top of the text size of your device.';

  @override
  String get tpTitle => 'Task';

  @override
  String get tpGone => 'This task no longer exists.';

  @override
  String get tpFocus => 'Focus';

  @override
  String get tpTrash => 'Move to trash';

  @override
  String get tpRename => 'Rename';

  @override
  String tpUnder(Object title) {
    return 'Subtask of $title';
  }

  @override
  String get tpList => 'List';

  @override
  String get tpColour => 'Colour';

  @override
  String get tpNotes => 'Notes';

  @override
  String get tpNotesHint => 'Add notes';

  @override
  String get tpSaveNotes => 'Save notes';

  @override
  String get tpPlan => 'Plan';

  @override
  String get tpSchedule => 'Schedule and reminders';

  @override
  String get tpNotScheduled => 'Not scheduled';

  @override
  String get tpNotTracked => 'Not tracked';

  @override
  String get tpSubtasks => 'Subtasks';
}
