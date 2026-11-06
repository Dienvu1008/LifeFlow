// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registry_database.dart';

// ignore_for_file: type=lint
class $RegistryProfilesTable extends RegistryProfiles
    with TableInfo<$RegistryProfilesTable, RegistryProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegistryProfilesTable(this.attachedDatabase, [this._alias]);
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
        accountId,
        accountProvider,
        isActive,
        signedOut,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registry_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<RegistryProfile> instance,
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
  RegistryProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistryProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      accountProvider: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}account_provider']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      signedOut: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}signed_out'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RegistryProfilesTable createAlias(String alias) {
    return $RegistryProfilesTable(attachedDatabase, alias);
  }
}

class RegistryProfile extends DataClass implements Insertable<RegistryProfile> {
  final String id;
  final String displayName;
  final String? accountId;
  final String? accountProvider;
  final bool isActive;
  final bool signedOut;
  final DateTime createdAt;
  const RegistryProfile(
      {required this.id,
      required this.displayName,
      this.accountId,
      this.accountProvider,
      required this.isActive,
      required this.signedOut,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || accountProvider != null) {
      map['account_provider'] = Variable<String>(accountProvider);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['signed_out'] = Variable<bool>(signedOut);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RegistryProfilesCompanion toCompanion(bool nullToAbsent) {
    return RegistryProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      accountProvider: accountProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(accountProvider),
      isActive: Value(isActive),
      signedOut: Value(signedOut),
      createdAt: Value(createdAt),
    );
  }

  factory RegistryProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistryProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      accountProvider: serializer.fromJson<String?>(json['accountProvider']),
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
      'accountId': serializer.toJson<String?>(accountId),
      'accountProvider': serializer.toJson<String?>(accountProvider),
      'isActive': serializer.toJson<bool>(isActive),
      'signedOut': serializer.toJson<bool>(signedOut),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RegistryProfile copyWith(
          {String? id,
          String? displayName,
          Value<String?> accountId = const Value.absent(),
          Value<String?> accountProvider = const Value.absent(),
          bool? isActive,
          bool? signedOut,
          DateTime? createdAt}) =>
      RegistryProfile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        accountId: accountId.present ? accountId.value : this.accountId,
        accountProvider: accountProvider.present
            ? accountProvider.value
            : this.accountProvider,
        isActive: isActive ?? this.isActive,
        signedOut: signedOut ?? this.signedOut,
        createdAt: createdAt ?? this.createdAt,
      );
  RegistryProfile copyWithCompanion(RegistryProfilesCompanion data) {
    return RegistryProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      accountProvider: data.accountProvider.present
          ? data.accountProvider.value
          : this.accountProvider,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      signedOut: data.signedOut.present ? data.signedOut.value : this.signedOut,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistryProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('accountId: $accountId, ')
          ..write('accountProvider: $accountProvider, ')
          ..write('isActive: $isActive, ')
          ..write('signedOut: $signedOut, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, accountId, accountProvider,
      isActive, signedOut, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistryProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.accountId == this.accountId &&
          other.accountProvider == this.accountProvider &&
          other.isActive == this.isActive &&
          other.signedOut == this.signedOut &&
          other.createdAt == this.createdAt);
}

class RegistryProfilesCompanion extends UpdateCompanion<RegistryProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> accountId;
  final Value<String?> accountProvider;
  final Value<bool> isActive;
  final Value<bool> signedOut;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RegistryProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.accountId = const Value.absent(),
    this.accountProvider = const Value.absent(),
    this.isActive = const Value.absent(),
    this.signedOut = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegistryProfilesCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.accountId = const Value.absent(),
    this.accountProvider = const Value.absent(),
    this.isActive = const Value.absent(),
    this.signedOut = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt);
  static Insertable<RegistryProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? accountId,
    Expression<String>? accountProvider,
    Expression<bool>? isActive,
    Expression<bool>? signedOut,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (accountId != null) 'account_id': accountId,
      if (accountProvider != null) 'account_provider': accountProvider,
      if (isActive != null) 'is_active': isActive,
      if (signedOut != null) 'signed_out': signedOut,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegistryProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<String?>? accountId,
      Value<String?>? accountProvider,
      Value<bool>? isActive,
      Value<bool>? signedOut,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return RegistryProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      accountId: accountId ?? this.accountId,
      accountProvider: accountProvider ?? this.accountProvider,
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
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (accountProvider.present) {
      map['account_provider'] = Variable<String>(accountProvider.value);
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
    return (StringBuffer('RegistryProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('accountId: $accountId, ')
          ..write('accountProvider: $accountProvider, ')
          ..write('isActive: $isActive, ')
          ..write('signedOut: $signedOut, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RegistryMetaTable extends RegistryMeta
    with TableInfo<$RegistryMetaTable, RegistryMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegistryMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registry_meta';
  @override
  VerificationContext validateIntegrity(Insertable<RegistryMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RegistryMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistryMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $RegistryMetaTable createAlias(String alias) {
    return $RegistryMetaTable(attachedDatabase, alias);
  }
}

class RegistryMetaData extends DataClass
    implements Insertable<RegistryMetaData> {
  final String key;
  final String value;
  const RegistryMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  RegistryMetaCompanion toCompanion(bool nullToAbsent) {
    return RegistryMetaCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory RegistryMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistryMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  RegistryMetaData copyWith({String? key, String? value}) => RegistryMetaData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  RegistryMetaData copyWithCompanion(RegistryMetaCompanion data) {
    return RegistryMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistryMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistryMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class RegistryMetaCompanion extends UpdateCompanion<RegistryMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const RegistryMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegistryMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<RegistryMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegistryMetaCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return RegistryMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegistryMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RegistryDatabase extends GeneratedDatabase {
  _$RegistryDatabase(QueryExecutor e) : super(e);
  $RegistryDatabaseManager get managers => $RegistryDatabaseManager(this);
  late final $RegistryProfilesTable registryProfiles =
      $RegistryProfilesTable(this);
  late final $RegistryMetaTable registryMeta = $RegistryMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [registryProfiles, registryMeta];
}

typedef $$RegistryProfilesTableCreateCompanionBuilder
    = RegistryProfilesCompanion Function({
  required String id,
  Value<String> displayName,
  Value<String?> accountId,
  Value<String?> accountProvider,
  Value<bool> isActive,
  Value<bool> signedOut,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$RegistryProfilesTableUpdateCompanionBuilder
    = RegistryProfilesCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String?> accountId,
  Value<String?> accountProvider,
  Value<bool> isActive,
  Value<bool> signedOut,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$RegistryProfilesTableFilterComposer
    extends Composer<_$RegistryDatabase, $RegistryProfilesTable> {
  $$RegistryProfilesTableFilterComposer({
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

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get signedOut => $composableBuilder(
      column: $table.signedOut, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$RegistryProfilesTableOrderingComposer
    extends Composer<_$RegistryDatabase, $RegistryProfilesTable> {
  $$RegistryProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get signedOut => $composableBuilder(
      column: $table.signedOut, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$RegistryProfilesTableAnnotationComposer
    extends Composer<_$RegistryDatabase, $RegistryProfilesTable> {
  $$RegistryProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get accountProvider => $composableBuilder(
      column: $table.accountProvider, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get signedOut =>
      $composableBuilder(column: $table.signedOut, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RegistryProfilesTableTableManager extends RootTableManager<
    _$RegistryDatabase,
    $RegistryProfilesTable,
    RegistryProfile,
    $$RegistryProfilesTableFilterComposer,
    $$RegistryProfilesTableOrderingComposer,
    $$RegistryProfilesTableAnnotationComposer,
    $$RegistryProfilesTableCreateCompanionBuilder,
    $$RegistryProfilesTableUpdateCompanionBuilder,
    (
      RegistryProfile,
      BaseReferences<_$RegistryDatabase, $RegistryProfilesTable,
          RegistryProfile>
    ),
    RegistryProfile,
    PrefetchHooks Function()> {
  $$RegistryProfilesTableTableManager(
      _$RegistryDatabase db, $RegistryProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegistryProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegistryProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegistryProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String?> accountProvider = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> signedOut = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RegistryProfilesCompanion(
            id: id,
            displayName: displayName,
            accountId: accountId,
            accountProvider: accountProvider,
            isActive: isActive,
            signedOut: signedOut,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> displayName = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String?> accountProvider = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> signedOut = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RegistryProfilesCompanion.insert(
            id: id,
            displayName: displayName,
            accountId: accountId,
            accountProvider: accountProvider,
            isActive: isActive,
            signedOut: signedOut,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RegistryProfilesTable, RegistryProfile>(table),
                    BaseReferences<_$RegistryDatabase, $RegistryProfilesTable,
                        RegistryProfile>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RegistryProfilesTableProcessedTableManager = ProcessedTableManager<
    _$RegistryDatabase,
    $RegistryProfilesTable,
    RegistryProfile,
    $$RegistryProfilesTableFilterComposer,
    $$RegistryProfilesTableOrderingComposer,
    $$RegistryProfilesTableAnnotationComposer,
    $$RegistryProfilesTableCreateCompanionBuilder,
    $$RegistryProfilesTableUpdateCompanionBuilder,
    (
      RegistryProfile,
      BaseReferences<_$RegistryDatabase, $RegistryProfilesTable,
          RegistryProfile>
    ),
    RegistryProfile,
    PrefetchHooks Function()>;
typedef $$RegistryMetaTableCreateCompanionBuilder = RegistryMetaCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$RegistryMetaTableUpdateCompanionBuilder = RegistryMetaCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$RegistryMetaTableFilterComposer
    extends Composer<_$RegistryDatabase, $RegistryMetaTable> {
  $$RegistryMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$RegistryMetaTableOrderingComposer
    extends Composer<_$RegistryDatabase, $RegistryMetaTable> {
  $$RegistryMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$RegistryMetaTableAnnotationComposer
    extends Composer<_$RegistryDatabase, $RegistryMetaTable> {
  $$RegistryMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$RegistryMetaTableTableManager extends RootTableManager<
    _$RegistryDatabase,
    $RegistryMetaTable,
    RegistryMetaData,
    $$RegistryMetaTableFilterComposer,
    $$RegistryMetaTableOrderingComposer,
    $$RegistryMetaTableAnnotationComposer,
    $$RegistryMetaTableCreateCompanionBuilder,
    $$RegistryMetaTableUpdateCompanionBuilder,
    (
      RegistryMetaData,
      BaseReferences<_$RegistryDatabase, $RegistryMetaTable, RegistryMetaData>
    ),
    RegistryMetaData,
    PrefetchHooks Function()> {
  $$RegistryMetaTableTableManager(
      _$RegistryDatabase db, $RegistryMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegistryMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegistryMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegistryMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RegistryMetaCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              RegistryMetaCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RegistryMetaTable, RegistryMetaData>(table),
                    BaseReferences<_$RegistryDatabase, $RegistryMetaTable,
                        RegistryMetaData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RegistryMetaTableProcessedTableManager = ProcessedTableManager<
    _$RegistryDatabase,
    $RegistryMetaTable,
    RegistryMetaData,
    $$RegistryMetaTableFilterComposer,
    $$RegistryMetaTableOrderingComposer,
    $$RegistryMetaTableAnnotationComposer,
    $$RegistryMetaTableCreateCompanionBuilder,
    $$RegistryMetaTableUpdateCompanionBuilder,
    (
      RegistryMetaData,
      BaseReferences<_$RegistryDatabase, $RegistryMetaTable, RegistryMetaData>
    ),
    RegistryMetaData,
    PrefetchHooks Function()>;

class $RegistryDatabaseManager {
  final _$RegistryDatabase _db;
  $RegistryDatabaseManager(this._db);
  $$RegistryProfilesTableTableManager get registryProfiles =>
      $$RegistryProfilesTableTableManager(_db, _db.registryProfiles);
  $$RegistryMetaTableTableManager get registryMeta =>
      $$RegistryMetaTableTableManager(_db, _db.registryMeta);
}
