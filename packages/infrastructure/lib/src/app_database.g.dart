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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, activeWorkspaceId, accountId,
      accountProvider, version, isActive, signedOut, createdAt);
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
  @override
  List<GeneratedColumn> get $columns => [id, kind, ownerId, createdAt];
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
  const Workspace(
      {required this.id,
      required this.kind,
      required this.ownerId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['owner_id'] = Variable<String>(ownerId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      kind: Value(kind),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
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
    };
  }

  Workspace copyWith(
          {String? id, String? kind, String? ownerId, DateTime? createdAt}) =>
      Workspace(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        ownerId: ownerId ?? this.ownerId,
        createdAt: createdAt ?? this.createdAt,
      );
  Workspace copyWithCompanion(WorkspacesCompanion data) {
    return Workspace(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workspace(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, ownerId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.ownerId == this.ownerId &&
          other.createdAt == this.createdAt);
}

class WorkspacesCompanion extends UpdateCompanion<Workspace> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> ownerId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    this.kind = const Value.absent(),
    required String ownerId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        ownerId = Value(ownerId),
        createdAt = Value(createdAt);
  static Insertable<Workspace> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? ownerId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String>? ownerId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      ownerId: ownerId ?? this.ownerId,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
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
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt, ')
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
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
        title
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
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
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
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
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
  final String title;
  const TaskList(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      required this.title});
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
    map['title'] = Variable<String>(title);
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
      title: Value(title),
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
      title: serializer.fromJson<String>(json['title']),
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
      'title': serializer.toJson<String>(title),
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
          String? title}) =>
      TaskList(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        title: title ?? this.title,
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
      title: data.title.present ? data.title.value : this.title,
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
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, ownerId, version, createdAt,
      updatedAt, deletedAt, deletedBy, title);
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
          other.title == this.title);
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
  final Value<String> title;
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
    this.title = const Value.absent(),
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
    required String title,
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
    Expression<String>? title,
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
      if (title != null) 'title': title,
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
      Value<String>? title,
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
      title: title ?? this.title,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
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
          ..write('title: $title, ')
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
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
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
        tags
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
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
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
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
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
  final String tags;
  const Task(
      {required this.id,
      required this.workspaceId,
      required this.ownerId,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
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
      required this.tags});
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
    map['tags'] = Variable<String>(tags);
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
      tags: Value(tags),
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
      tags: serializer.fromJson<String>(json['tags']),
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
      'tags': serializer.toJson<String>(tags),
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
          String? tags}) =>
      Task(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        ownerId: ownerId ?? this.ownerId,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
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
        tags: tags ?? this.tags,
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
      tags: data.tags.present ? data.tags.value : this.tags,
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
          ..write('tags: $tags')
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
      tags);
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
          other.tags == this.tags);
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
  final Value<String> tags;
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
    this.tags = const Value.absent(),
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
    this.tags = const Value.absent(),
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
    Expression<String>? tags,
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
      if (tags != null) 'tags': tags,
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
      Value<String>? tags,
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
      tags: tags ?? this.tags,
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
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
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
          ..write('tags: $tags, ')
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
  Set<GeneratedColumn> get $primaryKey => {operationId, entityId};
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
        opDedupe
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
  Value<int> rowid,
});
typedef $$WorkspacesTableUpdateCompanionBuilder = WorkspacesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> ownerId,
  Value<DateTime> createdAt,
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
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspacesCompanion(
            id: id,
            kind: kind,
            ownerId: ownerId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> kind = const Value.absent(),
            required String ownerId,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkspacesCompanion.insert(
            id: id,
            kind: kind,
            ownerId: ownerId,
            createdAt: createdAt,
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
  required String title,
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
  Value<String> title,
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

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);
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
            Value<String> title = const Value.absent(),
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
            title: title,
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
            required String title,
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
            title: title,
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
  Value<String> tags,
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
  Value<String> tags,
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

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);
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
            Value<String> tags = const Value.absent(),
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
            tags: tags,
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
            Value<String> tags = const Value.absent(),
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
            tags: tags,
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
}
