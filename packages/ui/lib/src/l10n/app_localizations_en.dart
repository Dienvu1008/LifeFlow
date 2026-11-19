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

  @override
  String get sySync => 'Sync';

  @override
  String get sySyncOff => 'Off · your data stays on this device';

  @override
  String get syUpToDate => 'Synced';

  @override
  String syUpToDateAt(Object time) {
    return 'Synced $time';
  }

  @override
  String get syNotSyncedYet => 'Not synced yet';

  @override
  String get sySyncing => 'Syncing…';

  @override
  String syWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes to send',
      one: '1 change to send',
    );
    return '$_temp0';
  }

  @override
  String get syOffline => 'Can\'t reach the server · will try again';

  @override
  String get sySignedOut => 'Signed out · sign in to sync';

  @override
  String get syUpdateNeeded => 'Update LifeFlow to keep syncing';

  @override
  String get syKeyChanged =>
      'Set up again on another device · turn sync off and on';

  @override
  String get syWorkspaceGone => 'The synced copy was deleted';

  @override
  String get syNotYours => 'This account can\'t sync this profile';

  @override
  String get syFailed => 'Sync failed · will try again';

  @override
  String syReviewsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes to review',
      one: '1 change to review',
    );
    return '$_temp0';
  }

  @override
  String syStatusAndReviews(Object status, Object reviews) {
    return '$status · $reviews';
  }

  @override
  String get sySyncThisProfile => 'Sync this profile';

  @override
  String get sySyncThisProfileHint =>
      'Keeps this profile the same on your devices signed in to this account. End-to-end encrypted: the server can\'t read your data.';

  @override
  String get syNotAvailable =>
      'Sync is not available in this build of LifeFlow.';

  @override
  String get sySignInFirst => 'Sign in to an account to sync this profile.';

  @override
  String get syLockedProfile =>
      'Signed out. Sign in again to sync this profile.';

  @override
  String get syOpenProfiles => 'Open Profiles';

  @override
  String get sySyncNow => 'Sync now';

  @override
  String get syWhenToSync => 'When to sync';

  @override
  String get syAutomatic => 'Automatic';

  @override
  String get syAutomaticHint =>
      'When the app opens, a few seconds after a change and every few minutes while it is open';

  @override
  String get syOnlySyncNow => 'Only when I tap “Sync now”';

  @override
  String get syOnlySyncNowHint =>
      'Nothing is sent or received until you tap it';

  @override
  String get syUndoJoin => 'Undo joining';

  @override
  String get syUndoJoinHint =>
      'Puts this device back as it was before it joined. What it already sent stays on your other devices.';

  @override
  String get syUndoJoinTitle => 'Undo joining?';

  @override
  String get syUndoJoinBody =>
      'This device goes back to its data from before it joined, and sync turns off. What it already sent stays on your other devices.';

  @override
  String get syUndo => 'Undo';

  @override
  String get syUndone => 'This device is back as it was before it joined.';

  @override
  String get syTurnOffTitle => 'Turn sync off?';

  @override
  String get syTurnOffBody =>
      'This device stops syncing this profile. Its data stays here, and your other devices keep their copies.';

  @override
  String get syTurnOff => 'Turn off';

  @override
  String get syTurnedOff => 'Sync is off. Your data stays on this device.';

  @override
  String get syDeleteServer => 'Delete my data from the server';

  @override
  String get syDeleteServerHint =>
      'Removes the synced copy. The data on this device stays.';

  @override
  String get syDeleteServerTitle => 'Delete your data from the server?';

  @override
  String get syDeleteServerBody =>
      'The encrypted copy on the server is deleted and sync turns off. This device keeps its data. Your other devices keep theirs but can no longer sync.';

  @override
  String get syDelete => 'Delete';

  @override
  String get syDeleted => 'Your data was deleted from the server.';

  @override
  String get syUpdateTitle => 'Update LifeFlow';

  @override
  String get syUpdateBody =>
      'Another device uses a newer LifeFlow. This device still sends its changes, but it can\'t take in the newer ones until you update.';

  @override
  String get syKeyChangedTitle => 'Sync was set up again';

  @override
  String get syKeyChangedBody =>
      'Another device set up sync again with a new key. Turn sync off here, then turn it on with the new recovery key or passphrase.';

  @override
  String get syWorkspaceGoneTitle => 'The synced copy was deleted';

  @override
  String get syWorkspaceGoneBody =>
      'The synced copy of this profile was deleted from the server. Turn sync off here. Turning it on again starts a new synced copy.';

  @override
  String get syReviewsTitle => 'Changes to review';

  @override
  String get syNoReviews => 'Nothing to review.';

  @override
  String get syReviewChanged =>
      'Changed on two devices. The newer change was kept.';

  @override
  String get syReviewDeleted =>
      'Deleted on one device and edited on another. It is in the trash with the edits: restore it from the trash to bring it back.';

  @override
  String get syReviewUnreadable =>
      'A change this version of LifeFlow can\'t read.';

  @override
  String get syKeptValue => 'Kept';

  @override
  String get syOtherValue => 'The other change';

  @override
  String get syEmptyValue => '(empty)';

  @override
  String get syKeepThis => 'Keep this';

  @override
  String get syTakeOther => 'Take the other';

  @override
  String get syDismiss => 'OK';

  @override
  String syRecordKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'task': 'Task',
        'event': 'Event',
        'taskList': 'List',
        'calendar': 'Calendar',
        'schedule': 'Schedule',
        'reminder': 'Reminder',
        'exception': 'Change to one occurrence',
        'goal': 'Goal',
        'milestone': 'Milestone',
        'goalLink': 'Goal link',
        'focusSession': 'Focus session',
        'periodResult': 'Habit result',
        'workspaceSettings': 'Settings',
        'document': 'Document',
        'documentRevision': 'Document version',
        'documentLink': 'Document link',
        'other': 'Item',
      },
    );
    return '$_temp0';
  }

  @override
  String syRecordOf(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String get syTurnOnTitle => 'Turn on sync';

  @override
  String get syChecking => 'Checking your account…';

  @override
  String get syTryAgain => 'Try again';

  @override
  String get syProtectTitle => 'How do you want to protect your data?';

  @override
  String get syProtectBody =>
      'Your data is encrypted on this device before it is sent. To open it on another device you need one of these. If you lose it, the synced copy can\'t be opened, not even by us.';

  @override
  String get syUseRecoveryKey => 'Recovery key (recommended)';

  @override
  String get syUseRecoveryKeyHint =>
      '24 words, made for you. Write them down or save them.';

  @override
  String get syUsePassphrase => 'Passphrase';

  @override
  String get syUsePassphraseHint =>
      'A long phrase you choose, at least 12 characters.';

  @override
  String get syYourRecoveryKey => 'Your recovery key';

  @override
  String get syRecoveryKeyBody =>
      'Write these 24 words down in order, or save them to a file, and keep them somewhere safe. You need them to sync another device.';

  @override
  String get syRecoveryKeyQr => 'QR code of your recovery key';

  @override
  String get sySaveToFile => 'Save to a file';

  @override
  String get sySaved => 'Saved.';

  @override
  String get syRecoveryKeyFileHeader =>
      'LifeFlow recovery key. Keep it safe; anyone with it and your account can read your synced data.';

  @override
  String get syNext => 'Next';

  @override
  String get syBack => 'Back';

  @override
  String get syConfirmKeyTitle => 'Confirm your recovery key';

  @override
  String syConfirmKeyBody(int first, int second) {
    return 'Type words $first and $second of your recovery key.';
  }

  @override
  String syWordN(int n) {
    return 'Word $n';
  }

  @override
  String get syTurnOn => 'Turn on sync';

  @override
  String get syChoosePassphrase => 'Choose a passphrase';

  @override
  String get syPassphrase => 'Passphrase';

  @override
  String get syRepeatPassphrase => 'Repeat the passphrase';

  @override
  String get syPassphraseHint =>
      'At least 12 characters. A few unrelated words are easy to remember and hard to guess.';

  @override
  String get syPassphrasesDiffer => 'The two passphrases are not the same.';

  @override
  String get syJoinTitle => 'Join your synced data';

  @override
  String get syJoinBody =>
      'This account already syncs from another device. Unlock its data:';

  @override
  String get syRecoveryKey => 'Recovery key';

  @override
  String get syRecoveryKeyHint => 'The 24 words, separated by spaces';

  @override
  String get syJoinWhat => 'And the data already on this device?';

  @override
  String get syJoinMerge => 'Add it to the synced data (recommended)';

  @override
  String get syJoinMergeHint =>
      'Both are kept: this device\'s data and the account\'s.';

  @override
  String get syJoinReplace => 'Use only the synced data';

  @override
  String get syJoinReplaceHint =>
      'This device\'s data is saved to a file first, then replaced. You can undo this.';

  @override
  String get syJoin => 'Join';

  @override
  String get syTurnedOn => 'Sync is on.';

  @override
  String get syJoined => 'This device now syncs with your account.';

  @override
  String get syExportSaved =>
      'This device\'s earlier data was saved to a file.';

  @override
  String get syExportNotSaved =>
      'This device\'s earlier data was not saved to a file. You can still undo joining.';

  @override
  String syProblem(String problem) {
    String _temp0 = intl.Intl.selectLogic(
      problem,
      {
        'offline':
            'Can\'t reach the server. Check your connection and try again.',
        'signedOut': 'You are signed out. Sign in again in Profiles.',
        'notYours': 'This account can\'t sync this profile.',
        'recoveryKeyNotConfirmed':
            'Those words don\'t match. Check the words at those positions.',
        'recoveryKeyInvalid': 'That isn\'t a valid recovery key.',
        'wrongRecoveryKey':
            'That recovery key doesn\'t open this account\'s data.',
        'wrongPassphrase':
            'That passphrase doesn\'t open this account\'s data.',
        'passphraseTooShort': 'Use at least 12 characters.',
        'passphraseTooCommon': 'That passphrase is too common. Choose another.',
        'alreadyOn': 'Sync is already on.',
        'notOn': 'Sync is off.',
        'nothingToUndo': 'There is nothing to undo.',
        'reviewGone': 'This was already closed, or its item is gone.',
        'other': 'Something went wrong. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String get spSpaces => 'Spaces';

  @override
  String get spPersonal => 'Personal';

  @override
  String get spNewSpace => 'New space…';

  @override
  String get spJoinSpace => 'Join with a code…';

  @override
  String spChooseSpace(String name) {
    return 'Spaces: $name';
  }

  @override
  String get spUnnamed => 'A shared space';

  @override
  String spRole(String role) {
    String _temp0 = intl.Intl.selectLogic(
      role,
      {
        'owner': 'Owner',
        'editor': 'Editor',
        'viewer': 'Viewer',
        'other': 'Member',
      },
    );
    return '$_temp0';
  }

  @override
  String spPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get spViewOnly => 'View only';

  @override
  String get spLeftCopy => 'A read-only copy: you are no longer in this space';

  @override
  String get spLeftExport =>
      'You are no longer in this space. Export a copy, then remove it.';

  @override
  String spBarLabel(String name, String details) {
    return '$name, $details. Space details';
  }

  @override
  String get spSpaceName => 'Name of the space';

  @override
  String get spCreate => 'Create';

  @override
  String get spCreated =>
      'The space is ready. Invite someone from its details.';

  @override
  String get spJoinTitle => 'Join a space';

  @override
  String get spJoinHint =>
      'The code or the lifeflow://join/ link you were given';

  @override
  String get spJoinNameHint => 'How the others in the space will know you';

  @override
  String get spJoinNameNeeded =>
      'Type your name: the others in the space will know you by it.';

  @override
  String get spLook => 'Look';

  @override
  String spInvitedAs(String role) {
    return 'You are invited as $role.';
  }

  @override
  String get spJoinApproveNote =>
      'The owner lets you in after you ask. Until then you see nothing of the space.';

  @override
  String get spJoinAtOnceNote => 'You are in as soon as you join.';

  @override
  String get spRulesTitle => 'The space\'s rules';

  @override
  String spLeaveRuleText(String rule) {
    String _temp0 = intl.Intl.selectLogic(
      rule,
      {
        'disappear':
            'If you leave or are removed, the space disappears from your devices.',
        'disappearWithExport':
            'If you leave or are removed, you may export a copy first; then it disappears from your devices.',
        'keepReadOnly':
            'If you leave or are removed, you keep a read-only copy of what was there.',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String spExportRuleText(String rule) {
    String _temp0 = intl.Intl.selectLogic(
      rule,
      {
        'ownerOnly': 'Only the owner can export the space.',
        'everyMember': 'Every member can export the space.',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String spInviteRuleText(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'approve': 'The owner approves who joins.',
        'joinAtOnce': 'People join at once with a code.',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get spCannotEnforce =>
      'LifeFlow keeps these rules, but anyone in the space can read everything while they are in it, and can take screenshots or copy it by hand.';

  @override
  String get spJoin => 'Join';

  @override
  String get spAskedToJoin => 'You asked to join. The owner lets you in.';

  @override
  String get spJoined => 'You are in the space.';

  @override
  String spProblem(String problem) {
    String _temp0 = intl.Intl.selectLogic(
      problem,
      {
        'notSignedIn': 'Sign in to an account first (Profiles).',
        'syncOff':
            'Turn sync on first (Settings → Sync): it carries the keys of your spaces.',
        'offline':
            'Can\'t reach the server. Check your connection and try again.',
        'notAllowed': 'Your role in this space does not allow that.',
        'noSuchInvitation':
            'That code is not valid: it was used, cancelled or has expired.',
        'alreadyMember': 'You are already in this space.',
        'spaceFull': 'This space already has 10 members.',
        'tooManySpaces': 'You are already in 10 spaces.',
        'ownerMustHandOver': 'Make someone else the owner before you leave.',
        'changedSinceShown': 'Something changed since you looked. Look again.',
        'cannotMove': 'This cannot move.',
        'exportNotAllowed':
            'The space\'s export rule does not allow you to export it.',
        'other': 'Something went wrong. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String get spDetails => 'Space details';

  @override
  String get spRename => 'Rename the space';

  @override
  String get spYourName => 'Your name in this space';

  @override
  String get spYourNameHint => 'Shown to the other members';

  @override
  String get spMembers => 'Members';

  @override
  String get spWaiting => 'Asks to join';

  @override
  String get spApprove => 'Let in';

  @override
  String get spTurnDown => 'Turn down';

  @override
  String get spRemove => 'Remove from the space';

  @override
  String spRemoveConfirm(String name) {
    return 'Remove $name? They can no longer open the space; what stays on their devices is the space\'s leaving rule.';
  }

  @override
  String spMakeRole(String role) {
    return 'Make $role';
  }

  @override
  String get spHandOver => 'Make the owner';

  @override
  String spHandOverConfirm(String name) {
    return 'Make $name the owner? You become an editor.';
  }

  @override
  String spYou(String name) {
    return '$name (you)';
  }

  @override
  String get spSomeone => 'A member';

  @override
  String spMemberActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get spInvite => 'Invite someone';

  @override
  String get spInviteRole => 'As';

  @override
  String get spInviteKind => 'How they get in';

  @override
  String get spInviteApprove => 'I approve who joins';

  @override
  String get spInviteAtOnce => 'Join at once';

  @override
  String get spInviteAtOnceWarning =>
      'Anyone who gets this code before it is used can join. Send it only to the person.';

  @override
  String get spInviteMake => 'Make the invitation';

  @override
  String get spInviteReady => 'Send this to the person, by any messenger';

  @override
  String get spInviteCode => 'Code';

  @override
  String get spInviteLink => 'Link';

  @override
  String get spCopy => 'Copy';

  @override
  String get spCopied => 'Copied.';

  @override
  String get spInviteQr => 'QR code of the invitation';

  @override
  String get spInviteOnce => 'For one person, valid for 7 days.';

  @override
  String get spOpenInvitations => 'Open invitations';

  @override
  String spInvitationLine(String role, String kind, String date) {
    return '$role · $kind · until $date';
  }

  @override
  String get spCancelInvitation => 'Cancel the invitation';

  @override
  String get spRules => 'Rules';

  @override
  String get spRuleLeave => 'When someone leaves';

  @override
  String spRuleLeaveOption(String rule) {
    String _temp0 = intl.Intl.selectLogic(
      rule,
      {
        'disappear': 'The space disappears',
        'disappearWithExport': 'They may export first',
        'keepReadOnly': 'They keep a read-only copy',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get spRuleExport => 'Who can export';

  @override
  String spRuleExportOption(String rule) {
    String _temp0 = intl.Intl.selectLogic(
      rule,
      {
        'ownerOnly': 'Only the owner',
        'everyMember': 'Every member',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get spRuleInvite => 'Invitations by default';

  @override
  String spRulesChanged(String name) {
    return 'The owner changed the rules of $name.';
  }

  @override
  String get spGotIt => 'Got it';

  @override
  String get spExport => 'Export a copy';

  @override
  String get spExported => 'Saved.';

  @override
  String get spLeave => 'Leave the space';

  @override
  String spLeaveConfirm(String name) {
    return 'Leave $name?';
  }

  @override
  String get spDelete => 'Delete the space for everyone';

  @override
  String spDeleteConfirm(String name) {
    return 'Delete $name for everyone? Nobody can open it any more.';
  }

  @override
  String get spForget => 'Remove this copy';

  @override
  String get spMoveTo => 'Move to a space…';

  @override
  String get spMoveOut => 'Move to Personal…';

  @override
  String get spPickSpace => 'Move to which space?';

  @override
  String spMoveTitle(String name) {
    return 'Move to $name?';
  }

  @override
  String spMoveBody(String name) {
    return 'Everyone in $name will see:';
  }

  @override
  String get spMoveOutBody =>
      'It leaves the space: for the others it is like a delete. It moves:';

  @override
  String get spMoveNotes => 'Its notes';

  @override
  String get spMoveDates => 'Its dates and repeats';

  @override
  String spMoveMore(int n) {
    return 'and $n more';
  }

  @override
  String get spMoveStays => 'Reminders and tracking stay with you.';

  @override
  String get spMove => 'Move';

  @override
  String get spMoved => 'Moved.';

  @override
  String spCannotMove(String reason) {
    return 'This cannot move: $reason';
  }

  @override
  String get spAssignedTo => 'Assigned to';

  @override
  String get spNobody => 'Nobody';

  @override
  String get spAssignedToMe => 'Assigned to me';

  @override
  String spChangedBy(String name, String time) {
    return 'Changed by $name, $time';
  }

  @override
  String get spSpaceDetails => 'Details';

  @override
  String get spNoSpaces => 'Spaces are not available in this build.';

  @override
  String get spSyncNow => 'Sync now';

  @override
  String get navDocuments => 'Documents';

  @override
  String get docNew => 'New document';

  @override
  String get docNewSub => 'New subdocument';

  @override
  String get docTitleLabel => 'Title';

  @override
  String get docUntitled => 'Untitled';

  @override
  String get docSearchHint => 'Search documents and tasks';

  @override
  String get docEmpty =>
      'No documents yet. Add one with +, then type [[ in it to link another.';

  @override
  String get docTrash => 'Trash';

  @override
  String get docTrashEmpty => 'The trash is empty.';

  @override
  String get docLoading => 'Loading documents';

  @override
  String get docCouldNotLoad => 'Could not load the documents.';

  @override
  String docNoResults(String query) {
    return 'Nothing found for “$query”.';
  }

  @override
  String get docResultsDocuments => 'Documents';

  @override
  String get docResultsTasks => 'Tasks';

  @override
  String get docMoveUnder => 'Move under…';

  @override
  String get docPickParent => 'Move under';

  @override
  String get docTopLevel => 'At the top';

  @override
  String get docHistory => 'History';

  @override
  String get docLinkItem => 'Link to a task or goal…';

  @override
  String get docSaved => 'Saved';

  @override
  String get docSaving => 'Saving…';

  @override
  String get docUnsaved => 'Not saved yet';

  @override
  String get docViewOnly => 'View only';

  @override
  String get docInTrash =>
      'This document is in the trash. Restore it to change it.';

  @override
  String get docUnreadable =>
      'This document cannot be shown: it was written by a newer version of LifeFlow, or it is damaged. Its history may hold a version that opens.';

  @override
  String get docGone => 'This document is not here any more.';

  @override
  String get docBacklinks => 'Backlinks';

  @override
  String get docNoBacklinks => 'No document links here yet.';

  @override
  String get docLinked => 'Linked';

  @override
  String get docNoLinked => 'Not linked to a task, an event or a goal.';

  @override
  String docLinksSummary(int backlinks, int linked) {
    String _temp0 = intl.Intl.pluralLogic(
      backlinks,
      locale: localeName,
      other: '$backlinks backlinks',
      one: '1 backlink',
      zero: 'No backlinks',
    );
    String _temp1 = intl.Intl.pluralLogic(
      linked,
      locale: localeName,
      other: '$linked linked',
      one: '1 linked',
      zero: 'nothing linked',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get docUnlink => 'Unlink';

  @override
  String docRevision(int version) {
    return 'Version $version';
  }

  @override
  String get docReasonSave => 'Saved';

  @override
  String get docReasonConflict => 'Kept from a change on two devices';

  @override
  String get docReasonRestore => 'An earlier version restored';

  @override
  String docRevisionMeta(String reason, String when, String who) {
    return '$reason · $when · $who';
  }

  @override
  String get docByYou => 'you';

  @override
  String docOnDevice(String who, String device) {
    return '$who, on $device';
  }

  @override
  String get docRestoreVersion => 'Restore this version';

  @override
  String get docRestored => 'Restored as a new version.';

  @override
  String get docVersionUnreadable => 'This version cannot be shown.';

  @override
  String get docLinkPickerTitle => 'Link to a document';

  @override
  String get docLinkPickerHint => 'Find a document';

  @override
  String docCreateNamed(String title) {
    return 'Create “$title”';
  }

  @override
  String docLinkInTrash(String title) {
    return '“$title” is in the trash. Restore it to open it.';
  }

  @override
  String get docLinkMissing =>
      'This link points to a document that is not here.';

  @override
  String docLinkCopied(String url) {
    return 'Copied the address $url';
  }

  @override
  String get docAttach => 'Attach a file';

  @override
  String docFileTooLarge(String size) {
    return 'This file is larger than $size.';
  }

  @override
  String get docFileNotKept => 'The file could not be kept.';

  @override
  String docFileElsewhere(String name, String size) {
    return 'On another device · $name · $size';
  }

  @override
  String docFileUnreadable(String name) {
    return 'Cannot be read · $name';
  }

  @override
  String docFileHere(String name, String size) {
    return '$name · $size';
  }

  @override
  String get docFileSaveCopy => 'Save a copy';

  @override
  String docFileSaved(String name) {
    return 'Saved a copy of $name.';
  }

  @override
  String docTrashed(String title) {
    return '“$title” and its subdocuments are in the trash.';
  }

  @override
  String get docItemDocuments => 'Documents';

  @override
  String get docPickItemTitle => 'Link to a task or goal';

  @override
  String get docPickItemHint => 'Find a task';

  @override
  String get docGoalsHeader => 'Goals';

  @override
  String docItemType(String type) {
    String _temp0 = intl.Intl.selectLogic(
      type,
      {
        'task': 'Task',
        'event': 'Event',
        'goal': 'Goal',
        'other': 'Item',
      },
    );
    return '$_temp0';
  }

  @override
  String get docItemMissing => 'Not here any more';

  @override
  String get docItemTrashed => 'In the trash';

  @override
  String get docItemDone => 'Done';

  @override
  String get docItemCancelled => 'Cancelled';

  @override
  String get docPlaceholder => 'Write here. Type [[ to link a document.';

  @override
  String get docToolParagraph => 'Text';

  @override
  String get docToolHeading1 => 'Heading 1';

  @override
  String get docToolHeading2 => 'Heading 2';

  @override
  String get docToolHeading3 => 'Heading 3';

  @override
  String get docToolBullet => 'Bulleted list';

  @override
  String get docToolNumbered => 'Numbered list';

  @override
  String get docToolTodo => 'To-do';

  @override
  String get docToolQuote => 'Quote';

  @override
  String get docToolCode => 'Code block';

  @override
  String get docToolBold => 'Bold';

  @override
  String get docToolItalic => 'Italic';

  @override
  String get docToolUnderline => 'Underline';

  @override
  String get docToolStrike => 'Strikethrough';

  @override
  String get docToolInlineCode => 'Code';

  @override
  String get docToolLink => 'Link to a document';

  @override
  String get docToolIndent => 'Indent';

  @override
  String get docToolOutdent => 'Outdent';

  @override
  String get docToolUndo => 'Undo';

  @override
  String get docToolRedo => 'Redo';

  @override
  String get docChangedElsewhere =>
      'This document also changed on another device while you were writing. Both versions are in its history.';

  @override
  String get docOpenAgain => 'Open again';
}
