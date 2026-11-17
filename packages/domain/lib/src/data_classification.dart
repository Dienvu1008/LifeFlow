// P04 T7 (ADR-0059; data-classification.md §1–§4, p04-plan.md D4, D12):
// the classes of data and what may leave the device for cloud sync. Pure:
// the sync engine asks this before it seals a record (LF-INV-PRIV-001/003),
// and the AI context builder of P06 will ask the same classes (FF-ARCH-08).

/// From least to most sensitive (data-classification.md §1).
enum DataClassification {
  /// Non-personal reference data shipped with the app.
  public,

  /// The user's ordinary content: tasks, events, goals, lists, schedules,
  /// focus sessions.
  personal,

  /// Personal content the user would not share without intent: note
  /// bodies, private documents (P05), AI chat history (P06).
  confidential,

  /// Health and activity data from a health source, secrets: tightest
  /// egress, explicit consent.
  restricted,
}

/// Whether a record of [classification] may be synced to the account's cloud copy.
/// Public, Personal and Confidential may: sync is end-to-end encrypted (D12)
/// and owner decision D4 includes every current kind, notes too (this answers
/// OQ-CLASS-1 for P04). Restricted is denied unless the user gave explicit
/// consent for its category ([restrictedConsent]); no such consent exists yet
/// (P08), so it never syncs.
bool cloudSyncAllowed(DataClassification classification, {bool restrictedConsent = false}) => switch (classification) {
      DataClassification.public || DataClassification.personal || DataClassification.confidential => true,
      DataClassification.restricted => restrictedConsent,
    };

/// Where a measurement may come from without being health data: typed in,
/// counted by a focus session, or restored from a LifeFlow file. Any other
/// source (a health platform, P08) is Restricted (data-classification.md §3).
const personalMeasurementSources = {'manual', 'focusSession', 'import'};
