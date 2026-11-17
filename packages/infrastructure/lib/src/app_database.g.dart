// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _activeWorkspaceIdMeta =
      const VerificationMeta('activeWorkspaceId');
  @override
  late final GeneratedColumn<String> activeWorkspaceId =
      GeneratedColumn<String>('active_workspace_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accountProviderMeta =
      const VerificationMeta('accountProvider');
  @override
  late final GeneratedColumn<String> accountProvider = GeneratedColumn<String>(
      'account_provider', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _signedOutMeta =
      const VerificationMeta('signedOut');
  @override
  late final GeneratedColumn<bool> signedOut = GeneratedColumn<bool>(
      'signed_out', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("signed_out" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _manualResultsMeta =
      const VerificationMeta('manualResults');
  @override
  late final GeneratedColumn<String> manualResults = GeneratedColumn<String>(
      'manual_results', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('target'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        displayName,
        activeWorkspaceId,
        accountId,
        accountProvider,
        version,
        isActive,
        signedOut,
        manualResults,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<Profile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('active_workspace_id')) {
      context.handle(
          _activeWorkspaceIdMeta,
          activeWorkspaceId.isAcceptableOrUnknown(
              data['active_workspace_id']!, _activeWorkspaceIdMeta));
    } else if (isInserting) {
      context.missing(_activeWorkspaceIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('account_provider')) {
      context.handle(
          _accountProviderMeta,
          accountProvider.isAcceptableOrUnknown(
              data['account_provider']!, _accountProviderMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('signed_out')) {
      context.handle(_signedOutMeta,
          signedOut.isAcceptableOrUnknown(data['signed_out']!, _signedOutMeta));
    }
    if (data.containsKey('manual_results')) {
      context.handle(
          _manualResultsMeta,
          manualResults.isAcceptableOrUnknown(
              data['manual_results']!, _manualResultsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      activeWorkspaceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}active_workspace_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      accountProvider: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}account_provider']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      signedOut: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}signed_out'])!,
      manualResults: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manual_results'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String displayName;
  final String activeWorkspaceId;
  final String? accountId;
  final String? accountProvider;
  final int version;
  final bool isActive;
  final bool signedOut;
  final String manualResults;
  final DateTime createdAt;
  const Profile(
      {required this.id,
      required this.displayName,
      required this.activeWorkspaceId,
      this.accountId,
      this.accountProvider,
      required this.version,
      required this.isActive,
      required this.signedOut,
      required this.manualResults,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['active_workspace_id'] = Variable<String>(activeWorkspaceId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || accountProvider != null) {
      map['account_provider'] = Variable<String>(accountProvider);
    }
    map['version'] = Variable<int>(version);
    map['is_active'] = Variable<bool>(isActive);
    map['signed_out'] = Variable<bool>(signedOut);
    map['manual_results'] = Variable<String>(manualResults);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      activeWorkspaceId: Value(activeWorkspaceId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      accountProvider: accountProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(accountProvider),
      version: Value(version),
      isActive: Value(isActive),
      signedOut: Value(signedOut),
      manualResults: Value(manualResults),
      createdAt: Value(createdAt),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      activeWorkspaceId: serializer.fromJson<String>(json['activeWorkspaceId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      accountProvider: serializer.fromJson<String?>(json['accountProvider']),
      version: serializer.fromJson<int>(json['version']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      signedOut: serializer.fromJson<bool>(json['signedOut']),
      manualResults: serializer.fromJson<String>(json['manualResults']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'activeWorkspaceId': serializer.toJson<String>(activeWorkspaceId),
      'accountId': serializer.toJson<String?>(accountId),
      'accountProvider': serializer.toJson<String?>(accountProvider),
      'version': serializer.toJson<int>(version),
      'isActive': serializer.toJson<bool>(isActive),
      'signedOut': serializer.toJson<bool>(signedOut),
      'manualResults': serializer.toJson<String>(manualResults),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Profile copyWith(
          {String? id,
          String? displayName,
          String? activeWorkspaceId,
          Value<String?> accountId = const Value.absent(),
          Value<String?> accountProvider = const Value.absent(),
          int? version,
          bool? isActive,
          bool? signedOut,
          String? manualResults,
          DateTime? createdAt}) =>
      Profile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        activeWorkspaceId: activeWorkspaceId ?? this.activeWorkspaceId,
        accountId: accountId.present ? accountId.value : this.accountId,
        accountProvider: accountProvider.present
            ? accountProvider.value
            : this.accountProvider,
        version: version ?? this.version,
        isActive: isActive ?? this.isActive,
        signedOut: signedOut ?? this.signedOut,
        manualResults: manualResults ?? this.manualResults,
        createdAt: createdAt ?? this.createdAt,
      );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      activeWorkspaceId: data.activeWorkspaceId.present
          ? data.activeWorkspaceId.value
          : this.activeWorkspaceId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      accountProvider: data.accountProvider.present
          ? data.accountProvider.value
          : this.accountProvider,
      version: data.version.present ? data.version.value : this.version,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      signedOut: data.signedOut.present ? data.signedOut.value : this.signedOut,
      manualResults: data.manualResults.present
          ? data.manualResults.value
          : this.manualResults,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('activeWorkspaceId: $activeWorkspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('accountProvider: $accountProvider, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('signedOut: $signedOut, ')
          ..write('manualResults: $manualResults, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, activeWorkspaceId, accountId,
      accountProvider, version, isActive, signedOut, manualResults, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.activeWorkspaceId == this.activeWorkspaceId &&
          other.accountId == this.accountId &&
          other.accountProvider == this.accountProvider &&
          other.version == this.version &&
          other.isActive == this.isActive &&
          other.signedOut == this.signedOut &&
          other.manualResults == this.manualResults &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> activeWorkspaceId;
  final Value<String?> accountId;
  final Value<String?> accountProvider;
  final Value<int> version;
  final Value<bool> isActive;
  final Value<bool> signedOut;
  final Value<String> manualResults;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.activeWorkspaceId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.accountProvider = const Value.absent(),
    this.version = const Value.absent(),
    this.isActive = const Value.absent(),
    this.signedOut = const Value.absent(),
    this.manualResults = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    required String activeWorkspaceId,
    this.accountId = const Value.absent(),
    this.accountProvider = const Value.absent(),
    this.version = const Value.absent(),
    this.isActive = const Value.absent(),
    this.signedOut = const Value.absent(),
    this.manualResults = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        activeWorkspaceId = Value(activeWorkspaceId),
        createdAt = Value(createdAt);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? activeWorkspaceId,
    Expression<String>? accountId,
    Expression<String>? accountProvider,
    Expression<int>? version,
    Expression<bool>? isActive,
    Expression<bool>? signedOut,
    Expression<String>? manualResults,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (activeWorkspaceId != null) 'active_workspace_id': activeWorkspaceId,
      if (accountId != null) 'account_id': accountId,
      if (accountProvider != null) 'account_provider': accountProvider,
      if (version != null) 'version': version,
      if (isActive != null) 'is_active': isActive,
      if (signedOut != null) 'signed_out': signedOut,
      if (manualResults != null) 'manual_results': manualResults,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<String>? activeWorkspaceId,
      Value<String?>? accountId,
      Value<String?>? accountProvider,
      Value<int>? version,
      Value<bool>? isActive,
      Value<bool>? signedOut,
      Value<String>? manualResults,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      activeWorkspaceId: activeWorkspaceId ?? this.activeWorkspaceId,
      accountId: accountId ?? this.accountId,
      accountProvider: accountProvider ?? this.accountProvider,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      signedOut: signedOut ?? this.signedOut,
      manualResults: manualResults ?? this.manualResults,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (activeWorkspaceId.present) {
      map['active_workspace_id'] = Variable<String>(activeWorkspaceId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (accountProvider.present) {
      map['account_provider'] = Variable<String>(accountProvider.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (signedOut.present) {
      map['signed_out'] = Variable<bool>(signedOut.value);
    }
    if (manualResults.present) {
      map['manual_results'] = Variable<String>(manualResults.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('activeWorkspaceId: $activeWorkspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('accountProvider: $accountProvider, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('signedOut: $signedOut, ')
          ..write('manualResults: $manualResults, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, Workspace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leaveRuleMeta =
      const VerificationMeta('leaveRule');
  @override
  late final GeneratedColumn<String> leaveRule = GeneratedColumn<String>(
      'leave_rule', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exportRuleMeta =
      const VerificationMeta('exportRule');
  @override
  late final GeneratedColumn<String> exportRule = GeneratedColumn<String>(
      'export_rule', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _inviteDefaultMeta =
      const VerificationMeta('inviteDefault');
  @override
  late final GeneratedColumn<String> inviteDefault = GeneratedColumn<String>(
      'invite_default', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rulesChangedAtMeta =
      const VerificationMeta('rulesChangedAt');
  @override
  late final GeneratedColumn<DateTime> rulesChangedAt =
      GeneratedColumn<DateTime>('rules_changed_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _rulesSeenAtMeta =
      const VerificationMeta('rulesSeenAt');
  @override
  late final GeneratedColumn<DateTime> rulesSeenAt = GeneratedColumn<DateTime>(
      'rules_seen_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _leftAtMeta = const VerificationMeta('leftAt');
  @override
  late final GeneratedColumn<DateTime> leftAt = GeneratedColumn<DateTime>(
      'left_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _leftKeepMeta =
      const VerificationMeta('leftKeep');
  @override
  late final GeneratedColumn<String> leftKeep = GeneratedColumn<String>(
      'left_keep', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        kind,
        ownerId,
        createdAt,
        name,
        leaveRule,
        exportRule,
        inviteDefault,
        rulesChangedAt,
        rulesSeenAt,
        leftAt,
        leftKeep
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(Insertable<Workspace> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('leave_rule')) {
      context.handle(_leaveRuleMeta,
          leaveRule.isAcceptableOrUnknown(data['leave_rule']!, _leaveRuleMeta));
    }
    if (data.containsKey('export_rule')) {
      context.handle(
          _exportRuleMeta,
          exportRule.isAcceptableOrUnknown(
              data['export_rule']!, _exportRuleMeta));
    }
    if (data.containsKey('invite_default')) {
      context.handle(
          _inviteDefaultMeta,
          inviteDefault.isAcceptableOrUnknown(
              data['invite_default']!, _inviteDefaultMeta));
    }
    if (data.containsKey('rules_changed_at')) {
      context.handle(
          _rulesChangedAtMeta,
          rulesChangedAt.isAcceptableOrUnknown(
              data['rules_changed_at']!, _rulesChangedAtMeta));
    }
    if (data.containsKey('rules_seen_at')) {
      context.handle(
          _rulesSeenAtMeta,
          rulesSeenAt.isAcceptableOrUnknown(
              data['rules_seen_at']!, _rulesSeenAtMeta));
    }
    if (data.containsKey('left_at')) {
      context.handle(_leftAtMeta,
          leftAt.isAcceptableOrUnknown(data['left_at']!, _leftAtMeta));
    }
    if (data.containsKey('left_keep')) {
      context.handle(_leftKeepMeta,
          leftKeep.isAcceptableOrUnknown(data['left_keep']!, _leftKeepMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workspace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workspace(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      leaveRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}leave_rule']),
      exportRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}export_rule']),
      inviteDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invite_default']),
      rulesChangedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}rules_changed_at']),
      rulesSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}rules_seen_at']),
      leftAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}left_at']),
      leftKeep: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}left_keep']),
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class Workspace extends DataClass implements Insertable<Workspace> {
  final String id;
  final String kind;
  final String ownerId;
  final DateTime createdAt;
  final String? name;
  final String? leaveRule;
  final String? exportRule;
  final String? inviteDefault;
  final DateTime? rulesChangedAt;
  final DateTime? rulesSeenAt;
  final DateTime? leftAt;
  final String? leftKeep;
  const Workspace(
      {required this.id,
      required this.kind,
      required this.ownerId,
      required this.createdAt,
      this.name,
      this.leaveRule,
      this.exportRule,
      this.inviteDefault,
      this.rulesChangedAt,
      this.rulesSeenAt,
      this.leftAt,
      this.leftKeep});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['owner_id'] = Variable<String>(ownerId);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || leaveRule != null) {
      map['leave_rule'] = Variable<String>(leaveRule);
    }
    if (!nullToAbsent || exportRule != null) {
      map['export_rule'] = Variable<String>(exportRule);
    }
    if (!nullToAbsent || inviteDefault != null) {
      map['invite_default'] = Variable<String>(inviteDefault);
    }
    if (!nullToAbsent || rulesChangedAt != null) {
      map['rules_changed_at'] = Variable<DateTime>(rulesChangedAt);
    }
    if (!nullToAbsent || rulesSeenAt != null) {
      map['rules_seen_at'] = Variable<DateTime>(rulesSeenAt);
    }
    if (!nullToAbsent || leftAt != null) {
      map['left_at'] = Variable<DateTime>(leftAt);
    }
    if (!nullToAbsent || leftKeep != null) {
      map['left_keep'] = Variable<String>(leftKeep);
    }
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      kind: Value(kind),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      leaveRule: leaveRule == null && nullToAbsent
          ? const Value.absent()
          : Value(leaveRule),
      exportRule: exportRule == null && nullToAbsent
          ? const Value.absent()
          : Value(exportRule),
      inviteDefault: inviteDefault == null && nullToAbsent
          ? const Value.absent()
          : Value(inviteDefault),
      rulesChangedAt: rulesChangedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(rulesChangedAt),
      rulesSeenAt: rulesSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(rulesSeenAt),
      leftAt:
          leftAt == null && nullToAbsent ? const Value.absent() : Value(leftAt),
      leftKeep: leftKeep == null && nullToAbsent
          ? const Value.absent()
          : Value(leftKeep),
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workspace(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      name: serializer.fromJson<String?>(json['name']),
      leaveRule: serializer.fromJson<String?>(json['leaveRule']),
      exportRule: serializer.fromJson<String?>(json['exportRule']),
      inviteDefault: serializer.fromJson<String?>(json['inviteDefault']),
      rulesChangedAt: serializer.fromJson<DateTime?>(json['rulesChangedAt']),
      rulesSeenAt: serializer.fromJson<DateTime?>(json['rulesSeenAt']),
      leftAt: serializer.fromJson<DateTime?>(json['leftAt']),
      leftKeep: serializer.fromJson<String?>(json['leftKeep']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'ownerId': serializer.toJson<String>(ownerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'name': serializer.toJson<String?>(name),
      'leaveRule': serializer.toJson<String?>(leaveRule),
      'exportRule': serializer.toJson<String?>(exportRule),
      'inviteDefault': serializer.toJson<String?>(inviteDefault),
      'rulesChangedAt': serializer.toJson<DateTime?>(rulesChangedAt),
      'rulesSeenAt': serializer.toJson<DateTime?>(rulesSeenAt),
      'leftAt': serializer.toJson<DateTime?>(leftAt),
      'leftKeep': serializer.toJson<String?>(leftKeep),
    };
  }

  Workspace copyWith(
          {String? id,
          String? kind,
          String? ownerId,
          DateTime? createdAt,
          Value<String?> name = const Value.absent(),
          Value<String?> leaveRule = const Value.absent(),
          Value<String?> exportRule = const Value.absent(),
          Value<String?> inviteDefault = const Value.absent(),
          Value<DateTime?> rulesChangedAt = const Value.absent(),
          Value<DateTime?> rulesSeenAt = const Value.absent(),
          Value<DateTime?> leftAt = const Value.absent(),
          Value<String?> leftKeep = const Value.absent()}) =>
      Workspace(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        ownerId: ownerId ?? this.ownerId,
        createdAt: createdAt ?? this.createdAt,
        name: name.present ? name.value : this.name,
        leaveRule: leaveRule.present ? leaveRule.value : this.leaveRule,
        exportRule: exportRule.present ? exportRule.value : this.exportRule,
        inviteDefault:
            inviteDefault.present ? inviteDefault.value : this.inviteDefault,
        rulesChangedAt:
            rulesChangedAt.present ? rulesChangedAt.value : this.rulesChangedAt,
        rulesSeenAt: rulesSeenAt.present ? rulesSeenAt.value : this.rulesSeenAt,
        leftAt: leftAt.present ? leftAt.value : this.leftAt,
        leftKeep: leftKeep.present ? leftKeep.value : this.leftKeep,
      );
  Workspace copyWithCompanion(WorkspacesCompanion data) {
    return Workspace(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      name: data.name.present ? data.name.value : this.name,
      leaveRule: data.leaveRule.present ? data.leaveRule.value : this.leaveRule,
      exportRule:
          data.exportRule.present ? data.exportRule.value : this.exportRule,
      inviteDefault: data.inviteDefault.present
          ? data.inviteDefault.value
          : this.inviteDefault,
      rulesChangedAt: data.rulesChangedAt.present
          ? data.rulesChangedAt.value
          : this.rulesChangedAt,
      rulesSeenAt:
          data.rulesSeenAt.present ? data.rulesSeenAt.value : this.rulesSeenAt,
      leftAt: data.leftAt.present ? data.leftAt.value : this.leftAt,
      leftKeep: data.leftKeep.present ? data.leftKeep.value : this.leftKeep,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workspace(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('leaveRule: $leaveRule, ')
          ..write('exportRule: $exportRule, ')
          ..write('inviteDefault: $inviteDefault, ')
          ..write('rulesChangedAt: $rulesChangedAt, ')
          ..write('rulesSeenAt: $rulesSeenAt, ')
          ..write('leftAt: $leftAt, ')
          ..write('leftKeep: $leftKeep')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, ownerId, createdAt, name, leaveRule,
      exportRule, inviteDefault, rulesChangedAt, rulesSeenAt, leftAt, leftKeep);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.ownerId == this.ownerId &&
          other.createdAt == this.createdAt &&
          other.name == this.name &&
          other.leaveRule == this.leaveRule &&
          other.exportRule == this.exportRule &&
          other.inviteDefault == this.inviteDefault &&
          other.rulesChangedAt == this.rulesChangedAt &&
          other.rulesSeenAt == this.rulesSeenAt &&
          other.leftAt == this.leftAt &&
          other.leftKeep == this.leftKeep);
}

class WorkspacesCompanion extends UpdateCompanion<Workspace> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> ownerId;
  final Value<DateTime> createdAt;
  final Value<String?> name;
  final Value<String?> leaveRule;
  final Value<String?> exportRule;
  final Value<String?> inviteDefault;
  final Value<DateTime?> rulesChangedAt;
  final Value<DateTime?> rulesSeenAt;
  final Value<DateTime?> leftAt;
  final Value<String?> leftKeep;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.name = const Value.absent(),
    this.leaveRule = const Value.absent(),
    this.exportRule = const Value.absent(),
    this.inviteDefault = const Value.absent(),
    this.rulesChangedAt = const Value.absent(),
    this.rulesSeenAt = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.leftKeep = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    this.kind = const Value.absent(),
    required String ownerId,
    required DateTime createdAt,
    this.name = const Value.absent(),
    this.leaveRule = const Value.absent(),
    this.exportRule = const Value.absent(),
    this.inviteDefault = const Value.absent(),
    this.rulesChangedAt = const Value.absent(),
    this.rulesSeenAt = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.leftKeep = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt);
  static Insertable<Workspace> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? ownerId,
    Expression<DateTime>? createdAt,
    Expression<String>? name,
    Expression<String>? leaveRule,
    Expression<String>? exportRule,
    Expression<String>? inviteDefault,
    Expression<DateTime>? rulesChangedAt,
    Expression<DateTime>? rulesSeenAt,
    Expression<DateTime>? leftAt,
    Expression<String>? leftKeep,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt,
      if (name != null) 'name': name,
      if (leaveRule != null) 'leave_rule': leaveRule,
      if (exportRule != null) 'export_rule': exportRule,
      if (inviteDefault != null) 'invite_default': inviteDefault,
      if (rulesChangedAt != null) 'rules_changed_at': rulesChangedAt,
      if (rulesSeenAt != null) 'rules_seen_at': rulesSeenAt,
      if (leftAt != null) 'left_at': leftAt,
      if (leftKeep != null) 'left_keep': leftKeep,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String>? ownerId,
      Value<DateTime>? createdAt,
      Value<String?>? name,
      Value<String?>? leaveRule,
      Value<String?>? exportRule,
      Value<String?>? inviteDefault,
      Value<DateTime?>? rulesChangedAt,
      Value<DateTime?>? rulesSeenAt,
      Value<DateTime?>? leftAt,
      Value<String?>? leftKeep,
      Value<int>? rowid}) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      leaveRule: leaveRule ?? this.leaveRule,
      exportRule: exportRule ?? this.exportRule,
      inviteDefault: inviteDefault ?? this.inviteDefault,
      rulesChangedAt: rulesChangedAt ?? this.rulesChangedAt,
      rulesSeenAt: rulesSeenAt ?? this.rulesSeenAt,
      leftAt: leftAt ?? this.leftAt,
      leftKeep: leftKeep ?? this.leftKeep,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (leaveRule.present) {
      map['leave_rule'] = Variable<String>(leaveRule.value);
    }
    if (exportRule.present) {
      map['export_rule'] = Variable<String>(exportRule.value);
    }
    if (inviteDefault.present) {
      map['invite_default'] = Variable<String>(inviteDefault.value);
    }
    if (rulesChangedAt.present) {
      map['rules_changed_at'] = Variable<DateTime>(rulesChangedAt.value);
    }
    if (rulesSeenAt.present) {
      map['rules_seen_at'] = Variable<DateTime>(rulesSeenAt.value);
    }
    if (leftAt.present) {
      map['left_at'] = Variable<DateTime>(leftAt.value);
    }
    if (leftKeep.present) {
      map['left_keep'] = Variable<String>(leftKeep.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('leaveRule: $leaveRule, ')
          ..write('exportRule: $exportRule, ')
          ..write('inviteDefault: $inviteDefault, ')
          ..write('rulesChangedAt: $rulesChangedAt, ')
          ..write('rulesSeenAt: $rulesSeenAt, ')
          ..write('leftAt: $leftAt, ')
          ..write('leftKeep: $leftKeep, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskListsTable extends TaskLists
    with TableInfo<$TaskListsTable, TaskList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorIndexMeta =
      const VerificationMeta('colorIndex');
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
      'color_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _orderKeyMeta =
      const VerificationMeta('orderKey');
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
      'order_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('a0'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        title,
        colorIndex,
        orderKey
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_lists';
  @override
  VerificationContext validateIntegrity(Insertable<TaskList> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
          _colorIndexMeta,
          colorIndex.isAcceptableOrUnknown(
              data['color_index']!, _colorIndexMeta));
    }
    if (data.containsKey('order_key')) {
      context.handle(_orderKeyMeta,
          orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskList(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      colorIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_index']),
      orderKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_key'])!,
    );
  }

  @override
  $TaskListsTable createAlias(String alias) {
    return $TaskListsTable(attachedDatabase, alias);
  }
}

class TaskList extends DataClass implements Insertable<TaskList> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String title;
  final int? colorIndex;
  final String orderKey;
  const TaskList(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.title,
      this.colorIndex,
      required this.orderKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || colorIndex != null) {
      map['color_index'] = Variable<int>(colorIndex);
    }
    map['order_key'] = Variable<String>(orderKey);
    return map;
  }

  TaskListsCompanion toCompanion(bool nullToAbsent) {
    return TaskListsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      title: Value(title),
      colorIndex: colorIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorIndex),
      orderKey: Value(orderKey),
    );
  }

  factory TaskList.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskList(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      title: serializer.fromJson<String>(json['title']),
      colorIndex: serializer.fromJson<int?>(json['colorIndex']),
      orderKey: serializer.fromJson<String>(json['orderKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'title': serializer.toJson<String>(title),
      'colorIndex': serializer.toJson<int?>(colorIndex),
      'orderKey': serializer.toJson<String>(orderKey),
    };
  }

  TaskList copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? title,
          Value<int?> colorIndex = const Value.absent(),
          String? orderKey}) =>
      TaskList(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        title: title ?? this.title,
        colorIndex: colorIndex.present ? colorIndex.value : this.colorIndex,
        orderKey: orderKey ?? this.orderKey,
      );
  TaskList copyWithCompanion(TaskListsCompanion data) {
    return TaskList(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      title: data.title.present ? data.title.value : this.title,
      colorIndex:
          data.colorIndex.present ? data.colorIndex.value : this.colorIndex,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskList(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, ownerId, version, createdAt,
      updatedAt, deletedAt, deletedBy, changedBy, title, colorIndex, orderKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskList &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.title == this.title &&
          other.colorIndex == this.colorIndex &&
          other.orderKey == this.orderKey);
}

class TaskListsCompanion extends UpdateCompanion<TaskList> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> title;
  final Value<int?> colorIndex;
  final Value<String> orderKey;
  final Value<int> rowid;
  const TaskListsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.title = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskListsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String title,
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        title = Value(title);
  static Insertable<TaskList> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? title,
    Expression<int>? colorIndex,
    Expression<String>? orderKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (title != null) 'title': title,
      if (colorIndex != null) 'color_index': colorIndex,
      if (orderKey != null) 'order_key': orderKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskListsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? title,
      Value<int?>? colorIndex,
      Value<String>? orderKey,
      Value<int>? rowid}) {
    return TaskListsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      title: title ?? this.title,
      colorIndex: colorIndex ?? this.colorIndex,
      orderKey: orderKey ?? this.orderKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskListsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('inbox'));
  static const VerificationMeta _isImportantMeta =
      const VerificationMeta('isImportant');
  @override
  late final GeneratedColumn<bool> isImportant = GeneratedColumn<bool>(
      'is_important', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_important" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _taskListIdMeta =
      const VerificationMeta('taskListId');
  @override
  late final GeneratedColumn<String> taskListId = GeneratedColumn<String>(
      'task_list_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentTaskIdMeta =
      const VerificationMeta('parentTaskId');
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
      'parent_task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _targetTypeMeta =
      const VerificationMeta('targetType');
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
      'target_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _targetMinMeta =
      const VerificationMeta('targetMin');
  @override
  late final GeneratedColumn<double> targetMin = GeneratedColumn<double>(
      'target_min', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _targetMaxMeta =
      const VerificationMeta('targetMax');
  @override
  late final GeneratedColumn<double> targetMax = GeneratedColumn<double>(
      'target_max', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _completionPolicyMeta =
      const VerificationMeta('completionPolicy');
  @override
  late final GeneratedColumn<String> completionPolicy = GeneratedColumn<String>(
      'completion_policy', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _targetAggregationMeta =
      const VerificationMeta('targetAggregation');
  @override
  late final GeneratedColumn<String> targetAggregation =
      GeneratedColumn<String>('target_aggregation', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('sum'));
  static const VerificationMeta _isHabitMeta =
      const VerificationMeta('isHabit');
  @override
  late final GeneratedColumn<bool> isHabit = GeneratedColumn<bool>(
      'is_habit', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_habit" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _trackedSinceMeta =
      const VerificationMeta('trackedSince');
  @override
  late final GeneratedColumn<String> trackedSince = GeneratedColumn<String>(
      'tracked_since', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorIndexMeta =
      const VerificationMeta('colorIndex');
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
      'color_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _orderKeyMeta =
      const VerificationMeta('orderKey');
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
      'order_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('a0'));
  static const VerificationMeta _assigneeIdMeta =
      const VerificationMeta('assigneeId');
  @override
  late final GeneratedColumn<String> assigneeId = GeneratedColumn<String>(
      'assignee_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        title,
        status,
        isImportant,
        taskListId,
        parentTaskId,
        sortOrder,
        targetType,
        targetMin,
        targetMax,
        unit,
        completionPolicy,
        targetAggregation,
        isHabit,
        trackedSince,
        tags,
        notes,
        colorIndex,
        orderKey,
        assigneeId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(Insertable<Task> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('is_important')) {
      context.handle(
          _isImportantMeta,
          isImportant.isAcceptableOrUnknown(
              data['is_important']!, _isImportantMeta));
    }
    if (data.containsKey('task_list_id')) {
      context.handle(
          _taskListIdMeta,
          taskListId.isAcceptableOrUnknown(
              data['task_list_id']!, _taskListIdMeta));
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
          _parentTaskIdMeta,
          parentTaskId.isAcceptableOrUnknown(
              data['parent_task_id']!, _parentTaskIdMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('target_type')) {
      context.handle(
          _targetTypeMeta,
          targetType.isAcceptableOrUnknown(
              data['target_type']!, _targetTypeMeta));
    }
    if (data.containsKey('target_min')) {
      context.handle(_targetMinMeta,
          targetMin.isAcceptableOrUnknown(data['target_min']!, _targetMinMeta));
    }
    if (data.containsKey('target_max')) {
      context.handle(_targetMaxMeta,
          targetMax.isAcceptableOrUnknown(data['target_max']!, _targetMaxMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('completion_policy')) {
      context.handle(
          _completionPolicyMeta,
          completionPolicy.isAcceptableOrUnknown(
              data['completion_policy']!, _completionPolicyMeta));
    }
    if (data.containsKey('target_aggregation')) {
      context.handle(
          _targetAggregationMeta,
          targetAggregation.isAcceptableOrUnknown(
              data['target_aggregation']!, _targetAggregationMeta));
    }
    if (data.containsKey('is_habit')) {
      context.handle(_isHabitMeta,
          isHabit.isAcceptableOrUnknown(data['is_habit']!, _isHabitMeta));
    }
    if (data.containsKey('tracked_since')) {
      context.handle(
          _trackedSinceMeta,
          trackedSince.isAcceptableOrUnknown(
              data['tracked_since']!, _trackedSinceMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('color_index')) {
      context.handle(
          _colorIndexMeta,
          colorIndex.isAcceptableOrUnknown(
              data['color_index']!, _colorIndexMeta));
    }
    if (data.containsKey('order_key')) {
      context.handle(_orderKeyMeta,
          orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta));
    }
    if (data.containsKey('assignee_id')) {
      context.handle(
          _assigneeIdMeta,
          assigneeId.isAcceptableOrUnknown(
              data['assignee_id']!, _assigneeIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      isImportant: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_important'])!,
      taskListId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_list_id']),
      parentTaskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_task_id']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      targetType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_type']),
      targetMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_min']),
      targetMax: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_max']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      completionPolicy: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}completion_policy'])!,
      targetAggregation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}target_aggregation'])!,
      isHabit: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_habit'])!,
      trackedSince: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tracked_since']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      colorIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_index']),
      orderKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_key'])!,
      assigneeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assignee_id']),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String title;
  final String status;
  final bool isImportant;
  final String? taskListId;
  final String? parentTaskId;
  final int sortOrder;
  final String? targetType;
  final double? targetMin;
  final double? targetMax;
  final String? unit;
  final String completionPolicy;
  final String targetAggregation;
  final bool isHabit;
  final String? trackedSince;
  final String tags;
  final String? notes;
  final int? colorIndex;
  final String orderKey;
  final String? assigneeId;
  const Task(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.title,
      required this.status,
      required this.isImportant,
      this.taskListId,
      this.parentTaskId,
      required this.sortOrder,
      this.targetType,
      this.targetMin,
      this.targetMax,
      this.unit,
      required this.completionPolicy,
      required this.targetAggregation,
      required this.isHabit,
      this.trackedSince,
      required this.tags,
      this.notes,
      this.colorIndex,
      required this.orderKey,
      this.assigneeId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['is_important'] = Variable<bool>(isImportant);
    if (!nullToAbsent || taskListId != null) {
      map['task_list_id'] = Variable<String>(taskListId);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || targetType != null) {
      map['target_type'] = Variable<String>(targetType);
    }
    if (!nullToAbsent || targetMin != null) {
      map['target_min'] = Variable<double>(targetMin);
    }
    if (!nullToAbsent || targetMax != null) {
      map['target_max'] = Variable<double>(targetMax);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['completion_policy'] = Variable<String>(completionPolicy);
    map['target_aggregation'] = Variable<String>(targetAggregation);
    map['is_habit'] = Variable<bool>(isHabit);
    if (!nullToAbsent || trackedSince != null) {
      map['tracked_since'] = Variable<String>(trackedSince);
    }
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || colorIndex != null) {
      map['color_index'] = Variable<int>(colorIndex);
    }
    map['order_key'] = Variable<String>(orderKey);
    if (!nullToAbsent || assigneeId != null) {
      map['assignee_id'] = Variable<String>(assigneeId);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      title: Value(title),
      status: Value(status),
      isImportant: Value(isImportant),
      taskListId: taskListId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskListId),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      sortOrder: Value(sortOrder),
      targetType: targetType == null && nullToAbsent
          ? const Value.absent()
          : Value(targetType),
      targetMin: targetMin == null && nullToAbsent
          ? const Value.absent()
          : Value(targetMin),
      targetMax: targetMax == null && nullToAbsent
          ? const Value.absent()
          : Value(targetMax),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      completionPolicy: Value(completionPolicy),
      targetAggregation: Value(targetAggregation),
      isHabit: Value(isHabit),
      trackedSince: trackedSince == null && nullToAbsent
          ? const Value.absent()
          : Value(trackedSince),
      tags: Value(tags),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      colorIndex: colorIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorIndex),
      orderKey: Value(orderKey),
      assigneeId: assigneeId == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeId),
    );
  }

  factory Task.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      isImportant: serializer.fromJson<bool>(json['isImportant']),
      taskListId: serializer.fromJson<String?>(json['taskListId']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      targetType: serializer.fromJson<String?>(json['targetType']),
      targetMin: serializer.fromJson<double?>(json['targetMin']),
      targetMax: serializer.fromJson<double?>(json['targetMax']),
      unit: serializer.fromJson<String?>(json['unit']),
      completionPolicy: serializer.fromJson<String>(json['completionPolicy']),
      targetAggregation: serializer.fromJson<String>(json['targetAggregation']),
      isHabit: serializer.fromJson<bool>(json['isHabit']),
      trackedSince: serializer.fromJson<String?>(json['trackedSince']),
      tags: serializer.fromJson<String>(json['tags']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorIndex: serializer.fromJson<int?>(json['colorIndex']),
      orderKey: serializer.fromJson<String>(json['orderKey']),
      assigneeId: serializer.fromJson<String?>(json['assigneeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'isImportant': serializer.toJson<bool>(isImportant),
      'taskListId': serializer.toJson<String?>(taskListId),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'targetType': serializer.toJson<String?>(targetType),
      'targetMin': serializer.toJson<double?>(targetMin),
      'targetMax': serializer.toJson<double?>(targetMax),
      'unit': serializer.toJson<String?>(unit),
      'completionPolicy': serializer.toJson<String>(completionPolicy),
      'targetAggregation': serializer.toJson<String>(targetAggregation),
      'isHabit': serializer.toJson<bool>(isHabit),
      'trackedSince': serializer.toJson<String?>(trackedSince),
      'tags': serializer.toJson<String>(tags),
      'notes': serializer.toJson<String?>(notes),
      'colorIndex': serializer.toJson<int?>(colorIndex),
      'orderKey': serializer.toJson<String>(orderKey),
      'assigneeId': serializer.toJson<String?>(assigneeId),
    };
  }

  Task copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? title,
          String? status,
          bool? isImportant,
          Value<String?> taskListId = const Value.absent(),
          Value<String?> parentTaskId = const Value.absent(),
          int? sortOrder,
          Value<String?> targetType = const Value.absent(),
          Value<double?> targetMin = const Value.absent(),
          Value<double?> targetMax = const Value.absent(),
          Value<String?> unit = const Value.absent(),
          String? completionPolicy,
          String? targetAggregation,
          bool? isHabit,
          Value<String?> trackedSince = const Value.absent(),
          String? tags,
          Value<String?> notes = const Value.absent(),
          Value<int?> colorIndex = const Value.absent(),
          String? orderKey,
          Value<String?> assigneeId = const Value.absent()}) =>
      Task(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        title: title ?? this.title,
        status: status ?? this.status,
        isImportant: isImportant ?? this.isImportant,
        taskListId: taskListId.present ? taskListId.value : this.taskListId,
        parentTaskId:
            parentTaskId.present ? parentTaskId.value : this.parentTaskId,
        sortOrder: sortOrder ?? this.sortOrder,
        targetType: targetType.present ? targetType.value : this.targetType,
        targetMin: targetMin.present ? targetMin.value : this.targetMin,
        targetMax: targetMax.present ? targetMax.value : this.targetMax,
        unit: unit.present ? unit.value : this.unit,
        completionPolicy: completionPolicy ?? this.completionPolicy,
        targetAggregation: targetAggregation ?? this.targetAggregation,
        isHabit: isHabit ?? this.isHabit,
        trackedSince:
            trackedSince.present ? trackedSince.value : this.trackedSince,
        tags: tags ?? this.tags,
        notes: notes.present ? notes.value : this.notes,
        colorIndex: colorIndex.present ? colorIndex.value : this.colorIndex,
        orderKey: orderKey ?? this.orderKey,
        assigneeId: assigneeId.present ? assigneeId.value : this.assigneeId,
      );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      isImportant:
          data.isImportant.present ? data.isImportant.value : this.isImportant,
      taskListId:
          data.taskListId.present ? data.taskListId.value : this.taskListId,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      targetType:
          data.targetType.present ? data.targetType.value : this.targetType,
      targetMin: data.targetMin.present ? data.targetMin.value : this.targetMin,
      targetMax: data.targetMax.present ? data.targetMax.value : this.targetMax,
      unit: data.unit.present ? data.unit.value : this.unit,
      completionPolicy: data.completionPolicy.present
          ? data.completionPolicy.value
          : this.completionPolicy,
      targetAggregation: data.targetAggregation.present
          ? data.targetAggregation.value
          : this.targetAggregation,
      isHabit: data.isHabit.present ? data.isHabit.value : this.isHabit,
      trackedSince: data.trackedSince.present
          ? data.trackedSince.value
          : this.trackedSince,
      tags: data.tags.present ? data.tags.value : this.tags,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorIndex:
          data.colorIndex.present ? data.colorIndex.value : this.colorIndex,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
      assigneeId:
          data.assigneeId.present ? data.assigneeId.value : this.assigneeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('isImportant: $isImportant, ')
          ..write('taskListId: $taskListId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('targetType: $targetType, ')
          ..write('targetMin: $targetMin, ')
          ..write('targetMax: $targetMax, ')
          ..write('unit: $unit, ')
          ..write('completionPolicy: $completionPolicy, ')
          ..write('targetAggregation: $targetAggregation, ')
          ..write('isHabit: $isHabit, ')
          ..write('trackedSince: $trackedSince, ')
          ..write('tags: $tags, ')
          ..write('notes: $notes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey, ')
          ..write('assigneeId: $assigneeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        title,
        status,
        isImportant,
        taskListId,
        parentTaskId,
        sortOrder,
        targetType,
        targetMin,
        targetMax,
        unit,
        completionPolicy,
        targetAggregation,
        isHabit,
        trackedSince,
        tags,
        notes,
        colorIndex,
        orderKey,
        assigneeId
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.title == this.title &&
          other.status == this.status &&
          other.isImportant == this.isImportant &&
          other.taskListId == this.taskListId &&
          other.parentTaskId == this.parentTaskId &&
          other.sortOrder == this.sortOrder &&
          other.targetType == this.targetType &&
          other.targetMin == this.targetMin &&
          other.targetMax == this.targetMax &&
          other.unit == this.unit &&
          other.completionPolicy == this.completionPolicy &&
          other.targetAggregation == this.targetAggregation &&
          other.isHabit == this.isHabit &&
          other.trackedSince == this.trackedSince &&
          other.tags == this.tags &&
          other.notes == this.notes &&
          other.colorIndex == this.colorIndex &&
          other.orderKey == this.orderKey &&
          other.assigneeId == this.assigneeId);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> title;
  final Value<String> status;
  final Value<bool> isImportant;
  final Value<String?> taskListId;
  final Value<String?> parentTaskId;
  final Value<int> sortOrder;
  final Value<String?> targetType;
  final Value<double?> targetMin;
  final Value<double?> targetMax;
  final Value<String?> unit;
  final Value<String> completionPolicy;
  final Value<String> targetAggregation;
  final Value<bool> isHabit;
  final Value<String?> trackedSince;
  final Value<String> tags;
  final Value<String?> notes;
  final Value<int?> colorIndex;
  final Value<String> orderKey;
  final Value<String?> assigneeId;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.isImportant = const Value.absent(),
    this.taskListId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetMin = const Value.absent(),
    this.targetMax = const Value.absent(),
    this.unit = const Value.absent(),
    this.completionPolicy = const Value.absent(),
    this.targetAggregation = const Value.absent(),
    this.isHabit = const Value.absent(),
    this.trackedSince = const Value.absent(),
    this.tags = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.assigneeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String title,
    this.status = const Value.absent(),
    this.isImportant = const Value.absent(),
    this.taskListId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetMin = const Value.absent(),
    this.targetMax = const Value.absent(),
    this.unit = const Value.absent(),
    this.completionPolicy = const Value.absent(),
    this.targetAggregation = const Value.absent(),
    this.isHabit = const Value.absent(),
    this.trackedSince = const Value.absent(),
    this.tags = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.assigneeId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        title = Value(title);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? title,
    Expression<String>? status,
    Expression<bool>? isImportant,
    Expression<String>? taskListId,
    Expression<String>? parentTaskId,
    Expression<int>? sortOrder,
    Expression<String>? targetType,
    Expression<double>? targetMin,
    Expression<double>? targetMax,
    Expression<String>? unit,
    Expression<String>? completionPolicy,
    Expression<String>? targetAggregation,
    Expression<bool>? isHabit,
    Expression<String>? trackedSince,
    Expression<String>? tags,
    Expression<String>? notes,
    Expression<int>? colorIndex,
    Expression<String>? orderKey,
    Expression<String>? assigneeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (isImportant != null) 'is_important': isImportant,
      if (taskListId != null) 'task_list_id': taskListId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (targetType != null) 'target_type': targetType,
      if (targetMin != null) 'target_min': targetMin,
      if (targetMax != null) 'target_max': targetMax,
      if (unit != null) 'unit': unit,
      if (completionPolicy != null) 'completion_policy': completionPolicy,
      if (targetAggregation != null) 'target_aggregation': targetAggregation,
      if (isHabit != null) 'is_habit': isHabit,
      if (trackedSince != null) 'tracked_since': trackedSince,
      if (tags != null) 'tags': tags,
      if (notes != null) 'notes': notes,
      if (colorIndex != null) 'color_index': colorIndex,
      if (orderKey != null) 'order_key': orderKey,
      if (assigneeId != null) 'assignee_id': assigneeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? title,
      Value<String>? status,
      Value<bool>? isImportant,
      Value<String?>? taskListId,
      Value<String?>? parentTaskId,
      Value<int>? sortOrder,
      Value<String?>? targetType,
      Value<double?>? targetMin,
      Value<double?>? targetMax,
      Value<String?>? unit,
      Value<String>? completionPolicy,
      Value<String>? targetAggregation,
      Value<bool>? isHabit,
      Value<String?>? trackedSince,
      Value<String>? tags,
      Value<String?>? notes,
      Value<int?>? colorIndex,
      Value<String>? orderKey,
      Value<String?>? assigneeId,
      Value<int>? rowid}) {
    return TasksCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      title: title ?? this.title,
      status: status ?? this.status,
      isImportant: isImportant ?? this.isImportant,
      taskListId: taskListId ?? this.taskListId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      sortOrder: sortOrder ?? this.sortOrder,
      targetType: targetType ?? this.targetType,
      targetMin: targetMin ?? this.targetMin,
      targetMax: targetMax ?? this.targetMax,
      unit: unit ?? this.unit,
      completionPolicy: completionPolicy ?? this.completionPolicy,
      targetAggregation: targetAggregation ?? this.targetAggregation,
      isHabit: isHabit ?? this.isHabit,
      trackedSince: trackedSince ?? this.trackedSince,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      colorIndex: colorIndex ?? this.colorIndex,
      orderKey: orderKey ?? this.orderKey,
      assigneeId: assigneeId ?? this.assigneeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isImportant.present) {
      map['is_important'] = Variable<bool>(isImportant.value);
    }
    if (taskListId.present) {
      map['task_list_id'] = Variable<String>(taskListId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetMin.present) {
      map['target_min'] = Variable<double>(targetMin.value);
    }
    if (targetMax.present) {
      map['target_max'] = Variable<double>(targetMax.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (completionPolicy.present) {
      map['completion_policy'] = Variable<String>(completionPolicy.value);
    }
    if (targetAggregation.present) {
      map['target_aggregation'] = Variable<String>(targetAggregation.value);
    }
    if (isHabit.present) {
      map['is_habit'] = Variable<bool>(isHabit.value);
    }
    if (trackedSince.present) {
      map['tracked_since'] = Variable<String>(trackedSince.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (assigneeId.present) {
      map['assignee_id'] = Variable<String>(assigneeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('isImportant: $isImportant, ')
          ..write('taskListId: $taskListId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('targetType: $targetType, ')
          ..write('targetMin: $targetMin, ')
          ..write('targetMax: $targetMax, ')
          ..write('unit: $unit, ')
          ..write('completionPolicy: $completionPolicy, ')
          ..write('targetAggregation: $targetAggregation, ')
          ..write('isHabit: $isHabit, ')
          ..write('trackedSince: $trackedSince, ')
          ..write('tags: $tags, ')
          ..write('notes: $notes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey, ')
          ..write('assigneeId: $assigneeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogTable extends AuditLog
    with TableInfo<$AuditLogTable, AuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _auditIdMeta =
      const VerificationMeta('auditId');
  @override
  late final GeneratedColumn<String> auditId = GeneratedColumn<String>(
      'audit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
      'actor', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _onBehalfOfMeta =
      const VerificationMeta('onBehalfOf');
  @override
  late final GeneratedColumn<String> onBehalfOf = GeneratedColumn<String>(
      'on_behalf_of', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceTypeMeta =
      const VerificationMeta('resourceType');
  @override
  late final GeneratedColumn<String> resourceType = GeneratedColumn<String>(
      'resource_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceIdMeta =
      const VerificationMeta('resourceId');
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionBeforeMeta =
      const VerificationMeta('versionBefore');
  @override
  late final GeneratedColumn<int> versionBefore = GeneratedColumn<int>(
      'version_before', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _versionAfterMeta =
      const VerificationMeta('versionAfter');
  @override
  late final GeneratedColumn<int> versionAfter = GeneratedColumn<int>(
      'version_after', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
      'at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        auditId,
        operationId,
        actor,
        onBehalfOf,
        action,
        resourceType,
        resourceId,
        versionBefore,
        versionAfter,
        outcome,
        reason,
        at
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audit_id')) {
      context.handle(_auditIdMeta,
          auditId.isAcceptableOrUnknown(data['audit_id']!, _auditIdMeta));
    } else if (isInserting) {
      context.missing(_auditIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('actor')) {
      context.handle(
          _actorMeta, actor.isAcceptableOrUnknown(data['actor']!, _actorMeta));
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('on_behalf_of')) {
      context.handle(
          _onBehalfOfMeta,
          onBehalfOf.isAcceptableOrUnknown(
              data['on_behalf_of']!, _onBehalfOfMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('resource_type')) {
      context.handle(
          _resourceTypeMeta,
          resourceType.isAcceptableOrUnknown(
              data['resource_type']!, _resourceTypeMeta));
    } else if (isInserting) {
      context.missing(_resourceTypeMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
          _resourceIdMeta,
          resourceId.isAcceptableOrUnknown(
              data['resource_id']!, _resourceIdMeta));
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('version_before')) {
      context.handle(
          _versionBeforeMeta,
          versionBefore.isAcceptableOrUnknown(
              data['version_before']!, _versionBeforeMeta));
    }
    if (data.containsKey('version_after')) {
      context.handle(
          _versionAfterMeta,
          versionAfter.isAcceptableOrUnknown(
              data['version_after']!, _versionAfterMeta));
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {auditId};
  @override
  AuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogData(
      auditId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audit_id'])!,
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      actor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor'])!,
      onBehalfOf: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}on_behalf_of']),
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      resourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_type'])!,
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id'])!,
      versionBefore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version_before']),
      versionAfter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version_after']),
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
      at: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
    );
  }

  @override
  $AuditLogTable createAlias(String alias) {
    return $AuditLogTable(attachedDatabase, alias);
  }
}

class AuditLogData extends DataClass implements Insertable<AuditLogData> {
  final String auditId;
  final String operationId;
  final String actor;
  final String? onBehalfOf;
  final String action;
  final String resourceType;
  final String resourceId;
  final int? versionBefore;
  final int? versionAfter;
  final String outcome;
  final String? reason;
  final DateTime at;
  const AuditLogData(
      {required this.auditId,
      required this.operationId,
      required this.actor,
      this.onBehalfOf,
      required this.action,
      required this.resourceType,
      required this.resourceId,
      this.versionBefore,
      this.versionAfter,
      required this.outcome,
      this.reason,
      required this.at});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audit_id'] = Variable<String>(auditId);
    map['operation_id'] = Variable<String>(operationId);
    map['actor'] = Variable<String>(actor);
    if (!nullToAbsent || onBehalfOf != null) {
      map['on_behalf_of'] = Variable<String>(onBehalfOf);
    }
    map['action'] = Variable<String>(action);
    map['resource_type'] = Variable<String>(resourceType);
    map['resource_id'] = Variable<String>(resourceId);
    if (!nullToAbsent || versionBefore != null) {
      map['version_before'] = Variable<int>(versionBefore);
    }
    if (!nullToAbsent || versionAfter != null) {
      map['version_after'] = Variable<int>(versionAfter);
    }
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  AuditLogCompanion toCompanion(bool nullToAbsent) {
    return AuditLogCompanion(
      auditId: Value(auditId),
      operationId: Value(operationId),
      actor: Value(actor),
      onBehalfOf: onBehalfOf == null && nullToAbsent
          ? const Value.absent()
          : Value(onBehalfOf),
      action: Value(action),
      resourceType: Value(resourceType),
      resourceId: Value(resourceId),
      versionBefore: versionBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(versionBefore),
      versionAfter: versionAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(versionAfter),
      outcome: Value(outcome),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
      at: Value(at),
    );
  }

  factory AuditLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogData(
      auditId: serializer.fromJson<String>(json['auditId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      actor: serializer.fromJson<String>(json['actor']),
      onBehalfOf: serializer.fromJson<String?>(json['onBehalfOf']),
      action: serializer.fromJson<String>(json['action']),
      resourceType: serializer.fromJson<String>(json['resourceType']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      versionBefore: serializer.fromJson<int?>(json['versionBefore']),
      versionAfter: serializer.fromJson<int?>(json['versionAfter']),
      outcome: serializer.fromJson<String>(json['outcome']),
      reason: serializer.fromJson<String?>(json['reason']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'auditId': serializer.toJson<String>(auditId),
      'operationId': serializer.toJson<String>(operationId),
      'actor': serializer.toJson<String>(actor),
      'onBehalfOf': serializer.toJson<String?>(onBehalfOf),
      'action': serializer.toJson<String>(action),
      'resourceType': serializer.toJson<String>(resourceType),
      'resourceId': serializer.toJson<String>(resourceId),
      'versionBefore': serializer.toJson<int?>(versionBefore),
      'versionAfter': serializer.toJson<int?>(versionAfter),
      'outcome': serializer.toJson<String>(outcome),
      'reason': serializer.toJson<String?>(reason),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  AuditLogData copyWith(
          {String? auditId,
          String? operationId,
          String? actor,
          Value<String?> onBehalfOf = const Value.absent(),
          String? action,
          String? resourceType,
          String? resourceId,
          Value<int?> versionBefore = const Value.absent(),
          Value<int?> versionAfter = const Value.absent(),
          String? outcome,
          Value<String?> reason = const Value.absent(),
          DateTime? at}) =>
      AuditLogData(
        auditId: auditId ?? this.auditId,
        operationId: operationId ?? this.operationId,
        actor: actor ?? this.actor,
        onBehalfOf: onBehalfOf.present ? onBehalfOf.value : this.onBehalfOf,
        action: action ?? this.action,
        resourceType: resourceType ?? this.resourceType,
        resourceId: resourceId ?? this.resourceId,
        versionBefore:
            versionBefore.present ? versionBefore.value : this.versionBefore,
        versionAfter:
            versionAfter.present ? versionAfter.value : this.versionAfter,
        outcome: outcome ?? this.outcome,
        reason: reason.present ? reason.value : this.reason,
        at: at ?? this.at,
      );
  AuditLogData copyWithCompanion(AuditLogCompanion data) {
    return AuditLogData(
      auditId: data.auditId.present ? data.auditId.value : this.auditId,
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      actor: data.actor.present ? data.actor.value : this.actor,
      onBehalfOf:
          data.onBehalfOf.present ? data.onBehalfOf.value : this.onBehalfOf,
      action: data.action.present ? data.action.value : this.action,
      resourceType: data.resourceType.present
          ? data.resourceType.value
          : this.resourceType,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      versionBefore: data.versionBefore.present
          ? data.versionBefore.value
          : this.versionBefore,
      versionAfter: data.versionAfter.present
          ? data.versionAfter.value
          : this.versionAfter,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      reason: data.reason.present ? data.reason.value : this.reason,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogData(')
          ..write('auditId: $auditId, ')
          ..write('operationId: $operationId, ')
          ..write('actor: $actor, ')
          ..write('onBehalfOf: $onBehalfOf, ')
          ..write('action: $action, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('versionBefore: $versionBefore, ')
          ..write('versionAfter: $versionAfter, ')
          ..write('outcome: $outcome, ')
          ..write('reason: $reason, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      auditId,
      operationId,
      actor,
      onBehalfOf,
      action,
      resourceType,
      resourceId,
      versionBefore,
      versionAfter,
      outcome,
      reason,
      at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogData &&
          other.auditId == this.auditId &&
          other.operationId == this.operationId &&
          other.actor == this.actor &&
          other.onBehalfOf == this.onBehalfOf &&
          other.action == this.action &&
          other.resourceType == this.resourceType &&
          other.resourceId == this.resourceId &&
          other.versionBefore == this.versionBefore &&
          other.versionAfter == this.versionAfter &&
          other.outcome == this.outcome &&
          other.reason == this.reason &&
          other.at == this.at);
}

class AuditLogCompanion extends UpdateCompanion<AuditLogData> {
  final Value<String> auditId;
  final Value<String> operationId;
  final Value<String> actor;
  final Value<String?> onBehalfOf;
  final Value<String> action;
  final Value<String> resourceType;
  final Value<String> resourceId;
  final Value<int?> versionBefore;
  final Value<int?> versionAfter;
  final Value<String> outcome;
  final Value<String?> reason;
  final Value<DateTime> at;
  final Value<int> rowid;
  const AuditLogCompanion({
    this.auditId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.actor = const Value.absent(),
    this.onBehalfOf = const Value.absent(),
    this.action = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.versionBefore = const Value.absent(),
    this.versionAfter = const Value.absent(),
    this.outcome = const Value.absent(),
    this.reason = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogCompanion.insert({
    required String auditId,
    required String operationId,
    required String actor,
    this.onBehalfOf = const Value.absent(),
    required String action,
    required String resourceType,
    required String resourceId,
    this.versionBefore = const Value.absent(),
    this.versionAfter = const Value.absent(),
    required String outcome,
    this.reason = const Value.absent(),
    required DateTime at,
    this.rowid = const Value.absent(),
  })  : auditId = Value(auditId),
        operationId = Value(operationId),
        actor = Value(actor),
        action = Value(action),
        resourceType = Value(resourceType),
        resourceId = Value(resourceId),
        outcome = Value(outcome),
        at = Value(at);
  static Insertable<AuditLogData> custom({
    Expression<String>? auditId,
    Expression<String>? operationId,
    Expression<String>? actor,
    Expression<String>? onBehalfOf,
    Expression<String>? action,
    Expression<String>? resourceType,
    Expression<String>? resourceId,
    Expression<int>? versionBefore,
    Expression<int>? versionAfter,
    Expression<String>? outcome,
    Expression<String>? reason,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (auditId != null) 'audit_id': auditId,
      if (operationId != null) 'operation_id': operationId,
      if (actor != null) 'actor': actor,
      if (onBehalfOf != null) 'on_behalf_of': onBehalfOf,
      if (action != null) 'action': action,
      if (resourceType != null) 'resource_type': resourceType,
      if (resourceId != null) 'resource_id': resourceId,
      if (versionBefore != null) 'version_before': versionBefore,
      if (versionAfter != null) 'version_after': versionAfter,
      if (outcome != null) 'outcome': outcome,
      if (reason != null) 'reason': reason,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogCompanion copyWith(
      {Value<String>? auditId,
      Value<String>? operationId,
      Value<String>? actor,
      Value<String?>? onBehalfOf,
      Value<String>? action,
      Value<String>? resourceType,
      Value<String>? resourceId,
      Value<int?>? versionBefore,
      Value<int?>? versionAfter,
      Value<String>? outcome,
      Value<String?>? reason,
      Value<DateTime>? at,
      Value<int>? rowid}) {
    return AuditLogCompanion(
      auditId: auditId ?? this.auditId,
      operationId: operationId ?? this.operationId,
      actor: actor ?? this.actor,
      onBehalfOf: onBehalfOf ?? this.onBehalfOf,
      action: action ?? this.action,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      versionBefore: versionBefore ?? this.versionBefore,
      versionAfter: versionAfter ?? this.versionAfter,
      outcome: outcome ?? this.outcome,
      reason: reason ?? this.reason,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (auditId.present) {
      map['audit_id'] = Variable<String>(auditId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (onBehalfOf.present) {
      map['on_behalf_of'] = Variable<String>(onBehalfOf.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (resourceType.present) {
      map['resource_type'] = Variable<String>(resourceType.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (versionBefore.present) {
      map['version_before'] = Variable<int>(versionBefore.value);
    }
    if (versionAfter.present) {
      map['version_after'] = Variable<int>(versionAfter.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogCompanion(')
          ..write('auditId: $auditId, ')
          ..write('operationId: $operationId, ')
          ..write('actor: $actor, ')
          ..write('onBehalfOf: $onBehalfOf, ')
          ..write('action: $action, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('versionBefore: $versionBefore, ')
          ..write('versionAfter: $versionAfter, ')
          ..write('outcome: $outcome, ')
          ..write('reason: $reason, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationTypeMeta =
      const VerificationMeta('operationType');
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
      'operation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseVersionMeta =
      const VerificationMeta('baseVersion');
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
      'base_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns => [
        operationId,
        entityId,
        entityType,
        workspaceId,
        actorId,
        operationType,
        baseVersion,
        payload,
        createdAt,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
          _operationTypeMeta,
          operationType.isAcceptableOrUnknown(
              data['operation_type']!, _operationTypeMeta));
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
          _baseVersionMeta,
          baseVersion.isAcceptableOrUnknown(
              data['base_version']!, _baseVersionMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId, entityType, entityId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id'])!,
      operationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_type'])!,
      baseVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}base_version']),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String operationId;
  final String entityId;
  final String entityType;
  final String workspaceId;
  final String actorId;
  final String operationType;
  final int? baseVersion;
  final String payload;
  final DateTime createdAt;
  final String status;
  const OutboxData(
      {required this.operationId,
      required this.entityId,
      required this.entityType,
      required this.workspaceId,
      required this.actorId,
      required this.operationType,
      this.baseVersion,
      required this.payload,
      required this.createdAt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_type'] = Variable<String>(entityType);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['actor_id'] = Variable<String>(actorId);
    map['operation_type'] = Variable<String>(operationType);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      operationId: Value(operationId),
      entityId: Value(entityId),
      entityType: Value(entityType),
      workspaceId: Value(workspaceId),
      actorId: Value(actorId),
      operationType: Value(operationType),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      payload: Value(payload),
      createdAt: Value(createdAt),
      status: Value(status),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      operationId: serializer.fromJson<String>(json['operationId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      actorId: serializer.fromJson<String>(json['actorId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'entityId': serializer.toJson<String>(entityId),
      'entityType': serializer.toJson<String>(entityType),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'actorId': serializer.toJson<String>(actorId),
      'operationType': serializer.toJson<String>(operationType),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxData copyWith(
          {String? operationId,
          String? entityId,
          String? entityType,
          String? workspaceId,
          String? actorId,
          String? operationType,
          Value<int?> baseVersion = const Value.absent(),
          String? payload,
          DateTime? createdAt,
          String? status}) =>
      OutboxData(
        operationId: operationId ?? this.operationId,
        entityId: entityId ?? this.entityId,
        entityType: entityType ?? this.entityType,
        workspaceId: workspaceId ?? this.workspaceId,
        actorId: actorId ?? this.actorId,
        operationType: operationType ?? this.operationType,
        baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      baseVersion:
          data.baseVersion.present ? data.baseVersion.value : this.baseVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('operationId: $operationId, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('actorId: $actorId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      operationId,
      entityId,
      entityType,
      workspaceId,
      actorId,
      operationType,
      baseVersion,
      payload,
      createdAt,
      status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.operationId == this.operationId &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.workspaceId == this.workspaceId &&
          other.actorId == this.actorId &&
          other.operationType == this.operationType &&
          other.baseVersion == this.baseVersion &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.status == this.status);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> operationId;
  final Value<String> entityId;
  final Value<String> entityType;
  final Value<String> workspaceId;
  final Value<String> actorId;
  final Value<String> operationType;
  final Value<int?> baseVersion;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> rowid;
  const OutboxCompanion({
    this.operationId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String operationId,
    required String entityId,
    required String entityType,
    required String workspaceId,
    required String actorId,
    required String operationType,
    this.baseVersion = const Value.absent(),
    required String payload,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : operationId = Value(operationId),
        entityId = Value(entityId),
        entityType = Value(entityType),
        workspaceId = Value(workspaceId),
        actorId = Value(actorId),
        operationType = Value(operationType),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? operationId,
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<String>? workspaceId,
    Expression<String>? actorId,
    Expression<String>? operationType,
    Expression<int>? baseVersion,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (actorId != null) 'actor_id': actorId,
      if (operationType != null) 'operation_type': operationType,
      if (baseVersion != null) 'base_version': baseVersion,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith(
      {Value<String>? operationId,
      Value<String>? entityId,
      Value<String>? entityType,
      Value<String>? workspaceId,
      Value<String>? actorId,
      Value<String>? operationType,
      Value<int?>? baseVersion,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? rowid}) {
    return OutboxCompanion(
      operationId: operationId ?? this.operationId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      workspaceId: workspaceId ?? this.workspaceId,
      actorId: actorId ?? this.actorId,
      operationType: operationType ?? this.operationType,
      baseVersion: baseVersion ?? this.baseVersion,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('operationId: $operationId, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('actorId: $actorId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventLogTable extends EventLog
    with TableInfo<$EventLogTable, EventLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dispatchedMeta =
      const VerificationMeta('dispatched');
  @override
  late final GeneratedColumn<bool> dispatched = GeneratedColumn<bool>(
      'dispatched', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dispatched" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [eventId, operationId, eventType, payload, createdAt, dispatched];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_log';
  @override
  VerificationContext validateIntegrity(Insertable<EventLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('dispatched')) {
      context.handle(
          _dispatchedMeta,
          dispatched.isAcceptableOrUnknown(
              data['dispatched']!, _dispatchedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  EventLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventLogData(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      dispatched: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dispatched'])!,
    );
  }

  @override
  $EventLogTable createAlias(String alias) {
    return $EventLogTable(attachedDatabase, alias);
  }
}

class EventLogData extends DataClass implements Insertable<EventLogData> {
  final String eventId;
  final String operationId;
  final String eventType;
  final String payload;
  final DateTime createdAt;
  final bool dispatched;
  const EventLogData(
      {required this.eventId,
      required this.operationId,
      required this.eventType,
      required this.payload,
      required this.createdAt,
      required this.dispatched});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['operation_id'] = Variable<String>(operationId);
    map['event_type'] = Variable<String>(eventType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['dispatched'] = Variable<bool>(dispatched);
    return map;
  }

  EventLogCompanion toCompanion(bool nullToAbsent) {
    return EventLogCompanion(
      eventId: Value(eventId),
      operationId: Value(operationId),
      eventType: Value(eventType),
      payload: Value(payload),
      createdAt: Value(createdAt),
      dispatched: Value(dispatched),
    );
  }

  factory EventLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventLogData(
      eventId: serializer.fromJson<String>(json['eventId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      dispatched: serializer.fromJson<bool>(json['dispatched']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'operationId': serializer.toJson<String>(operationId),
      'eventType': serializer.toJson<String>(eventType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'dispatched': serializer.toJson<bool>(dispatched),
    };
  }

  EventLogData copyWith(
          {String? eventId,
          String? operationId,
          String? eventType,
          String? payload,
          DateTime? createdAt,
          bool? dispatched}) =>
      EventLogData(
        eventId: eventId ?? this.eventId,
        operationId: operationId ?? this.operationId,
        eventType: eventType ?? this.eventType,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        dispatched: dispatched ?? this.dispatched,
      );
  EventLogData copyWithCompanion(EventLogCompanion data) {
    return EventLogData(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      dispatched:
          data.dispatched.present ? data.dispatched.value : this.dispatched,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventLogData(')
          ..write('eventId: $eventId, ')
          ..write('operationId: $operationId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('dispatched: $dispatched')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      eventId, operationId, eventType, payload, createdAt, dispatched);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventLogData &&
          other.eventId == this.eventId &&
          other.operationId == this.operationId &&
          other.eventType == this.eventType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.dispatched == this.dispatched);
}

class EventLogCompanion extends UpdateCompanion<EventLogData> {
  final Value<String> eventId;
  final Value<String> operationId;
  final Value<String> eventType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<bool> dispatched;
  final Value<int> rowid;
  const EventLogCompanion({
    this.eventId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dispatched = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventLogCompanion.insert({
    required String eventId,
    required String operationId,
    required String eventType,
    required String payload,
    required DateTime createdAt,
    this.dispatched = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : eventId = Value(eventId),
        operationId = Value(operationId),
        eventType = Value(eventType),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<EventLogData> custom({
    Expression<String>? eventId,
    Expression<String>? operationId,
    Expression<String>? eventType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<bool>? dispatched,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (operationId != null) 'operation_id': operationId,
      if (eventType != null) 'event_type': eventType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (dispatched != null) 'dispatched': dispatched,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventLogCompanion copyWith(
      {Value<String>? eventId,
      Value<String>? operationId,
      Value<String>? eventType,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<bool>? dispatched,
      Value<int>? rowid}) {
    return EventLogCompanion(
      eventId: eventId ?? this.eventId,
      operationId: operationId ?? this.operationId,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      dispatched: dispatched ?? this.dispatched,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (dispatched.present) {
      map['dispatched'] = Variable<bool>(dispatched.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventLogCompanion(')
          ..write('eventId: $eventId, ')
          ..write('operationId: $operationId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('dispatched: $dispatched, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpDedupeTable extends OpDedupe
    with TableInfo<$OpDedupeTable, OpDedupeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpDedupeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resultSummaryMeta =
      const VerificationMeta('resultSummary');
  @override
  late final GeneratedColumn<String> resultSummary = GeneratedColumn<String>(
      'result_summary', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _appliedAtMeta =
      const VerificationMeta('appliedAt');
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
      'applied_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [operationId, workspaceId, resultSummary, appliedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'op_dedupe';
  @override
  VerificationContext validateIntegrity(Insertable<OpDedupeData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('result_summary')) {
      context.handle(
          _resultSummaryMeta,
          resultSummary.isAcceptableOrUnknown(
              data['result_summary']!, _resultSummaryMeta));
    } else if (isInserting) {
      context.missing(_resultSummaryMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(_appliedAtMeta,
          appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta));
    } else if (isInserting) {
      context.missing(_appliedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  OpDedupeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpDedupeData(
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      resultSummary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_summary'])!,
      appliedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}applied_at'])!,
    );
  }

  @override
  $OpDedupeTable createAlias(String alias) {
    return $OpDedupeTable(attachedDatabase, alias);
  }
}

class OpDedupeData extends DataClass implements Insertable<OpDedupeData> {
  final String operationId;
  final String workspaceId;
  final String resultSummary;
  final DateTime appliedAt;
  const OpDedupeData(
      {required this.operationId,
      required this.workspaceId,
      required this.resultSummary,
      required this.appliedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['result_summary'] = Variable<String>(resultSummary);
    map['applied_at'] = Variable<DateTime>(appliedAt);
    return map;
  }

  OpDedupeCompanion toCompanion(bool nullToAbsent) {
    return OpDedupeCompanion(
      operationId: Value(operationId),
      workspaceId: Value(workspaceId),
      resultSummary: Value(resultSummary),
      appliedAt: Value(appliedAt),
    );
  }

  factory OpDedupeData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpDedupeData(
      operationId: serializer.fromJson<String>(json['operationId']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      resultSummary: serializer.fromJson<String>(json['resultSummary']),
      appliedAt: serializer.fromJson<DateTime>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'resultSummary': serializer.toJson<String>(resultSummary),
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
    };
  }

  OpDedupeData copyWith(
          {String? operationId,
          String? workspaceId,
          String? resultSummary,
          DateTime? appliedAt}) =>
      OpDedupeData(
        operationId: operationId ?? this.operationId,
        workspaceId: workspaceId ?? this.workspaceId,
        resultSummary: resultSummary ?? this.resultSummary,
        appliedAt: appliedAt ?? this.appliedAt,
      );
  OpDedupeData copyWithCompanion(OpDedupeCompanion data) {
    return OpDedupeData(
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      resultSummary: data.resultSummary.present
          ? data.resultSummary.value
          : this.resultSummary,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpDedupeData(')
          ..write('operationId: $operationId, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('resultSummary: $resultSummary, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(operationId, workspaceId, resultSummary, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpDedupeData &&
          other.operationId == this.operationId &&
          other.workspaceId == this.workspaceId &&
          other.resultSummary == this.resultSummary &&
          other.appliedAt == this.appliedAt);
}

class OpDedupeCompanion extends UpdateCompanion<OpDedupeData> {
  final Value<String> operationId;
  final Value<String> workspaceId;
  final Value<String> resultSummary;
  final Value<DateTime> appliedAt;
  final Value<int> rowid;
  const OpDedupeCompanion({
    this.operationId = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.resultSummary = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpDedupeCompanion.insert({
    required String operationId,
    required String workspaceId,
    required String resultSummary,
    required DateTime appliedAt,
    this.rowid = const Value.absent(),
  })  : operationId = Value(operationId),
        workspaceId = Value(workspaceId),
        resultSummary = Value(resultSummary),
        appliedAt = Value(appliedAt);
  static Insertable<OpDedupeData> custom({
    Expression<String>? operationId,
    Expression<String>? workspaceId,
    Expression<String>? resultSummary,
    Expression<DateTime>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (resultSummary != null) 'result_summary': resultSummary,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpDedupeCompanion copyWith(
      {Value<String>? operationId,
      Value<String>? workspaceId,
      Value<String>? resultSummary,
      Value<DateTime>? appliedAt,
      Value<int>? rowid}) {
    return OpDedupeCompanion(
      operationId: operationId ?? this.operationId,
      workspaceId: workspaceId ?? this.workspaceId,
      resultSummary: resultSummary ?? this.resultSummary,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (resultSummary.present) {
      map['result_summary'] = Variable<String>(resultSummary.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpDedupeCompanion(')
          ..write('operationId: $operationId, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('resultSummary: $resultSummary, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestoreSnapshotsTable extends RestoreSnapshots
    with TableInfo<$RestoreSnapshotsTable, RestoreSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestoreSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _exportTextMeta =
      const VerificationMeta('exportText');
  @override
  late final GeneratedColumn<String> exportText = GeneratedColumn<String>(
      'export_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, operationId, createdAt, exportText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restore_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<RestoreSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('export_text')) {
      context.handle(
          _exportTextMeta,
          exportText.isAcceptableOrUnknown(
              data['export_text']!, _exportTextMeta));
    } else if (isInserting) {
      context.missing(_exportTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestoreSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestoreSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      exportText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}export_text'])!,
    );
  }

  @override
  $RestoreSnapshotsTable createAlias(String alias) {
    return $RestoreSnapshotsTable(attachedDatabase, alias);
  }
}

class RestoreSnapshot extends DataClass implements Insertable<RestoreSnapshot> {
  final String id;
  final String operationId;
  final DateTime createdAt;
  final String exportText;
  const RestoreSnapshot(
      {required this.id,
      required this.operationId,
      required this.createdAt,
      required this.exportText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['export_text'] = Variable<String>(exportText);
    return map;
  }

  RestoreSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return RestoreSnapshotsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      createdAt: Value(createdAt),
      exportText: Value(exportText),
    );
  }

  factory RestoreSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestoreSnapshot(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      exportText: serializer.fromJson<String>(json['exportText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'exportText': serializer.toJson<String>(exportText),
    };
  }

  RestoreSnapshot copyWith(
          {String? id,
          String? operationId,
          DateTime? createdAt,
          String? exportText}) =>
      RestoreSnapshot(
        id: id ?? this.id,
        operationId: operationId ?? this.operationId,
        createdAt: createdAt ?? this.createdAt,
        exportText: exportText ?? this.exportText,
      );
  RestoreSnapshot copyWithCompanion(RestoreSnapshotsCompanion data) {
    return RestoreSnapshot(
      id: data.id.present ? data.id.value : this.id,
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      exportText:
          data.exportText.present ? data.exportText.value : this.exportText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestoreSnapshot(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportText: $exportText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, operationId, createdAt, exportText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestoreSnapshot &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.createdAt == this.createdAt &&
          other.exportText == this.exportText);
}

class RestoreSnapshotsCompanion extends UpdateCompanion<RestoreSnapshot> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<DateTime> createdAt;
  final Value<String> exportText;
  final Value<int> rowid;
  const RestoreSnapshotsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.exportText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestoreSnapshotsCompanion.insert({
    required String id,
    required String operationId,
    required DateTime createdAt,
    required String exportText,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        operationId = Value(operationId),
        createdAt = Value(createdAt),
        exportText = Value(exportText);
  static Insertable<RestoreSnapshot> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<DateTime>? createdAt,
    Expression<String>? exportText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (createdAt != null) 'created_at': createdAt,
      if (exportText != null) 'export_text': exportText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestoreSnapshotsCompanion copyWith(
      {Value<String>? id,
      Value<String>? operationId,
      Value<DateTime>? createdAt,
      Value<String>? exportText,
      Value<int>? rowid}) {
    return RestoreSnapshotsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      createdAt: createdAt ?? this.createdAt,
      exportText: exportText ?? this.exportText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (exportText.present) {
      map['export_text'] = Variable<String>(exportText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestoreSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportText: $exportText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarsTable extends Calendars
    with TableInfo<$CalendarsTable, Calendar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xFF009688));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        name,
        color
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendars';
  @override
  VerificationContext validateIntegrity(Insertable<Calendar> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Calendar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Calendar(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
    );
  }

  @override
  $CalendarsTable createAlias(String alias) {
    return $CalendarsTable(attachedDatabase, alias);
  }
}

class Calendar extends DataClass implements Insertable<Calendar> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String name;
  final int color;
  const Calendar(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.name,
      required this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    return map;
  }

  CalendarsCompanion toCompanion(bool nullToAbsent) {
    return CalendarsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      name: Value(name),
      color: Value(color),
    );
  }

  factory Calendar.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Calendar(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
    };
  }

  Calendar copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? name,
          int? color}) =>
      Calendar(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        name: name ?? this.name,
        color: color ?? this.color,
      );
  Calendar copyWithCompanion(CalendarsCompanion data) {
    return Calendar(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Calendar(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, ownerId, version, createdAt,
      updatedAt, deletedAt, deletedBy, changedBy, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Calendar &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.name == this.name &&
          other.color == this.color);
}

class CalendarsCompanion extends UpdateCompanion<Calendar> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> name;
  final Value<int> color;
  final Value<int> rowid;
  const CalendarsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        name = Value(name);
  static Insertable<Calendar> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? name,
      Value<int>? color,
      Value<int>? rowid}) {
    return CalendarsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      name: name ?? this.name,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _calendarIdMeta =
      const VerificationMeta('calendarId');
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
      'calendar_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('confirmed'));
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
      'list_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorIndexMeta =
      const VerificationMeta('colorIndex');
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
      'color_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _orderKeyMeta =
      const VerificationMeta('orderKey');
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
      'order_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('a0'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        title,
        location,
        calendarId,
        status,
        listId,
        colorIndex,
        orderKey
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(Insertable<Event> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
          _calendarIdMeta,
          calendarId.isAcceptableOrUnknown(
              data['calendar_id']!, _calendarIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta,
          listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    }
    if (data.containsKey('color_index')) {
      context.handle(
          _colorIndexMeta,
          colorIndex.isAcceptableOrUnknown(
              data['color_index']!, _colorIndexMeta));
    }
    if (data.containsKey('order_key')) {
      context.handle(_orderKeyMeta,
          orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      calendarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}calendar_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      listId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_id']),
      colorIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_index']),
      orderKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_key'])!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String title;
  final String? location;
  final String? calendarId;
  final String status;
  final String? listId;
  final int? colorIndex;
  final String orderKey;
  const Event(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.title,
      this.location,
      this.calendarId,
      required this.status,
      this.listId,
      this.colorIndex,
      required this.orderKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || calendarId != null) {
      map['calendar_id'] = Variable<String>(calendarId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    if (!nullToAbsent || colorIndex != null) {
      map['color_index'] = Variable<int>(colorIndex);
    }
    map['order_key'] = Variable<String>(orderKey);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      title: Value(title),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      calendarId: calendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarId),
      status: Value(status),
      listId:
          listId == null && nullToAbsent ? const Value.absent() : Value(listId),
      colorIndex: colorIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorIndex),
      orderKey: Value(orderKey),
    );
  }

  factory Event.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      title: serializer.fromJson<String>(json['title']),
      location: serializer.fromJson<String?>(json['location']),
      calendarId: serializer.fromJson<String?>(json['calendarId']),
      status: serializer.fromJson<String>(json['status']),
      listId: serializer.fromJson<String?>(json['listId']),
      colorIndex: serializer.fromJson<int?>(json['colorIndex']),
      orderKey: serializer.fromJson<String>(json['orderKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'title': serializer.toJson<String>(title),
      'location': serializer.toJson<String?>(location),
      'calendarId': serializer.toJson<String?>(calendarId),
      'status': serializer.toJson<String>(status),
      'listId': serializer.toJson<String?>(listId),
      'colorIndex': serializer.toJson<int?>(colorIndex),
      'orderKey': serializer.toJson<String>(orderKey),
    };
  }

  Event copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? title,
          Value<String?> location = const Value.absent(),
          Value<String?> calendarId = const Value.absent(),
          String? status,
          Value<String?> listId = const Value.absent(),
          Value<int?> colorIndex = const Value.absent(),
          String? orderKey}) =>
      Event(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        title: title ?? this.title,
        location: location.present ? location.value : this.location,
        calendarId: calendarId.present ? calendarId.value : this.calendarId,
        status: status ?? this.status,
        listId: listId.present ? listId.value : this.listId,
        colorIndex: colorIndex.present ? colorIndex.value : this.colorIndex,
        orderKey: orderKey ?? this.orderKey,
      );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      title: data.title.present ? data.title.value : this.title,
      location: data.location.present ? data.location.value : this.location,
      calendarId:
          data.calendarId.present ? data.calendarId.value : this.calendarId,
      status: data.status.present ? data.status.value : this.status,
      listId: data.listId.present ? data.listId.value : this.listId,
      colorIndex:
          data.colorIndex.present ? data.colorIndex.value : this.colorIndex,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('calendarId: $calendarId, ')
          ..write('status: $status, ')
          ..write('listId: $listId, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      title,
      location,
      calendarId,
      status,
      listId,
      colorIndex,
      orderKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.title == this.title &&
          other.location == this.location &&
          other.calendarId == this.calendarId &&
          other.status == this.status &&
          other.listId == this.listId &&
          other.colorIndex == this.colorIndex &&
          other.orderKey == this.orderKey);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> title;
  final Value<String?> location;
  final Value<String?> calendarId;
  final Value<String> status;
  final Value<String?> listId;
  final Value<int?> colorIndex;
  final Value<String> orderKey;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.title = const Value.absent(),
    this.location = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.status = const Value.absent(),
    this.listId = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String title,
    this.location = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.status = const Value.absent(),
    this.listId = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        title = Value(title);
  static Insertable<Event> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? title,
    Expression<String>? location,
    Expression<String>? calendarId,
    Expression<String>? status,
    Expression<String>? listId,
    Expression<int>? colorIndex,
    Expression<String>? orderKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (title != null) 'title': title,
      if (location != null) 'location': location,
      if (calendarId != null) 'calendar_id': calendarId,
      if (status != null) 'status': status,
      if (listId != null) 'list_id': listId,
      if (colorIndex != null) 'color_index': colorIndex,
      if (orderKey != null) 'order_key': orderKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? title,
      Value<String?>? location,
      Value<String?>? calendarId,
      Value<String>? status,
      Value<String?>? listId,
      Value<int?>? colorIndex,
      Value<String>? orderKey,
      Value<int>? rowid}) {
    return EventsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      title: title ?? this.title,
      location: location ?? this.location,
      calendarId: calendarId ?? this.calendarId,
      status: status ?? this.status,
      listId: listId ?? this.listId,
      colorIndex: colorIndex ?? this.colorIndex,
      orderKey: orderKey ?? this.orderKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('calendarId: $calendarId, ')
          ..write('status: $status, ')
          ..write('listId: $listId, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('orderKey: $orderKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchedulesTable extends Schedules
    with TableInfo<$SchedulesTable, Schedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subjectTypeMeta =
      const VerificationMeta('subjectType');
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
      'subject_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectIdMeta =
      const VerificationMeta('subjectId');
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
      'subject_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
      'start_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
      'start_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startZoneMeta =
      const VerificationMeta('startZone');
  @override
  late final GeneratedColumn<String> startZone = GeneratedColumn<String>(
      'start_zone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
      'end_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
      'end_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endZoneMeta =
      const VerificationMeta('endZone');
  @override
  late final GeneratedColumn<String> endZone = GeneratedColumn<String>(
      'end_zone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deadlineDateMeta =
      const VerificationMeta('deadlineDate');
  @override
  late final GeneratedColumn<String> deadlineDate = GeneratedColumn<String>(
      'deadline_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deadlineTimeMeta =
      const VerificationMeta('deadlineTime');
  @override
  late final GeneratedColumn<String> deadlineTime = GeneratedColumn<String>(
      'deadline_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deadlineZoneMeta =
      const VerificationMeta('deadlineZone');
  @override
  late final GeneratedColumn<String> deadlineZone = GeneratedColumn<String>(
      'deadline_zone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firstDateMeta =
      const VerificationMeta('firstDate');
  @override
  late final GeneratedColumn<String> firstDate = GeneratedColumn<String>(
      'first_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastDateMeta =
      const VerificationMeta('lastDate');
  @override
  late final GeneratedColumn<String> lastDate = GeneratedColumn<String>(
      'last_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _frequencyMeta =
      const VerificationMeta('frequency');
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
      'frequency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _intervalMeta =
      const VerificationMeta('interval');
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
      'interval', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _weekdaysMeta =
      const VerificationMeta('weekdays');
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
      'weekdays', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endKindMeta =
      const VerificationMeta('endKind');
  @override
  late final GeneratedColumn<String> endKind = GeneratedColumn<String>(
      'end_kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endDateRuleMeta =
      const VerificationMeta('endDateRule');
  @override
  late final GeneratedColumn<String> endDateRule = GeneratedColumn<String>(
      'end_date_rule', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _endCountMeta =
      const VerificationMeta('endCount');
  @override
  late final GeneratedColumn<int> endCount = GeneratedColumn<int>(
      'end_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _monthEndRuleMeta =
      const VerificationMeta('monthEndRule');
  @override
  late final GeneratedColumn<String> monthEndRule = GeneratedColumn<String>(
      'month_end_rule', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('skip'));
  static const VerificationMeta _weekStartMeta =
      const VerificationMeta('weekStart');
  @override
  late final GeneratedColumn<int> weekStart = GeneratedColumn<int>(
      'week_start', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        subjectType,
        subjectId,
        startDate,
        startTime,
        startZone,
        endDate,
        endTime,
        endZone,
        deadlineDate,
        deadlineTime,
        deadlineZone,
        firstDate,
        lastDate,
        frequency,
        interval,
        weekdays,
        endKind,
        endDateRule,
        endCount,
        monthEndRule,
        weekStart
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedules';
  @override
  VerificationContext validateIntegrity(Insertable<Schedule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
          _subjectTypeMeta,
          subjectType.isAcceptableOrUnknown(
              data['subject_type']!, _subjectTypeMeta));
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(_subjectIdMeta,
          subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta));
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    }
    if (data.containsKey('start_zone')) {
      context.handle(_startZoneMeta,
          startZone.isAcceptableOrUnknown(data['start_zone']!, _startZoneMeta));
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    }
    if (data.containsKey('end_zone')) {
      context.handle(_endZoneMeta,
          endZone.isAcceptableOrUnknown(data['end_zone']!, _endZoneMeta));
    }
    if (data.containsKey('deadline_date')) {
      context.handle(
          _deadlineDateMeta,
          deadlineDate.isAcceptableOrUnknown(
              data['deadline_date']!, _deadlineDateMeta));
    }
    if (data.containsKey('deadline_time')) {
      context.handle(
          _deadlineTimeMeta,
          deadlineTime.isAcceptableOrUnknown(
              data['deadline_time']!, _deadlineTimeMeta));
    }
    if (data.containsKey('deadline_zone')) {
      context.handle(
          _deadlineZoneMeta,
          deadlineZone.isAcceptableOrUnknown(
              data['deadline_zone']!, _deadlineZoneMeta));
    }
    if (data.containsKey('first_date')) {
      context.handle(_firstDateMeta,
          firstDate.isAcceptableOrUnknown(data['first_date']!, _firstDateMeta));
    } else if (isInserting) {
      context.missing(_firstDateMeta);
    }
    if (data.containsKey('last_date')) {
      context.handle(_lastDateMeta,
          lastDate.isAcceptableOrUnknown(data['last_date']!, _lastDateMeta));
    }
    if (data.containsKey('frequency')) {
      context.handle(_frequencyMeta,
          frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta));
    }
    if (data.containsKey('interval')) {
      context.handle(_intervalMeta,
          interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta));
    }
    if (data.containsKey('weekdays')) {
      context.handle(_weekdaysMeta,
          weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta));
    }
    if (data.containsKey('end_kind')) {
      context.handle(_endKindMeta,
          endKind.isAcceptableOrUnknown(data['end_kind']!, _endKindMeta));
    }
    if (data.containsKey('end_date_rule')) {
      context.handle(
          _endDateRuleMeta,
          endDateRule.isAcceptableOrUnknown(
              data['end_date_rule']!, _endDateRuleMeta));
    }
    if (data.containsKey('end_count')) {
      context.handle(_endCountMeta,
          endCount.isAcceptableOrUnknown(data['end_count']!, _endCountMeta));
    }
    if (data.containsKey('month_end_rule')) {
      context.handle(
          _monthEndRuleMeta,
          monthEndRule.isAcceptableOrUnknown(
              data['month_end_rule']!, _monthEndRuleMeta));
    }
    if (data.containsKey('week_start')) {
      context.handle(_weekStartMeta,
          weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Schedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Schedule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      subjectType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_type'])!,
      subjectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_id'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_date']),
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_time']),
      startZone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_zone']),
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_date']),
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_time']),
      endZone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_zone']),
      deadlineDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deadline_date']),
      deadlineTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deadline_time']),
      deadlineZone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deadline_zone']),
      firstDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}first_date'])!,
      lastDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_date']),
      frequency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}frequency']),
      interval: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval'])!,
      weekdays: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weekdays']),
      endKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_kind']),
      endDateRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_date_rule']),
      endCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_count']),
      monthEndRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}month_end_rule'])!,
      weekStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_start'])!,
    );
  }

  @override
  $SchedulesTable createAlias(String alias) {
    return $SchedulesTable(attachedDatabase, alias);
  }
}

class Schedule extends DataClass implements Insertable<Schedule> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String subjectType;
  final String subjectId;
  final String? startDate;
  final String? startTime;
  final String? startZone;
  final String? endDate;
  final String? endTime;
  final String? endZone;
  final String? deadlineDate;
  final String? deadlineTime;
  final String? deadlineZone;
  final String firstDate;
  final String? lastDate;
  final String? frequency;
  final int interval;
  final String? weekdays;
  final String? endKind;
  final String? endDateRule;
  final int? endCount;
  final String monthEndRule;
  final int weekStart;
  const Schedule(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.subjectType,
      required this.subjectId,
      this.startDate,
      this.startTime,
      this.startZone,
      this.endDate,
      this.endTime,
      this.endZone,
      this.deadlineDate,
      this.deadlineTime,
      this.deadlineZone,
      required this.firstDate,
      this.lastDate,
      this.frequency,
      required this.interval,
      this.weekdays,
      this.endKind,
      this.endDateRule,
      this.endCount,
      required this.monthEndRule,
      required this.weekStart});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<String>(subjectId);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || startZone != null) {
      map['start_zone'] = Variable<String>(startZone);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    if (!nullToAbsent || endZone != null) {
      map['end_zone'] = Variable<String>(endZone);
    }
    if (!nullToAbsent || deadlineDate != null) {
      map['deadline_date'] = Variable<String>(deadlineDate);
    }
    if (!nullToAbsent || deadlineTime != null) {
      map['deadline_time'] = Variable<String>(deadlineTime);
    }
    if (!nullToAbsent || deadlineZone != null) {
      map['deadline_zone'] = Variable<String>(deadlineZone);
    }
    map['first_date'] = Variable<String>(firstDate);
    if (!nullToAbsent || lastDate != null) {
      map['last_date'] = Variable<String>(lastDate);
    }
    if (!nullToAbsent || frequency != null) {
      map['frequency'] = Variable<String>(frequency);
    }
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || endKind != null) {
      map['end_kind'] = Variable<String>(endKind);
    }
    if (!nullToAbsent || endDateRule != null) {
      map['end_date_rule'] = Variable<String>(endDateRule);
    }
    if (!nullToAbsent || endCount != null) {
      map['end_count'] = Variable<int>(endCount);
    }
    map['month_end_rule'] = Variable<String>(monthEndRule);
    map['week_start'] = Variable<int>(weekStart);
    return map;
  }

  SchedulesCompanion toCompanion(bool nullToAbsent) {
    return SchedulesCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      startZone: startZone == null && nullToAbsent
          ? const Value.absent()
          : Value(startZone),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      endZone: endZone == null && nullToAbsent
          ? const Value.absent()
          : Value(endZone),
      deadlineDate: deadlineDate == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineDate),
      deadlineTime: deadlineTime == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineTime),
      deadlineZone: deadlineZone == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineZone),
      firstDate: Value(firstDate),
      lastDate: lastDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDate),
      frequency: frequency == null && nullToAbsent
          ? const Value.absent()
          : Value(frequency),
      interval: Value(interval),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      endKind: endKind == null && nullToAbsent
          ? const Value.absent()
          : Value(endKind),
      endDateRule: endDateRule == null && nullToAbsent
          ? const Value.absent()
          : Value(endDateRule),
      endCount: endCount == null && nullToAbsent
          ? const Value.absent()
          : Value(endCount),
      monthEndRule: Value(monthEndRule),
      weekStart: Value(weekStart),
    );
  }

  factory Schedule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Schedule(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      startZone: serializer.fromJson<String?>(json['startZone']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      endZone: serializer.fromJson<String?>(json['endZone']),
      deadlineDate: serializer.fromJson<String?>(json['deadlineDate']),
      deadlineTime: serializer.fromJson<String?>(json['deadlineTime']),
      deadlineZone: serializer.fromJson<String?>(json['deadlineZone']),
      firstDate: serializer.fromJson<String>(json['firstDate']),
      lastDate: serializer.fromJson<String?>(json['lastDate']),
      frequency: serializer.fromJson<String?>(json['frequency']),
      interval: serializer.fromJson<int>(json['interval']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      endKind: serializer.fromJson<String?>(json['endKind']),
      endDateRule: serializer.fromJson<String?>(json['endDateRule']),
      endCount: serializer.fromJson<int?>(json['endCount']),
      monthEndRule: serializer.fromJson<String>(json['monthEndRule']),
      weekStart: serializer.fromJson<int>(json['weekStart']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<String>(subjectId),
      'startDate': serializer.toJson<String?>(startDate),
      'startTime': serializer.toJson<String?>(startTime),
      'startZone': serializer.toJson<String?>(startZone),
      'endDate': serializer.toJson<String?>(endDate),
      'endTime': serializer.toJson<String?>(endTime),
      'endZone': serializer.toJson<String?>(endZone),
      'deadlineDate': serializer.toJson<String?>(deadlineDate),
      'deadlineTime': serializer.toJson<String?>(deadlineTime),
      'deadlineZone': serializer.toJson<String?>(deadlineZone),
      'firstDate': serializer.toJson<String>(firstDate),
      'lastDate': serializer.toJson<String?>(lastDate),
      'frequency': serializer.toJson<String?>(frequency),
      'interval': serializer.toJson<int>(interval),
      'weekdays': serializer.toJson<String?>(weekdays),
      'endKind': serializer.toJson<String?>(endKind),
      'endDateRule': serializer.toJson<String?>(endDateRule),
      'endCount': serializer.toJson<int?>(endCount),
      'monthEndRule': serializer.toJson<String>(monthEndRule),
      'weekStart': serializer.toJson<int>(weekStart),
    };
  }

  Schedule copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? subjectType,
          String? subjectId,
          Value<String?> startDate = const Value.absent(),
          Value<String?> startTime = const Value.absent(),
          Value<String?> startZone = const Value.absent(),
          Value<String?> endDate = const Value.absent(),
          Value<String?> endTime = const Value.absent(),
          Value<String?> endZone = const Value.absent(),
          Value<String?> deadlineDate = const Value.absent(),
          Value<String?> deadlineTime = const Value.absent(),
          Value<String?> deadlineZone = const Value.absent(),
          String? firstDate,
          Value<String?> lastDate = const Value.absent(),
          Value<String?> frequency = const Value.absent(),
          int? interval,
          Value<String?> weekdays = const Value.absent(),
          Value<String?> endKind = const Value.absent(),
          Value<String?> endDateRule = const Value.absent(),
          Value<int?> endCount = const Value.absent(),
          String? monthEndRule,
          int? weekStart}) =>
      Schedule(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
        startDate: startDate.present ? startDate.value : this.startDate,
        startTime: startTime.present ? startTime.value : this.startTime,
        startZone: startZone.present ? startZone.value : this.startZone,
        endDate: endDate.present ? endDate.value : this.endDate,
        endTime: endTime.present ? endTime.value : this.endTime,
        endZone: endZone.present ? endZone.value : this.endZone,
        deadlineDate:
            deadlineDate.present ? deadlineDate.value : this.deadlineDate,
        deadlineTime:
            deadlineTime.present ? deadlineTime.value : this.deadlineTime,
        deadlineZone:
            deadlineZone.present ? deadlineZone.value : this.deadlineZone,
        firstDate: firstDate ?? this.firstDate,
        lastDate: lastDate.present ? lastDate.value : this.lastDate,
        frequency: frequency.present ? frequency.value : this.frequency,
        interval: interval ?? this.interval,
        weekdays: weekdays.present ? weekdays.value : this.weekdays,
        endKind: endKind.present ? endKind.value : this.endKind,
        endDateRule: endDateRule.present ? endDateRule.value : this.endDateRule,
        endCount: endCount.present ? endCount.value : this.endCount,
        monthEndRule: monthEndRule ?? this.monthEndRule,
        weekStart: weekStart ?? this.weekStart,
      );
  Schedule copyWithCompanion(SchedulesCompanion data) {
    return Schedule(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      subjectType:
          data.subjectType.present ? data.subjectType.value : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      startZone: data.startZone.present ? data.startZone.value : this.startZone,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      endZone: data.endZone.present ? data.endZone.value : this.endZone,
      deadlineDate: data.deadlineDate.present
          ? data.deadlineDate.value
          : this.deadlineDate,
      deadlineTime: data.deadlineTime.present
          ? data.deadlineTime.value
          : this.deadlineTime,
      deadlineZone: data.deadlineZone.present
          ? data.deadlineZone.value
          : this.deadlineZone,
      firstDate: data.firstDate.present ? data.firstDate.value : this.firstDate,
      lastDate: data.lastDate.present ? data.lastDate.value : this.lastDate,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      endKind: data.endKind.present ? data.endKind.value : this.endKind,
      endDateRule:
          data.endDateRule.present ? data.endDateRule.value : this.endDateRule,
      endCount: data.endCount.present ? data.endCount.value : this.endCount,
      monthEndRule: data.monthEndRule.present
          ? data.monthEndRule.value
          : this.monthEndRule,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Schedule(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('startDate: $startDate, ')
          ..write('startTime: $startTime, ')
          ..write('startZone: $startZone, ')
          ..write('endDate: $endDate, ')
          ..write('endTime: $endTime, ')
          ..write('endZone: $endZone, ')
          ..write('deadlineDate: $deadlineDate, ')
          ..write('deadlineTime: $deadlineTime, ')
          ..write('deadlineZone: $deadlineZone, ')
          ..write('firstDate: $firstDate, ')
          ..write('lastDate: $lastDate, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('endKind: $endKind, ')
          ..write('endDateRule: $endDateRule, ')
          ..write('endCount: $endCount, ')
          ..write('monthEndRule: $monthEndRule, ')
          ..write('weekStart: $weekStart')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        subjectType,
        subjectId,
        startDate,
        startTime,
        startZone,
        endDate,
        endTime,
        endZone,
        deadlineDate,
        deadlineTime,
        deadlineZone,
        firstDate,
        lastDate,
        frequency,
        interval,
        weekdays,
        endKind,
        endDateRule,
        endCount,
        monthEndRule,
        weekStart
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Schedule &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.startDate == this.startDate &&
          other.startTime == this.startTime &&
          other.startZone == this.startZone &&
          other.endDate == this.endDate &&
          other.endTime == this.endTime &&
          other.endZone == this.endZone &&
          other.deadlineDate == this.deadlineDate &&
          other.deadlineTime == this.deadlineTime &&
          other.deadlineZone == this.deadlineZone &&
          other.firstDate == this.firstDate &&
          other.lastDate == this.lastDate &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.weekdays == this.weekdays &&
          other.endKind == this.endKind &&
          other.endDateRule == this.endDateRule &&
          other.endCount == this.endCount &&
          other.monthEndRule == this.monthEndRule &&
          other.weekStart == this.weekStart);
}

class SchedulesCompanion extends UpdateCompanion<Schedule> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> subjectType;
  final Value<String> subjectId;
  final Value<String?> startDate;
  final Value<String?> startTime;
  final Value<String?> startZone;
  final Value<String?> endDate;
  final Value<String?> endTime;
  final Value<String?> endZone;
  final Value<String?> deadlineDate;
  final Value<String?> deadlineTime;
  final Value<String?> deadlineZone;
  final Value<String> firstDate;
  final Value<String?> lastDate;
  final Value<String?> frequency;
  final Value<int> interval;
  final Value<String?> weekdays;
  final Value<String?> endKind;
  final Value<String?> endDateRule;
  final Value<int?> endCount;
  final Value<String> monthEndRule;
  final Value<int> weekStart;
  final Value<int> rowid;
  const SchedulesCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.startZone = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endTime = const Value.absent(),
    this.endZone = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.deadlineTime = const Value.absent(),
    this.deadlineZone = const Value.absent(),
    this.firstDate = const Value.absent(),
    this.lastDate = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.endKind = const Value.absent(),
    this.endDateRule = const Value.absent(),
    this.endCount = const Value.absent(),
    this.monthEndRule = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchedulesCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String subjectType,
    required String subjectId,
    this.startDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.startZone = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endTime = const Value.absent(),
    this.endZone = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.deadlineTime = const Value.absent(),
    this.deadlineZone = const Value.absent(),
    required String firstDate,
    this.lastDate = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.endKind = const Value.absent(),
    this.endDateRule = const Value.absent(),
    this.endCount = const Value.absent(),
    this.monthEndRule = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        subjectType = Value(subjectType),
        subjectId = Value(subjectId),
        firstDate = Value(firstDate);
  static Insertable<Schedule> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? subjectType,
    Expression<String>? subjectId,
    Expression<String>? startDate,
    Expression<String>? startTime,
    Expression<String>? startZone,
    Expression<String>? endDate,
    Expression<String>? endTime,
    Expression<String>? endZone,
    Expression<String>? deadlineDate,
    Expression<String>? deadlineTime,
    Expression<String>? deadlineZone,
    Expression<String>? firstDate,
    Expression<String>? lastDate,
    Expression<String>? frequency,
    Expression<int>? interval,
    Expression<String>? weekdays,
    Expression<String>? endKind,
    Expression<String>? endDateRule,
    Expression<int>? endCount,
    Expression<String>? monthEndRule,
    Expression<int>? weekStart,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (startDate != null) 'start_date': startDate,
      if (startTime != null) 'start_time': startTime,
      if (startZone != null) 'start_zone': startZone,
      if (endDate != null) 'end_date': endDate,
      if (endTime != null) 'end_time': endTime,
      if (endZone != null) 'end_zone': endZone,
      if (deadlineDate != null) 'deadline_date': deadlineDate,
      if (deadlineTime != null) 'deadline_time': deadlineTime,
      if (deadlineZone != null) 'deadline_zone': deadlineZone,
      if (firstDate != null) 'first_date': firstDate,
      if (lastDate != null) 'last_date': lastDate,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (weekdays != null) 'weekdays': weekdays,
      if (endKind != null) 'end_kind': endKind,
      if (endDateRule != null) 'end_date_rule': endDateRule,
      if (endCount != null) 'end_count': endCount,
      if (monthEndRule != null) 'month_end_rule': monthEndRule,
      if (weekStart != null) 'week_start': weekStart,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchedulesCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? subjectType,
      Value<String>? subjectId,
      Value<String?>? startDate,
      Value<String?>? startTime,
      Value<String?>? startZone,
      Value<String?>? endDate,
      Value<String?>? endTime,
      Value<String?>? endZone,
      Value<String?>? deadlineDate,
      Value<String?>? deadlineTime,
      Value<String?>? deadlineZone,
      Value<String>? firstDate,
      Value<String?>? lastDate,
      Value<String?>? frequency,
      Value<int>? interval,
      Value<String?>? weekdays,
      Value<String?>? endKind,
      Value<String?>? endDateRule,
      Value<int?>? endCount,
      Value<String>? monthEndRule,
      Value<int>? weekStart,
      Value<int>? rowid}) {
    return SchedulesCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      startZone: startZone ?? this.startZone,
      endDate: endDate ?? this.endDate,
      endTime: endTime ?? this.endTime,
      endZone: endZone ?? this.endZone,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      deadlineTime: deadlineTime ?? this.deadlineTime,
      deadlineZone: deadlineZone ?? this.deadlineZone,
      firstDate: firstDate ?? this.firstDate,
      lastDate: lastDate ?? this.lastDate,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      endKind: endKind ?? this.endKind,
      endDateRule: endDateRule ?? this.endDateRule,
      endCount: endCount ?? this.endCount,
      monthEndRule: monthEndRule ?? this.monthEndRule,
      weekStart: weekStart ?? this.weekStart,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (startZone.present) {
      map['start_zone'] = Variable<String>(startZone.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (endZone.present) {
      map['end_zone'] = Variable<String>(endZone.value);
    }
    if (deadlineDate.present) {
      map['deadline_date'] = Variable<String>(deadlineDate.value);
    }
    if (deadlineTime.present) {
      map['deadline_time'] = Variable<String>(deadlineTime.value);
    }
    if (deadlineZone.present) {
      map['deadline_zone'] = Variable<String>(deadlineZone.value);
    }
    if (firstDate.present) {
      map['first_date'] = Variable<String>(firstDate.value);
    }
    if (lastDate.present) {
      map['last_date'] = Variable<String>(lastDate.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (endKind.present) {
      map['end_kind'] = Variable<String>(endKind.value);
    }
    if (endDateRule.present) {
      map['end_date_rule'] = Variable<String>(endDateRule.value);
    }
    if (endCount.present) {
      map['end_count'] = Variable<int>(endCount.value);
    }
    if (monthEndRule.present) {
      map['month_end_rule'] = Variable<String>(monthEndRule.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<int>(weekStart.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedulesCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('startDate: $startDate, ')
          ..write('startTime: $startTime, ')
          ..write('startZone: $startZone, ')
          ..write('endDate: $endDate, ')
          ..write('endTime: $endTime, ')
          ..write('endZone: $endZone, ')
          ..write('deadlineDate: $deadlineDate, ')
          ..write('deadlineTime: $deadlineTime, ')
          ..write('deadlineZone: $deadlineZone, ')
          ..write('firstDate: $firstDate, ')
          ..write('lastDate: $lastDate, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('endKind: $endKind, ')
          ..write('endDateRule: $endDateRule, ')
          ..write('endCount: $endCount, ')
          ..write('monthEndRule: $monthEndRule, ')
          ..write('weekStart: $weekStart, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccurrenceExceptionsTable extends OccurrenceExceptions
    with TableInfo<$OccurrenceExceptionsTable, OccurrenceException> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccurrenceExceptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subjectTypeMeta =
      const VerificationMeta('subjectType');
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
      'subject_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectIdMeta =
      const VerificationMeta('subjectId');
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
      'subject_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalDateMeta =
      const VerificationMeta('originalDate');
  @override
  late final GeneratedColumn<String> originalDate = GeneratedColumn<String>(
      'original_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _moveDateMeta =
      const VerificationMeta('moveDate');
  @override
  late final GeneratedColumn<String> moveDate = GeneratedColumn<String>(
      'move_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _moveTimeMeta =
      const VerificationMeta('moveTime');
  @override
  late final GeneratedColumn<String> moveTime = GeneratedColumn<String>(
      'move_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _patchMeta = const VerificationMeta('patch');
  @override
  late final GeneratedColumn<String> patch = GeneratedColumn<String>(
      'patch', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        subjectType,
        subjectId,
        originalDate,
        kind,
        moveDate,
        moveTime,
        patch
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occurrence_exceptions';
  @override
  VerificationContext validateIntegrity(
      Insertable<OccurrenceException> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
          _subjectTypeMeta,
          subjectType.isAcceptableOrUnknown(
              data['subject_type']!, _subjectTypeMeta));
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(_subjectIdMeta,
          subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta));
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('original_date')) {
      context.handle(
          _originalDateMeta,
          originalDate.isAcceptableOrUnknown(
              data['original_date']!, _originalDateMeta));
    } else if (isInserting) {
      context.missing(_originalDateMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('move_date')) {
      context.handle(_moveDateMeta,
          moveDate.isAcceptableOrUnknown(data['move_date']!, _moveDateMeta));
    }
    if (data.containsKey('move_time')) {
      context.handle(_moveTimeMeta,
          moveTime.isAcceptableOrUnknown(data['move_time']!, _moveTimeMeta));
    }
    if (data.containsKey('patch')) {
      context.handle(
          _patchMeta, patch.isAcceptableOrUnknown(data['patch']!, _patchMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OccurrenceException map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OccurrenceException(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      subjectType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_type'])!,
      subjectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_id'])!,
      originalDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_date'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      moveDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}move_date']),
      moveTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}move_time']),
      patch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patch']),
    );
  }

  @override
  $OccurrenceExceptionsTable createAlias(String alias) {
    return $OccurrenceExceptionsTable(attachedDatabase, alias);
  }
}

class OccurrenceException extends DataClass
    implements Insertable<OccurrenceException> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String subjectType;
  final String subjectId;
  final String originalDate;
  final String kind;
  final String? moveDate;
  final String? moveTime;
  final String? patch;
  const OccurrenceException(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.subjectType,
      required this.subjectId,
      required this.originalDate,
      required this.kind,
      this.moveDate,
      this.moveTime,
      this.patch});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<String>(subjectId);
    map['original_date'] = Variable<String>(originalDate);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || moveDate != null) {
      map['move_date'] = Variable<String>(moveDate);
    }
    if (!nullToAbsent || moveTime != null) {
      map['move_time'] = Variable<String>(moveTime);
    }
    if (!nullToAbsent || patch != null) {
      map['patch'] = Variable<String>(patch);
    }
    return map;
  }

  OccurrenceExceptionsCompanion toCompanion(bool nullToAbsent) {
    return OccurrenceExceptionsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      originalDate: Value(originalDate),
      kind: Value(kind),
      moveDate: moveDate == null && nullToAbsent
          ? const Value.absent()
          : Value(moveDate),
      moveTime: moveTime == null && nullToAbsent
          ? const Value.absent()
          : Value(moveTime),
      patch:
          patch == null && nullToAbsent ? const Value.absent() : Value(patch),
    );
  }

  factory OccurrenceException.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OccurrenceException(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      originalDate: serializer.fromJson<String>(json['originalDate']),
      kind: serializer.fromJson<String>(json['kind']),
      moveDate: serializer.fromJson<String?>(json['moveDate']),
      moveTime: serializer.fromJson<String?>(json['moveTime']),
      patch: serializer.fromJson<String?>(json['patch']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<String>(subjectId),
      'originalDate': serializer.toJson<String>(originalDate),
      'kind': serializer.toJson<String>(kind),
      'moveDate': serializer.toJson<String?>(moveDate),
      'moveTime': serializer.toJson<String?>(moveTime),
      'patch': serializer.toJson<String?>(patch),
    };
  }

  OccurrenceException copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? subjectType,
          String? subjectId,
          String? originalDate,
          String? kind,
          Value<String?> moveDate = const Value.absent(),
          Value<String?> moveTime = const Value.absent(),
          Value<String?> patch = const Value.absent()}) =>
      OccurrenceException(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
        originalDate: originalDate ?? this.originalDate,
        kind: kind ?? this.kind,
        moveDate: moveDate.present ? moveDate.value : this.moveDate,
        moveTime: moveTime.present ? moveTime.value : this.moveTime,
        patch: patch.present ? patch.value : this.patch,
      );
  OccurrenceException copyWithCompanion(OccurrenceExceptionsCompanion data) {
    return OccurrenceException(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      subjectType:
          data.subjectType.present ? data.subjectType.value : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      kind: data.kind.present ? data.kind.value : this.kind,
      moveDate: data.moveDate.present ? data.moveDate.value : this.moveDate,
      moveTime: data.moveTime.present ? data.moveTime.value : this.moveTime,
      patch: data.patch.present ? data.patch.value : this.patch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceException(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('originalDate: $originalDate, ')
          ..write('kind: $kind, ')
          ..write('moveDate: $moveDate, ')
          ..write('moveTime: $moveTime, ')
          ..write('patch: $patch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      subjectType,
      subjectId,
      originalDate,
      kind,
      moveDate,
      moveTime,
      patch);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OccurrenceException &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.originalDate == this.originalDate &&
          other.kind == this.kind &&
          other.moveDate == this.moveDate &&
          other.moveTime == this.moveTime &&
          other.patch == this.patch);
}

class OccurrenceExceptionsCompanion
    extends UpdateCompanion<OccurrenceException> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> subjectType;
  final Value<String> subjectId;
  final Value<String> originalDate;
  final Value<String> kind;
  final Value<String?> moveDate;
  final Value<String?> moveTime;
  final Value<String?> patch;
  final Value<int> rowid;
  const OccurrenceExceptionsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.kind = const Value.absent(),
    this.moveDate = const Value.absent(),
    this.moveTime = const Value.absent(),
    this.patch = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccurrenceExceptionsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String subjectType,
    required String subjectId,
    required String originalDate,
    required String kind,
    this.moveDate = const Value.absent(),
    this.moveTime = const Value.absent(),
    this.patch = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        subjectType = Value(subjectType),
        subjectId = Value(subjectId),
        originalDate = Value(originalDate),
        kind = Value(kind);
  static Insertable<OccurrenceException> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? subjectType,
    Expression<String>? subjectId,
    Expression<String>? originalDate,
    Expression<String>? kind,
    Expression<String>? moveDate,
    Expression<String>? moveTime,
    Expression<String>? patch,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (originalDate != null) 'original_date': originalDate,
      if (kind != null) 'kind': kind,
      if (moveDate != null) 'move_date': moveDate,
      if (moveTime != null) 'move_time': moveTime,
      if (patch != null) 'patch': patch,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccurrenceExceptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? subjectType,
      Value<String>? subjectId,
      Value<String>? originalDate,
      Value<String>? kind,
      Value<String?>? moveDate,
      Value<String?>? moveTime,
      Value<String?>? patch,
      Value<int>? rowid}) {
    return OccurrenceExceptionsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      originalDate: originalDate ?? this.originalDate,
      kind: kind ?? this.kind,
      moveDate: moveDate ?? this.moveDate,
      moveTime: moveTime ?? this.moveTime,
      patch: patch ?? this.patch,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<String>(originalDate.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (moveDate.present) {
      map['move_date'] = Variable<String>(moveDate.value);
    }
    if (moveTime.present) {
      map['move_time'] = Variable<String>(moveTime.value);
    }
    if (patch.present) {
      map['patch'] = Variable<String>(patch.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('originalDate: $originalDate, ')
          ..write('kind: $kind, ')
          ..write('moveDate: $moveDate, ')
          ..write('moveTime: $moveTime, ')
          ..write('patch: $patch, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccurrenceCompletionsTable extends OccurrenceCompletions
    with TableInfo<$OccurrenceCompletionsTable, OccurrenceCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccurrenceCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalDateMeta =
      const VerificationMeta('originalDate');
  @override
  late final GeneratedColumn<String> originalDate = GeneratedColumn<String>(
      'original_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        taskId,
        originalDate,
        completedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occurrence_completions';
  @override
  VerificationContext validateIntegrity(
      Insertable<OccurrenceCompletion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('original_date')) {
      context.handle(
          _originalDateMeta,
          originalDate.isAcceptableOrUnknown(
              data['original_date']!, _originalDateMeta));
    } else if (isInserting) {
      context.missing(_originalDateMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OccurrenceCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OccurrenceCompletion(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      originalDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_date'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])!,
    );
  }

  @override
  $OccurrenceCompletionsTable createAlias(String alias) {
    return $OccurrenceCompletionsTable(attachedDatabase, alias);
  }
}

class OccurrenceCompletion extends DataClass
    implements Insertable<OccurrenceCompletion> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String taskId;
  final String originalDate;
  final DateTime completedAt;
  const OccurrenceCompletion(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.taskId,
      required this.originalDate,
      required this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['task_id'] = Variable<String>(taskId);
    map['original_date'] = Variable<String>(originalDate);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  OccurrenceCompletionsCompanion toCompanion(bool nullToAbsent) {
    return OccurrenceCompletionsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      taskId: Value(taskId),
      originalDate: Value(originalDate),
      completedAt: Value(completedAt),
    );
  }

  factory OccurrenceCompletion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OccurrenceCompletion(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      taskId: serializer.fromJson<String>(json['taskId']),
      originalDate: serializer.fromJson<String>(json['originalDate']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'taskId': serializer.toJson<String>(taskId),
      'originalDate': serializer.toJson<String>(originalDate),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  OccurrenceCompletion copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? taskId,
          String? originalDate,
          DateTime? completedAt}) =>
      OccurrenceCompletion(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        taskId: taskId ?? this.taskId,
        originalDate: originalDate ?? this.originalDate,
        completedAt: completedAt ?? this.completedAt,
      );
  OccurrenceCompletion copyWithCompanion(OccurrenceCompletionsCompanion data) {
    return OccurrenceCompletion(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceCompletion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('originalDate: $originalDate, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      taskId,
      originalDate,
      completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OccurrenceCompletion &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.taskId == this.taskId &&
          other.originalDate == this.originalDate &&
          other.completedAt == this.completedAt);
}

class OccurrenceCompletionsCompanion
    extends UpdateCompanion<OccurrenceCompletion> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> taskId;
  final Value<String> originalDate;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const OccurrenceCompletionsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.taskId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccurrenceCompletionsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String taskId,
    required String originalDate,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        taskId = Value(taskId),
        originalDate = Value(originalDate),
        completedAt = Value(completedAt);
  static Insertable<OccurrenceCompletion> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? taskId,
    Expression<String>? originalDate,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (taskId != null) 'task_id': taskId,
      if (originalDate != null) 'original_date': originalDate,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccurrenceCompletionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? taskId,
      Value<String>? originalDate,
      Value<DateTime>? completedAt,
      Value<int>? rowid}) {
    return OccurrenceCompletionsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      taskId: taskId ?? this.taskId,
      originalDate: originalDate ?? this.originalDate,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<String>(originalDate.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceCompletionsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('originalDate: $originalDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subjectTypeMeta =
      const VerificationMeta('subjectType');
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
      'subject_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectIdMeta =
      const VerificationMeta('subjectId');
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
      'subject_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _offsetMinutesMeta =
      const VerificationMeta('offsetMinutes');
  @override
  late final GeneratedColumn<int> offsetMinutes = GeneratedColumn<int>(
      'offset_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _atUtcMeta = const VerificationMeta('atUtc');
  @override
  late final GeneratedColumn<DateTime> atUtc = GeneratedColumn<DateTime>(
      'at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        subjectType,
        subjectId,
        offsetMinutes,
        atUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(Insertable<Reminder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
          _subjectTypeMeta,
          subjectType.isAcceptableOrUnknown(
              data['subject_type']!, _subjectTypeMeta));
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(_subjectIdMeta,
          subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta));
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('offset_minutes')) {
      context.handle(
          _offsetMinutesMeta,
          offsetMinutes.isAcceptableOrUnknown(
              data['offset_minutes']!, _offsetMinutesMeta));
    }
    if (data.containsKey('at_utc')) {
      context.handle(
          _atUtcMeta, atUtc.isAcceptableOrUnknown(data['at_utc']!, _atUtcMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      subjectType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_type'])!,
      subjectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_id'])!,
      offsetMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}offset_minutes']),
      atUtc: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}at_utc']),
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String subjectType;
  final String subjectId;
  final int? offsetMinutes;
  final DateTime? atUtc;
  const Reminder(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.subjectType,
      required this.subjectId,
      this.offsetMinutes,
      this.atUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<String>(subjectId);
    if (!nullToAbsent || offsetMinutes != null) {
      map['offset_minutes'] = Variable<int>(offsetMinutes);
    }
    if (!nullToAbsent || atUtc != null) {
      map['at_utc'] = Variable<DateTime>(atUtc);
    }
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      offsetMinutes: offsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(offsetMinutes),
      atUtc:
          atUtc == null && nullToAbsent ? const Value.absent() : Value(atUtc),
    );
  }

  factory Reminder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      offsetMinutes: serializer.fromJson<int?>(json['offsetMinutes']),
      atUtc: serializer.fromJson<DateTime?>(json['atUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<String>(subjectId),
      'offsetMinutes': serializer.toJson<int?>(offsetMinutes),
      'atUtc': serializer.toJson<DateTime?>(atUtc),
    };
  }

  Reminder copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? subjectType,
          String? subjectId,
          Value<int?> offsetMinutes = const Value.absent(),
          Value<DateTime?> atUtc = const Value.absent()}) =>
      Reminder(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
        offsetMinutes:
            offsetMinutes.present ? offsetMinutes.value : this.offsetMinutes,
        atUtc: atUtc.present ? atUtc.value : this.atUtc,
      );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      subjectType:
          data.subjectType.present ? data.subjectType.value : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      offsetMinutes: data.offsetMinutes.present
          ? data.offsetMinutes.value
          : this.offsetMinutes,
      atUtc: data.atUtc.present ? data.atUtc.value : this.atUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('atUtc: $atUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      subjectType,
      subjectId,
      offsetMinutes,
      atUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.offsetMinutes == this.offsetMinutes &&
          other.atUtc == this.atUtc);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> subjectType;
  final Value<String> subjectId;
  final Value<int?> offsetMinutes;
  final Value<DateTime?> atUtc;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.atUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String subjectType,
    required String subjectId,
    this.offsetMinutes = const Value.absent(),
    this.atUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        subjectType = Value(subjectType),
        subjectId = Value(subjectId);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? subjectType,
    Expression<String>? subjectId,
    Expression<int>? offsetMinutes,
    Expression<DateTime>? atUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (offsetMinutes != null) 'offset_minutes': offsetMinutes,
      if (atUtc != null) 'at_utc': atUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? subjectType,
      Value<String>? subjectId,
      Value<int?>? offsetMinutes,
      Value<DateTime?>? atUtc,
      Value<int>? rowid}) {
    return RemindersCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      atUtc: atUtc ?? this.atUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (offsetMinutes.present) {
      map['offset_minutes'] = Variable<int>(offsetMinutes.value);
    }
    if (atUtc.present) {
      map['at_utc'] = Variable<DateTime>(atUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('atUtc: $atUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurrenceDateMeta =
      const VerificationMeta('occurrenceDate');
  @override
  late final GeneratedColumn<String> occurrenceDate = GeneratedColumn<String>(
      'occurrence_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _plannedMsMeta =
      const VerificationMeta('plannedMs');
  @override
  late final GeneratedColumn<int> plannedMs = GeneratedColumn<int>(
      'planned_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pausedMsMeta =
      const VerificationMeta('pausedMs');
  @override
  late final GeneratedColumn<int> pausedMs = GeneratedColumn<int>(
      'paused_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _pausedAtMeta =
      const VerificationMeta('pausedAt');
  @override
  late final GeneratedColumn<int> pausedAt = GeneratedColumn<int>(
      'paused_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        taskId,
        occurrenceDate,
        mode,
        state,
        startedAt,
        plannedMs,
        pausedMs,
        pausedAt,
        endedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<FocusSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
          _occurrenceDateMeta,
          occurrenceDate.isAcceptableOrUnknown(
              data['occurrence_date']!, _occurrenceDateMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('planned_ms')) {
      context.handle(_plannedMsMeta,
          plannedMs.isAcceptableOrUnknown(data['planned_ms']!, _plannedMsMeta));
    }
    if (data.containsKey('paused_ms')) {
      context.handle(_pausedMsMeta,
          pausedMs.isAcceptableOrUnknown(data['paused_ms']!, _pausedMsMeta));
    }
    if (data.containsKey('paused_at')) {
      context.handle(_pausedAtMeta,
          pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta));
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id']),
      occurrenceDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurrence_date']),
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      plannedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}planned_ms']),
      pausedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paused_ms'])!,
      pausedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paused_at']),
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ended_at']),
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String? taskId;
  final String? occurrenceDate;
  final String mode;
  final String state;
  final int startedAt;
  final int? plannedMs;
  final int pausedMs;
  final int? pausedAt;
  final int? endedAt;
  const FocusSessionRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      this.taskId,
      this.occurrenceDate,
      required this.mode,
      required this.state,
      required this.startedAt,
      this.plannedMs,
      required this.pausedMs,
      this.pausedAt,
      this.endedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || occurrenceDate != null) {
      map['occurrence_date'] = Variable<String>(occurrenceDate);
    }
    map['mode'] = Variable<String>(mode);
    map['state'] = Variable<String>(state);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || plannedMs != null) {
      map['planned_ms'] = Variable<int>(plannedMs);
    }
    map['paused_ms'] = Variable<int>(pausedMs);
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<int>(pausedAt);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      taskId:
          taskId == null && nullToAbsent ? const Value.absent() : Value(taskId),
      occurrenceDate: occurrenceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceDate),
      mode: Value(mode),
      state: Value(state),
      startedAt: Value(startedAt),
      plannedMs: plannedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedMs),
      pausedMs: Value(pausedMs),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory FocusSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      occurrenceDate: serializer.fromJson<String?>(json['occurrenceDate']),
      mode: serializer.fromJson<String>(json['mode']),
      state: serializer.fromJson<String>(json['state']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      plannedMs: serializer.fromJson<int?>(json['plannedMs']),
      pausedMs: serializer.fromJson<int>(json['pausedMs']),
      pausedAt: serializer.fromJson<int?>(json['pausedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'taskId': serializer.toJson<String?>(taskId),
      'occurrenceDate': serializer.toJson<String?>(occurrenceDate),
      'mode': serializer.toJson<String>(mode),
      'state': serializer.toJson<String>(state),
      'startedAt': serializer.toJson<int>(startedAt),
      'plannedMs': serializer.toJson<int?>(plannedMs),
      'pausedMs': serializer.toJson<int>(pausedMs),
      'pausedAt': serializer.toJson<int?>(pausedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
    };
  }

  FocusSessionRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          Value<String?> taskId = const Value.absent(),
          Value<String?> occurrenceDate = const Value.absent(),
          String? mode,
          String? state,
          int? startedAt,
          Value<int?> plannedMs = const Value.absent(),
          int? pausedMs,
          Value<int?> pausedAt = const Value.absent(),
          Value<int?> endedAt = const Value.absent()}) =>
      FocusSessionRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        taskId: taskId.present ? taskId.value : this.taskId,
        occurrenceDate:
            occurrenceDate.present ? occurrenceDate.value : this.occurrenceDate,
        mode: mode ?? this.mode,
        state: state ?? this.state,
        startedAt: startedAt ?? this.startedAt,
        plannedMs: plannedMs.present ? plannedMs.value : this.plannedMs,
        pausedMs: pausedMs ?? this.pausedMs,
        pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
      );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      mode: data.mode.present ? data.mode.value : this.mode,
      state: data.state.present ? data.state.value : this.state,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      plannedMs: data.plannedMs.present ? data.plannedMs.value : this.plannedMs,
      pausedMs: data.pausedMs.present ? data.pausedMs.value : this.pausedMs,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('mode: $mode, ')
          ..write('state: $state, ')
          ..write('startedAt: $startedAt, ')
          ..write('plannedMs: $plannedMs, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      taskId,
      occurrenceDate,
      mode,
      state,
      startedAt,
      plannedMs,
      pausedMs,
      pausedAt,
      endedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.taskId == this.taskId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.mode == this.mode &&
          other.state == this.state &&
          other.startedAt == this.startedAt &&
          other.plannedMs == this.plannedMs &&
          other.pausedMs == this.pausedMs &&
          other.pausedAt == this.pausedAt &&
          other.endedAt == this.endedAt);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String?> taskId;
  final Value<String?> occurrenceDate;
  final Value<String> mode;
  final Value<String> state;
  final Value<int> startedAt;
  final Value<int?> plannedMs;
  final Value<int> pausedMs;
  final Value<int?> pausedAt;
  final Value<int?> endedAt;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.mode = const Value.absent(),
    this.state = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.plannedMs = const Value.absent(),
    this.pausedMs = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    required String mode,
    required String state,
    required int startedAt,
    this.plannedMs = const Value.absent(),
    this.pausedMs = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        mode = Value(mode),
        state = Value(state),
        startedAt = Value(startedAt);
  static Insertable<FocusSessionRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? taskId,
    Expression<String>? occurrenceDate,
    Expression<String>? mode,
    Expression<String>? state,
    Expression<int>? startedAt,
    Expression<int>? plannedMs,
    Expression<int>? pausedMs,
    Expression<int>? pausedAt,
    Expression<int>? endedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (mode != null) 'mode': mode,
      if (state != null) 'state': state,
      if (startedAt != null) 'started_at': startedAt,
      if (plannedMs != null) 'planned_ms': plannedMs,
      if (pausedMs != null) 'paused_ms': pausedMs,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String?>? taskId,
      Value<String?>? occurrenceDate,
      Value<String>? mode,
      Value<String>? state,
      Value<int>? startedAt,
      Value<int?>? plannedMs,
      Value<int>? pausedMs,
      Value<int?>? pausedAt,
      Value<int?>? endedAt,
      Value<int>? rowid}) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      taskId: taskId ?? this.taskId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      mode: mode ?? this.mode,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      plannedMs: plannedMs ?? this.plannedMs,
      pausedMs: pausedMs ?? this.pausedMs,
      pausedAt: pausedAt ?? this.pausedAt,
      endedAt: endedAt ?? this.endedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<String>(occurrenceDate.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (plannedMs.present) {
      map['planned_ms'] = Variable<int>(plannedMs.value);
    }
    if (pausedMs.present) {
      map['paused_ms'] = Variable<int>(pausedMs.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<int>(pausedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('mode: $mode, ')
          ..write('state: $state, ')
          ..write('startedAt: $startedAt, ')
          ..write('plannedMs: $plannedMs, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExecutionRecordsTable extends ExecutionRecords
    with TableInfo<$ExecutionRecordsTable, ExecutionRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExecutionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurrenceDateMeta =
      const VerificationMeta('occurrenceDate');
  @override
  late final GeneratedColumn<String> occurrenceDate = GeneratedColumn<String>(
      'occurrence_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actualStartMeta =
      const VerificationMeta('actualStart');
  @override
  late final GeneratedColumn<DateTime> actualStart = GeneratedColumn<DateTime>(
      'actual_start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _actualEndMeta =
      const VerificationMeta('actualEnd');
  @override
  late final GeneratedColumn<DateTime> actualEnd = GeneratedColumn<DateTime>(
      'actual_end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _focusMsMeta =
      const VerificationMeta('focusMs');
  @override
  late final GeneratedColumn<int> focusMs = GeneratedColumn<int>(
      'focus_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        sessionId,
        taskId,
        occurrenceDate,
        actualStart,
        actualEnd,
        focusMs,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'execution_records';
  @override
  VerificationContext validateIntegrity(Insertable<ExecutionRecordRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
          _occurrenceDateMeta,
          occurrenceDate.isAcceptableOrUnknown(
              data['occurrence_date']!, _occurrenceDateMeta));
    }
    if (data.containsKey('actual_start')) {
      context.handle(
          _actualStartMeta,
          actualStart.isAcceptableOrUnknown(
              data['actual_start']!, _actualStartMeta));
    } else if (isInserting) {
      context.missing(_actualStartMeta);
    }
    if (data.containsKey('actual_end')) {
      context.handle(_actualEndMeta,
          actualEnd.isAcceptableOrUnknown(data['actual_end']!, _actualEndMeta));
    } else if (isInserting) {
      context.missing(_actualEndMeta);
    }
    if (data.containsKey('focus_ms')) {
      context.handle(_focusMsMeta,
          focusMs.isAcceptableOrUnknown(data['focus_ms']!, _focusMsMeta));
    } else if (isInserting) {
      context.missing(_focusMsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExecutionRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExecutionRecordRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id']),
      occurrenceDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurrence_date']),
      actualStart: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}actual_start'])!,
      actualEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}actual_end'])!,
      focusMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}focus_ms'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $ExecutionRecordsTable createAlias(String alias) {
    return $ExecutionRecordsTable(attachedDatabase, alias);
  }
}

class ExecutionRecordRow extends DataClass
    implements Insertable<ExecutionRecordRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String? sessionId;
  final String? taskId;
  final String? occurrenceDate;
  final DateTime actualStart;
  final DateTime actualEnd;
  final int focusMs;
  final String? note;
  const ExecutionRecordRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      this.sessionId,
      this.taskId,
      this.occurrenceDate,
      required this.actualStart,
      required this.actualEnd,
      required this.focusMs,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || occurrenceDate != null) {
      map['occurrence_date'] = Variable<String>(occurrenceDate);
    }
    map['actual_start'] = Variable<DateTime>(actualStart);
    map['actual_end'] = Variable<DateTime>(actualEnd);
    map['focus_ms'] = Variable<int>(focusMs);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ExecutionRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExecutionRecordsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      taskId:
          taskId == null && nullToAbsent ? const Value.absent() : Value(taskId),
      occurrenceDate: occurrenceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceDate),
      actualStart: Value(actualStart),
      actualEnd: Value(actualEnd),
      focusMs: Value(focusMs),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ExecutionRecordRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExecutionRecordRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      occurrenceDate: serializer.fromJson<String?>(json['occurrenceDate']),
      actualStart: serializer.fromJson<DateTime>(json['actualStart']),
      actualEnd: serializer.fromJson<DateTime>(json['actualEnd']),
      focusMs: serializer.fromJson<int>(json['focusMs']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'sessionId': serializer.toJson<String?>(sessionId),
      'taskId': serializer.toJson<String?>(taskId),
      'occurrenceDate': serializer.toJson<String?>(occurrenceDate),
      'actualStart': serializer.toJson<DateTime>(actualStart),
      'actualEnd': serializer.toJson<DateTime>(actualEnd),
      'focusMs': serializer.toJson<int>(focusMs),
      'note': serializer.toJson<String?>(note),
    };
  }

  ExecutionRecordRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          Value<String?> sessionId = const Value.absent(),
          Value<String?> taskId = const Value.absent(),
          Value<String?> occurrenceDate = const Value.absent(),
          DateTime? actualStart,
          DateTime? actualEnd,
          int? focusMs,
          Value<String?> note = const Value.absent()}) =>
      ExecutionRecordRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        taskId: taskId.present ? taskId.value : this.taskId,
        occurrenceDate:
            occurrenceDate.present ? occurrenceDate.value : this.occurrenceDate,
        actualStart: actualStart ?? this.actualStart,
        actualEnd: actualEnd ?? this.actualEnd,
        focusMs: focusMs ?? this.focusMs,
        note: note.present ? note.value : this.note,
      );
  ExecutionRecordRow copyWithCompanion(ExecutionRecordsCompanion data) {
    return ExecutionRecordRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      actualStart:
          data.actualStart.present ? data.actualStart.value : this.actualStart,
      actualEnd: data.actualEnd.present ? data.actualEnd.value : this.actualEnd,
      focusMs: data.focusMs.present ? data.focusMs.value : this.focusMs,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionRecordRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('sessionId: $sessionId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('actualStart: $actualStart, ')
          ..write('actualEnd: $actualEnd, ')
          ..write('focusMs: $focusMs, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      sessionId,
      taskId,
      occurrenceDate,
      actualStart,
      actualEnd,
      focusMs,
      note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExecutionRecordRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.sessionId == this.sessionId &&
          other.taskId == this.taskId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.actualStart == this.actualStart &&
          other.actualEnd == this.actualEnd &&
          other.focusMs == this.focusMs &&
          other.note == this.note);
}

class ExecutionRecordsCompanion extends UpdateCompanion<ExecutionRecordRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String?> sessionId;
  final Value<String?> taskId;
  final Value<String?> occurrenceDate;
  final Value<DateTime> actualStart;
  final Value<DateTime> actualEnd;
  final Value<int> focusMs;
  final Value<String?> note;
  final Value<int> rowid;
  const ExecutionRecordsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.actualStart = const Value.absent(),
    this.actualEnd = const Value.absent(),
    this.focusMs = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExecutionRecordsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    required DateTime actualStart,
    required DateTime actualEnd,
    required int focusMs,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        actualStart = Value(actualStart),
        actualEnd = Value(actualEnd),
        focusMs = Value(focusMs);
  static Insertable<ExecutionRecordRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? sessionId,
    Expression<String>? taskId,
    Expression<String>? occurrenceDate,
    Expression<DateTime>? actualStart,
    Expression<DateTime>? actualEnd,
    Expression<int>? focusMs,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (sessionId != null) 'session_id': sessionId,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (actualStart != null) 'actual_start': actualStart,
      if (actualEnd != null) 'actual_end': actualEnd,
      if (focusMs != null) 'focus_ms': focusMs,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExecutionRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String?>? sessionId,
      Value<String?>? taskId,
      Value<String?>? occurrenceDate,
      Value<DateTime>? actualStart,
      Value<DateTime>? actualEnd,
      Value<int>? focusMs,
      Value<String?>? note,
      Value<int>? rowid}) {
    return ExecutionRecordsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      sessionId: sessionId ?? this.sessionId,
      taskId: taskId ?? this.taskId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      focusMs: focusMs ?? this.focusMs,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<String>(occurrenceDate.value);
    }
    if (actualStart.present) {
      map['actual_start'] = Variable<DateTime>(actualStart.value);
    }
    if (actualEnd.present) {
      map['actual_end'] = Variable<DateTime>(actualEnd.value);
    }
    if (focusMs.present) {
      map['focus_ms'] = Variable<int>(focusMs.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionRecordsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('sessionId: $sessionId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('actualStart: $actualStart, ')
          ..write('actualEnd: $actualEnd, ')
          ..write('focusMs: $focusMs, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeasurementsTable extends Measurements
    with TableInfo<$MeasurementsTable, MeasurementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasurementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _localDateMeta =
      const VerificationMeta('localDate');
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
      'local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _supersedesIdMeta =
      const VerificationMeta('supersedesId');
  @override
  late final GeneratedColumn<String> supersedesId = GeneratedColumn<String>(
      'supersedes_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _withdrawnMeta =
      const VerificationMeta('withdrawn');
  @override
  late final GeneratedColumn<bool> withdrawn = GeneratedColumn<bool>(
      'withdrawn', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("withdrawn" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        taskId,
        value,
        localDate,
        recordedAt,
        source,
        deviceId,
        note,
        supersedesId,
        withdrawn,
        recordId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurements';
  @override
  VerificationContext validateIntegrity(Insertable<MeasurementRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(_localDateMeta,
          localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta));
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('supersedes_id')) {
      context.handle(
          _supersedesIdMeta,
          supersedesId.isAcceptableOrUnknown(
              data['supersedes_id']!, _supersedesIdMeta));
    }
    if (data.containsKey('withdrawn')) {
      context.handle(_withdrawnMeta,
          withdrawn.isAcceptableOrUnknown(data['withdrawn']!, _withdrawnMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeasurementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeasurementRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      localDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_date'])!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      supersedesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supersedes_id']),
      withdrawn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}withdrawn'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id']),
    );
  }

  @override
  $MeasurementsTable createAlias(String alias) {
    return $MeasurementsTable(attachedDatabase, alias);
  }
}

class MeasurementRow extends DataClass implements Insertable<MeasurementRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String taskId;
  final double value;
  final String localDate;
  final DateTime recordedAt;
  final String source;
  final String? deviceId;
  final String? note;
  final String? supersedesId;
  final bool withdrawn;
  final String? recordId;
  const MeasurementRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.taskId,
      required this.value,
      required this.localDate,
      required this.recordedAt,
      required this.source,
      this.deviceId,
      this.note,
      this.supersedesId,
      required this.withdrawn,
      this.recordId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['task_id'] = Variable<String>(taskId);
    map['value'] = Variable<double>(value);
    map['local_date'] = Variable<String>(localDate);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || supersedesId != null) {
      map['supersedes_id'] = Variable<String>(supersedesId);
    }
    map['withdrawn'] = Variable<bool>(withdrawn);
    if (!nullToAbsent || recordId != null) {
      map['record_id'] = Variable<String>(recordId);
    }
    return map;
  }

  MeasurementsCompanion toCompanion(bool nullToAbsent) {
    return MeasurementsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      taskId: Value(taskId),
      value: Value(value),
      localDate: Value(localDate),
      recordedAt: Value(recordedAt),
      source: Value(source),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      supersedesId: supersedesId == null && nullToAbsent
          ? const Value.absent()
          : Value(supersedesId),
      withdrawn: Value(withdrawn),
      recordId: recordId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordId),
    );
  }

  factory MeasurementRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeasurementRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      taskId: serializer.fromJson<String>(json['taskId']),
      value: serializer.fromJson<double>(json['value']),
      localDate: serializer.fromJson<String>(json['localDate']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      source: serializer.fromJson<String>(json['source']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      note: serializer.fromJson<String?>(json['note']),
      supersedesId: serializer.fromJson<String?>(json['supersedesId']),
      withdrawn: serializer.fromJson<bool>(json['withdrawn']),
      recordId: serializer.fromJson<String?>(json['recordId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'taskId': serializer.toJson<String>(taskId),
      'value': serializer.toJson<double>(value),
      'localDate': serializer.toJson<String>(localDate),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'source': serializer.toJson<String>(source),
      'deviceId': serializer.toJson<String?>(deviceId),
      'note': serializer.toJson<String?>(note),
      'supersedesId': serializer.toJson<String?>(supersedesId),
      'withdrawn': serializer.toJson<bool>(withdrawn),
      'recordId': serializer.toJson<String?>(recordId),
    };
  }

  MeasurementRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? taskId,
          double? value,
          String? localDate,
          DateTime? recordedAt,
          String? source,
          Value<String?> deviceId = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> supersedesId = const Value.absent(),
          bool? withdrawn,
          Value<String?> recordId = const Value.absent()}) =>
      MeasurementRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        taskId: taskId ?? this.taskId,
        value: value ?? this.value,
        localDate: localDate ?? this.localDate,
        recordedAt: recordedAt ?? this.recordedAt,
        source: source ?? this.source,
        deviceId: deviceId.present ? deviceId.value : this.deviceId,
        note: note.present ? note.value : this.note,
        supersedesId:
            supersedesId.present ? supersedesId.value : this.supersedesId,
        withdrawn: withdrawn ?? this.withdrawn,
        recordId: recordId.present ? recordId.value : this.recordId,
      );
  MeasurementRow copyWithCompanion(MeasurementsCompanion data) {
    return MeasurementRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      value: data.value.present ? data.value.value : this.value,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      source: data.source.present ? data.source.value : this.source,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      note: data.note.present ? data.note.value : this.note,
      supersedesId: data.supersedesId.present
          ? data.supersedesId.value
          : this.supersedesId,
      withdrawn: data.withdrawn.present ? data.withdrawn.value : this.withdrawn,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('value: $value, ')
          ..write('localDate: $localDate, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('source: $source, ')
          ..write('deviceId: $deviceId, ')
          ..write('note: $note, ')
          ..write('supersedesId: $supersedesId, ')
          ..write('withdrawn: $withdrawn, ')
          ..write('recordId: $recordId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      taskId,
      value,
      localDate,
      recordedAt,
      source,
      deviceId,
      note,
      supersedesId,
      withdrawn,
      recordId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeasurementRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.taskId == this.taskId &&
          other.value == this.value &&
          other.localDate == this.localDate &&
          other.recordedAt == this.recordedAt &&
          other.source == this.source &&
          other.deviceId == this.deviceId &&
          other.note == this.note &&
          other.supersedesId == this.supersedesId &&
          other.withdrawn == this.withdrawn &&
          other.recordId == this.recordId);
}

class MeasurementsCompanion extends UpdateCompanion<MeasurementRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> taskId;
  final Value<double> value;
  final Value<String> localDate;
  final Value<DateTime> recordedAt;
  final Value<String> source;
  final Value<String?> deviceId;
  final Value<String?> note;
  final Value<String?> supersedesId;
  final Value<bool> withdrawn;
  final Value<String?> recordId;
  final Value<int> rowid;
  const MeasurementsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.taskId = const Value.absent(),
    this.value = const Value.absent(),
    this.localDate = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.note = const Value.absent(),
    this.supersedesId = const Value.absent(),
    this.withdrawn = const Value.absent(),
    this.recordId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeasurementsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String taskId,
    required double value,
    required String localDate,
    required DateTime recordedAt,
    required String source,
    this.deviceId = const Value.absent(),
    this.note = const Value.absent(),
    this.supersedesId = const Value.absent(),
    this.withdrawn = const Value.absent(),
    this.recordId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        taskId = Value(taskId),
        value = Value(value),
        localDate = Value(localDate),
        recordedAt = Value(recordedAt),
        source = Value(source);
  static Insertable<MeasurementRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? taskId,
    Expression<double>? value,
    Expression<String>? localDate,
    Expression<DateTime>? recordedAt,
    Expression<String>? source,
    Expression<String>? deviceId,
    Expression<String>? note,
    Expression<String>? supersedesId,
    Expression<bool>? withdrawn,
    Expression<String>? recordId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (taskId != null) 'task_id': taskId,
      if (value != null) 'value': value,
      if (localDate != null) 'local_date': localDate,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (source != null) 'source': source,
      if (deviceId != null) 'device_id': deviceId,
      if (note != null) 'note': note,
      if (supersedesId != null) 'supersedes_id': supersedesId,
      if (withdrawn != null) 'withdrawn': withdrawn,
      if (recordId != null) 'record_id': recordId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeasurementsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? taskId,
      Value<double>? value,
      Value<String>? localDate,
      Value<DateTime>? recordedAt,
      Value<String>? source,
      Value<String?>? deviceId,
      Value<String?>? note,
      Value<String?>? supersedesId,
      Value<bool>? withdrawn,
      Value<String?>? recordId,
      Value<int>? rowid}) {
    return MeasurementsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      taskId: taskId ?? this.taskId,
      value: value ?? this.value,
      localDate: localDate ?? this.localDate,
      recordedAt: recordedAt ?? this.recordedAt,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      note: note ?? this.note,
      supersedesId: supersedesId ?? this.supersedesId,
      withdrawn: withdrawn ?? this.withdrawn,
      recordId: recordId ?? this.recordId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (supersedesId.present) {
      map['supersedes_id'] = Variable<String>(supersedesId.value);
    }
    if (withdrawn.present) {
      map['withdrawn'] = Variable<bool>(withdrawn.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('value: $value, ')
          ..write('localDate: $localDate, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('source: $source, ')
          ..write('deviceId: $deviceId, ')
          ..write('note: $note, ')
          ..write('supersedesId: $supersedesId, ')
          ..write('withdrawn: $withdrawn, ')
          ..write('recordId: $recordId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeriodResultsTable extends PeriodResults
    with TableInfo<$PeriodResultsTable, PeriodResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _periodKeyMeta =
      const VerificationMeta('periodKey');
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
      'period_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
      'target', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _evaluatedAtMeta =
      const VerificationMeta('evaluatedAt');
  @override
  late final GeneratedColumn<DateTime> evaluatedAt = GeneratedColumn<DateTime>(
      'evaluated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        taskId,
        periodKey,
        kind,
        outcome,
        value,
        target,
        evaluatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'period_results';
  @override
  VerificationContext validateIntegrity(Insertable<PeriodResultRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(_periodKeyMeta,
          periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta));
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta,
          target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('evaluated_at')) {
      context.handle(
          _evaluatedAtMeta,
          evaluatedAt.isAcceptableOrUnknown(
              data['evaluated_at']!, _evaluatedAtMeta));
    } else if (isInserting) {
      context.missing(_evaluatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeriodResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodResultRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      periodKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}period_key'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value']),
      target: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target']),
      evaluatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}evaluated_at'])!,
    );
  }

  @override
  $PeriodResultsTable createAlias(String alias) {
    return $PeriodResultsTable(attachedDatabase, alias);
  }
}

class PeriodResultRow extends DataClass implements Insertable<PeriodResultRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String taskId;
  final String periodKey;
  final String kind;
  final String outcome;
  final double? value;
  final String? target;
  final DateTime evaluatedAt;
  const PeriodResultRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.taskId,
      required this.periodKey,
      required this.kind,
      required this.outcome,
      this.value,
      this.target,
      required this.evaluatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['task_id'] = Variable<String>(taskId);
    map['period_key'] = Variable<String>(periodKey);
    map['kind'] = Variable<String>(kind);
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    map['evaluated_at'] = Variable<DateTime>(evaluatedAt);
    return map;
  }

  PeriodResultsCompanion toCompanion(bool nullToAbsent) {
    return PeriodResultsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      taskId: Value(taskId),
      periodKey: Value(periodKey),
      kind: Value(kind),
      outcome: Value(outcome),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
      target:
          target == null && nullToAbsent ? const Value.absent() : Value(target),
      evaluatedAt: Value(evaluatedAt),
    );
  }

  factory PeriodResultRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodResultRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      taskId: serializer.fromJson<String>(json['taskId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      kind: serializer.fromJson<String>(json['kind']),
      outcome: serializer.fromJson<String>(json['outcome']),
      value: serializer.fromJson<double?>(json['value']),
      target: serializer.fromJson<String?>(json['target']),
      evaluatedAt: serializer.fromJson<DateTime>(json['evaluatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'taskId': serializer.toJson<String>(taskId),
      'periodKey': serializer.toJson<String>(periodKey),
      'kind': serializer.toJson<String>(kind),
      'outcome': serializer.toJson<String>(outcome),
      'value': serializer.toJson<double?>(value),
      'target': serializer.toJson<String?>(target),
      'evaluatedAt': serializer.toJson<DateTime>(evaluatedAt),
    };
  }

  PeriodResultRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? taskId,
          String? periodKey,
          String? kind,
          String? outcome,
          Value<double?> value = const Value.absent(),
          Value<String?> target = const Value.absent(),
          DateTime? evaluatedAt}) =>
      PeriodResultRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        taskId: taskId ?? this.taskId,
        periodKey: periodKey ?? this.periodKey,
        kind: kind ?? this.kind,
        outcome: outcome ?? this.outcome,
        value: value.present ? value.value : this.value,
        target: target.present ? target.value : this.target,
        evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      );
  PeriodResultRow copyWithCompanion(PeriodResultsCompanion data) {
    return PeriodResultRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      value: data.value.present ? data.value.value : this.value,
      target: data.target.present ? data.target.value : this.target,
      evaluatedAt:
          data.evaluatedAt.present ? data.evaluatedAt.value : this.evaluatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeriodResultRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('periodKey: $periodKey, ')
          ..write('kind: $kind, ')
          ..write('outcome: $outcome, ')
          ..write('value: $value, ')
          ..write('target: $target, ')
          ..write('evaluatedAt: $evaluatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      taskId,
      periodKey,
      kind,
      outcome,
      value,
      target,
      evaluatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodResultRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.taskId == this.taskId &&
          other.periodKey == this.periodKey &&
          other.kind == this.kind &&
          other.outcome == this.outcome &&
          other.value == this.value &&
          other.target == this.target &&
          other.evaluatedAt == this.evaluatedAt);
}

class PeriodResultsCompanion extends UpdateCompanion<PeriodResultRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> taskId;
  final Value<String> periodKey;
  final Value<String> kind;
  final Value<String> outcome;
  final Value<double?> value;
  final Value<String?> target;
  final Value<DateTime> evaluatedAt;
  final Value<int> rowid;
  const PeriodResultsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.taskId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.outcome = const Value.absent(),
    this.value = const Value.absent(),
    this.target = const Value.absent(),
    this.evaluatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeriodResultsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String taskId,
    required String periodKey,
    required String kind,
    required String outcome,
    this.value = const Value.absent(),
    this.target = const Value.absent(),
    required DateTime evaluatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        taskId = Value(taskId),
        periodKey = Value(periodKey),
        kind = Value(kind),
        outcome = Value(outcome),
        evaluatedAt = Value(evaluatedAt);
  static Insertable<PeriodResultRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? taskId,
    Expression<String>? periodKey,
    Expression<String>? kind,
    Expression<String>? outcome,
    Expression<double>? value,
    Expression<String>? target,
    Expression<DateTime>? evaluatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (taskId != null) 'task_id': taskId,
      if (periodKey != null) 'period_key': periodKey,
      if (kind != null) 'kind': kind,
      if (outcome != null) 'outcome': outcome,
      if (value != null) 'value': value,
      if (target != null) 'target': target,
      if (evaluatedAt != null) 'evaluated_at': evaluatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeriodResultsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? taskId,
      Value<String>? periodKey,
      Value<String>? kind,
      Value<String>? outcome,
      Value<double?>? value,
      Value<String?>? target,
      Value<DateTime>? evaluatedAt,
      Value<int>? rowid}) {
    return PeriodResultsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      taskId: taskId ?? this.taskId,
      periodKey: periodKey ?? this.periodKey,
      kind: kind ?? this.kind,
      outcome: outcome ?? this.outcome,
      value: value ?? this.value,
      target: target ?? this.target,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (evaluatedAt.present) {
      map['evaluated_at'] = Variable<DateTime>(evaluatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeriodResultsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('taskId: $taskId, ')
          ..write('periodKey: $periodKey, ')
          ..write('kind: $kind, ')
          ..write('outcome: $outcome, ')
          ..write('value: $value, ')
          ..write('target: $target, ')
          ..write('evaluatedAt: $evaluatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
      'start_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<String> targetDate = GeneratedColumn<String>(
      'target_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        kind,
        title,
        description,
        status,
        startDate,
        targetDate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(Insertable<GoalRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_date']),
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_date']),
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String kind;
  final String title;
  final String? description;
  final String status;
  final String? startDate;
  final String? targetDate;
  const GoalRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.kind,
      required this.title,
      this.description,
      required this.status,
      this.startDate,
      this.targetDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<String>(targetDate);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      kind: Value(kind),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
    );
  }

  factory GoalRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      targetDate: serializer.fromJson<String?>(json['targetDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'startDate': serializer.toJson<String?>(startDate),
      'targetDate': serializer.toJson<String?>(targetDate),
    };
  }

  GoalRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? kind,
          String? title,
          Value<String?> description = const Value.absent(),
          String? status,
          Value<String?> startDate = const Value.absent(),
          Value<String?> targetDate = const Value.absent()}) =>
      GoalRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        status: status ?? this.status,
        startDate: startDate.present ? startDate.value : this.startDate,
        targetDate: targetDate.present ? targetDate.value : this.targetDate,
      );
  GoalRow copyWithCompanion(GoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      kind,
      title,
      description,
      status,
      startDate,
      targetDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.startDate == this.startDate &&
          other.targetDate == this.targetDate);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> status;
  final Value<String?> startDate;
  final Value<String?> targetDate;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String kind,
    required String title,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        kind = Value(kind),
        title = Value(title);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<String>? startDate,
    Expression<String>? targetDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': startDate,
      if (targetDate != null) 'target_date': targetDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? kind,
      Value<String>? title,
      Value<String?>? description,
      Value<String>? status,
      Value<String?>? startDate,
      Value<String?>? targetDate,
      Value<int>? rowid}) {
    return GoalsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<String>(targetDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MilestonesTable extends Milestones
    with TableInfo<$MilestonesTable, MilestoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MilestonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
      'goal_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
      'due_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        goalId,
        title,
        dueDate,
        isCompleted,
        completedAt,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'milestones';
  @override
  VerificationContext validateIntegrity(Insertable<MilestoneRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('goal_id')) {
      context.handle(_goalIdMeta,
          goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta));
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MilestoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MilestoneRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      goalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}due_date']),
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $MilestonesTable createAlias(String alias) {
    return $MilestonesTable(attachedDatabase, alias);
  }
}

class MilestoneRow extends DataClass implements Insertable<MilestoneRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String goalId;
  final String title;
  final String? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int sortOrder;
  const MilestoneRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.goalId,
      required this.title,
      this.dueDate,
      required this.isCompleted,
      this.completedAt,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['goal_id'] = Variable<String>(goalId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  MilestonesCompanion toCompanion(bool nullToAbsent) {
    return MilestonesCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      goalId: Value(goalId),
      title: Value(title),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      isCompleted: Value(isCompleted),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory MilestoneRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MilestoneRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      goalId: serializer.fromJson<String>(json['goalId']),
      title: serializer.fromJson<String>(json['title']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'goalId': serializer.toJson<String>(goalId),
      'title': serializer.toJson<String>(title),
      'dueDate': serializer.toJson<String?>(dueDate),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  MilestoneRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? goalId,
          String? title,
          Value<String?> dueDate = const Value.absent(),
          bool? isCompleted,
          Value<DateTime?> completedAt = const Value.absent(),
          int? sortOrder}) =>
      MilestoneRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        goalId: goalId ?? this.goalId,
        title: title ?? this.title,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  MilestoneRow copyWithCompanion(MilestonesCompanion data) {
    return MilestoneRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      title: data.title.present ? data.title.value : this.title,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MilestoneRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('goalId: $goalId, ')
          ..write('title: $title, ')
          ..write('dueDate: $dueDate, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      ownerId,
      version,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      changedBy,
      goalId,
      title,
      dueDate,
      isCompleted,
      completedAt,
      sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MilestoneRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.goalId == this.goalId &&
          other.title == this.title &&
          other.dueDate == this.dueDate &&
          other.isCompleted == this.isCompleted &&
          other.completedAt == this.completedAt &&
          other.sortOrder == this.sortOrder);
}

class MilestonesCompanion extends UpdateCompanion<MilestoneRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> goalId;
  final Value<String> title;
  final Value<String?> dueDate;
  final Value<bool> isCompleted;
  final Value<DateTime?> completedAt;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const MilestonesCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.goalId = const Value.absent(),
    this.title = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MilestonesCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String goalId,
    required String title,
    this.dueDate = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        goalId = Value(goalId),
        title = Value(title);
  static Insertable<MilestoneRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? goalId,
    Expression<String>? title,
    Expression<String>? dueDate,
    Expression<bool>? isCompleted,
    Expression<DateTime>? completedAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (goalId != null) 'goal_id': goalId,
      if (title != null) 'title': title,
      if (dueDate != null) 'due_date': dueDate,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MilestonesCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? goalId,
      Value<String>? title,
      Value<String?>? dueDate,
      Value<bool>? isCompleted,
      Value<DateTime?>? completedAt,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return MilestonesCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MilestonesCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('goalId: $goalId, ')
          ..write('title: $title, ')
          ..write('dueDate: $dueDate, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalLinksTable extends GoalLinks
    with TableInfo<$GoalLinksTable, GoalLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
      'goal_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemTypeMeta =
      const VerificationMeta('itemType');
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
      'item_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        goalId,
        itemType,
        itemId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_links';
  @override
  VerificationContext validateIntegrity(Insertable<GoalLinkRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('goal_id')) {
      context.handle(_goalIdMeta,
          goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta));
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(_itemTypeMeta,
          itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta));
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalLinkRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      goalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_id'])!,
      itemType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_type'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
    );
  }

  @override
  $GoalLinksTable createAlias(String alias) {
    return $GoalLinksTable(attachedDatabase, alias);
  }
}

class GoalLinkRow extends DataClass implements Insertable<GoalLinkRow> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String goalId;
  final String itemType;
  final String itemId;
  const GoalLinkRow(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.goalId,
      required this.itemType,
      required this.itemId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['goal_id'] = Variable<String>(goalId);
    map['item_type'] = Variable<String>(itemType);
    map['item_id'] = Variable<String>(itemId);
    return map;
  }

  GoalLinksCompanion toCompanion(bool nullToAbsent) {
    return GoalLinksCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      goalId: Value(goalId),
      itemType: Value(itemType),
      itemId: Value(itemId),
    );
  }

  factory GoalLinkRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalLinkRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      goalId: serializer.fromJson<String>(json['goalId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      itemId: serializer.fromJson<String>(json['itemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'goalId': serializer.toJson<String>(goalId),
      'itemType': serializer.toJson<String>(itemType),
      'itemId': serializer.toJson<String>(itemId),
    };
  }

  GoalLinkRow copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? goalId,
          String? itemType,
          String? itemId}) =>
      GoalLinkRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        goalId: goalId ?? this.goalId,
        itemType: itemType ?? this.itemType,
        itemId: itemId ?? this.itemId,
      );
  GoalLinkRow copyWithCompanion(GoalLinksCompanion data) {
    return GoalLinkRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalLinkRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('goalId: $goalId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, ownerId, version, createdAt,
      updatedAt, deletedAt, deletedBy, changedBy, goalId, itemType, itemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalLinkRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.goalId == this.goalId &&
          other.itemType == this.itemType &&
          other.itemId == this.itemId);
}

class GoalLinksCompanion extends UpdateCompanion<GoalLinkRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> goalId;
  final Value<String> itemType;
  final Value<String> itemId;
  final Value<int> rowid;
  const GoalLinksCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.goalId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.itemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalLinksCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    required String goalId,
    required String itemType,
    required String itemId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        goalId = Value(goalId),
        itemType = Value(itemType),
        itemId = Value(itemId);
  static Insertable<GoalLinkRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? goalId,
    Expression<String>? itemType,
    Expression<String>? itemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (goalId != null) 'goal_id': goalId,
      if (itemType != null) 'item_type': itemType,
      if (itemId != null) 'item_id': itemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalLinksCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? goalId,
      Value<String>? itemType,
      Value<String>? itemId,
      Value<int>? rowid}) {
    return GoalLinksCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      goalId: goalId ?? this.goalId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalLinksCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('goalId: $goalId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspaceSettingsTable extends WorkspaceSettings
    with TableInfo<$WorkspaceSettingsTable, WorkspaceSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changedByMeta =
      const VerificationMeta('changedBy');
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
      'changed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _manualResultsMeta =
      const VerificationMeta('manualResults');
  @override
  late final GeneratedColumn<String> manualResults = GeneratedColumn<String>(
      'manual_results', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('target'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        ownerId,
        version,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        changedBy,
        manualResults,
        name
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_settings';
  @override
  VerificationContext validateIntegrity(Insertable<WorkspaceSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('changed_by')) {
      context.handle(_changedByMeta,
          changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta));
    }
    if (data.containsKey('manual_results')) {
      context.handle(
          _manualResultsMeta,
          manualResults.isAcceptableOrUnknown(
              data['manual_results']!, _manualResultsMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      changedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_by']),
      manualResults: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manual_results'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
    );
  }

  @override
  $WorkspaceSettingsTable createAlias(String alias) {
    return $WorkspaceSettingsTable(attachedDatabase, alias);
  }
}

class WorkspaceSetting extends DataClass
    implements Insertable<WorkspaceSetting> {
  final String id;
  final String workspaceId;
  final String ownerId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? changedBy;
  final String manualResults;
  final String? name;
  const WorkspaceSetting(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      this.changedBy,
      required this.manualResults,
      this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['manual_results'] = Variable<String>(manualResults);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  WorkspaceSettingsCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceSettingsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      changedBy: changedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(changedBy),
      manualResults: Value(manualResults),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory WorkspaceSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceSetting(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      changedBy: serializer.fromJson<String?>(json['changedBy']),
      manualResults: serializer.fromJson<String>(json['manualResults']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'changedBy': serializer.toJson<String?>(changedBy),
      'manualResults': serializer.toJson<String>(manualResults),
      'name': serializer.toJson<String?>(name),
    };
  }

  WorkspaceSetting copyWith(
          {String? id,
          String? workspaceId,
          String? ownerId,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          Value<String?> changedBy = const Value.absent(),
          String? manualResults,
          Value<String?> name = const Value.absent()}) =>
      WorkspaceSetting(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        changedBy: changedBy.present ? changedBy.value : this.changedBy,
        manualResults: manualResults ?? this.manualResults,
        name: name.present ? name.value : this.name,
      );
  WorkspaceSetting copyWithCompanion(WorkspaceSettingsCompanion data) {
    return WorkspaceSetting(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      manualResults: data.manualResults.present
          ? data.manualResults.value
          : this.manualResults,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceSetting(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('manualResults: $manualResults, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, ownerId, version, createdAt,
      updatedAt, deletedAt, deletedBy, changedBy, manualResults, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceSetting &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.changedBy == this.changedBy &&
          other.manualResults == this.manualResults &&
          other.name == this.name);
}

class WorkspaceSettingsCompanion extends UpdateCompanion<WorkspaceSetting> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String?> changedBy;
  final Value<String> manualResults;
  final Value<String?> name;
  final Value<int> rowid;
  const WorkspaceSettingsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.manualResults = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspaceSettingsCompanion.insert({
    required String id,
    required String workspaceId,
    required String ownerId,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.manualResults = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<WorkspaceSetting> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? changedBy,
    Expression<String>? manualResults,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (changedBy != null) 'changed_by': changedBy,
      if (manualResults != null) 'manual_results': manualResults,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspaceSettingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? ownerId,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String?>? changedBy,
      Value<String>? manualResults,
      Value<String?>? name,
      Value<int>? rowid}) {
    return WorkspaceSettingsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      changedBy: changedBy ?? this.changedBy,
      manualResults: manualResults ?? this.manualResults,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (manualResults.present) {
      map['manual_results'] = Variable<String>(manualResults.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceSettingsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('changedBy: $changedBy, ')
          ..write('manualResults: $manualResults, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncBaseTable extends SyncBase
    with TableInfo<$SyncBaseTable, SyncBaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncBaseTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [kind, recordId, version, data, serverId, workspaceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_base';
  @override
  VerificationContext validateIntegrity(Insertable<SyncBaseRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId, kind, recordId};
  @override
  SyncBaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncBaseRow(
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
    );
  }

  @override
  $SyncBaseTable createAlias(String alias) {
    return $SyncBaseTable(attachedDatabase, alias);
  }
}

class SyncBaseRow extends DataClass implements Insertable<SyncBaseRow> {
  final String kind;
  final String recordId;
  final int version;
  final String data;
  final String? serverId;
  final String workspaceId;
  const SyncBaseRow(
      {required this.kind,
      required this.recordId,
      required this.version,
      required this.data,
      this.serverId,
      required this.workspaceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['record_id'] = Variable<String>(recordId);
    map['version'] = Variable<int>(version);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['workspace_id'] = Variable<String>(workspaceId);
    return map;
  }

  SyncBaseCompanion toCompanion(bool nullToAbsent) {
    return SyncBaseCompanion(
      kind: Value(kind),
      recordId: Value(recordId),
      version: Value(version),
      data: Value(data),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      workspaceId: Value(workspaceId),
    );
  }

  factory SyncBaseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncBaseRow(
      kind: serializer.fromJson<String>(json['kind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      version: serializer.fromJson<int>(json['version']),
      data: serializer.fromJson<String>(json['data']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'recordId': serializer.toJson<String>(recordId),
      'version': serializer.toJson<int>(version),
      'data': serializer.toJson<String>(data),
      'serverId': serializer.toJson<String?>(serverId),
      'workspaceId': serializer.toJson<String>(workspaceId),
    };
  }

  SyncBaseRow copyWith(
          {String? kind,
          String? recordId,
          int? version,
          String? data,
          Value<String?> serverId = const Value.absent(),
          String? workspaceId}) =>
      SyncBaseRow(
        kind: kind ?? this.kind,
        recordId: recordId ?? this.recordId,
        version: version ?? this.version,
        data: data ?? this.data,
        serverId: serverId.present ? serverId.value : this.serverId,
        workspaceId: workspaceId ?? this.workspaceId,
      );
  SyncBaseRow copyWithCompanion(SyncBaseCompanion data) {
    return SyncBaseRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      version: data.version.present ? data.version.value : this.version,
      data: data.data.present ? data.data.value : this.data,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncBaseRow(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version, ')
          ..write('data: $data, ')
          ..write('serverId: $serverId, ')
          ..write('workspaceId: $workspaceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(kind, recordId, version, data, serverId, workspaceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncBaseRow &&
          other.kind == this.kind &&
          other.recordId == this.recordId &&
          other.version == this.version &&
          other.data == this.data &&
          other.serverId == this.serverId &&
          other.workspaceId == this.workspaceId);
}

class SyncBaseCompanion extends UpdateCompanion<SyncBaseRow> {
  final Value<String> kind;
  final Value<String> recordId;
  final Value<int> version;
  final Value<String> data;
  final Value<String?> serverId;
  final Value<String> workspaceId;
  final Value<int> rowid;
  const SyncBaseCompanion({
    this.kind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.version = const Value.absent(),
    this.data = const Value.absent(),
    this.serverId = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncBaseCompanion.insert({
    required String kind,
    required String recordId,
    required int version,
    required String data,
    this.serverId = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : kind = Value(kind),
        recordId = Value(recordId),
        version = Value(version),
        data = Value(data);
  static Insertable<SyncBaseRow> custom({
    Expression<String>? kind,
    Expression<String>? recordId,
    Expression<int>? version,
    Expression<String>? data,
    Expression<String>? serverId,
    Expression<String>? workspaceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (recordId != null) 'record_id': recordId,
      if (version != null) 'version': version,
      if (data != null) 'data': data,
      if (serverId != null) 'server_id': serverId,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncBaseCompanion copyWith(
      {Value<String>? kind,
      Value<String>? recordId,
      Value<int>? version,
      Value<String>? data,
      Value<String?>? serverId,
      Value<String>? workspaceId,
      Value<int>? rowid}) {
    return SyncBaseCompanion(
      kind: kind ?? this.kind,
      recordId: recordId ?? this.recordId,
      version: version ?? this.version,
      data: data ?? this.data,
      serverId: serverId ?? this.serverId,
      workspaceId: workspaceId ?? this.workspaceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncBaseCompanion(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version, ')
          ..write('data: $data, ')
          ..write('serverId: $serverId, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
      'cursor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastSyncAtMeta =
      const VerificationMeta('lastSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
      'last_sync_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastResultMeta =
      const VerificationMeta('lastResult');
  @override
  late final GeneratedColumn<String> lastResult = GeneratedColumn<String>(
      'last_result', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [workspaceId, deviceId, cursor, lastSyncAt, lastResult];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(_cursorMeta,
          cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta));
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
          _lastSyncAtMeta,
          lastSyncAt.isAcceptableOrUnknown(
              data['last_sync_at']!, _lastSyncAtMeta));
    }
    if (data.containsKey('last_result')) {
      context.handle(
          _lastResultMeta,
          lastResult.isAcceptableOrUnknown(
              data['last_result']!, _lastResultMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      cursor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cursor'])!,
      lastSyncAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_at']),
      lastResult: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_result']),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String workspaceId;
  final String deviceId;
  final int cursor;
  final DateTime? lastSyncAt;
  final String? lastResult;
  const SyncStateRow(
      {required this.workspaceId,
      required this.deviceId,
      required this.cursor,
      this.lastSyncAt,
      this.lastResult});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['device_id'] = Variable<String>(deviceId);
    map['cursor'] = Variable<int>(cursor);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || lastResult != null) {
      map['last_result'] = Variable<String>(lastResult);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      workspaceId: Value(workspaceId),
      deviceId: Value(deviceId),
      cursor: Value(cursor),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastResult: lastResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResult),
    );
  }

  factory SyncStateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      cursor: serializer.fromJson<int>(json['cursor']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastResult: serializer.fromJson<String?>(json['lastResult']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'deviceId': serializer.toJson<String>(deviceId),
      'cursor': serializer.toJson<int>(cursor),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastResult': serializer.toJson<String?>(lastResult),
    };
  }

  SyncStateRow copyWith(
          {String? workspaceId,
          String? deviceId,
          int? cursor,
          Value<DateTime?> lastSyncAt = const Value.absent(),
          Value<String?> lastResult = const Value.absent()}) =>
      SyncStateRow(
        workspaceId: workspaceId ?? this.workspaceId,
        deviceId: deviceId ?? this.deviceId,
        cursor: cursor ?? this.cursor,
        lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
        lastResult: lastResult.present ? lastResult.value : this.lastResult,
      );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      lastResult:
          data.lastResult.present ? data.lastResult.value : this.lastResult,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('workspaceId: $workspaceId, ')
          ..write('deviceId: $deviceId, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastResult: $lastResult')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(workspaceId, deviceId, cursor, lastSyncAt, lastResult);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.workspaceId == this.workspaceId &&
          other.deviceId == this.deviceId &&
          other.cursor == this.cursor &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastResult == this.lastResult);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> workspaceId;
  final Value<String> deviceId;
  final Value<int> cursor;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastResult;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.workspaceId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String workspaceId,
    required String deviceId,
    this.cursor = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : workspaceId = Value(workspaceId),
        deviceId = Value(deviceId);
  static Insertable<SyncStateRow> custom({
    Expression<String>? workspaceId,
    Expression<String>? deviceId,
    Expression<int>? cursor,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastResult,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (deviceId != null) 'device_id': deviceId,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastResult != null) 'last_result': lastResult,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith(
      {Value<String>? workspaceId,
      Value<String>? deviceId,
      Value<int>? cursor,
      Value<DateTime?>? lastSyncAt,
      Value<String?>? lastResult,
      Value<int>? rowid}) {
    return SyncStateCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      deviceId: deviceId ?? this.deviceId,
      cursor: cursor ?? this.cursor,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastResult.present) {
      map['last_result'] = Variable<String>(lastResult.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('deviceId: $deviceId, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastResult: $lastResult, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncReviewsTable extends SyncReviews
    with TableInfo<$SyncReviewsTable, SyncReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
      'field', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keptMeta = const VerificationMeta('kept');
  @override
  late final GeneratedColumn<String> kept = GeneratedColumn<String>(
      'kept', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _otherMeta = const VerificationMeta('other');
  @override
  late final GeneratedColumn<String> other = GeneratedColumn<String>(
      'other', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        kind,
        recordId,
        field,
        kept,
        other,
        reason,
        createdAt,
        resolvedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_reviews';
  @override
  VerificationContext validateIntegrity(Insertable<SyncReviewRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
          _fieldMeta, field.isAcceptableOrUnknown(data['field']!, _fieldMeta));
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('kept')) {
      context.handle(
          _keptMeta, kept.isAcceptableOrUnknown(data['kept']!, _keptMeta));
    } else if (isInserting) {
      context.missing(_keptMeta);
    }
    if (data.containsKey('other')) {
      context.handle(
          _otherMeta, other.isAcceptableOrUnknown(data['other']!, _otherMeta));
    } else if (isInserting) {
      context.missing(_otherMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncReviewRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      field: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field'])!,
      kept: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kept'])!,
      other: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
    );
  }

  @override
  $SyncReviewsTable createAlias(String alias) {
    return $SyncReviewsTable(attachedDatabase, alias);
  }
}

class SyncReviewRow extends DataClass implements Insertable<SyncReviewRow> {
  final String id;
  final String workspaceId;
  final String kind;
  final String recordId;
  final String field;
  final String kept;
  final String other;
  final String reason;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const SyncReviewRow(
      {required this.id,
      required this.workspaceId,
      required this.kind,
      required this.recordId,
      required this.field,
      required this.kept,
      required this.other,
      required this.reason,
      required this.createdAt,
      this.resolvedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['kind'] = Variable<String>(kind);
    map['record_id'] = Variable<String>(recordId);
    map['field'] = Variable<String>(field);
    map['kept'] = Variable<String>(kept);
    map['other'] = Variable<String>(other);
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncReviewsCompanion toCompanion(bool nullToAbsent) {
    return SyncReviewsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      kind: Value(kind),
      recordId: Value(recordId),
      field: Value(field),
      kept: Value(kept),
      other: Value(other),
      reason: Value(reason),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncReviewRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncReviewRow(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      kind: serializer.fromJson<String>(json['kind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      field: serializer.fromJson<String>(json['field']),
      kept: serializer.fromJson<String>(json['kept']),
      other: serializer.fromJson<String>(json['other']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'kind': serializer.toJson<String>(kind),
      'recordId': serializer.toJson<String>(recordId),
      'field': serializer.toJson<String>(field),
      'kept': serializer.toJson<String>(kept),
      'other': serializer.toJson<String>(other),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncReviewRow copyWith(
          {String? id,
          String? workspaceId,
          String? kind,
          String? recordId,
          String? field,
          String? kept,
          String? other,
          String? reason,
          DateTime? createdAt,
          Value<DateTime?> resolvedAt = const Value.absent()}) =>
      SyncReviewRow(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        kind: kind ?? this.kind,
        recordId: recordId ?? this.recordId,
        field: field ?? this.field,
        kept: kept ?? this.kept,
        other: other ?? this.other,
        reason: reason ?? this.reason,
        createdAt: createdAt ?? this.createdAt,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
      );
  SyncReviewRow copyWithCompanion(SyncReviewsCompanion data) {
    return SyncReviewRow(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      field: data.field.present ? data.field.value : this.field,
      kept: data.kept.present ? data.kept.value : this.kept,
      other: data.other.present ? data.other.value : this.other,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncReviewRow(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('kept: $kept, ')
          ..write('other: $other, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, kind, recordId, field, kept,
      other, reason, createdAt, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncReviewRow &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.kind == this.kind &&
          other.recordId == this.recordId &&
          other.field == this.field &&
          other.kept == this.kept &&
          other.other == this.other &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class SyncReviewsCompanion extends UpdateCompanion<SyncReviewRow> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> kind;
  final Value<String> recordId;
  final Value<String> field;
  final Value<String> kept;
  final Value<String> other;
  final Value<String> reason;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const SyncReviewsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.field = const Value.absent(),
    this.kept = const Value.absent(),
    this.other = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncReviewsCompanion.insert({
    required String id,
    required String workspaceId,
    required String kind,
    required String recordId,
    required String field,
    required String kept,
    required String other,
    required String reason,
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        kind = Value(kind),
        recordId = Value(recordId),
        field = Value(field),
        kept = Value(kept),
        other = Value(other),
        reason = Value(reason),
        createdAt = Value(createdAt);
  static Insertable<SyncReviewRow> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? kind,
    Expression<String>? recordId,
    Expression<String>? field,
    Expression<String>? kept,
    Expression<String>? other,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (kind != null) 'kind': kind,
      if (recordId != null) 'record_id': recordId,
      if (field != null) 'field': field,
      if (kept != null) 'kept': kept,
      if (other != null) 'other': other,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncReviewsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? kind,
      Value<String>? recordId,
      Value<String>? field,
      Value<String>? kept,
      Value<String>? other,
      Value<String>? reason,
      Value<DateTime>? createdAt,
      Value<DateTime?>? resolvedAt,
      Value<int>? rowid}) {
    return SyncReviewsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      kind: kind ?? this.kind,
      recordId: recordId ?? this.recordId,
      field: field ?? this.field,
      kept: kept ?? this.kept,
      other: other ?? this.other,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (kept.present) {
      map['kept'] = Variable<String>(kept.value);
    }
    if (other.present) {
      map['other'] = Variable<String>(other.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncReviewsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('kept: $kept, ')
          ..write('other: $other, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpaceMembersTable extends SpaceMembers
    with TableInfo<$SpaceMembersTable, SpaceMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpaceMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [workspaceId, accountId, role, status, displayName, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_members';
  @override
  VerificationContext validateIntegrity(Insertable<SpaceMemberRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId, accountId};
  @override
  SpaceMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceMemberRow(
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SpaceMembersTable createAlias(String alias) {
    return $SpaceMembersTable(attachedDatabase, alias);
  }
}

class SpaceMemberRow extends DataClass implements Insertable<SpaceMemberRow> {
  final String workspaceId;
  final String accountId;
  final String role;
  final String status;
  final String displayName;
  final DateTime updatedAt;
  const SpaceMemberRow(
      {required this.workspaceId,
      required this.accountId,
      required this.role,
      required this.status,
      required this.displayName,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['account_id'] = Variable<String>(accountId);
    map['role'] = Variable<String>(role);
    map['status'] = Variable<String>(status);
    map['display_name'] = Variable<String>(displayName);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SpaceMembersCompanion toCompanion(bool nullToAbsent) {
    return SpaceMembersCompanion(
      workspaceId: Value(workspaceId),
      accountId: Value(accountId),
      role: Value(role),
      status: Value(status),
      displayName: Value(displayName),
      updatedAt: Value(updatedAt),
    );
  }

  factory SpaceMemberRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceMemberRow(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<String>(json['status']),
      displayName: serializer.fromJson<String>(json['displayName']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'accountId': serializer.toJson<String>(accountId),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<String>(status),
      'displayName': serializer.toJson<String>(displayName),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SpaceMemberRow copyWith(
          {String? workspaceId,
          String? accountId,
          String? role,
          String? status,
          String? displayName,
          DateTime? updatedAt}) =>
      SpaceMemberRow(
        workspaceId: workspaceId ?? this.workspaceId,
        accountId: accountId ?? this.accountId,
        role: role ?? this.role,
        status: status ?? this.status,
        displayName: displayName ?? this.displayName,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SpaceMemberRow copyWithCompanion(SpaceMembersCompanion data) {
    return SpaceMemberRow(
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMemberRow(')
          ..write('workspaceId: $workspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('displayName: $displayName, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(workspaceId, accountId, role, status, displayName, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceMemberRow &&
          other.workspaceId == this.workspaceId &&
          other.accountId == this.accountId &&
          other.role == this.role &&
          other.status == this.status &&
          other.displayName == this.displayName &&
          other.updatedAt == this.updatedAt);
}

class SpaceMembersCompanion extends UpdateCompanion<SpaceMemberRow> {
  final Value<String> workspaceId;
  final Value<String> accountId;
  final Value<String> role;
  final Value<String> status;
  final Value<String> displayName;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SpaceMembersCompanion({
    this.workspaceId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.displayName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceMembersCompanion.insert({
    required String workspaceId,
    required String accountId,
    required String role,
    required String status,
    this.displayName = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : workspaceId = Value(workspaceId),
        accountId = Value(accountId),
        role = Value(role),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<SpaceMemberRow> custom({
    Expression<String>? workspaceId,
    Expression<String>? accountId,
    Expression<String>? role,
    Expression<String>? status,
    Expression<String>? displayName,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (accountId != null) 'account_id': accountId,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (displayName != null) 'display_name': displayName,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceMembersCompanion copyWith(
      {Value<String>? workspaceId,
      Value<String>? accountId,
      Value<String>? role,
      Value<String>? status,
      Value<String>? displayName,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SpaceMembersCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      accountId: accountId ?? this.accountId,
      role: role ?? this.role,
      status: status ?? this.status,
      displayName: displayName ?? this.displayName,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMembersCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('displayName: $displayName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncParkedTable extends SyncParked
    with TableInfo<$SyncParkedTable, SyncParkedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncParkedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [workspaceId, kind, recordId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_parked';
  @override
  VerificationContext validateIntegrity(Insertable<SyncParkedRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId, kind, recordId};
  @override
  SyncParkedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncParkedRow(
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  $SyncParkedTable createAlias(String alias) {
    return $SyncParkedTable(attachedDatabase, alias);
  }
}

class SyncParkedRow extends DataClass implements Insertable<SyncParkedRow> {
  final String workspaceId;
  final String kind;
  final String recordId;
  final int seq;
  const SyncParkedRow(
      {required this.workspaceId,
      required this.kind,
      required this.recordId,
      required this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['kind'] = Variable<String>(kind);
    map['record_id'] = Variable<String>(recordId);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncParkedCompanion toCompanion(bool nullToAbsent) {
    return SyncParkedCompanion(
      workspaceId: Value(workspaceId),
      kind: Value(kind),
      recordId: Value(recordId),
      seq: Value(seq),
    );
  }

  factory SyncParkedRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncParkedRow(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      kind: serializer.fromJson<String>(json['kind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'kind': serializer.toJson<String>(kind),
      'recordId': serializer.toJson<String>(recordId),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncParkedRow copyWith(
          {String? workspaceId, String? kind, String? recordId, int? seq}) =>
      SyncParkedRow(
        workspaceId: workspaceId ?? this.workspaceId,
        kind: kind ?? this.kind,
        recordId: recordId ?? this.recordId,
        seq: seq ?? this.seq,
      );
  SyncParkedRow copyWithCompanion(SyncParkedCompanion data) {
    return SyncParkedRow(
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncParkedRow(')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workspaceId, kind, recordId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncParkedRow &&
          other.workspaceId == this.workspaceId &&
          other.kind == this.kind &&
          other.recordId == this.recordId &&
          other.seq == this.seq);
}

class SyncParkedCompanion extends UpdateCompanion<SyncParkedRow> {
  final Value<String> workspaceId;
  final Value<String> kind;
  final Value<String> recordId;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncParkedCompanion({
    this.workspaceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncParkedCompanion.insert({
    required String workspaceId,
    required String kind,
    required String recordId,
    required int seq,
    this.rowid = const Value.absent(),
  })  : workspaceId = Value(workspaceId),
        kind = Value(kind),
        recordId = Value(recordId),
        seq = Value(seq);
  static Insertable<SyncParkedRow> custom({
    Expression<String>? workspaceId,
    Expression<String>? kind,
    Expression<String>? recordId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (kind != null) 'kind': kind,
      if (recordId != null) 'record_id': recordId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncParkedCompanion copyWith(
      {Value<String>? workspaceId,
      Value<String>? kind,
      Value<String>? recordId,
      Value<int>? seq,
      Value<int>? rowid}) {
    return SyncParkedCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      kind: kind ?? this.kind,
      recordId: recordId ?? this.recordId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncParkedCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $TaskListsTable taskLists = $TaskListsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $AuditLogTable auditLog = $AuditLogTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $EventLogTable eventLog = $EventLogTable(this);
  late final $OpDedupeTable opDedupe = $OpDedupeTable(this);
  late final $RestoreSnapshotsTable restoreSnapshots =
      $RestoreSnapshotsTable(this);
  late final $CalendarsTable calendars = $CalendarsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $SchedulesTable schedules = $SchedulesTable(this);
  late final $OccurrenceExceptionsTable occurrenceExceptions =
      $OccurrenceExceptionsTable(this);
  late final $OccurrenceCompletionsTable occurrenceCompletions =
      $OccurrenceCompletionsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $ExecutionRecordsTable executionRecords =
      $ExecutionRecordsTable(this);
  late final $MeasurementsTable measurements = $MeasurementsTable(this);
  late final $PeriodResultsTable periodResults = $PeriodResultsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $MilestonesTable milestones = $MilestonesTable(this);
  late final $GoalLinksTable goalLinks = $GoalLinksTable(this);
  late final $WorkspaceSettingsTable workspaceSettings =
      $WorkspaceSettingsTable(this);
  late final $SyncBaseTable syncBase = $SyncBaseTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $SyncReviewsTable syncReviews = $SyncReviewsTable(this);
  late final $SpaceMembersTable spaceMembers = $SpaceMembersTable(this);
  late final $SyncParkedTable syncParked = $SyncParkedTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        workspaces,
        taskLists,
        tasks,
        auditLog,
        outbox,
        eventLog,
        opDedupe,
        restoreSnapshots,
        calendars,
        events,
        schedules,
        occurrenceExceptions,
        occurrenceCompletions,
        reminders,
        focusSessions,
        executionRecords,
        measurements,
        periodResults,
        goals,
        milestones,
        goalLinks,
        workspaceSettings,
        syncBase,
        syncState,
        syncReviews,
        spaceMembers,
        syncParked
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  Value<String> displayName,
  required String activeWorkspaceId,
  Value<String?> accountId,
  Value<String?> accountProvider,
  Value<int> version,
  Value<bool> isActive,
  Value<bool> signedOut,
  Value<String> manualResults,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String> activeWorkspaceId,
  Value<String?> accountId,
  Value<String?> accountProvider,
  Value<int> version,
  Value<bool> isActive,
  Value<bool> signedOut,
  Value<String> manualResults,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeWorkspaceId => $composableBuilder(
      column: $table.activeWorkspaceId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get signedOut => $composableBuilder(
      column: $table.signedOut, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manualResults => $composableBuilder(
      column: $table.manualResults, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeWorkspaceId => $composableBuilder(
      column: $table.activeWorkspaceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get signedOut => $composableBuilder(
      column: $table.signedOut, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manualResults => $composableBuilder(
      column: $table.manualResults,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get activeWorkspaceId => $composableBuilder(
      column: $table.activeWorkspaceId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get signedOut =>
      $composableBuilder(column: $table.signedOut, builder: (column) => column);

  GeneratedColumn<String> get manualResults => $composableBuilder(
      column: $table.manualResults, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
    Profile,
    PrefetchHooks Function()> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> activeWorkspaceId = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String?> accountProvider = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> signedOut = const Value.absent(),
            Value<String> manualResults = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            displayName: displayName,
            activeWorkspaceId: activeWorkspaceId,
            accountId: accountId,
            accountProvider: accountProvider,
            version: version,
            isActive: isActive,
            signedOut: signedOut,
            manualResults: manualResults,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> displayName = const Value.absent(),
            required String activeWorkspaceId,
            Value<String?> accountId = const Value.absent(),
            Value<String?> accountProvider = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> signedOut = const Value.absent(),
            Value<String> manualResults = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            displayName: displayName,
            activeWorkspaceId: activeWorkspaceId,
            accountId: accountId,
            accountProvider: accountProvider,
            version: version,
            isActive: isActive,
            signedOut: signedOut,
            manualResults: manualResults,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProfilesTable, Profile>(table),
                    BaseReferences<_$AppDatabase, $ProfilesTable, Profile>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
    Profile,
    PrefetchHooks Function()>;
typedef $$WorkspacesTableCreateCompanionBuilder = WorkspacesCompanion Function({
  required String id,
  Value<String> kind,
  required String ownerId,
  required DateTime createdAt,
  Value<String?> name,
  Value<String?> leaveRule,
  Value<String?> exportRule,
  Value<String?> inviteDefault,
  Value<DateTime?> rulesChangedAt,
  Value<DateTime?> rulesSeenAt,
  Value<DateTime?> leftAt,
  Value<String?> leftKeep,
  Value<int> rowid,
});
typedef $$WorkspacesTableUpdateCompanionBuilder = WorkspacesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> ownerId,
  Value<DateTime> createdAt,
  Value<String?> name,
  Value<String?> leaveRule,
  Value<String?> exportRule,
  Value<String?> inviteDefault,
  Value<DateTime?> rulesChangedAt,
  Value<DateTime?> rulesSeenAt,
  Value<DateTime?> leftAt,
  Value<String?> leftKeep,
  Value<int> rowid,
});

class $$WorkspacesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get leaveRule => $composableBuilder(
      column: $table.leaveRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exportRule => $composableBuilder(
      column: $table.exportRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviteDefault => $composableBuilder(
      column: $table.inviteDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get rulesChangedAt => $composableBuilder(
      column: $table.rulesChangedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get rulesSeenAt => $composableBuilder(
      column: $table.rulesSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get leftAt => $composableBuilder(
      column: $table.leftAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get leftKeep => $composableBuilder(
      column: $table.leftKeep, builder: (column) => ColumnFilters(column));
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get leaveRule => $composableBuilder(
      column: $table.leaveRule, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exportRule => $composableBuilder(
      column: $table.exportRule, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviteDefault => $composableBuilder(
      column: $table.inviteDefault,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get rulesChangedAt => $composableBuilder(
      column: $table.rulesChangedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get rulesSeenAt => $composableBuilder(
      column: $table.rulesSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get leftAt => $composableBuilder(
      column: $table.leftAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get leftKeep => $composableBuilder(
      column: $table.leftKeep, builder: (column) => ColumnOrderings(column));
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get leaveRule =>
      $composableBuilder(column: $table.leaveRule, builder: (column) => column);

  GeneratedColumn<String> get exportRule => $composableBuilder(
      column: $table.exportRule, builder: (column) => column);

  GeneratedColumn<String> get inviteDefault => $composableBuilder(
      column: $table.inviteDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get rulesChangedAt => $composableBuilder(
      column: $table.rulesChangedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get rulesSeenAt => $composableBuilder(
      column: $table.rulesSeenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get leftAt =>
      $composableBuilder(column: $table.leftAt, builder: (column) => column);

  GeneratedColumn<String> get leftKeep =>
      $composableBuilder(column: $table.leftKeep, builder: (column) => column);
}

class $$WorkspacesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkspacesTable,
    Workspace,
    $$WorkspacesTableFilterComposer,
    $$WorkspacesTableOrderingComposer,
    $$WorkspacesTableAnnotationComposer,
    $$WorkspacesTableCreateCompanionBuilder,
    $$WorkspacesTableUpdateCompanionBuilder,
    (Workspace, BaseReferences<_$AppDatabase, $WorkspacesTable, Workspace>),
    Workspace,
    PrefetchHooks Function()> {
  $$WorkspacesTableTableManager(_$AppDatabase db, $WorkspacesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> leaveRule = const Value.absent(),
            Value<String?> exportRule = const Value.absent(),
            Value<String?> inviteDefault = const Value.absent(),
            Value<DateTime?> rulesChangedAt = const Value.absent(),
            Value<DateTime?> rulesSeenAt = const Value.absent(),
            Value<DateTime?> leftAt = const Value.absent(),
            Value<String?> leftKeep = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspacesCompanion(
            id: id,
            kind: kind,
            ownerId: ownerId,
            createdAt: createdAt,
            name: name,
            leaveRule: leaveRule,
            exportRule: exportRule,
            inviteDefault: inviteDefault,
            rulesChangedAt: rulesChangedAt,
            rulesSeenAt: rulesSeenAt,
            leftAt: leftAt,
            leftKeep: leftKeep,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> kind = const Value.absent(),
            required String ownerId,
            required DateTime createdAt,
            Value<String?> name = const Value.absent(),
            Value<String?> leaveRule = const Value.absent(),
            Value<String?> exportRule = const Value.absent(),
            Value<String?> inviteDefault = const Value.absent(),
            Value<DateTime?> rulesChangedAt = const Value.absent(),
            Value<DateTime?> rulesSeenAt = const Value.absent(),
            Value<DateTime?> leftAt = const Value.absent(),
            Value<String?> leftKeep = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspacesCompanion.insert(
            id: id,
            kind: kind,
            ownerId: ownerId,
            createdAt: createdAt,
            name: name,
            leaveRule: leaveRule,
            exportRule: exportRule,
            inviteDefault: inviteDefault,
            rulesChangedAt: rulesChangedAt,
            rulesSeenAt: rulesSeenAt,
            leftAt: leftAt,
            leftKeep: leftKeep,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WorkspacesTable, Workspace>(table),
                    BaseReferences<_$AppDatabase, $WorkspacesTable, Workspace>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkspacesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkspacesTable,
    Workspace,
    $$WorkspacesTableFilterComposer,
    $$WorkspacesTableOrderingComposer,
    $$WorkspacesTableAnnotationComposer,
    $$WorkspacesTableCreateCompanionBuilder,
    $$WorkspacesTableUpdateCompanionBuilder,
    (Workspace, BaseReferences<_$AppDatabase, $WorkspacesTable, Workspace>),
    Workspace,
    PrefetchHooks Function()>;
typedef $$TaskListsTableCreateCompanionBuilder = TaskListsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String title,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<int> rowid,
});
typedef $$TaskListsTableUpdateCompanionBuilder = TaskListsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> title,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<int> rowid,
});

class $$TaskListsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnFilters(column));
}

class $$TaskListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnOrderings(column));
}

class $$TaskListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);
}

class $$TaskListsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskListsTable,
    TaskList,
    $$TaskListsTableFilterComposer,
    $$TaskListsTableOrderingComposer,
    $$TaskListsTableAnnotationComposer,
    $$TaskListsTableCreateCompanionBuilder,
    $$TaskListsTableUpdateCompanionBuilder,
    (TaskList, BaseReferences<_$AppDatabase, $TaskListsTable, TaskList>),
    TaskList,
    PrefetchHooks Function()> {
  $$TaskListsTableTableManager(_$AppDatabase db, $TaskListsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskListsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            colorIndex: colorIndex,
            orderKey: orderKey,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String title,
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskListsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            colorIndex: colorIndex,
            orderKey: orderKey,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TaskListsTable, TaskList>(table),
                    BaseReferences<_$AppDatabase, $TaskListsTable, TaskList>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaskListsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaskListsTable,
    TaskList,
    $$TaskListsTableFilterComposer,
    $$TaskListsTableOrderingComposer,
    $$TaskListsTableAnnotationComposer,
    $$TaskListsTableCreateCompanionBuilder,
    $$TaskListsTableUpdateCompanionBuilder,
    (TaskList, BaseReferences<_$AppDatabase, $TaskListsTable, TaskList>),
    TaskList,
    PrefetchHooks Function()>;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String title,
  Value<String> status,
  Value<bool> isImportant,
  Value<String?> taskListId,
  Value<String?> parentTaskId,
  Value<int> sortOrder,
  Value<String?> targetType,
  Value<double?> targetMin,
  Value<double?> targetMax,
  Value<String?> unit,
  Value<String> completionPolicy,
  Value<String> targetAggregation,
  Value<bool> isHabit,
  Value<String?> trackedSince,
  Value<String> tags,
  Value<String?> notes,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<String?> assigneeId,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> title,
  Value<String> status,
  Value<bool> isImportant,
  Value<String?> taskListId,
  Value<String?> parentTaskId,
  Value<int> sortOrder,
  Value<String?> targetType,
  Value<double?> targetMin,
  Value<double?> targetMax,
  Value<String?> unit,
  Value<String> completionPolicy,
  Value<String> targetAggregation,
  Value<bool> isHabit,
  Value<String?> trackedSince,
  Value<String> tags,
  Value<String?> notes,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<String?> assigneeId,
  Value<int> rowid,
});

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isImportant => $composableBuilder(
      column: $table.isImportant, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskListId => $composableBuilder(
      column: $table.taskListId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetType => $composableBuilder(
      column: $table.targetType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetMin => $composableBuilder(
      column: $table.targetMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetMax => $composableBuilder(
      column: $table.targetMax, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get completionPolicy => $composableBuilder(
      column: $table.completionPolicy,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetAggregation => $composableBuilder(
      column: $table.targetAggregation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHabit => $composableBuilder(
      column: $table.isHabit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trackedSince => $composableBuilder(
      column: $table.trackedSince, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assigneeId => $composableBuilder(
      column: $table.assigneeId, builder: (column) => ColumnFilters(column));
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isImportant => $composableBuilder(
      column: $table.isImportant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskListId => $composableBuilder(
      column: $table.taskListId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetType => $composableBuilder(
      column: $table.targetType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetMin => $composableBuilder(
      column: $table.targetMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetMax => $composableBuilder(
      column: $table.targetMax, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get completionPolicy => $composableBuilder(
      column: $table.completionPolicy,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetAggregation => $composableBuilder(
      column: $table.targetAggregation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHabit => $composableBuilder(
      column: $table.isHabit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trackedSince => $composableBuilder(
      column: $table.trackedSince,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assigneeId => $composableBuilder(
      column: $table.assigneeId, builder: (column) => ColumnOrderings(column));
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isImportant => $composableBuilder(
      column: $table.isImportant, builder: (column) => column);

  GeneratedColumn<String> get taskListId => $composableBuilder(
      column: $table.taskListId, builder: (column) => column);

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get targetType => $composableBuilder(
      column: $table.targetType, builder: (column) => column);

  GeneratedColumn<double> get targetMin =>
      $composableBuilder(column: $table.targetMin, builder: (column) => column);

  GeneratedColumn<double> get targetMax =>
      $composableBuilder(column: $table.targetMax, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get completionPolicy => $composableBuilder(
      column: $table.completionPolicy, builder: (column) => column);

  GeneratedColumn<String> get targetAggregation => $composableBuilder(
      column: $table.targetAggregation, builder: (column) => column);

  GeneratedColumn<bool> get isHabit =>
      $composableBuilder(column: $table.isHabit, builder: (column) => column);

  GeneratedColumn<String> get trackedSince => $composableBuilder(
      column: $table.trackedSince, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);

  GeneratedColumn<String> get assigneeId => $composableBuilder(
      column: $table.assigneeId, builder: (column) => column);
}

class $$TasksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()> {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> isImportant = const Value.absent(),
            Value<String?> taskListId = const Value.absent(),
            Value<String?> parentTaskId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> targetType = const Value.absent(),
            Value<double?> targetMin = const Value.absent(),
            Value<double?> targetMax = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String> completionPolicy = const Value.absent(),
            Value<String> targetAggregation = const Value.absent(),
            Value<bool> isHabit = const Value.absent(),
            Value<String?> trackedSince = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<String?> assigneeId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            status: status,
            isImportant: isImportant,
            taskListId: taskListId,
            parentTaskId: parentTaskId,
            sortOrder: sortOrder,
            targetType: targetType,
            targetMin: targetMin,
            targetMax: targetMax,
            unit: unit,
            completionPolicy: completionPolicy,
            targetAggregation: targetAggregation,
            isHabit: isHabit,
            trackedSince: trackedSince,
            tags: tags,
            notes: notes,
            colorIndex: colorIndex,
            orderKey: orderKey,
            assigneeId: assigneeId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String title,
            Value<String> status = const Value.absent(),
            Value<bool> isImportant = const Value.absent(),
            Value<String?> taskListId = const Value.absent(),
            Value<String?> parentTaskId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> targetType = const Value.absent(),
            Value<double?> targetMin = const Value.absent(),
            Value<double?> targetMax = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String> completionPolicy = const Value.absent(),
            Value<String> targetAggregation = const Value.absent(),
            Value<bool> isHabit = const Value.absent(),
            Value<String?> trackedSince = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<String?> assigneeId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            status: status,
            isImportant: isImportant,
            taskListId: taskListId,
            parentTaskId: parentTaskId,
            sortOrder: sortOrder,
            targetType: targetType,
            targetMin: targetMin,
            targetMax: targetMax,
            unit: unit,
            completionPolicy: completionPolicy,
            targetAggregation: targetAggregation,
            isHabit: isHabit,
            trackedSince: trackedSince,
            tags: tags,
            notes: notes,
            colorIndex: colorIndex,
            orderKey: orderKey,
            assigneeId: assigneeId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TasksTable, Task>(table),
                    BaseReferences<_$AppDatabase, $TasksTable, Task>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TasksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()>;
typedef $$AuditLogTableCreateCompanionBuilder = AuditLogCompanion Function({
  required String auditId,
  required String operationId,
  required String actor,
  Value<String?> onBehalfOf,
  required String action,
  required String resourceType,
  required String resourceId,
  Value<int?> versionBefore,
  Value<int?> versionAfter,
  required String outcome,
  Value<String?> reason,
  required DateTime at,
  Value<int> rowid,
});
typedef $$AuditLogTableUpdateCompanionBuilder = AuditLogCompanion Function({
  Value<String> auditId,
  Value<String> operationId,
  Value<String> actor,
  Value<String?> onBehalfOf,
  Value<String> action,
  Value<String> resourceType,
  Value<String> resourceId,
  Value<int?> versionBefore,
  Value<int?> versionAfter,
  Value<String> outcome,
  Value<String?> reason,
  Value<DateTime> at,
  Value<int> rowid,
});

class $$AuditLogTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get auditId => $composableBuilder(
      column: $table.auditId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actor => $composableBuilder(
      column: $table.actor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get onBehalfOf => $composableBuilder(
      column: $table.onBehalfOf, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceType => $composableBuilder(
      column: $table.resourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get versionBefore => $composableBuilder(
      column: $table.versionBefore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get versionAfter => $composableBuilder(
      column: $table.versionAfter, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnFilters(column));
}

class $$AuditLogTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get auditId => $composableBuilder(
      column: $table.auditId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actor => $composableBuilder(
      column: $table.actor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get onBehalfOf => $composableBuilder(
      column: $table.onBehalfOf, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceType => $composableBuilder(
      column: $table.resourceType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get versionBefore => $composableBuilder(
      column: $table.versionBefore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get versionAfter => $composableBuilder(
      column: $table.versionAfter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnOrderings(column));
}

class $$AuditLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get auditId =>
      $composableBuilder(column: $table.auditId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<String> get onBehalfOf => $composableBuilder(
      column: $table.onBehalfOf, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get resourceType => $composableBuilder(
      column: $table.resourceType, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => column);

  GeneratedColumn<int> get versionBefore => $composableBuilder(
      column: $table.versionBefore, builder: (column) => column);

  GeneratedColumn<int> get versionAfter => $composableBuilder(
      column: $table.versionAfter, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$AuditLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (AuditLogData, BaseReferences<_$AppDatabase, $AuditLogTable, AuditLogData>),
    AuditLogData,
    PrefetchHooks Function()> {
  $$AuditLogTableTableManager(_$AppDatabase db, $AuditLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> auditId = const Value.absent(),
            Value<String> operationId = const Value.absent(),
            Value<String> actor = const Value.absent(),
            Value<String?> onBehalfOf = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> resourceType = const Value.absent(),
            Value<String> resourceId = const Value.absent(),
            Value<int?> versionBefore = const Value.absent(),
            Value<int?> versionAfter = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<String?> reason = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditLogCompanion(
            auditId: auditId,
            operationId: operationId,
            actor: actor,
            onBehalfOf: onBehalfOf,
            action: action,
            resourceType: resourceType,
            resourceId: resourceId,
            versionBefore: versionBefore,
            versionAfter: versionAfter,
            outcome: outcome,
            reason: reason,
            at: at,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String auditId,
            required String operationId,
            required String actor,
            Value<String?> onBehalfOf = const Value.absent(),
            required String action,
            required String resourceType,
            required String resourceId,
            Value<int?> versionBefore = const Value.absent(),
            Value<int?> versionAfter = const Value.absent(),
            required String outcome,
            Value<String?> reason = const Value.absent(),
            required DateTime at,
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditLogCompanion.insert(
            auditId: auditId,
            operationId: operationId,
            actor: actor,
            onBehalfOf: onBehalfOf,
            action: action,
            resourceType: resourceType,
            resourceId: resourceId,
            versionBefore: versionBefore,
            versionAfter: versionAfter,
            outcome: outcome,
            reason: reason,
            at: at,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AuditLogTable, AuditLogData>(table),
                    BaseReferences<_$AppDatabase, $AuditLogTable, AuditLogData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (AuditLogData, BaseReferences<_$AppDatabase, $AuditLogTable, AuditLogData>),
    AuditLogData,
    PrefetchHooks Function()>;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String operationId,
  required String entityId,
  required String entityType,
  required String workspaceId,
  required String actorId,
  required String operationType,
  Value<int?> baseVersion,
  required String payload,
  required DateTime createdAt,
  Value<String> status,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> operationId,
  Value<String> entityId,
  Value<String> entityType,
  Value<String> workspaceId,
  Value<String> actorId,
  Value<String> operationType,
  Value<int?> baseVersion,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get baseVersion => $composableBuilder(
      column: $table.baseVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationType => $composableBuilder(
      column: $table.operationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get baseVersion => $composableBuilder(
      column: $table.baseVersion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
      column: $table.baseVersion, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> operationId = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> actorId = const Value.absent(),
            Value<String> operationType = const Value.absent(),
            Value<int?> baseVersion = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion(
            operationId: operationId,
            entityId: entityId,
            entityType: entityType,
            workspaceId: workspaceId,
            actorId: actorId,
            operationType: operationType,
            baseVersion: baseVersion,
            payload: payload,
            createdAt: createdAt,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String operationId,
            required String entityId,
            required String entityType,
            required String workspaceId,
            required String actorId,
            required String operationType,
            Value<int?> baseVersion = const Value.absent(),
            required String payload,
            required DateTime createdAt,
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            operationId: operationId,
            entityId: entityId,
            entityType: entityType,
            workspaceId: workspaceId,
            actorId: actorId,
            operationType: operationType,
            baseVersion: baseVersion,
            payload: payload,
            createdAt: createdAt,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxTable, OutboxData>(table),
                    BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;
typedef $$EventLogTableCreateCompanionBuilder = EventLogCompanion Function({
  required String eventId,
  required String operationId,
  required String eventType,
  required String payload,
  required DateTime createdAt,
  Value<bool> dispatched,
  Value<int> rowid,
});
typedef $$EventLogTableUpdateCompanionBuilder = EventLogCompanion Function({
  Value<String> eventId,
  Value<String> operationId,
  Value<String> eventType,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<bool> dispatched,
  Value<int> rowid,
});

class $$EventLogTableFilterComposer
    extends Composer<_$AppDatabase, $EventLogTable> {
  $$EventLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dispatched => $composableBuilder(
      column: $table.dispatched, builder: (column) => ColumnFilters(column));
}

class $$EventLogTableOrderingComposer
    extends Composer<_$AppDatabase, $EventLogTable> {
  $$EventLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dispatched => $composableBuilder(
      column: $table.dispatched, builder: (column) => ColumnOrderings(column));
}

class $$EventLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventLogTable> {
  $$EventLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get dispatched => $composableBuilder(
      column: $table.dispatched, builder: (column) => column);
}

class $$EventLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EventLogTable,
    EventLogData,
    $$EventLogTableFilterComposer,
    $$EventLogTableOrderingComposer,
    $$EventLogTableAnnotationComposer,
    $$EventLogTableCreateCompanionBuilder,
    $$EventLogTableUpdateCompanionBuilder,
    (EventLogData, BaseReferences<_$AppDatabase, $EventLogTable, EventLogData>),
    EventLogData,
    PrefetchHooks Function()> {
  $$EventLogTableTableManager(_$AppDatabase db, $EventLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> eventId = const Value.absent(),
            Value<String> operationId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> dispatched = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventLogCompanion(
            eventId: eventId,
            operationId: operationId,
            eventType: eventType,
            payload: payload,
            createdAt: createdAt,
            dispatched: dispatched,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String eventId,
            required String operationId,
            required String eventType,
            required String payload,
            required DateTime createdAt,
            Value<bool> dispatched = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventLogCompanion.insert(
            eventId: eventId,
            operationId: operationId,
            eventType: eventType,
            payload: payload,
            createdAt: createdAt,
            dispatched: dispatched,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$EventLogTable, EventLogData>(table),
                    BaseReferences<_$AppDatabase, $EventLogTable, EventLogData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EventLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EventLogTable,
    EventLogData,
    $$EventLogTableFilterComposer,
    $$EventLogTableOrderingComposer,
    $$EventLogTableAnnotationComposer,
    $$EventLogTableCreateCompanionBuilder,
    $$EventLogTableUpdateCompanionBuilder,
    (EventLogData, BaseReferences<_$AppDatabase, $EventLogTable, EventLogData>),
    EventLogData,
    PrefetchHooks Function()>;
typedef $$OpDedupeTableCreateCompanionBuilder = OpDedupeCompanion Function({
  required String operationId,
  required String workspaceId,
  required String resultSummary,
  required DateTime appliedAt,
  Value<int> rowid,
});
typedef $$OpDedupeTableUpdateCompanionBuilder = OpDedupeCompanion Function({
  Value<String> operationId,
  Value<String> workspaceId,
  Value<String> resultSummary,
  Value<DateTime> appliedAt,
  Value<int> rowid,
});

class $$OpDedupeTableFilterComposer
    extends Composer<_$AppDatabase, $OpDedupeTable> {
  $$OpDedupeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultSummary => $composableBuilder(
      column: $table.resultSummary, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
      column: $table.appliedAt, builder: (column) => ColumnFilters(column));
}

class $$OpDedupeTableOrderingComposer
    extends Composer<_$AppDatabase, $OpDedupeTable> {
  $$OpDedupeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultSummary => $composableBuilder(
      column: $table.resultSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
      column: $table.appliedAt, builder: (column) => ColumnOrderings(column));
}

class $$OpDedupeTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpDedupeTable> {
  $$OpDedupeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get resultSummary => $composableBuilder(
      column: $table.resultSummary, builder: (column) => column);

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$OpDedupeTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OpDedupeTable,
    OpDedupeData,
    $$OpDedupeTableFilterComposer,
    $$OpDedupeTableOrderingComposer,
    $$OpDedupeTableAnnotationComposer,
    $$OpDedupeTableCreateCompanionBuilder,
    $$OpDedupeTableUpdateCompanionBuilder,
    (OpDedupeData, BaseReferences<_$AppDatabase, $OpDedupeTable, OpDedupeData>),
    OpDedupeData,
    PrefetchHooks Function()> {
  $$OpDedupeTableTableManager(_$AppDatabase db, $OpDedupeTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpDedupeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpDedupeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpDedupeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> operationId = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> resultSummary = const Value.absent(),
            Value<DateTime> appliedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OpDedupeCompanion(
            operationId: operationId,
            workspaceId: workspaceId,
            resultSummary: resultSummary,
            appliedAt: appliedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String operationId,
            required String workspaceId,
            required String resultSummary,
            required DateTime appliedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OpDedupeCompanion.insert(
            operationId: operationId,
            workspaceId: workspaceId,
            resultSummary: resultSummary,
            appliedAt: appliedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OpDedupeTable, OpDedupeData>(table),
                    BaseReferences<_$AppDatabase, $OpDedupeTable, OpDedupeData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OpDedupeTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OpDedupeTable,
    OpDedupeData,
    $$OpDedupeTableFilterComposer,
    $$OpDedupeTableOrderingComposer,
    $$OpDedupeTableAnnotationComposer,
    $$OpDedupeTableCreateCompanionBuilder,
    $$OpDedupeTableUpdateCompanionBuilder,
    (OpDedupeData, BaseReferences<_$AppDatabase, $OpDedupeTable, OpDedupeData>),
    OpDedupeData,
    PrefetchHooks Function()>;
typedef $$RestoreSnapshotsTableCreateCompanionBuilder
    = RestoreSnapshotsCompanion Function({
  required String id,
  required String operationId,
  required DateTime createdAt,
  required String exportText,
  Value<int> rowid,
});
typedef $$RestoreSnapshotsTableUpdateCompanionBuilder
    = RestoreSnapshotsCompanion Function({
  Value<String> id,
  Value<String> operationId,
  Value<DateTime> createdAt,
  Value<String> exportText,
  Value<int> rowid,
});

class $$RestoreSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $RestoreSnapshotsTable> {
  $$RestoreSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exportText => $composableBuilder(
      column: $table.exportText, builder: (column) => ColumnFilters(column));
}

class $$RestoreSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestoreSnapshotsTable> {
  $$RestoreSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exportText => $composableBuilder(
      column: $table.exportText, builder: (column) => ColumnOrderings(column));
}

class $$RestoreSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestoreSnapshotsTable> {
  $$RestoreSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get exportText => $composableBuilder(
      column: $table.exportText, builder: (column) => column);
}

class $$RestoreSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RestoreSnapshotsTable,
    RestoreSnapshot,
    $$RestoreSnapshotsTableFilterComposer,
    $$RestoreSnapshotsTableOrderingComposer,
    $$RestoreSnapshotsTableAnnotationComposer,
    $$RestoreSnapshotsTableCreateCompanionBuilder,
    $$RestoreSnapshotsTableUpdateCompanionBuilder,
    (
      RestoreSnapshot,
      BaseReferences<_$AppDatabase, $RestoreSnapshotsTable, RestoreSnapshot>
    ),
    RestoreSnapshot,
    PrefetchHooks Function()> {
  $$RestoreSnapshotsTableTableManager(
      _$AppDatabase db, $RestoreSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestoreSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestoreSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestoreSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> operationId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> exportText = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RestoreSnapshotsCompanion(
            id: id,
            operationId: operationId,
            createdAt: createdAt,
            exportText: exportText,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String operationId,
            required DateTime createdAt,
            required String exportText,
            Value<int> rowid = const Value.absent(),
          }) =>
              RestoreSnapshotsCompanion.insert(
            id: id,
            operationId: operationId,
            createdAt: createdAt,
            exportText: exportText,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RestoreSnapshotsTable, RestoreSnapshot>(table),
                    BaseReferences<_$AppDatabase, $RestoreSnapshotsTable,
                        RestoreSnapshot>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RestoreSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RestoreSnapshotsTable,
    RestoreSnapshot,
    $$RestoreSnapshotsTableFilterComposer,
    $$RestoreSnapshotsTableOrderingComposer,
    $$RestoreSnapshotsTableAnnotationComposer,
    $$RestoreSnapshotsTableCreateCompanionBuilder,
    $$RestoreSnapshotsTableUpdateCompanionBuilder,
    (
      RestoreSnapshot,
      BaseReferences<_$AppDatabase, $RestoreSnapshotsTable, RestoreSnapshot>
    ),
    RestoreSnapshot,
    PrefetchHooks Function()>;
typedef $$CalendarsTableCreateCompanionBuilder = CalendarsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String name,
  Value<int> color,
  Value<int> rowid,
});
typedef $$CalendarsTableUpdateCompanionBuilder = CalendarsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> name,
  Value<int> color,
  Value<int> rowid,
});

class $$CalendarsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));
}

class $$CalendarsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));
}

class $$CalendarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$CalendarsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalendarsTable,
    Calendar,
    $$CalendarsTableFilterComposer,
    $$CalendarsTableOrderingComposer,
    $$CalendarsTableAnnotationComposer,
    $$CalendarsTableCreateCompanionBuilder,
    $$CalendarsTableUpdateCompanionBuilder,
    (Calendar, BaseReferences<_$AppDatabase, $CalendarsTable, Calendar>),
    Calendar,
    PrefetchHooks Function()> {
  $$CalendarsTableTableManager(_$AppDatabase db, $CalendarsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            name: name,
            color: color,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String name,
            Value<int> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            name: name,
            color: color,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CalendarsTable, Calendar>(table),
                    BaseReferences<_$AppDatabase, $CalendarsTable, Calendar>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalendarsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalendarsTable,
    Calendar,
    $$CalendarsTableFilterComposer,
    $$CalendarsTableOrderingComposer,
    $$CalendarsTableAnnotationComposer,
    $$CalendarsTableCreateCompanionBuilder,
    $$CalendarsTableUpdateCompanionBuilder,
    (Calendar, BaseReferences<_$AppDatabase, $CalendarsTable, Calendar>),
    Calendar,
    PrefetchHooks Function()>;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String title,
  Value<String?> location,
  Value<String?> calendarId,
  Value<String> status,
  Value<String?> listId,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<int> rowid,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> title,
  Value<String?> location,
  Value<String?> calendarId,
  Value<String> status,
  Value<String?> listId,
  Value<int?> colorIndex,
  Value<String> orderKey,
  Value<int> rowid,
});

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnFilters(column));
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderKey => $composableBuilder(
      column: $table.orderKey, builder: (column) => ColumnOrderings(column));
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
      column: $table.colorIndex, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);
}

class $$EventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EventsTable,
    Event,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
    Event,
    PrefetchHooks Function()> {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> calendarId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> listId = const Value.absent(),
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            location: location,
            calendarId: calendarId,
            status: status,
            listId: listId,
            colorIndex: colorIndex,
            orderKey: orderKey,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String title,
            Value<String?> location = const Value.absent(),
            Value<String?> calendarId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> listId = const Value.absent(),
            Value<int?> colorIndex = const Value.absent(),
            Value<String> orderKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            title: title,
            location: location,
            calendarId: calendarId,
            status: status,
            listId: listId,
            colorIndex: colorIndex,
            orderKey: orderKey,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$EventsTable, Event>(table),
                    BaseReferences<_$AppDatabase, $EventsTable, Event>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EventsTable,
    Event,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
    Event,
    PrefetchHooks Function()>;
typedef $$SchedulesTableCreateCompanionBuilder = SchedulesCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String subjectType,
  required String subjectId,
  Value<String?> startDate,
  Value<String?> startTime,
  Value<String?> startZone,
  Value<String?> endDate,
  Value<String?> endTime,
  Value<String?> endZone,
  Value<String?> deadlineDate,
  Value<String?> deadlineTime,
  Value<String?> deadlineZone,
  required String firstDate,
  Value<String?> lastDate,
  Value<String?> frequency,
  Value<int> interval,
  Value<String?> weekdays,
  Value<String?> endKind,
  Value<String?> endDateRule,
  Value<int?> endCount,
  Value<String> monthEndRule,
  Value<int> weekStart,
  Value<int> rowid,
});
typedef $$SchedulesTableUpdateCompanionBuilder = SchedulesCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> subjectType,
  Value<String> subjectId,
  Value<String?> startDate,
  Value<String?> startTime,
  Value<String?> startZone,
  Value<String?> endDate,
  Value<String?> endTime,
  Value<String?> endZone,
  Value<String?> deadlineDate,
  Value<String?> deadlineTime,
  Value<String?> deadlineZone,
  Value<String> firstDate,
  Value<String?> lastDate,
  Value<String?> frequency,
  Value<int> interval,
  Value<String?> weekdays,
  Value<String?> endKind,
  Value<String?> endDateRule,
  Value<int?> endCount,
  Value<String> monthEndRule,
  Value<int> weekStart,
  Value<int> rowid,
});

class $$SchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startZone => $composableBuilder(
      column: $table.startZone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endZone => $composableBuilder(
      column: $table.endZone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deadlineTime => $composableBuilder(
      column: $table.deadlineTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deadlineZone => $composableBuilder(
      column: $table.deadlineZone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firstDate => $composableBuilder(
      column: $table.firstDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastDate => $composableBuilder(
      column: $table.lastDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weekdays => $composableBuilder(
      column: $table.weekdays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endKind => $composableBuilder(
      column: $table.endKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endDateRule => $composableBuilder(
      column: $table.endDateRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endCount => $composableBuilder(
      column: $table.endCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get monthEndRule => $composableBuilder(
      column: $table.monthEndRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnFilters(column));
}

class $$SchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startZone => $composableBuilder(
      column: $table.startZone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endZone => $composableBuilder(
      column: $table.endZone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deadlineTime => $composableBuilder(
      column: $table.deadlineTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deadlineZone => $composableBuilder(
      column: $table.deadlineZone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firstDate => $composableBuilder(
      column: $table.firstDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastDate => $composableBuilder(
      column: $table.lastDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weekdays => $composableBuilder(
      column: $table.weekdays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endKind => $composableBuilder(
      column: $table.endKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endDateRule => $composableBuilder(
      column: $table.endDateRule, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endCount => $composableBuilder(
      column: $table.endCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get monthEndRule => $composableBuilder(
      column: $table.monthEndRule,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnOrderings(column));
}

class $$SchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get startZone =>
      $composableBuilder(column: $table.startZone, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get endZone =>
      $composableBuilder(column: $table.endZone, builder: (column) => column);

  GeneratedColumn<String> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate, builder: (column) => column);

  GeneratedColumn<String> get deadlineTime => $composableBuilder(
      column: $table.deadlineTime, builder: (column) => column);

  GeneratedColumn<String> get deadlineZone => $composableBuilder(
      column: $table.deadlineZone, builder: (column) => column);

  GeneratedColumn<String> get firstDate =>
      $composableBuilder(column: $table.firstDate, builder: (column) => column);

  GeneratedColumn<String> get lastDate =>
      $composableBuilder(column: $table.lastDate, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<String> get endKind =>
      $composableBuilder(column: $table.endKind, builder: (column) => column);

  GeneratedColumn<String> get endDateRule => $composableBuilder(
      column: $table.endDateRule, builder: (column) => column);

  GeneratedColumn<int> get endCount =>
      $composableBuilder(column: $table.endCount, builder: (column) => column);

  GeneratedColumn<String> get monthEndRule => $composableBuilder(
      column: $table.monthEndRule, builder: (column) => column);

  GeneratedColumn<int> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);
}

class $$SchedulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SchedulesTable,
    Schedule,
    $$SchedulesTableFilterComposer,
    $$SchedulesTableOrderingComposer,
    $$SchedulesTableAnnotationComposer,
    $$SchedulesTableCreateCompanionBuilder,
    $$SchedulesTableUpdateCompanionBuilder,
    (Schedule, BaseReferences<_$AppDatabase, $SchedulesTable, Schedule>),
    Schedule,
    PrefetchHooks Function()> {
  $$SchedulesTableTableManager(_$AppDatabase db, $SchedulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> subjectType = const Value.absent(),
            Value<String> subjectId = const Value.absent(),
            Value<String?> startDate = const Value.absent(),
            Value<String?> startTime = const Value.absent(),
            Value<String?> startZone = const Value.absent(),
            Value<String?> endDate = const Value.absent(),
            Value<String?> endTime = const Value.absent(),
            Value<String?> endZone = const Value.absent(),
            Value<String?> deadlineDate = const Value.absent(),
            Value<String?> deadlineTime = const Value.absent(),
            Value<String?> deadlineZone = const Value.absent(),
            Value<String> firstDate = const Value.absent(),
            Value<String?> lastDate = const Value.absent(),
            Value<String?> frequency = const Value.absent(),
            Value<int> interval = const Value.absent(),
            Value<String?> weekdays = const Value.absent(),
            Value<String?> endKind = const Value.absent(),
            Value<String?> endDateRule = const Value.absent(),
            Value<int?> endCount = const Value.absent(),
            Value<String> monthEndRule = const Value.absent(),
            Value<int> weekStart = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SchedulesCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            startDate: startDate,
            startTime: startTime,
            startZone: startZone,
            endDate: endDate,
            endTime: endTime,
            endZone: endZone,
            deadlineDate: deadlineDate,
            deadlineTime: deadlineTime,
            deadlineZone: deadlineZone,
            firstDate: firstDate,
            lastDate: lastDate,
            frequency: frequency,
            interval: interval,
            weekdays: weekdays,
            endKind: endKind,
            endDateRule: endDateRule,
            endCount: endCount,
            monthEndRule: monthEndRule,
            weekStart: weekStart,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String subjectType,
            required String subjectId,
            Value<String?> startDate = const Value.absent(),
            Value<String?> startTime = const Value.absent(),
            Value<String?> startZone = const Value.absent(),
            Value<String?> endDate = const Value.absent(),
            Value<String?> endTime = const Value.absent(),
            Value<String?> endZone = const Value.absent(),
            Value<String?> deadlineDate = const Value.absent(),
            Value<String?> deadlineTime = const Value.absent(),
            Value<String?> deadlineZone = const Value.absent(),
            required String firstDate,
            Value<String?> lastDate = const Value.absent(),
            Value<String?> frequency = const Value.absent(),
            Value<int> interval = const Value.absent(),
            Value<String?> weekdays = const Value.absent(),
            Value<String?> endKind = const Value.absent(),
            Value<String?> endDateRule = const Value.absent(),
            Value<int?> endCount = const Value.absent(),
            Value<String> monthEndRule = const Value.absent(),
            Value<int> weekStart = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SchedulesCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            startDate: startDate,
            startTime: startTime,
            startZone: startZone,
            endDate: endDate,
            endTime: endTime,
            endZone: endZone,
            deadlineDate: deadlineDate,
            deadlineTime: deadlineTime,
            deadlineZone: deadlineZone,
            firstDate: firstDate,
            lastDate: lastDate,
            frequency: frequency,
            interval: interval,
            weekdays: weekdays,
            endKind: endKind,
            endDateRule: endDateRule,
            endCount: endCount,
            monthEndRule: monthEndRule,
            weekStart: weekStart,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SchedulesTable, Schedule>(table),
                    BaseReferences<_$AppDatabase, $SchedulesTable, Schedule>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SchedulesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SchedulesTable,
    Schedule,
    $$SchedulesTableFilterComposer,
    $$SchedulesTableOrderingComposer,
    $$SchedulesTableAnnotationComposer,
    $$SchedulesTableCreateCompanionBuilder,
    $$SchedulesTableUpdateCompanionBuilder,
    (Schedule, BaseReferences<_$AppDatabase, $SchedulesTable, Schedule>),
    Schedule,
    PrefetchHooks Function()>;
typedef $$OccurrenceExceptionsTableCreateCompanionBuilder
    = OccurrenceExceptionsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String subjectType,
  required String subjectId,
  required String originalDate,
  required String kind,
  Value<String?> moveDate,
  Value<String?> moveTime,
  Value<String?> patch,
  Value<int> rowid,
});
typedef $$OccurrenceExceptionsTableUpdateCompanionBuilder
    = OccurrenceExceptionsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> subjectType,
  Value<String> subjectId,
  Value<String> originalDate,
  Value<String> kind,
  Value<String?> moveDate,
  Value<String?> moveTime,
  Value<String?> patch,
  Value<int> rowid,
});

class $$OccurrenceExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $OccurrenceExceptionsTable> {
  $$OccurrenceExceptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get moveDate => $composableBuilder(
      column: $table.moveDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get moveTime => $composableBuilder(
      column: $table.moveTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get patch => $composableBuilder(
      column: $table.patch, builder: (column) => ColumnFilters(column));
}

class $$OccurrenceExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OccurrenceExceptionsTable> {
  $$OccurrenceExceptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalDate => $composableBuilder(
      column: $table.originalDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get moveDate => $composableBuilder(
      column: $table.moveDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get moveTime => $composableBuilder(
      column: $table.moveTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get patch => $composableBuilder(
      column: $table.patch, builder: (column) => ColumnOrderings(column));
}

class $$OccurrenceExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OccurrenceExceptionsTable> {
  $$OccurrenceExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get moveDate =>
      $composableBuilder(column: $table.moveDate, builder: (column) => column);

  GeneratedColumn<String> get moveTime =>
      $composableBuilder(column: $table.moveTime, builder: (column) => column);

  GeneratedColumn<String> get patch =>
      $composableBuilder(column: $table.patch, builder: (column) => column);
}

class $$OccurrenceExceptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OccurrenceExceptionsTable,
    OccurrenceException,
    $$OccurrenceExceptionsTableFilterComposer,
    $$OccurrenceExceptionsTableOrderingComposer,
    $$OccurrenceExceptionsTableAnnotationComposer,
    $$OccurrenceExceptionsTableCreateCompanionBuilder,
    $$OccurrenceExceptionsTableUpdateCompanionBuilder,
    (
      OccurrenceException,
      BaseReferences<_$AppDatabase, $OccurrenceExceptionsTable,
          OccurrenceException>
    ),
    OccurrenceException,
    PrefetchHooks Function()> {
  $$OccurrenceExceptionsTableTableManager(
      _$AppDatabase db, $OccurrenceExceptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OccurrenceExceptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OccurrenceExceptionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OccurrenceExceptionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> subjectType = const Value.absent(),
            Value<String> subjectId = const Value.absent(),
            Value<String> originalDate = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> moveDate = const Value.absent(),
            Value<String?> moveTime = const Value.absent(),
            Value<String?> patch = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceExceptionsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            originalDate: originalDate,
            kind: kind,
            moveDate: moveDate,
            moveTime: moveTime,
            patch: patch,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String subjectType,
            required String subjectId,
            required String originalDate,
            required String kind,
            Value<String?> moveDate = const Value.absent(),
            Value<String?> moveTime = const Value.absent(),
            Value<String?> patch = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceExceptionsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            originalDate: originalDate,
            kind: kind,
            moveDate: moveDate,
            moveTime: moveTime,
            patch: patch,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OccurrenceExceptionsTable,
                        OccurrenceException>(table),
                    BaseReferences<_$AppDatabase, $OccurrenceExceptionsTable,
                        OccurrenceException>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OccurrenceExceptionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $OccurrenceExceptionsTable,
        OccurrenceException,
        $$OccurrenceExceptionsTableFilterComposer,
        $$OccurrenceExceptionsTableOrderingComposer,
        $$OccurrenceExceptionsTableAnnotationComposer,
        $$OccurrenceExceptionsTableCreateCompanionBuilder,
        $$OccurrenceExceptionsTableUpdateCompanionBuilder,
        (
          OccurrenceException,
          BaseReferences<_$AppDatabase, $OccurrenceExceptionsTable,
              OccurrenceException>
        ),
        OccurrenceException,
        PrefetchHooks Function()>;
typedef $$OccurrenceCompletionsTableCreateCompanionBuilder
    = OccurrenceCompletionsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String taskId,
  required String originalDate,
  required DateTime completedAt,
  Value<int> rowid,
});
typedef $$OccurrenceCompletionsTableUpdateCompanionBuilder
    = OccurrenceCompletionsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> taskId,
  Value<String> originalDate,
  Value<DateTime> completedAt,
  Value<int> rowid,
});

class $$OccurrenceCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $OccurrenceCompletionsTable> {
  $$OccurrenceCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$OccurrenceCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OccurrenceCompletionsTable> {
  $$OccurrenceCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalDate => $composableBuilder(
      column: $table.originalDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$OccurrenceCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OccurrenceCompletionsTable> {
  $$OccurrenceCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$OccurrenceCompletionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OccurrenceCompletionsTable,
    OccurrenceCompletion,
    $$OccurrenceCompletionsTableFilterComposer,
    $$OccurrenceCompletionsTableOrderingComposer,
    $$OccurrenceCompletionsTableAnnotationComposer,
    $$OccurrenceCompletionsTableCreateCompanionBuilder,
    $$OccurrenceCompletionsTableUpdateCompanionBuilder,
    (
      OccurrenceCompletion,
      BaseReferences<_$AppDatabase, $OccurrenceCompletionsTable,
          OccurrenceCompletion>
    ),
    OccurrenceCompletion,
    PrefetchHooks Function()> {
  $$OccurrenceCompletionsTableTableManager(
      _$AppDatabase db, $OccurrenceCompletionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OccurrenceCompletionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$OccurrenceCompletionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OccurrenceCompletionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<String> originalDate = const Value.absent(),
            Value<DateTime> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceCompletionsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            originalDate: originalDate,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String taskId,
            required String originalDate,
            required DateTime completedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceCompletionsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            originalDate: originalDate,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OccurrenceCompletionsTable,
                        OccurrenceCompletion>(table),
                    BaseReferences<_$AppDatabase, $OccurrenceCompletionsTable,
                        OccurrenceCompletion>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OccurrenceCompletionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $OccurrenceCompletionsTable,
        OccurrenceCompletion,
        $$OccurrenceCompletionsTableFilterComposer,
        $$OccurrenceCompletionsTableOrderingComposer,
        $$OccurrenceCompletionsTableAnnotationComposer,
        $$OccurrenceCompletionsTableCreateCompanionBuilder,
        $$OccurrenceCompletionsTableUpdateCompanionBuilder,
        (
          OccurrenceCompletion,
          BaseReferences<_$AppDatabase, $OccurrenceCompletionsTable,
              OccurrenceCompletion>
        ),
        OccurrenceCompletion,
        PrefetchHooks Function()>;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String subjectType,
  required String subjectId,
  Value<int?> offsetMinutes,
  Value<DateTime?> atUtc,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> subjectType,
  Value<String> subjectId,
  Value<int?> offsetMinutes,
  Value<DateTime?> atUtc,
  Value<int> rowid,
});

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get offsetMinutes => $composableBuilder(
      column: $table.offsetMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get atUtc => $composableBuilder(
      column: $table.atUtc, builder: (column) => ColumnFilters(column));
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get offsetMinutes => $composableBuilder(
      column: $table.offsetMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get atUtc => $composableBuilder(
      column: $table.atUtc, builder: (column) => ColumnOrderings(column));
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get offsetMinutes => $composableBuilder(
      column: $table.offsetMinutes, builder: (column) => column);

  GeneratedColumn<DateTime> get atUtc =>
      $composableBuilder(column: $table.atUtc, builder: (column) => column);
}

class $$RemindersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RemindersTable,
    Reminder,
    $$RemindersTableFilterComposer,
    $$RemindersTableOrderingComposer,
    $$RemindersTableAnnotationComposer,
    $$RemindersTableCreateCompanionBuilder,
    $$RemindersTableUpdateCompanionBuilder,
    (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
    Reminder,
    PrefetchHooks Function()> {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> subjectType = const Value.absent(),
            Value<String> subjectId = const Value.absent(),
            Value<int?> offsetMinutes = const Value.absent(),
            Value<DateTime?> atUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RemindersCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            offsetMinutes: offsetMinutes,
            atUtc: atUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String subjectType,
            required String subjectId,
            Value<int?> offsetMinutes = const Value.absent(),
            Value<DateTime?> atUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RemindersCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            subjectType: subjectType,
            subjectId: subjectId,
            offsetMinutes: offsetMinutes,
            atUtc: atUtc,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RemindersTable, Reminder>(table),
                    BaseReferences<_$AppDatabase, $RemindersTable, Reminder>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RemindersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RemindersTable,
    Reminder,
    $$RemindersTableFilterComposer,
    $$RemindersTableOrderingComposer,
    $$RemindersTableAnnotationComposer,
    $$RemindersTableCreateCompanionBuilder,
    $$RemindersTableUpdateCompanionBuilder,
    (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
    Reminder,
    PrefetchHooks Function()>;
typedef $$FocusSessionsTableCreateCompanionBuilder = FocusSessionsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String?> taskId,
  Value<String?> occurrenceDate,
  required String mode,
  required String state,
  required int startedAt,
  Value<int?> plannedMs,
  Value<int> pausedMs,
  Value<int?> pausedAt,
  Value<int?> endedAt,
  Value<int> rowid,
});
typedef $$FocusSessionsTableUpdateCompanionBuilder = FocusSessionsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String?> taskId,
  Value<String?> occurrenceDate,
  Value<String> mode,
  Value<String> state,
  Value<int> startedAt,
  Value<int?> plannedMs,
  Value<int> pausedMs,
  Value<int?> pausedAt,
  Value<int?> endedAt,
  Value<int> rowid,
});

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get plannedMs => $composableBuilder(
      column: $table.plannedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pausedMs => $composableBuilder(
      column: $table.pausedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pausedAt => $composableBuilder(
      column: $table.pausedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plannedMs => $composableBuilder(
      column: $table.plannedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pausedMs => $composableBuilder(
      column: $table.pausedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pausedAt => $composableBuilder(
      column: $table.pausedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get plannedMs =>
      $composableBuilder(column: $table.plannedMs, builder: (column) => column);

  GeneratedColumn<int> get pausedMs =>
      $composableBuilder(column: $table.pausedMs, builder: (column) => column);

  GeneratedColumn<int> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);
}

class $$FocusSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FocusSessionsTable,
    FocusSessionRow,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (
      FocusSessionRow,
      BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>
    ),
    FocusSessionRow,
    PrefetchHooks Function()> {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> occurrenceDate = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<int?> plannedMs = const Value.absent(),
            Value<int> pausedMs = const Value.absent(),
            Value<int?> pausedAt = const Value.absent(),
            Value<int?> endedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            mode: mode,
            state: state,
            startedAt: startedAt,
            plannedMs: plannedMs,
            pausedMs: pausedMs,
            pausedAt: pausedAt,
            endedAt: endedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> occurrenceDate = const Value.absent(),
            required String mode,
            required String state,
            required int startedAt,
            Value<int?> plannedMs = const Value.absent(),
            Value<int> pausedMs = const Value.absent(),
            Value<int?> pausedAt = const Value.absent(),
            Value<int?> endedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            mode: mode,
            state: state,
            startedAt: startedAt,
            plannedMs: plannedMs,
            pausedMs: pausedMs,
            pausedAt: pausedAt,
            endedAt: endedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FocusSessionsTable, FocusSessionRow>(table),
                    BaseReferences<_$AppDatabase, $FocusSessionsTable,
                        FocusSessionRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FocusSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FocusSessionsTable,
    FocusSessionRow,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (
      FocusSessionRow,
      BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>
    ),
    FocusSessionRow,
    PrefetchHooks Function()>;
typedef $$ExecutionRecordsTableCreateCompanionBuilder
    = ExecutionRecordsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String?> sessionId,
  Value<String?> taskId,
  Value<String?> occurrenceDate,
  required DateTime actualStart,
  required DateTime actualEnd,
  required int focusMs,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$ExecutionRecordsTableUpdateCompanionBuilder
    = ExecutionRecordsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String?> sessionId,
  Value<String?> taskId,
  Value<String?> occurrenceDate,
  Value<DateTime> actualStart,
  Value<DateTime> actualEnd,
  Value<int> focusMs,
  Value<String?> note,
  Value<int> rowid,
});

class $$ExecutionRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ExecutionRecordsTable> {
  $$ExecutionRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get actualStart => $composableBuilder(
      column: $table.actualStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get actualEnd => $composableBuilder(
      column: $table.actualEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get focusMs => $composableBuilder(
      column: $table.focusMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$ExecutionRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExecutionRecordsTable> {
  $$ExecutionRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get actualStart => $composableBuilder(
      column: $table.actualStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get actualEnd => $composableBuilder(
      column: $table.actualEnd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get focusMs => $composableBuilder(
      column: $table.focusMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$ExecutionRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExecutionRecordsTable> {
  $$ExecutionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get occurrenceDate => $composableBuilder(
      column: $table.occurrenceDate, builder: (column) => column);

  GeneratedColumn<DateTime> get actualStart => $composableBuilder(
      column: $table.actualStart, builder: (column) => column);

  GeneratedColumn<DateTime> get actualEnd =>
      $composableBuilder(column: $table.actualEnd, builder: (column) => column);

  GeneratedColumn<int> get focusMs =>
      $composableBuilder(column: $table.focusMs, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$ExecutionRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExecutionRecordsTable,
    ExecutionRecordRow,
    $$ExecutionRecordsTableFilterComposer,
    $$ExecutionRecordsTableOrderingComposer,
    $$ExecutionRecordsTableAnnotationComposer,
    $$ExecutionRecordsTableCreateCompanionBuilder,
    $$ExecutionRecordsTableUpdateCompanionBuilder,
    (
      ExecutionRecordRow,
      BaseReferences<_$AppDatabase, $ExecutionRecordsTable, ExecutionRecordRow>
    ),
    ExecutionRecordRow,
    PrefetchHooks Function()> {
  $$ExecutionRecordsTableTableManager(
      _$AppDatabase db, $ExecutionRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExecutionRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExecutionRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExecutionRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> occurrenceDate = const Value.absent(),
            Value<DateTime> actualStart = const Value.absent(),
            Value<DateTime> actualEnd = const Value.absent(),
            Value<int> focusMs = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExecutionRecordsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            sessionId: sessionId,
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            actualStart: actualStart,
            actualEnd: actualEnd,
            focusMs: focusMs,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> occurrenceDate = const Value.absent(),
            required DateTime actualStart,
            required DateTime actualEnd,
            required int focusMs,
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExecutionRecordsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            sessionId: sessionId,
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            actualStart: actualStart,
            actualEnd: actualEnd,
            focusMs: focusMs,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ExecutionRecordsTable, ExecutionRecordRow>(
                        table),
                    BaseReferences<_$AppDatabase, $ExecutionRecordsTable,
                        ExecutionRecordRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExecutionRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExecutionRecordsTable,
    ExecutionRecordRow,
    $$ExecutionRecordsTableFilterComposer,
    $$ExecutionRecordsTableOrderingComposer,
    $$ExecutionRecordsTableAnnotationComposer,
    $$ExecutionRecordsTableCreateCompanionBuilder,
    $$ExecutionRecordsTableUpdateCompanionBuilder,
    (
      ExecutionRecordRow,
      BaseReferences<_$AppDatabase, $ExecutionRecordsTable, ExecutionRecordRow>
    ),
    ExecutionRecordRow,
    PrefetchHooks Function()>;
typedef $$MeasurementsTableCreateCompanionBuilder = MeasurementsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String taskId,
  required double value,
  required String localDate,
  required DateTime recordedAt,
  required String source,
  Value<String?> deviceId,
  Value<String?> note,
  Value<String?> supersedesId,
  Value<bool> withdrawn,
  Value<String?> recordId,
  Value<int> rowid,
});
typedef $$MeasurementsTableUpdateCompanionBuilder = MeasurementsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> taskId,
  Value<double> value,
  Value<String> localDate,
  Value<DateTime> recordedAt,
  Value<String> source,
  Value<String?> deviceId,
  Value<String?> note,
  Value<String?> supersedesId,
  Value<bool> withdrawn,
  Value<String?> recordId,
  Value<int> rowid,
});

class $$MeasurementsTableFilterComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supersedesId => $composableBuilder(
      column: $table.supersedesId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get withdrawn => $composableBuilder(
      column: $table.withdrawn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));
}

class $$MeasurementsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supersedesId => $composableBuilder(
      column: $table.supersedesId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get withdrawn => $composableBuilder(
      column: $table.withdrawn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));
}

class $$MeasurementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get supersedesId => $composableBuilder(
      column: $table.supersedesId, builder: (column) => column);

  GeneratedColumn<bool> get withdrawn =>
      $composableBuilder(column: $table.withdrawn, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);
}

class $$MeasurementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MeasurementsTable,
    MeasurementRow,
    $$MeasurementsTableFilterComposer,
    $$MeasurementsTableOrderingComposer,
    $$MeasurementsTableAnnotationComposer,
    $$MeasurementsTableCreateCompanionBuilder,
    $$MeasurementsTableUpdateCompanionBuilder,
    (
      MeasurementRow,
      BaseReferences<_$AppDatabase, $MeasurementsTable, MeasurementRow>
    ),
    MeasurementRow,
    PrefetchHooks Function()> {
  $$MeasurementsTableTableManager(_$AppDatabase db, $MeasurementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeasurementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeasurementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeasurementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String> localDate = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> supersedesId = const Value.absent(),
            Value<bool> withdrawn = const Value.absent(),
            Value<String?> recordId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurementsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            value: value,
            localDate: localDate,
            recordedAt: recordedAt,
            source: source,
            deviceId: deviceId,
            note: note,
            supersedesId: supersedesId,
            withdrawn: withdrawn,
            recordId: recordId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String taskId,
            required double value,
            required String localDate,
            required DateTime recordedAt,
            required String source,
            Value<String?> deviceId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> supersedesId = const Value.absent(),
            Value<bool> withdrawn = const Value.absent(),
            Value<String?> recordId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurementsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            value: value,
            localDate: localDate,
            recordedAt: recordedAt,
            source: source,
            deviceId: deviceId,
            note: note,
            supersedesId: supersedesId,
            withdrawn: withdrawn,
            recordId: recordId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MeasurementsTable, MeasurementRow>(table),
                    BaseReferences<_$AppDatabase, $MeasurementsTable,
                        MeasurementRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MeasurementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MeasurementsTable,
    MeasurementRow,
    $$MeasurementsTableFilterComposer,
    $$MeasurementsTableOrderingComposer,
    $$MeasurementsTableAnnotationComposer,
    $$MeasurementsTableCreateCompanionBuilder,
    $$MeasurementsTableUpdateCompanionBuilder,
    (
      MeasurementRow,
      BaseReferences<_$AppDatabase, $MeasurementsTable, MeasurementRow>
    ),
    MeasurementRow,
    PrefetchHooks Function()>;
typedef $$PeriodResultsTableCreateCompanionBuilder = PeriodResultsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String taskId,
  required String periodKey,
  required String kind,
  required String outcome,
  Value<double?> value,
  Value<String?> target,
  required DateTime evaluatedAt,
  Value<int> rowid,
});
typedef $$PeriodResultsTableUpdateCompanionBuilder = PeriodResultsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> taskId,
  Value<String> periodKey,
  Value<String> kind,
  Value<String> outcome,
  Value<double?> value,
  Value<String?> target,
  Value<DateTime> evaluatedAt,
  Value<int> rowid,
});

class $$PeriodResultsTableFilterComposer
    extends Composer<_$AppDatabase, $PeriodResultsTable> {
  $$PeriodResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get periodKey => $composableBuilder(
      column: $table.periodKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get evaluatedAt => $composableBuilder(
      column: $table.evaluatedAt, builder: (column) => ColumnFilters(column));
}

class $$PeriodResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $PeriodResultsTable> {
  $$PeriodResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get periodKey => $composableBuilder(
      column: $table.periodKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get evaluatedAt => $composableBuilder(
      column: $table.evaluatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PeriodResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeriodResultsTable> {
  $$PeriodResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<DateTime> get evaluatedAt => $composableBuilder(
      column: $table.evaluatedAt, builder: (column) => column);
}

class $$PeriodResultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PeriodResultsTable,
    PeriodResultRow,
    $$PeriodResultsTableFilterComposer,
    $$PeriodResultsTableOrderingComposer,
    $$PeriodResultsTableAnnotationComposer,
    $$PeriodResultsTableCreateCompanionBuilder,
    $$PeriodResultsTableUpdateCompanionBuilder,
    (
      PeriodResultRow,
      BaseReferences<_$AppDatabase, $PeriodResultsTable, PeriodResultRow>
    ),
    PeriodResultRow,
    PrefetchHooks Function()> {
  $$PeriodResultsTableTableManager(_$AppDatabase db, $PeriodResultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeriodResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<String> periodKey = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<double?> value = const Value.absent(),
            Value<String?> target = const Value.absent(),
            Value<DateTime> evaluatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PeriodResultsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            periodKey: periodKey,
            kind: kind,
            outcome: outcome,
            value: value,
            target: target,
            evaluatedAt: evaluatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String taskId,
            required String periodKey,
            required String kind,
            required String outcome,
            Value<double?> value = const Value.absent(),
            Value<String?> target = const Value.absent(),
            required DateTime evaluatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PeriodResultsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            taskId: taskId,
            periodKey: periodKey,
            kind: kind,
            outcome: outcome,
            value: value,
            target: target,
            evaluatedAt: evaluatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PeriodResultsTable, PeriodResultRow>(table),
                    BaseReferences<_$AppDatabase, $PeriodResultsTable,
                        PeriodResultRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PeriodResultsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PeriodResultsTable,
    PeriodResultRow,
    $$PeriodResultsTableFilterComposer,
    $$PeriodResultsTableOrderingComposer,
    $$PeriodResultsTableAnnotationComposer,
    $$PeriodResultsTableCreateCompanionBuilder,
    $$PeriodResultsTableUpdateCompanionBuilder,
    (
      PeriodResultRow,
      BaseReferences<_$AppDatabase, $PeriodResultsTable, PeriodResultRow>
    ),
    PeriodResultRow,
    PrefetchHooks Function()>;
typedef $$GoalsTableCreateCompanionBuilder = GoalsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String kind,
  required String title,
  Value<String?> description,
  Value<String> status,
  Value<String?> startDate,
  Value<String?> targetDate,
  Value<int> rowid,
});
typedef $$GoalsTableUpdateCompanionBuilder = GoalsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> kind,
  Value<String> title,
  Value<String?> description,
  Value<String> status,
  Value<String?> startDate,
  Value<String?> targetDate,
  Value<int> rowid,
});

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);
}

class $$GoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GoalsTable,
    GoalRow,
    $$GoalsTableFilterComposer,
    $$GoalsTableOrderingComposer,
    $$GoalsTableAnnotationComposer,
    $$GoalsTableCreateCompanionBuilder,
    $$GoalsTableUpdateCompanionBuilder,
    (GoalRow, BaseReferences<_$AppDatabase, $GoalsTable, GoalRow>),
    GoalRow,
    PrefetchHooks Function()> {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> startDate = const Value.absent(),
            Value<String?> targetDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            kind: kind,
            title: title,
            description: description,
            status: status,
            startDate: startDate,
            targetDate: targetDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String kind,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> startDate = const Value.absent(),
            Value<String?> targetDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            kind: kind,
            title: title,
            description: description,
            status: status,
            startDate: startDate,
            targetDate: targetDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$GoalsTable, GoalRow>(table),
                    BaseReferences<_$AppDatabase, $GoalsTable, GoalRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GoalsTable,
    GoalRow,
    $$GoalsTableFilterComposer,
    $$GoalsTableOrderingComposer,
    $$GoalsTableAnnotationComposer,
    $$GoalsTableCreateCompanionBuilder,
    $$GoalsTableUpdateCompanionBuilder,
    (GoalRow, BaseReferences<_$AppDatabase, $GoalsTable, GoalRow>),
    GoalRow,
    PrefetchHooks Function()>;
typedef $$MilestonesTableCreateCompanionBuilder = MilestonesCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String goalId,
  required String title,
  Value<String?> dueDate,
  Value<bool> isCompleted,
  Value<DateTime?> completedAt,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$MilestonesTableUpdateCompanionBuilder = MilestonesCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> goalId,
  Value<String> title,
  Value<String?> dueDate,
  Value<bool> isCompleted,
  Value<DateTime?> completedAt,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$MilestonesTableFilterComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$MilestonesTableOrderingComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$MilestonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$MilestonesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MilestonesTable,
    MilestoneRow,
    $$MilestonesTableFilterComposer,
    $$MilestonesTableOrderingComposer,
    $$MilestonesTableAnnotationComposer,
    $$MilestonesTableCreateCompanionBuilder,
    $$MilestonesTableUpdateCompanionBuilder,
    (
      MilestoneRow,
      BaseReferences<_$AppDatabase, $MilestonesTable, MilestoneRow>
    ),
    MilestoneRow,
    PrefetchHooks Function()> {
  $$MilestonesTableTableManager(_$AppDatabase db, $MilestonesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MilestonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MilestonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MilestonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> goalId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> dueDate = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MilestonesCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            goalId: goalId,
            title: title,
            dueDate: dueDate,
            isCompleted: isCompleted,
            completedAt: completedAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String goalId,
            required String title,
            Value<String?> dueDate = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MilestonesCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            goalId: goalId,
            title: title,
            dueDate: dueDate,
            isCompleted: isCompleted,
            completedAt: completedAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MilestonesTable, MilestoneRow>(table),
                    BaseReferences<_$AppDatabase, $MilestonesTable,
                        MilestoneRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MilestonesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MilestonesTable,
    MilestoneRow,
    $$MilestonesTableFilterComposer,
    $$MilestonesTableOrderingComposer,
    $$MilestonesTableAnnotationComposer,
    $$MilestonesTableCreateCompanionBuilder,
    $$MilestonesTableUpdateCompanionBuilder,
    (
      MilestoneRow,
      BaseReferences<_$AppDatabase, $MilestonesTable, MilestoneRow>
    ),
    MilestoneRow,
    PrefetchHooks Function()>;
typedef $$GoalLinksTableCreateCompanionBuilder = GoalLinksCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  required String goalId,
  required String itemType,
  required String itemId,
  Value<int> rowid,
});
typedef $$GoalLinksTableUpdateCompanionBuilder = GoalLinksCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> goalId,
  Value<String> itemType,
  Value<String> itemId,
  Value<int> rowid,
});

class $$GoalLinksTableFilterComposer
    extends Composer<_$AppDatabase, $GoalLinksTable> {
  $$GoalLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemType => $composableBuilder(
      column: $table.itemType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));
}

class $$GoalLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalLinksTable> {
  $$GoalLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemType => $composableBuilder(
      column: $table.itemType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));
}

class $$GoalLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalLinksTable> {
  $$GoalLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);
}

class $$GoalLinksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GoalLinksTable,
    GoalLinkRow,
    $$GoalLinksTableFilterComposer,
    $$GoalLinksTableOrderingComposer,
    $$GoalLinksTableAnnotationComposer,
    $$GoalLinksTableCreateCompanionBuilder,
    $$GoalLinksTableUpdateCompanionBuilder,
    (GoalLinkRow, BaseReferences<_$AppDatabase, $GoalLinksTable, GoalLinkRow>),
    GoalLinkRow,
    PrefetchHooks Function()> {
  $$GoalLinksTableTableManager(_$AppDatabase db, $GoalLinksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> goalId = const Value.absent(),
            Value<String> itemType = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalLinksCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            goalId: goalId,
            itemType: itemType,
            itemId: itemId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            required String goalId,
            required String itemType,
            required String itemId,
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalLinksCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            goalId: goalId,
            itemType: itemType,
            itemId: itemId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$GoalLinksTable, GoalLinkRow>(table),
                    BaseReferences<_$AppDatabase, $GoalLinksTable, GoalLinkRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GoalLinksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GoalLinksTable,
    GoalLinkRow,
    $$GoalLinksTableFilterComposer,
    $$GoalLinksTableOrderingComposer,
    $$GoalLinksTableAnnotationComposer,
    $$GoalLinksTableCreateCompanionBuilder,
    $$GoalLinksTableUpdateCompanionBuilder,
    (GoalLinkRow, BaseReferences<_$AppDatabase, $GoalLinksTable, GoalLinkRow>),
    GoalLinkRow,
    PrefetchHooks Function()>;
typedef $$WorkspaceSettingsTableCreateCompanionBuilder
    = WorkspaceSettingsCompanion Function({
  required String id,
  required String workspaceId,
  required String ownerId,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> manualResults,
  Value<String?> name,
  Value<int> rowid,
});
typedef $$WorkspaceSettingsTableUpdateCompanionBuilder
    = WorkspaceSettingsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> ownerId,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String?> changedBy,
  Value<String> manualResults,
  Value<String?> name,
  Value<int> rowid,
});

class $$WorkspaceSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspaceSettingsTable> {
  $$WorkspaceSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manualResults => $composableBuilder(
      column: $table.manualResults, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));
}

class $$WorkspaceSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspaceSettingsTable> {
  $$WorkspaceSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy => $composableBuilder(
      column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manualResults => $composableBuilder(
      column: $table.manualResults,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $$WorkspaceSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspaceSettingsTable> {
  $$WorkspaceSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get manualResults => $composableBuilder(
      column: $table.manualResults, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$WorkspaceSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkspaceSettingsTable,
    WorkspaceSetting,
    $$WorkspaceSettingsTableFilterComposer,
    $$WorkspaceSettingsTableOrderingComposer,
    $$WorkspaceSettingsTableAnnotationComposer,
    $$WorkspaceSettingsTableCreateCompanionBuilder,
    $$WorkspaceSettingsTableUpdateCompanionBuilder,
    (
      WorkspaceSetting,
      BaseReferences<_$AppDatabase, $WorkspaceSettingsTable, WorkspaceSetting>
    ),
    WorkspaceSetting,
    PrefetchHooks Function()> {
  $$WorkspaceSettingsTableTableManager(
      _$AppDatabase db, $WorkspaceSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspaceSettingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> manualResults = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspaceSettingsCompanion(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            manualResults: manualResults,
            name: name,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String ownerId,
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String?> changedBy = const Value.absent(),
            Value<String> manualResults = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspaceSettingsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            ownerId: ownerId,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            changedBy: changedBy,
            manualResults: manualResults,
            name: name,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WorkspaceSettingsTable, WorkspaceSetting>(
                        table),
                    BaseReferences<_$AppDatabase, $WorkspaceSettingsTable,
                        WorkspaceSetting>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkspaceSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkspaceSettingsTable,
    WorkspaceSetting,
    $$WorkspaceSettingsTableFilterComposer,
    $$WorkspaceSettingsTableOrderingComposer,
    $$WorkspaceSettingsTableAnnotationComposer,
    $$WorkspaceSettingsTableCreateCompanionBuilder,
    $$WorkspaceSettingsTableUpdateCompanionBuilder,
    (
      WorkspaceSetting,
      BaseReferences<_$AppDatabase, $WorkspaceSettingsTable, WorkspaceSetting>
    ),
    WorkspaceSetting,
    PrefetchHooks Function()>;
typedef $$SyncBaseTableCreateCompanionBuilder = SyncBaseCompanion Function({
  required String kind,
  required String recordId,
  required int version,
  required String data,
  Value<String?> serverId,
  Value<String> workspaceId,
  Value<int> rowid,
});
typedef $$SyncBaseTableUpdateCompanionBuilder = SyncBaseCompanion Function({
  Value<String> kind,
  Value<String> recordId,
  Value<int> version,
  Value<String> data,
  Value<String?> serverId,
  Value<String> workspaceId,
  Value<int> rowid,
});

class $$SyncBaseTableFilterComposer
    extends Composer<_$AppDatabase, $SyncBaseTable> {
  $$SyncBaseTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));
}

class $$SyncBaseTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncBaseTable> {
  $$SyncBaseTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));
}

class $$SyncBaseTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncBaseTable> {
  $$SyncBaseTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);
}

class $$SyncBaseTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncBaseTable,
    SyncBaseRow,
    $$SyncBaseTableFilterComposer,
    $$SyncBaseTableOrderingComposer,
    $$SyncBaseTableAnnotationComposer,
    $$SyncBaseTableCreateCompanionBuilder,
    $$SyncBaseTableUpdateCompanionBuilder,
    (SyncBaseRow, BaseReferences<_$AppDatabase, $SyncBaseTable, SyncBaseRow>),
    SyncBaseRow,
    PrefetchHooks Function()> {
  $$SyncBaseTableTableManager(_$AppDatabase db, $SyncBaseTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncBaseTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncBaseTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncBaseTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> kind = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncBaseCompanion(
            kind: kind,
            recordId: recordId,
            version: version,
            data: data,
            serverId: serverId,
            workspaceId: workspaceId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String kind,
            required String recordId,
            required int version,
            required String data,
            Value<String?> serverId = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncBaseCompanion.insert(
            kind: kind,
            recordId: recordId,
            version: version,
            data: data,
            serverId: serverId,
            workspaceId: workspaceId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncBaseTable, SyncBaseRow>(table),
                    BaseReferences<_$AppDatabase, $SyncBaseTable, SyncBaseRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncBaseTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncBaseTable,
    SyncBaseRow,
    $$SyncBaseTableFilterComposer,
    $$SyncBaseTableOrderingComposer,
    $$SyncBaseTableAnnotationComposer,
    $$SyncBaseTableCreateCompanionBuilder,
    $$SyncBaseTableUpdateCompanionBuilder,
    (SyncBaseRow, BaseReferences<_$AppDatabase, $SyncBaseTable, SyncBaseRow>),
    SyncBaseRow,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String workspaceId,
  required String deviceId,
  Value<int> cursor,
  Value<DateTime?> lastSyncAt,
  Value<String?> lastResult,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> workspaceId,
  Value<String> deviceId,
  Value<int> cursor,
  Value<DateTime?> lastSyncAt,
  Value<String?> lastResult,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastResult => $composableBuilder(
      column: $table.lastResult, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastResult => $composableBuilder(
      column: $table.lastResult, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => column);

  GeneratedColumn<String> get lastResult => $composableBuilder(
      column: $table.lastResult, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateRow,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateRow,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>
    ),
    SyncStateRow,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> workspaceId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> cursor = const Value.absent(),
            Value<DateTime?> lastSyncAt = const Value.absent(),
            Value<String?> lastResult = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion(
            workspaceId: workspaceId,
            deviceId: deviceId,
            cursor: cursor,
            lastSyncAt: lastSyncAt,
            lastResult: lastResult,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String workspaceId,
            required String deviceId,
            Value<int> cursor = const Value.absent(),
            Value<DateTime?> lastSyncAt = const Value.absent(),
            Value<String?> lastResult = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            workspaceId: workspaceId,
            deviceId: deviceId,
            cursor: cursor,
            lastSyncAt: lastSyncAt,
            lastResult: lastResult,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncStateTable, SyncStateRow>(table),
                    BaseReferences<_$AppDatabase, $SyncStateTable,
                        SyncStateRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateRow,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateRow,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>
    ),
    SyncStateRow,
    PrefetchHooks Function()>;
typedef $$SyncReviewsTableCreateCompanionBuilder = SyncReviewsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String kind,
  required String recordId,
  required String field,
  required String kept,
  required String other,
  required String reason,
  required DateTime createdAt,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});
typedef $$SyncReviewsTableUpdateCompanionBuilder = SyncReviewsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> kind,
  Value<String> recordId,
  Value<String> field,
  Value<String> kept,
  Value<String> other,
  Value<String> reason,
  Value<DateTime> createdAt,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});

class $$SyncReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncReviewsTable> {
  $$SyncReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get field => $composableBuilder(
      column: $table.field, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kept => $composableBuilder(
      column: $table.kept, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get other => $composableBuilder(
      column: $table.other, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncReviewsTable> {
  $$SyncReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get field => $composableBuilder(
      column: $table.field, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kept => $composableBuilder(
      column: $table.kept, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get other => $composableBuilder(
      column: $table.other, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncReviewsTable> {
  $$SyncReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get kept =>
      $composableBuilder(column: $table.kept, builder: (column) => column);

  GeneratedColumn<String> get other =>
      $composableBuilder(column: $table.other, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);
}

class $$SyncReviewsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncReviewsTable,
    SyncReviewRow,
    $$SyncReviewsTableFilterComposer,
    $$SyncReviewsTableOrderingComposer,
    $$SyncReviewsTableAnnotationComposer,
    $$SyncReviewsTableCreateCompanionBuilder,
    $$SyncReviewsTableUpdateCompanionBuilder,
    (
      SyncReviewRow,
      BaseReferences<_$AppDatabase, $SyncReviewsTable, SyncReviewRow>
    ),
    SyncReviewRow,
    PrefetchHooks Function()> {
  $$SyncReviewsTableTableManager(_$AppDatabase db, $SyncReviewsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> field = const Value.absent(),
            Value<String> kept = const Value.absent(),
            Value<String> other = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncReviewsCompanion(
            id: id,
            workspaceId: workspaceId,
            kind: kind,
            recordId: recordId,
            field: field,
            kept: kept,
            other: other,
            reason: reason,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String kind,
            required String recordId,
            required String field,
            required String kept,
            required String other,
            required String reason,
            required DateTime createdAt,
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncReviewsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            kind: kind,
            recordId: recordId,
            field: field,
            kept: kept,
            other: other,
            reason: reason,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncReviewsTable, SyncReviewRow>(table),
                    BaseReferences<_$AppDatabase, $SyncReviewsTable,
                        SyncReviewRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncReviewsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncReviewsTable,
    SyncReviewRow,
    $$SyncReviewsTableFilterComposer,
    $$SyncReviewsTableOrderingComposer,
    $$SyncReviewsTableAnnotationComposer,
    $$SyncReviewsTableCreateCompanionBuilder,
    $$SyncReviewsTableUpdateCompanionBuilder,
    (
      SyncReviewRow,
      BaseReferences<_$AppDatabase, $SyncReviewsTable, SyncReviewRow>
    ),
    SyncReviewRow,
    PrefetchHooks Function()>;
typedef $$SpaceMembersTableCreateCompanionBuilder = SpaceMembersCompanion
    Function({
  required String workspaceId,
  required String accountId,
  required String role,
  required String status,
  Value<String> displayName,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SpaceMembersTableUpdateCompanionBuilder = SpaceMembersCompanion
    Function({
  Value<String> workspaceId,
  Value<String> accountId,
  Value<String> role,
  Value<String> status,
  Value<String> displayName,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SpaceMembersTableFilterComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SpaceMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SpaceMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SpaceMembersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SpaceMembersTable,
    SpaceMemberRow,
    $$SpaceMembersTableFilterComposer,
    $$SpaceMembersTableOrderingComposer,
    $$SpaceMembersTableAnnotationComposer,
    $$SpaceMembersTableCreateCompanionBuilder,
    $$SpaceMembersTableUpdateCompanionBuilder,
    (
      SpaceMemberRow,
      BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMemberRow>
    ),
    SpaceMemberRow,
    PrefetchHooks Function()> {
  $$SpaceMembersTableTableManager(_$AppDatabase db, $SpaceMembersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpaceMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpaceMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpaceMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> workspaceId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SpaceMembersCompanion(
            workspaceId: workspaceId,
            accountId: accountId,
            role: role,
            status: status,
            displayName: displayName,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String workspaceId,
            required String accountId,
            required String role,
            required String status,
            Value<String> displayName = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SpaceMembersCompanion.insert(
            workspaceId: workspaceId,
            accountId: accountId,
            role: role,
            status: status,
            displayName: displayName,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SpaceMembersTable, SpaceMemberRow>(table),
                    BaseReferences<_$AppDatabase, $SpaceMembersTable,
                        SpaceMemberRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SpaceMembersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SpaceMembersTable,
    SpaceMemberRow,
    $$SpaceMembersTableFilterComposer,
    $$SpaceMembersTableOrderingComposer,
    $$SpaceMembersTableAnnotationComposer,
    $$SpaceMembersTableCreateCompanionBuilder,
    $$SpaceMembersTableUpdateCompanionBuilder,
    (
      SpaceMemberRow,
      BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMemberRow>
    ),
    SpaceMemberRow,
    PrefetchHooks Function()>;
typedef $$SyncParkedTableCreateCompanionBuilder = SyncParkedCompanion Function({
  required String workspaceId,
  required String kind,
  required String recordId,
  required int seq,
  Value<int> rowid,
});
typedef $$SyncParkedTableUpdateCompanionBuilder = SyncParkedCompanion Function({
  Value<String> workspaceId,
  Value<String> kind,
  Value<String> recordId,
  Value<int> seq,
  Value<int> rowid,
});

class $$SyncParkedTableFilterComposer
    extends Composer<_$AppDatabase, $SyncParkedTable> {
  $$SyncParkedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $$SyncParkedTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncParkedTable> {
  $$SyncParkedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $$SyncParkedTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncParkedTable> {
  $$SyncParkedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$SyncParkedTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncParkedTable,
    SyncParkedRow,
    $$SyncParkedTableFilterComposer,
    $$SyncParkedTableOrderingComposer,
    $$SyncParkedTableAnnotationComposer,
    $$SyncParkedTableCreateCompanionBuilder,
    $$SyncParkedTableUpdateCompanionBuilder,
    (
      SyncParkedRow,
      BaseReferences<_$AppDatabase, $SyncParkedTable, SyncParkedRow>
    ),
    SyncParkedRow,
    PrefetchHooks Function()> {
  $$SyncParkedTableTableManager(_$AppDatabase db, $SyncParkedTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncParkedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncParkedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncParkedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> workspaceId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncParkedCompanion(
            workspaceId: workspaceId,
            kind: kind,
            recordId: recordId,
            seq: seq,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String workspaceId,
            required String kind,
            required String recordId,
            required int seq,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncParkedCompanion.insert(
            workspaceId: workspaceId,
            kind: kind,
            recordId: recordId,
            seq: seq,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncParkedTable, SyncParkedRow>(table),
                    BaseReferences<_$AppDatabase, $SyncParkedTable,
                        SyncParkedRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncParkedTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncParkedTable,
    SyncParkedRow,
    $$SyncParkedTableFilterComposer,
    $$SyncParkedTableOrderingComposer,
    $$SyncParkedTableAnnotationComposer,
    $$SyncParkedTableCreateCompanionBuilder,
    $$SyncParkedTableUpdateCompanionBuilder,
    (
      SyncParkedRow,
      BaseReferences<_$AppDatabase, $SyncParkedTable, SyncParkedRow>
    ),
    SyncParkedRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db, _db.taskLists);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$AuditLogTableTableManager get auditLog =>
      $$AuditLogTableTableManager(_db, _db.auditLog);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$EventLogTableTableManager get eventLog =>
      $$EventLogTableTableManager(_db, _db.eventLog);
  $$OpDedupeTableTableManager get opDedupe =>
      $$OpDedupeTableTableManager(_db, _db.opDedupe);
  $$RestoreSnapshotsTableTableManager get restoreSnapshots =>
      $$RestoreSnapshotsTableTableManager(_db, _db.restoreSnapshots);
  $$CalendarsTableTableManager get calendars =>
      $$CalendarsTableTableManager(_db, _db.calendars);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$SchedulesTableTableManager get schedules =>
      $$SchedulesTableTableManager(_db, _db.schedules);
  $$OccurrenceExceptionsTableTableManager get occurrenceExceptions =>
      $$OccurrenceExceptionsTableTableManager(_db, _db.occurrenceExceptions);
  $$OccurrenceCompletionsTableTableManager get occurrenceCompletions =>
      $$OccurrenceCompletionsTableTableManager(_db, _db.occurrenceCompletions);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$ExecutionRecordsTableTableManager get executionRecords =>
      $$ExecutionRecordsTableTableManager(_db, _db.executionRecords);
  $$MeasurementsTableTableManager get measurements =>
      $$MeasurementsTableTableManager(_db, _db.measurements);
  $$PeriodResultsTableTableManager get periodResults =>
      $$PeriodResultsTableTableManager(_db, _db.periodResults);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$MilestonesTableTableManager get milestones =>
      $$MilestonesTableTableManager(_db, _db.milestones);
  $$GoalLinksTableTableManager get goalLinks =>
      $$GoalLinksTableTableManager(_db, _db.goalLinks);
  $$WorkspaceSettingsTableTableManager get workspaceSettings =>
      $$WorkspaceSettingsTableTableManager(_db, _db.workspaceSettings);
  $$SyncBaseTableTableManager get syncBase =>
      $$SyncBaseTableTableManager(_db, _db.syncBase);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$SyncReviewsTableTableManager get syncReviews =>
      $$SyncReviewsTableTableManager(_db, _db.syncReviews);
  $$SpaceMembersTableTableManager get spaceMembers =>
      $$SpaceMembersTableTableManager(_db, _db.spaceMembers);
  $$SyncParkedTableTableManager get syncParked =>
      $$SyncParkedTableTableManager(_db, _db.syncParked);
}
