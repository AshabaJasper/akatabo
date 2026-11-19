// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta('iconKey');
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colourTokenMeta = const VerificationMeta('colourToken');
  @override
  late final GeneratedColumn<String> colourToken = GeneratedColumn<String>(
    'colour_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CategoryKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _monthlyBudgetMeta = const VerificationMeta('monthlyBudget');
  @override
  late final GeneratedColumn<int> monthlyBudget = GeneratedColumn<int>(
    'monthly_budget',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _budgetCarriesOverMeta = const VerificationMeta(
    'budgetCarriesOver',
  );
  @override
  late final GeneratedColumn<bool> budgetCarriesOver = GeneratedColumn<bool>(
    'budget_carries_over',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("budget_carries_over" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _budgetWarnAtMeta = const VerificationMeta('budgetWarnAt');
  @override
  late final GeneratedColumn<int> budgetWarnAt = GeneratedColumn<int>(
    'budget_warn_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta('isSystem');
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_system" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    name,
    iconKey,
    colourToken,
    kind,
    sortOrder,
    hidden,
    monthlyBudget,
    budgetCarriesOver,
    budgetWarnAt,
    isSystem,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta, iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('colour_token')) {
      context.handle(
        _colourTokenMeta,
        colourToken.isAcceptableOrUnknown(data['colour_token']!, _colourTokenMeta),
      );
    } else if (isInserting) {
      context.missing(_colourTokenMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta, hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('monthly_budget')) {
      context.handle(
        _monthlyBudgetMeta,
        monthlyBudget.isAcceptableOrUnknown(data['monthly_budget']!, _monthlyBudgetMeta),
      );
    }
    if (data.containsKey('budget_carries_over')) {
      context.handle(
        _budgetCarriesOverMeta,
        budgetCarriesOver.isAcceptableOrUnknown(
          data['budget_carries_over']!,
          _budgetCarriesOverMeta,
        ),
      );
    }
    if (data.containsKey('budget_warn_at')) {
      context.handle(
        _budgetWarnAtMeta,
        budgetWarnAt.isAcceptableOrUnknown(data['budget_warn_at']!, _budgetWarnAtMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      colourToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colour_token'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      monthlyBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_budget'],
      ),
      budgetCarriesOver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}budget_carries_over'],
      )!,
      budgetWarnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_warn_at'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, String, String> $converterkind =
      const EnumNameConverter<CategoryKind>(CategoryKind.values);
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;

  /// A name from the icon table in DESIGN_SYSTEM.md.
  final String iconKey;

  /// A `cat-` colour token name.
  final String colourToken;
  final CategoryKind kind;
  final int sortOrder;
  final bool hidden;
  final int? monthlyBudget;
  final bool budgetCarriesOver;

  /// The "Nearly used" level, as a whole percent of the budget.
  final int budgetWarnAt;

  /// Fees and tax: its totals are built from the fee and tax fields, not chosen on Add.
  final bool isSystem;
  const Category({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    required this.iconKey,
    required this.colourToken,
    required this.kind,
    required this.sortOrder,
    required this.hidden,
    this.monthlyBudget,
    required this.budgetCarriesOver,
    required this.budgetWarnAt,
    required this.isSystem,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['name'] = Variable<String>(name);
    map['icon_key'] = Variable<String>(iconKey);
    map['colour_token'] = Variable<String>(colourToken);
    {
      map['kind'] = Variable<String>($CategoriesTable.$converterkind.toSql(kind));
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || monthlyBudget != null) {
      map['monthly_budget'] = Variable<int>(monthlyBudget);
    }
    map['budget_carries_over'] = Variable<bool>(budgetCarriesOver);
    map['budget_warn_at'] = Variable<int>(budgetWarnAt);
    map['is_system'] = Variable<bool>(isSystem);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      name: Value(name),
      iconKey: Value(iconKey),
      colourToken: Value(colourToken),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      hidden: Value(hidden),
      monthlyBudget: monthlyBudget == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyBudget),
      budgetCarriesOver: Value(budgetCarriesOver),
      budgetWarnAt: Value(budgetWarnAt),
      isSystem: Value(isSystem),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      name: serializer.fromJson<String>(json['name']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      colourToken: serializer.fromJson<String>(json['colourToken']),
      kind: $CategoriesTable.$converterkind.fromJson(serializer.fromJson<String>(json['kind'])),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      monthlyBudget: serializer.fromJson<int?>(json['monthlyBudget']),
      budgetCarriesOver: serializer.fromJson<bool>(json['budgetCarriesOver']),
      budgetWarnAt: serializer.fromJson<int>(json['budgetWarnAt']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'name': serializer.toJson<String>(name),
      'iconKey': serializer.toJson<String>(iconKey),
      'colourToken': serializer.toJson<String>(colourToken),
      'kind': serializer.toJson<String>($CategoriesTable.$converterkind.toJson(kind)),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'hidden': serializer.toJson<bool>(hidden),
      'monthlyBudget': serializer.toJson<int?>(monthlyBudget),
      'budgetCarriesOver': serializer.toJson<bool>(budgetCarriesOver),
      'budgetWarnAt': serializer.toJson<int>(budgetWarnAt),
      'isSystem': serializer.toJson<bool>(isSystem),
    };
  }

  Category copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? iconKey,
    String? colourToken,
    CategoryKind? kind,
    int? sortOrder,
    bool? hidden,
    Value<int?> monthlyBudget = const Value.absent(),
    bool? budgetCarriesOver,
    int? budgetWarnAt,
    bool? isSystem,
  }) => Category(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    colourToken: colourToken ?? this.colourToken,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    hidden: hidden ?? this.hidden,
    monthlyBudget: monthlyBudget.present ? monthlyBudget.value : this.monthlyBudget,
    budgetCarriesOver: budgetCarriesOver ?? this.budgetCarriesOver,
    budgetWarnAt: budgetWarnAt ?? this.budgetWarnAt,
    isSystem: isSystem ?? this.isSystem,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      name: data.name.present ? data.name.value : this.name,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colourToken: data.colourToken.present ? data.colourToken.value : this.colourToken,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      monthlyBudget: data.monthlyBudget.present ? data.monthlyBudget.value : this.monthlyBudget,
      budgetCarriesOver: data.budgetCarriesOver.present
          ? data.budgetCarriesOver.value
          : this.budgetCarriesOver,
      budgetWarnAt: data.budgetWarnAt.present ? data.budgetWarnAt.value : this.budgetWarnAt,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('colourToken: $colourToken, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden, ')
          ..write('monthlyBudget: $monthlyBudget, ')
          ..write('budgetCarriesOver: $budgetCarriesOver, ')
          ..write('budgetWarnAt: $budgetWarnAt, ')
          ..write('isSystem: $isSystem')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    name,
    iconKey,
    colourToken,
    kind,
    sortOrder,
    hidden,
    monthlyBudget,
    budgetCarriesOver,
    budgetWarnAt,
    isSystem,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.name == this.name &&
          other.iconKey == this.iconKey &&
          other.colourToken == this.colourToken &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.hidden == this.hidden &&
          other.monthlyBudget == this.monthlyBudget &&
          other.budgetCarriesOver == this.budgetCarriesOver &&
          other.budgetWarnAt == this.budgetWarnAt &&
          other.isSystem == this.isSystem);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> name;
  final Value<String> iconKey;
  final Value<String> colourToken;
  final Value<CategoryKind> kind;
  final Value<int> sortOrder;
  final Value<bool> hidden;
  final Value<int?> monthlyBudget;
  final Value<bool> budgetCarriesOver;
  final Value<int> budgetWarnAt;
  final Value<bool> isSystem;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colourToken = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.monthlyBudget = const Value.absent(),
    this.budgetCarriesOver = const Value.absent(),
    this.budgetWarnAt = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String iconKey,
    required String colourToken,
    required CategoryKind kind,
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.monthlyBudget = const Value.absent(),
    this.budgetCarriesOver = const Value.absent(),
    this.budgetWarnAt = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name),
       iconKey = Value(iconKey),
       colourToken = Value(colourToken),
       kind = Value(kind);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? name,
    Expression<String>? iconKey,
    Expression<String>? colourToken,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<bool>? hidden,
    Expression<int>? monthlyBudget,
    Expression<bool>? budgetCarriesOver,
    Expression<int>? budgetWarnAt,
    Expression<bool>? isSystem,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (name != null) 'name': name,
      if (iconKey != null) 'icon_key': iconKey,
      if (colourToken != null) 'colour_token': colourToken,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (hidden != null) 'hidden': hidden,
      if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
      if (budgetCarriesOver != null) 'budget_carries_over': budgetCarriesOver,
      if (budgetWarnAt != null) 'budget_warn_at': budgetWarnAt,
      if (isSystem != null) 'is_system': isSystem,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? name,
    Value<String>? iconKey,
    Value<String>? colourToken,
    Value<CategoryKind>? kind,
    Value<int>? sortOrder,
    Value<bool>? hidden,
    Value<int?>? monthlyBudget,
    Value<bool>? budgetCarriesOver,
    Value<int>? budgetWarnAt,
    Value<bool>? isSystem,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colourToken: colourToken ?? this.colourToken,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      hidden: hidden ?? this.hidden,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      budgetCarriesOver: budgetCarriesOver ?? this.budgetCarriesOver,
      budgetWarnAt: budgetWarnAt ?? this.budgetWarnAt,
      isSystem: isSystem ?? this.isSystem,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colourToken.present) {
      map['colour_token'] = Variable<String>(colourToken.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>($CategoriesTable.$converterkind.toSql(kind.value));
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (monthlyBudget.present) {
      map['monthly_budget'] = Variable<int>(monthlyBudget.value);
    }
    if (budgetCarriesOver.present) {
      map['budget_carries_over'] = Variable<bool>(budgetCarriesOver.value);
    }
    if (budgetWarnAt.present) {
      map['budget_warn_at'] = Variable<int>(budgetWarnAt.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('colourToken: $colourToken, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden, ')
          ..write('monthlyBudget: $monthlyBudget, ')
          ..write('budgetCarriesOver: $budgetCarriesOver, ')
          ..write('budgetWarnAt: $budgetWarnAt, ')
          ..write('isSystem: $isSystem, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountKind, String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AccountKind>($AccountsTable.$converterkind);
  static const VerificationMeta _colourTokenMeta = const VerificationMeta('colourToken');
  @override
  late final GeneratedColumn<String> colourToken = GeneratedColumn<String>(
    'colour_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingBalanceMeta = const VerificationMeta('openingBalance');
  @override
  late final GeneratedColumn<int> openingBalance = GeneratedColumn<int>(
    'opening_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _askFeeEachTimeMeta = const VerificationMeta('askFeeEachTime');
  @override
  late final GeneratedColumn<bool> askFeeEachTime = GeneratedColumn<bool>(
    'ask_fee_each_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("ask_fee_each_time" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _countInTotalsMeta = const VerificationMeta('countInTotals');
  @override
  late final GeneratedColumn<bool> countInTotals = GeneratedColumn<bool>(
    'count_in_totals',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("count_in_totals" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    name,
    kind,
    colourToken,
    openingBalance,
    askFeeEachTime,
    countInTotals,
    enabled,
    isDefault,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('colour_token')) {
      context.handle(
        _colourTokenMeta,
        colourToken.isAcceptableOrUnknown(data['colour_token']!, _colourTokenMeta),
      );
    } else if (isInserting) {
      context.missing(_colourTokenMeta);
    }
    if (data.containsKey('opening_balance')) {
      context.handle(
        _openingBalanceMeta,
        openingBalance.isAcceptableOrUnknown(data['opening_balance']!, _openingBalanceMeta),
      );
    }
    if (data.containsKey('ask_fee_each_time')) {
      context.handle(
        _askFeeEachTimeMeta,
        askFeeEachTime.isAcceptableOrUnknown(data['ask_fee_each_time']!, _askFeeEachTimeMeta),
      );
    }
    if (data.containsKey('count_in_totals')) {
      context.handle(
        _countInTotalsMeta,
        countInTotals.isAcceptableOrUnknown(data['count_in_totals']!, _countInTotalsMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: $AccountsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ),
      colourToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colour_token'],
      )!,
      openingBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_balance'],
      )!,
      askFeeEachTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ask_fee_each_time'],
      )!,
      countInTotals: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}count_in_totals'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountKind, String, String> $converterkind =
      const EnumNameConverter<AccountKind>(AccountKind.values);
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;
  final AccountKind kind;

  /// An `acct-` or `cat-` colour token name.
  final String colourToken;
  final int openingBalance;
  final bool askFeeEachTime;
  final bool countInTotals;
  final bool enabled;
  final bool isDefault;
  final int sortOrder;
  const Account({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    required this.kind,
    required this.colourToken,
    required this.openingBalance,
    required this.askFeeEachTime,
    required this.countInTotals,
    required this.enabled,
    required this.isDefault,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>($AccountsTable.$converterkind.toSql(kind));
    }
    map['colour_token'] = Variable<String>(colourToken);
    map['opening_balance'] = Variable<int>(openingBalance);
    map['ask_fee_each_time'] = Variable<bool>(askFeeEachTime);
    map['count_in_totals'] = Variable<bool>(countInTotals);
    map['enabled'] = Variable<bool>(enabled);
    map['is_default'] = Variable<bool>(isDefault);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      name: Value(name),
      kind: Value(kind),
      colourToken: Value(colourToken),
      openingBalance: Value(openingBalance),
      askFeeEachTime: Value(askFeeEachTime),
      countInTotals: Value(countInTotals),
      enabled: Value(enabled),
      isDefault: Value(isDefault),
      sortOrder: Value(sortOrder),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      name: serializer.fromJson<String>(json['name']),
      kind: $AccountsTable.$converterkind.fromJson(serializer.fromJson<String>(json['kind'])),
      colourToken: serializer.fromJson<String>(json['colourToken']),
      openingBalance: serializer.fromJson<int>(json['openingBalance']),
      askFeeEachTime: serializer.fromJson<bool>(json['askFeeEachTime']),
      countInTotals: serializer.fromJson<bool>(json['countInTotals']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>($AccountsTable.$converterkind.toJson(kind)),
      'colourToken': serializer.toJson<String>(colourToken),
      'openingBalance': serializer.toJson<int>(openingBalance),
      'askFeeEachTime': serializer.toJson<bool>(askFeeEachTime),
      'countInTotals': serializer.toJson<bool>(countInTotals),
      'enabled': serializer.toJson<bool>(enabled),
      'isDefault': serializer.toJson<bool>(isDefault),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Account copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    AccountKind? kind,
    String? colourToken,
    int? openingBalance,
    bool? askFeeEachTime,
    bool? countInTotals,
    bool? enabled,
    bool? isDefault,
    int? sortOrder,
  }) => Account(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colourToken: colourToken ?? this.colourToken,
    openingBalance: openingBalance ?? this.openingBalance,
    askFeeEachTime: askFeeEachTime ?? this.askFeeEachTime,
    countInTotals: countInTotals ?? this.countInTotals,
    enabled: enabled ?? this.enabled,
    isDefault: isDefault ?? this.isDefault,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      colourToken: data.colourToken.present ? data.colourToken.value : this.colourToken,
      openingBalance: data.openingBalance.present ? data.openingBalance.value : this.openingBalance,
      askFeeEachTime: data.askFeeEachTime.present ? data.askFeeEachTime.value : this.askFeeEachTime,
      countInTotals: data.countInTotals.present ? data.countInTotals.value : this.countInTotals,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colourToken: $colourToken, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('askFeeEachTime: $askFeeEachTime, ')
          ..write('countInTotals: $countInTotals, ')
          ..write('enabled: $enabled, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    name,
    kind,
    colourToken,
    openingBalance,
    askFeeEachTime,
    countInTotals,
    enabled,
    isDefault,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.colourToken == this.colourToken &&
          other.openingBalance == this.openingBalance &&
          other.askFeeEachTime == this.askFeeEachTime &&
          other.countInTotals == this.countInTotals &&
          other.enabled == this.enabled &&
          other.isDefault == this.isDefault &&
          other.sortOrder == this.sortOrder);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> name;
  final Value<AccountKind> kind;
  final Value<String> colourToken;
  final Value<int> openingBalance;
  final Value<bool> askFeeEachTime;
  final Value<bool> countInTotals;
  final Value<bool> enabled;
  final Value<bool> isDefault;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.colourToken = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.askFeeEachTime = const Value.absent(),
    this.countInTotals = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required AccountKind kind,
    required String colourToken,
    this.openingBalance = const Value.absent(),
    this.askFeeEachTime = const Value.absent(),
    this.countInTotals = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name),
       kind = Value(kind),
       colourToken = Value(colourToken);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? colourToken,
    Expression<int>? openingBalance,
    Expression<bool>? askFeeEachTime,
    Expression<bool>? countInTotals,
    Expression<bool>? enabled,
    Expression<bool>? isDefault,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (colourToken != null) 'colour_token': colourToken,
      if (openingBalance != null) 'opening_balance': openingBalance,
      if (askFeeEachTime != null) 'ask_fee_each_time': askFeeEachTime,
      if (countInTotals != null) 'count_in_totals': countInTotals,
      if (enabled != null) 'enabled': enabled,
      if (isDefault != null) 'is_default': isDefault,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? name,
    Value<AccountKind>? kind,
    Value<String>? colourToken,
    Value<int>? openingBalance,
    Value<bool>? askFeeEachTime,
    Value<bool>? countInTotals,
    Value<bool>? enabled,
    Value<bool>? isDefault,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colourToken: colourToken ?? this.colourToken,
      openingBalance: openingBalance ?? this.openingBalance,
      askFeeEachTime: askFeeEachTime ?? this.askFeeEachTime,
      countInTotals: countInTotals ?? this.countInTotals,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>($AccountsTable.$converterkind.toSql(kind.value));
    }
    if (colourToken.present) {
      map['colour_token'] = Variable<String>(colourToken.value);
    }
    if (openingBalance.present) {
      map['opening_balance'] = Variable<int>(openingBalance.value);
    }
    if (askFeeEachTime.present) {
      map['ask_fee_each_time'] = Variable<bool>(askFeeEachTime.value);
    }
    if (countInTotals.present) {
      map['count_in_totals'] = Variable<bool>(countInTotals.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
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
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colourToken: $colourToken, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('askFeeEachTime: $askFeeEachTime, ')
          ..write('countInTotals: $countInTotals, ')
          ..write('enabled: $enabled, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Direction, String> direction =
      GeneratedColumn<String>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Direction>($TransactionsTable.$converterdirection);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    check: () => ComparableExpr(amount).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payeeKeyMeta = const VerificationMeta('payeeKey');
  @override
  late final GeneratedColumn<String> payeeKey = GeneratedColumn<String>(
    'payee_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES categories (id)'),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES accounts (id)'),
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES accounts (id)'),
  );
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<int> fee = GeneratedColumn<int>(
    'fee',
    aliasedName,
    false,
    check: () => ComparableExpr(fee).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<int> tax = GeneratedColumn<int>(
    'tax',
    aliasedName,
    false,
    check: () => ComparableExpr(tax).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta('localDay');
  @override
  late final GeneratedColumn<int> localDay = GeneratedColumn<int>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _suggestedCategoryIdMeta = const VerificationMeta(
    'suggestedCategoryId',
  );
  @override
  late final GeneratedColumn<String> suggestedCategoryId = GeneratedColumn<String>(
    'suggested_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestionConfidenceMeta = const VerificationMeta(
    'suggestionConfidence',
  );
  @override
  late final GeneratedColumn<double> suggestionConfidence = GeneratedColumn<double>(
    'suggestion_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryWasCorrectedMeta = const VerificationMeta(
    'categoryWasCorrected',
  );
  @override
  late final GeneratedColumn<bool> categoryWasCorrected = GeneratedColumn<bool>(
    'category_was_corrected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("category_was_corrected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _flaggedUnusualMeta = const VerificationMeta('flaggedUnusual');
  @override
  late final GeneratedColumn<bool> flaggedUnusual = GeneratedColumn<bool>(
    'flagged_unusual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("flagged_unusual" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _flagDismissedMeta = const VerificationMeta('flagDismissed');
  @override
  late final GeneratedColumn<bool> flagDismissed = GeneratedColumn<bool>(
    'flag_dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("flag_dismissed" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _regularPaymentIdMeta = const VerificationMeta('regularPaymentId');
  @override
  late final GeneratedColumn<String> regularPaymentId = GeneratedColumn<String>(
    'regular_payment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    direction,
    amount,
    description,
    payeeKey,
    categoryId,
    accountId,
    toAccountId,
    fee,
    tax,
    note,
    occurredAt,
    localDay,
    suggestedCategoryId,
    suggestionConfidence,
    categoryWasCorrected,
    flaggedUnusual,
    flagDismissed,
    regularPaymentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta, amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['description']!, _descriptionMeta),
      );
    }
    if (data.containsKey('payee_key')) {
      context.handle(
        _payeeKeyMeta,
        payeeKey.isAcceptableOrUnknown(data['payee_key']!, _payeeKeyMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(data['to_account_id']!, _toAccountIdMeta),
      );
    }
    if (data.containsKey('fee')) {
      context.handle(_feeMeta, fee.isAcceptableOrUnknown(data['fee']!, _feeMeta));
    }
    if (data.containsKey('tax')) {
      context.handle(_taxMeta, tax.isAcceptableOrUnknown(data['tax']!, _taxMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('suggested_category_id')) {
      context.handle(
        _suggestedCategoryIdMeta,
        suggestedCategoryId.isAcceptableOrUnknown(
          data['suggested_category_id']!,
          _suggestedCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('suggestion_confidence')) {
      context.handle(
        _suggestionConfidenceMeta,
        suggestionConfidence.isAcceptableOrUnknown(
          data['suggestion_confidence']!,
          _suggestionConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('category_was_corrected')) {
      context.handle(
        _categoryWasCorrectedMeta,
        categoryWasCorrected.isAcceptableOrUnknown(
          data['category_was_corrected']!,
          _categoryWasCorrectedMeta,
        ),
      );
    }
    if (data.containsKey('flagged_unusual')) {
      context.handle(
        _flaggedUnusualMeta,
        flaggedUnusual.isAcceptableOrUnknown(data['flagged_unusual']!, _flaggedUnusualMeta),
      );
    }
    if (data.containsKey('flag_dismissed')) {
      context.handle(
        _flagDismissedMeta,
        flagDismissed.isAcceptableOrUnknown(data['flag_dismissed']!, _flagDismissedMeta),
      );
    }
    if (data.containsKey('regular_payment_id')) {
      context.handle(
        _regularPaymentIdMeta,
        regularPaymentId.isAcceptableOrUnknown(data['regular_payment_id']!, _regularPaymentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      direction: $TransactionsTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      payeeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_key'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      fee: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}fee'])!,
      tax: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tax'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_day'],
      )!,
      suggestedCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_category_id'],
      ),
      suggestionConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}suggestion_confidence'],
      ),
      categoryWasCorrected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}category_was_corrected'],
      )!,
      flaggedUnusual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flagged_unusual'],
      )!,
      flagDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flag_dismissed'],
      )!,
      regularPaymentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regular_payment_id'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Direction, String, String> $converterdirection =
      const EnumNameConverter<Direction>(Direction.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Direction direction;

  /// Whole shillings, always above zero. The direction carries the sign.
  final int amount;
  final String description;

  /// The description normalised for matching: payee history, regular payments, new payee.
  final String payeeKey;

  /// Null only for transfers, which have no category.
  final String? categoryId;
  final String accountId;

  /// The receiving account of a transfer.
  final String? toAccountId;
  final int fee;
  final int tax;
  final String? note;
  final DateTime occurredAt;

  /// The local calendar day of [occurredAt] as yyyymmdd, written at save time, so period
  /// queries do not depend on the phone's time zone later.
  final int localDay;
  final String? suggestedCategoryId;
  final double? suggestionConfidence;
  final bool categoryWasCorrected;
  final bool flaggedUnusual;
  final bool flagDismissed;
  final String? regularPaymentId;
  const Transaction({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.direction,
    required this.amount,
    required this.description,
    required this.payeeKey,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.fee,
    required this.tax,
    this.note,
    required this.occurredAt,
    required this.localDay,
    this.suggestedCategoryId,
    this.suggestionConfidence,
    required this.categoryWasCorrected,
    required this.flaggedUnusual,
    required this.flagDismissed,
    this.regularPaymentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['direction'] = Variable<String>($TransactionsTable.$converterdirection.toSql(direction));
    }
    map['amount'] = Variable<int>(amount);
    map['description'] = Variable<String>(description);
    map['payee_key'] = Variable<String>(payeeKey);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    map['fee'] = Variable<int>(fee);
    map['tax'] = Variable<int>(tax);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['local_day'] = Variable<int>(localDay);
    if (!nullToAbsent || suggestedCategoryId != null) {
      map['suggested_category_id'] = Variable<String>(suggestedCategoryId);
    }
    if (!nullToAbsent || suggestionConfidence != null) {
      map['suggestion_confidence'] = Variable<double>(suggestionConfidence);
    }
    map['category_was_corrected'] = Variable<bool>(categoryWasCorrected);
    map['flagged_unusual'] = Variable<bool>(flaggedUnusual);
    map['flag_dismissed'] = Variable<bool>(flagDismissed);
    if (!nullToAbsent || regularPaymentId != null) {
      map['regular_payment_id'] = Variable<String>(regularPaymentId);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      direction: Value(direction),
      amount: Value(amount),
      description: Value(description),
      payeeKey: Value(payeeKey),
      categoryId: categoryId == null && nullToAbsent ? const Value.absent() : Value(categoryId),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent ? const Value.absent() : Value(toAccountId),
      fee: Value(fee),
      tax: Value(tax),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      localDay: Value(localDay),
      suggestedCategoryId: suggestedCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCategoryId),
      suggestionConfidence: suggestionConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestionConfidence),
      categoryWasCorrected: Value(categoryWasCorrected),
      flaggedUnusual: Value(flaggedUnusual),
      flagDismissed: Value(flagDismissed),
      regularPaymentId: regularPaymentId == null && nullToAbsent
          ? const Value.absent()
          : Value(regularPaymentId),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      direction: $TransactionsTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      amount: serializer.fromJson<int>(json['amount']),
      description: serializer.fromJson<String>(json['description']),
      payeeKey: serializer.fromJson<String>(json['payeeKey']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      fee: serializer.fromJson<int>(json['fee']),
      tax: serializer.fromJson<int>(json['tax']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      localDay: serializer.fromJson<int>(json['localDay']),
      suggestedCategoryId: serializer.fromJson<String?>(json['suggestedCategoryId']),
      suggestionConfidence: serializer.fromJson<double?>(json['suggestionConfidence']),
      categoryWasCorrected: serializer.fromJson<bool>(json['categoryWasCorrected']),
      flaggedUnusual: serializer.fromJson<bool>(json['flaggedUnusual']),
      flagDismissed: serializer.fromJson<bool>(json['flagDismissed']),
      regularPaymentId: serializer.fromJson<String?>(json['regularPaymentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'direction': serializer.toJson<String>(
        $TransactionsTable.$converterdirection.toJson(direction),
      ),
      'amount': serializer.toJson<int>(amount),
      'description': serializer.toJson<String>(description),
      'payeeKey': serializer.toJson<String>(payeeKey),
      'categoryId': serializer.toJson<String?>(categoryId),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'fee': serializer.toJson<int>(fee),
      'tax': serializer.toJson<int>(tax),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'localDay': serializer.toJson<int>(localDay),
      'suggestedCategoryId': serializer.toJson<String?>(suggestedCategoryId),
      'suggestionConfidence': serializer.toJson<double?>(suggestionConfidence),
      'categoryWasCorrected': serializer.toJson<bool>(categoryWasCorrected),
      'flaggedUnusual': serializer.toJson<bool>(flaggedUnusual),
      'flagDismissed': serializer.toJson<bool>(flagDismissed),
      'regularPaymentId': serializer.toJson<String?>(regularPaymentId),
    };
  }

  Transaction copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Direction? direction,
    int? amount,
    String? description,
    String? payeeKey,
    Value<String?> categoryId = const Value.absent(),
    String? accountId,
    Value<String?> toAccountId = const Value.absent(),
    int? fee,
    int? tax,
    Value<String?> note = const Value.absent(),
    DateTime? occurredAt,
    int? localDay,
    Value<String?> suggestedCategoryId = const Value.absent(),
    Value<double?> suggestionConfidence = const Value.absent(),
    bool? categoryWasCorrected,
    bool? flaggedUnusual,
    bool? flagDismissed,
    Value<String?> regularPaymentId = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    direction: direction ?? this.direction,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    payeeKey: payeeKey ?? this.payeeKey,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    fee: fee ?? this.fee,
    tax: tax ?? this.tax,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    localDay: localDay ?? this.localDay,
    suggestedCategoryId: suggestedCategoryId.present
        ? suggestedCategoryId.value
        : this.suggestedCategoryId,
    suggestionConfidence: suggestionConfidence.present
        ? suggestionConfidence.value
        : this.suggestionConfidence,
    categoryWasCorrected: categoryWasCorrected ?? this.categoryWasCorrected,
    flaggedUnusual: flaggedUnusual ?? this.flaggedUnusual,
    flagDismissed: flagDismissed ?? this.flagDismissed,
    regularPaymentId: regularPaymentId.present ? regularPaymentId.value : this.regularPaymentId,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      direction: data.direction.present ? data.direction.value : this.direction,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present ? data.description.value : this.description,
      payeeKey: data.payeeKey.present ? data.payeeKey.value : this.payeeKey,
      categoryId: data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      fee: data.fee.present ? data.fee.value : this.fee,
      tax: data.tax.present ? data.tax.value : this.tax,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      suggestedCategoryId: data.suggestedCategoryId.present
          ? data.suggestedCategoryId.value
          : this.suggestedCategoryId,
      suggestionConfidence: data.suggestionConfidence.present
          ? data.suggestionConfidence.value
          : this.suggestionConfidence,
      categoryWasCorrected: data.categoryWasCorrected.present
          ? data.categoryWasCorrected.value
          : this.categoryWasCorrected,
      flaggedUnusual: data.flaggedUnusual.present ? data.flaggedUnusual.value : this.flaggedUnusual,
      flagDismissed: data.flagDismissed.present ? data.flagDismissed.value : this.flagDismissed,
      regularPaymentId: data.regularPaymentId.present
          ? data.regularPaymentId.value
          : this.regularPaymentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('direction: $direction, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('fee: $fee, ')
          ..write('tax: $tax, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDay: $localDay, ')
          ..write('suggestedCategoryId: $suggestedCategoryId, ')
          ..write('suggestionConfidence: $suggestionConfidence, ')
          ..write('categoryWasCorrected: $categoryWasCorrected, ')
          ..write('flaggedUnusual: $flaggedUnusual, ')
          ..write('flagDismissed: $flagDismissed, ')
          ..write('regularPaymentId: $regularPaymentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    direction,
    amount,
    description,
    payeeKey,
    categoryId,
    accountId,
    toAccountId,
    fee,
    tax,
    note,
    occurredAt,
    localDay,
    suggestedCategoryId,
    suggestionConfidence,
    categoryWasCorrected,
    flaggedUnusual,
    flagDismissed,
    regularPaymentId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.direction == this.direction &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.payeeKey == this.payeeKey &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.fee == this.fee &&
          other.tax == this.tax &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.localDay == this.localDay &&
          other.suggestedCategoryId == this.suggestedCategoryId &&
          other.suggestionConfidence == this.suggestionConfidence &&
          other.categoryWasCorrected == this.categoryWasCorrected &&
          other.flaggedUnusual == this.flaggedUnusual &&
          other.flagDismissed == this.flagDismissed &&
          other.regularPaymentId == this.regularPaymentId);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<Direction> direction;
  final Value<int> amount;
  final Value<String> description;
  final Value<String> payeeKey;
  final Value<String?> categoryId;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<int> fee;
  final Value<int> tax;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<int> localDay;
  final Value<String?> suggestedCategoryId;
  final Value<double?> suggestionConfidence;
  final Value<bool> categoryWasCorrected;
  final Value<bool> flaggedUnusual;
  final Value<bool> flagDismissed;
  final Value<String?> regularPaymentId;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.direction = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.payeeKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.fee = const Value.absent(),
    this.tax = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.localDay = const Value.absent(),
    this.suggestedCategoryId = const Value.absent(),
    this.suggestionConfidence = const Value.absent(),
    this.categoryWasCorrected = const Value.absent(),
    this.flaggedUnusual = const Value.absent(),
    this.flagDismissed = const Value.absent(),
    this.regularPaymentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required Direction direction,
    required int amount,
    this.description = const Value.absent(),
    this.payeeKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.fee = const Value.absent(),
    this.tax = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime occurredAt,
    required int localDay,
    this.suggestedCategoryId = const Value.absent(),
    this.suggestionConfidence = const Value.absent(),
    this.categoryWasCorrected = const Value.absent(),
    this.flaggedUnusual = const Value.absent(),
    this.flagDismissed = const Value.absent(),
    this.regularPaymentId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       direction = Value(direction),
       amount = Value(amount),
       accountId = Value(accountId),
       occurredAt = Value(occurredAt),
       localDay = Value(localDay);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? direction,
    Expression<int>? amount,
    Expression<String>? description,
    Expression<String>? payeeKey,
    Expression<String>? categoryId,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<int>? fee,
    Expression<int>? tax,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<int>? localDay,
    Expression<String>? suggestedCategoryId,
    Expression<double>? suggestionConfidence,
    Expression<bool>? categoryWasCorrected,
    Expression<bool>? flaggedUnusual,
    Expression<bool>? flagDismissed,
    Expression<String>? regularPaymentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (direction != null) 'direction': direction,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (payeeKey != null) 'payee_key': payeeKey,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (fee != null) 'fee': fee,
      if (tax != null) 'tax': tax,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (localDay != null) 'local_day': localDay,
      if (suggestedCategoryId != null) 'suggested_category_id': suggestedCategoryId,
      if (suggestionConfidence != null) 'suggestion_confidence': suggestionConfidence,
      if (categoryWasCorrected != null) 'category_was_corrected': categoryWasCorrected,
      if (flaggedUnusual != null) 'flagged_unusual': flaggedUnusual,
      if (flagDismissed != null) 'flag_dismissed': flagDismissed,
      if (regularPaymentId != null) 'regular_payment_id': regularPaymentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<Direction>? direction,
    Value<int>? amount,
    Value<String>? description,
    Value<String>? payeeKey,
    Value<String?>? categoryId,
    Value<String>? accountId,
    Value<String?>? toAccountId,
    Value<int>? fee,
    Value<int>? tax,
    Value<String?>? note,
    Value<DateTime>? occurredAt,
    Value<int>? localDay,
    Value<String?>? suggestedCategoryId,
    Value<double?>? suggestionConfidence,
    Value<bool>? categoryWasCorrected,
    Value<bool>? flaggedUnusual,
    Value<bool>? flagDismissed,
    Value<String?>? regularPaymentId,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      payeeKey: payeeKey ?? this.payeeKey,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      fee: fee ?? this.fee,
      tax: tax ?? this.tax,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      localDay: localDay ?? this.localDay,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestionConfidence: suggestionConfidence ?? this.suggestionConfidence,
      categoryWasCorrected: categoryWasCorrected ?? this.categoryWasCorrected,
      flaggedUnusual: flaggedUnusual ?? this.flaggedUnusual,
      flagDismissed: flagDismissed ?? this.flagDismissed,
      regularPaymentId: regularPaymentId ?? this.regularPaymentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $TransactionsTable.$converterdirection.toSql(direction.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (payeeKey.present) {
      map['payee_key'] = Variable<String>(payeeKey.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (fee.present) {
      map['fee'] = Variable<int>(fee.value);
    }
    if (tax.present) {
      map['tax'] = Variable<int>(tax.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<int>(localDay.value);
    }
    if (suggestedCategoryId.present) {
      map['suggested_category_id'] = Variable<String>(suggestedCategoryId.value);
    }
    if (suggestionConfidence.present) {
      map['suggestion_confidence'] = Variable<double>(suggestionConfidence.value);
    }
    if (categoryWasCorrected.present) {
      map['category_was_corrected'] = Variable<bool>(categoryWasCorrected.value);
    }
    if (flaggedUnusual.present) {
      map['flagged_unusual'] = Variable<bool>(flaggedUnusual.value);
    }
    if (flagDismissed.present) {
      map['flag_dismissed'] = Variable<bool>(flagDismissed.value);
    }
    if (regularPaymentId.present) {
      map['regular_payment_id'] = Variable<String>(regularPaymentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('direction: $direction, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('fee: $fee, ')
          ..write('tax: $tax, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDay: $localDay, ')
          ..write('suggestedCategoryId: $suggestedCategoryId, ')
          ..write('suggestionConfidence: $suggestionConfidence, ')
          ..write('categoryWasCorrected: $categoryWasCorrected, ')
          ..write('flaggedUnusual: $flaggedUnusual, ')
          ..write('flagDismissed: $flagDismissed, ')
          ..write('regularPaymentId: $regularPaymentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RegularPaymentsTable extends RegularPayments
    with TableInfo<$RegularPaymentsTable, RegularPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegularPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES categories (id)'),
  );
  static const VerificationMeta _payeeKeyMeta = const VerificationMeta('payeeKey');
  @override
  late final GeneratedColumn<String> payeeKey = GeneratedColumn<String>(
    'payee_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typicalAmountMeta = const VerificationMeta('typicalAmount');
  @override
  late final GeneratedColumn<int> typicalAmount = GeneratedColumn<int>(
    'typical_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountLowMeta = const VerificationMeta('amountLow');
  @override
  late final GeneratedColumn<int> amountLow = GeneratedColumn<int>(
    'amount_low',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountHighMeta = const VerificationMeta('amountHigh');
  @override
  late final GeneratedColumn<int> amountHigh = GeneratedColumn<int>(
    'amount_high',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta('intervalDays');
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextDueOnMeta = const VerificationMeta('nextDueOn');
  @override
  late final GeneratedColumn<int> nextDueOn = GeneratedColumn<int>(
    'next_due_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timesSeenMeta = const VerificationMeta('timesSeen');
  @override
  late final GeneratedColumn<int> timesSeen = GeneratedColumn<int>(
    'times_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RegularSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RegularSource>($RegularPaymentsTable.$convertersource);
  static const VerificationMeta _remindMeta = const VerificationMeta('remind');
  @override
  late final GeneratedColumn<bool> remind = GeneratedColumn<bool>(
    'remind',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("remind" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta('dismissed');
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("dismissed" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    label,
    categoryId,
    payeeKey,
    typicalAmount,
    amountLow,
    amountHigh,
    intervalDays,
    nextDueOn,
    timesSeen,
    source,
    remind,
    dismissed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'regular_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegularPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('payee_key')) {
      context.handle(
        _payeeKeyMeta,
        payeeKey.isAcceptableOrUnknown(data['payee_key']!, _payeeKeyMeta),
      );
    }
    if (data.containsKey('typical_amount')) {
      context.handle(
        _typicalAmountMeta,
        typicalAmount.isAcceptableOrUnknown(data['typical_amount']!, _typicalAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_typicalAmountMeta);
    }
    if (data.containsKey('amount_low')) {
      context.handle(
        _amountLowMeta,
        amountLow.isAcceptableOrUnknown(data['amount_low']!, _amountLowMeta),
      );
    } else if (isInserting) {
      context.missing(_amountLowMeta);
    }
    if (data.containsKey('amount_high')) {
      context.handle(
        _amountHighMeta,
        amountHigh.isAcceptableOrUnknown(data['amount_high']!, _amountHighMeta),
      );
    } else if (isInserting) {
      context.missing(_amountHighMeta);
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(data['interval_days']!, _intervalDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_intervalDaysMeta);
    }
    if (data.containsKey('next_due_on')) {
      context.handle(
        _nextDueOnMeta,
        nextDueOn.isAcceptableOrUnknown(data['next_due_on']!, _nextDueOnMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueOnMeta);
    }
    if (data.containsKey('times_seen')) {
      context.handle(
        _timesSeenMeta,
        timesSeen.isAcceptableOrUnknown(data['times_seen']!, _timesSeenMeta),
      );
    }
    if (data.containsKey('remind')) {
      context.handle(_remindMeta, remind.isAcceptableOrUnknown(data['remind']!, _remindMeta));
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegularPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegularPayment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      payeeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_key'],
      )!,
      typicalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}typical_amount'],
      )!,
      amountLow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_low'],
      )!,
      amountHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_high'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      nextDueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_due_on'],
      )!,
      timesSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_seen'],
      )!,
      source: $RegularPaymentsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      ),
      remind: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}remind'],
      )!,
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
    );
  }

  @override
  $RegularPaymentsTable createAlias(String alias) {
    return $RegularPaymentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RegularSource, String, String> $convertersource =
      const EnumNameConverter<RegularSource>(RegularSource.values);
}

class RegularPayment extends DataClass implements Insertable<RegularPayment> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String label;
  final String? categoryId;
  final String payeeKey;
  final int typicalAmount;
  final int amountLow;
  final int amountHigh;
  final int intervalDays;

  /// yyyymmdd.
  final int nextDueOn;
  final int timesSeen;
  final RegularSource source;
  final bool remind;

  /// A wrong detection the person removed. Kept so it is not detected again.
  final bool dismissed;
  const RegularPayment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.label,
    this.categoryId,
    required this.payeeKey,
    required this.typicalAmount,
    required this.amountLow,
    required this.amountHigh,
    required this.intervalDays,
    required this.nextDueOn,
    required this.timesSeen,
    required this.source,
    required this.remind,
    required this.dismissed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['payee_key'] = Variable<String>(payeeKey);
    map['typical_amount'] = Variable<int>(typicalAmount);
    map['amount_low'] = Variable<int>(amountLow);
    map['amount_high'] = Variable<int>(amountHigh);
    map['interval_days'] = Variable<int>(intervalDays);
    map['next_due_on'] = Variable<int>(nextDueOn);
    map['times_seen'] = Variable<int>(timesSeen);
    {
      map['source'] = Variable<String>($RegularPaymentsTable.$convertersource.toSql(source));
    }
    map['remind'] = Variable<bool>(remind);
    map['dismissed'] = Variable<bool>(dismissed);
    return map;
  }

  RegularPaymentsCompanion toCompanion(bool nullToAbsent) {
    return RegularPaymentsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      label: Value(label),
      categoryId: categoryId == null && nullToAbsent ? const Value.absent() : Value(categoryId),
      payeeKey: Value(payeeKey),
      typicalAmount: Value(typicalAmount),
      amountLow: Value(amountLow),
      amountHigh: Value(amountHigh),
      intervalDays: Value(intervalDays),
      nextDueOn: Value(nextDueOn),
      timesSeen: Value(timesSeen),
      source: Value(source),
      remind: Value(remind),
      dismissed: Value(dismissed),
    );
  }

  factory RegularPayment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegularPayment(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      label: serializer.fromJson<String>(json['label']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      payeeKey: serializer.fromJson<String>(json['payeeKey']),
      typicalAmount: serializer.fromJson<int>(json['typicalAmount']),
      amountLow: serializer.fromJson<int>(json['amountLow']),
      amountHigh: serializer.fromJson<int>(json['amountHigh']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      nextDueOn: serializer.fromJson<int>(json['nextDueOn']),
      timesSeen: serializer.fromJson<int>(json['timesSeen']),
      source: $RegularPaymentsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      remind: serializer.fromJson<bool>(json['remind']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'label': serializer.toJson<String>(label),
      'categoryId': serializer.toJson<String?>(categoryId),
      'payeeKey': serializer.toJson<String>(payeeKey),
      'typicalAmount': serializer.toJson<int>(typicalAmount),
      'amountLow': serializer.toJson<int>(amountLow),
      'amountHigh': serializer.toJson<int>(amountHigh),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'nextDueOn': serializer.toJson<int>(nextDueOn),
      'timesSeen': serializer.toJson<int>(timesSeen),
      'source': serializer.toJson<String>($RegularPaymentsTable.$convertersource.toJson(source)),
      'remind': serializer.toJson<bool>(remind),
      'dismissed': serializer.toJson<bool>(dismissed),
    };
  }

  RegularPayment copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? label,
    Value<String?> categoryId = const Value.absent(),
    String? payeeKey,
    int? typicalAmount,
    int? amountLow,
    int? amountHigh,
    int? intervalDays,
    int? nextDueOn,
    int? timesSeen,
    RegularSource? source,
    bool? remind,
    bool? dismissed,
  }) => RegularPayment(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    label: label ?? this.label,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    payeeKey: payeeKey ?? this.payeeKey,
    typicalAmount: typicalAmount ?? this.typicalAmount,
    amountLow: amountLow ?? this.amountLow,
    amountHigh: amountHigh ?? this.amountHigh,
    intervalDays: intervalDays ?? this.intervalDays,
    nextDueOn: nextDueOn ?? this.nextDueOn,
    timesSeen: timesSeen ?? this.timesSeen,
    source: source ?? this.source,
    remind: remind ?? this.remind,
    dismissed: dismissed ?? this.dismissed,
  );
  RegularPayment copyWithCompanion(RegularPaymentsCompanion data) {
    return RegularPayment(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      label: data.label.present ? data.label.value : this.label,
      categoryId: data.categoryId.present ? data.categoryId.value : this.categoryId,
      payeeKey: data.payeeKey.present ? data.payeeKey.value : this.payeeKey,
      typicalAmount: data.typicalAmount.present ? data.typicalAmount.value : this.typicalAmount,
      amountLow: data.amountLow.present ? data.amountLow.value : this.amountLow,
      amountHigh: data.amountHigh.present ? data.amountHigh.value : this.amountHigh,
      intervalDays: data.intervalDays.present ? data.intervalDays.value : this.intervalDays,
      nextDueOn: data.nextDueOn.present ? data.nextDueOn.value : this.nextDueOn,
      timesSeen: data.timesSeen.present ? data.timesSeen.value : this.timesSeen,
      source: data.source.present ? data.source.value : this.source,
      remind: data.remind.present ? data.remind.value : this.remind,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegularPayment(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('label: $label, ')
          ..write('categoryId: $categoryId, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('typicalAmount: $typicalAmount, ')
          ..write('amountLow: $amountLow, ')
          ..write('amountHigh: $amountHigh, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('timesSeen: $timesSeen, ')
          ..write('source: $source, ')
          ..write('remind: $remind, ')
          ..write('dismissed: $dismissed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    label,
    categoryId,
    payeeKey,
    typicalAmount,
    amountLow,
    amountHigh,
    intervalDays,
    nextDueOn,
    timesSeen,
    source,
    remind,
    dismissed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegularPayment &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.label == this.label &&
          other.categoryId == this.categoryId &&
          other.payeeKey == this.payeeKey &&
          other.typicalAmount == this.typicalAmount &&
          other.amountLow == this.amountLow &&
          other.amountHigh == this.amountHigh &&
          other.intervalDays == this.intervalDays &&
          other.nextDueOn == this.nextDueOn &&
          other.timesSeen == this.timesSeen &&
          other.source == this.source &&
          other.remind == this.remind &&
          other.dismissed == this.dismissed);
}

class RegularPaymentsCompanion extends UpdateCompanion<RegularPayment> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> label;
  final Value<String?> categoryId;
  final Value<String> payeeKey;
  final Value<int> typicalAmount;
  final Value<int> amountLow;
  final Value<int> amountHigh;
  final Value<int> intervalDays;
  final Value<int> nextDueOn;
  final Value<int> timesSeen;
  final Value<RegularSource> source;
  final Value<bool> remind;
  final Value<bool> dismissed;
  final Value<int> rowid;
  const RegularPaymentsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.label = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.payeeKey = const Value.absent(),
    this.typicalAmount = const Value.absent(),
    this.amountLow = const Value.absent(),
    this.amountHigh = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.nextDueOn = const Value.absent(),
    this.timesSeen = const Value.absent(),
    this.source = const Value.absent(),
    this.remind = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegularPaymentsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String label,
    this.categoryId = const Value.absent(),
    this.payeeKey = const Value.absent(),
    required int typicalAmount,
    required int amountLow,
    required int amountHigh,
    required int intervalDays,
    required int nextDueOn,
    this.timesSeen = const Value.absent(),
    required RegularSource source,
    this.remind = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       label = Value(label),
       typicalAmount = Value(typicalAmount),
       amountLow = Value(amountLow),
       amountHigh = Value(amountHigh),
       intervalDays = Value(intervalDays),
       nextDueOn = Value(nextDueOn),
       source = Value(source);
  static Insertable<RegularPayment> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? label,
    Expression<String>? categoryId,
    Expression<String>? payeeKey,
    Expression<int>? typicalAmount,
    Expression<int>? amountLow,
    Expression<int>? amountHigh,
    Expression<int>? intervalDays,
    Expression<int>? nextDueOn,
    Expression<int>? timesSeen,
    Expression<String>? source,
    Expression<bool>? remind,
    Expression<bool>? dismissed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (label != null) 'label': label,
      if (categoryId != null) 'category_id': categoryId,
      if (payeeKey != null) 'payee_key': payeeKey,
      if (typicalAmount != null) 'typical_amount': typicalAmount,
      if (amountLow != null) 'amount_low': amountLow,
      if (amountHigh != null) 'amount_high': amountHigh,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (nextDueOn != null) 'next_due_on': nextDueOn,
      if (timesSeen != null) 'times_seen': timesSeen,
      if (source != null) 'source': source,
      if (remind != null) 'remind': remind,
      if (dismissed != null) 'dismissed': dismissed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegularPaymentsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? label,
    Value<String?>? categoryId,
    Value<String>? payeeKey,
    Value<int>? typicalAmount,
    Value<int>? amountLow,
    Value<int>? amountHigh,
    Value<int>? intervalDays,
    Value<int>? nextDueOn,
    Value<int>? timesSeen,
    Value<RegularSource>? source,
    Value<bool>? remind,
    Value<bool>? dismissed,
    Value<int>? rowid,
  }) {
    return RegularPaymentsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      label: label ?? this.label,
      categoryId: categoryId ?? this.categoryId,
      payeeKey: payeeKey ?? this.payeeKey,
      typicalAmount: typicalAmount ?? this.typicalAmount,
      amountLow: amountLow ?? this.amountLow,
      amountHigh: amountHigh ?? this.amountHigh,
      intervalDays: intervalDays ?? this.intervalDays,
      nextDueOn: nextDueOn ?? this.nextDueOn,
      timesSeen: timesSeen ?? this.timesSeen,
      source: source ?? this.source,
      remind: remind ?? this.remind,
      dismissed: dismissed ?? this.dismissed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (payeeKey.present) {
      map['payee_key'] = Variable<String>(payeeKey.value);
    }
    if (typicalAmount.present) {
      map['typical_amount'] = Variable<int>(typicalAmount.value);
    }
    if (amountLow.present) {
      map['amount_low'] = Variable<int>(amountLow.value);
    }
    if (amountHigh.present) {
      map['amount_high'] = Variable<int>(amountHigh.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (nextDueOn.present) {
      map['next_due_on'] = Variable<int>(nextDueOn.value);
    }
    if (timesSeen.present) {
      map['times_seen'] = Variable<int>(timesSeen.value);
    }
    if (source.present) {
      map['source'] = Variable<String>($RegularPaymentsTable.$convertersource.toSql(source.value));
    }
    if (remind.present) {
      map['remind'] = Variable<bool>(remind.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegularPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('label: $label, ')
          ..write('categoryId: $categoryId, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('typicalAmount: $typicalAmount, ')
          ..write('amountLow: $amountLow, ')
          ..write('amountHigh: $amountHigh, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('timesSeen: $timesSeen, ')
          ..write('source: $source, ')
          ..write('remind: $remind, ')
          ..write('dismissed: $dismissed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const Setting({required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value), updatedAt: Value(updatedAt));
  }

  factory Setting.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({String? key, String? value, DateTime? updatedAt}) => Setting(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ForecastSnapshotsTable extends ForecastSnapshots
    with TableInfo<$ForecastSnapshotsTable, ForecastSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ForecastSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _periodStartMeta = const VerificationMeta('periodStart');
  @override
  late final GeneratedColumn<int> periodStart = GeneratedColumn<int>(
    'period_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenOnMeta = const VerificationMeta('takenOn');
  @override
  late final GeneratedColumn<int> takenOn = GeneratedColumn<int>(
    'taken_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointMeta = const VerificationMeta('point');
  @override
  late final GeneratedColumn<int> point = GeneratedColumn<int>(
    'point',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<int> low = GeneratedColumn<int>(
    'low',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<int> high = GeneratedColumn<int>(
    'high',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spentSoFarMeta = const VerificationMeta('spentSoFar');
  @override
  late final GeneratedColumn<int> spentSoFar = GeneratedColumn<int>(
    'spent_so_far',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    periodStart,
    takenOn,
    point,
    low,
    high,
    spentSoFar,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'forecast_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ForecastSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(data['period_start']!, _periodStartMeta),
      );
    } else if (isInserting) {
      context.missing(_periodStartMeta);
    }
    if (data.containsKey('taken_on')) {
      context.handle(_takenOnMeta, takenOn.isAcceptableOrUnknown(data['taken_on']!, _takenOnMeta));
    } else if (isInserting) {
      context.missing(_takenOnMeta);
    }
    if (data.containsKey('point')) {
      context.handle(_pointMeta, point.isAcceptableOrUnknown(data['point']!, _pointMeta));
    } else if (isInserting) {
      context.missing(_pointMeta);
    }
    if (data.containsKey('low')) {
      context.handle(_lowMeta, low.isAcceptableOrUnknown(data['low']!, _lowMeta));
    } else if (isInserting) {
      context.missing(_lowMeta);
    }
    if (data.containsKey('high')) {
      context.handle(_highMeta, high.isAcceptableOrUnknown(data['high']!, _highMeta));
    } else if (isInserting) {
      context.missing(_highMeta);
    }
    if (data.containsKey('spent_so_far')) {
      context.handle(
        _spentSoFarMeta,
        spentSoFar.isAcceptableOrUnknown(data['spent_so_far']!, _spentSoFarMeta),
      );
    } else if (isInserting) {
      context.missing(_spentSoFarMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {periodStart, takenOn};
  @override
  ForecastSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ForecastSnapshot(
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_start'],
      )!,
      takenOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_on'],
      )!,
      point: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}point'])!,
      low: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}low'])!,
      high: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}high'])!,
      spentSoFar: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spent_so_far'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ForecastSnapshotsTable createAlias(String alias) {
    return $ForecastSnapshotsTable(attachedDatabase, alias);
  }
}

class ForecastSnapshot extends DataClass implements Insertable<ForecastSnapshot> {
  /// First day of the month the forecast is for, yyyymmdd.
  final int periodStart;

  /// The day the forecast was shown, yyyymmdd.
  final int takenOn;
  final int point;
  final int low;
  final int high;
  final int spentSoFar;
  final DateTime createdAt;
  const ForecastSnapshot({
    required this.periodStart,
    required this.takenOn,
    required this.point,
    required this.low,
    required this.high,
    required this.spentSoFar,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['period_start'] = Variable<int>(periodStart);
    map['taken_on'] = Variable<int>(takenOn);
    map['point'] = Variable<int>(point);
    map['low'] = Variable<int>(low);
    map['high'] = Variable<int>(high);
    map['spent_so_far'] = Variable<int>(spentSoFar);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ForecastSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ForecastSnapshotsCompanion(
      periodStart: Value(periodStart),
      takenOn: Value(takenOn),
      point: Value(point),
      low: Value(low),
      high: Value(high),
      spentSoFar: Value(spentSoFar),
      createdAt: Value(createdAt),
    );
  }

  factory ForecastSnapshot.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ForecastSnapshot(
      periodStart: serializer.fromJson<int>(json['periodStart']),
      takenOn: serializer.fromJson<int>(json['takenOn']),
      point: serializer.fromJson<int>(json['point']),
      low: serializer.fromJson<int>(json['low']),
      high: serializer.fromJson<int>(json['high']),
      spentSoFar: serializer.fromJson<int>(json['spentSoFar']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'periodStart': serializer.toJson<int>(periodStart),
      'takenOn': serializer.toJson<int>(takenOn),
      'point': serializer.toJson<int>(point),
      'low': serializer.toJson<int>(low),
      'high': serializer.toJson<int>(high),
      'spentSoFar': serializer.toJson<int>(spentSoFar),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ForecastSnapshot copyWith({
    int? periodStart,
    int? takenOn,
    int? point,
    int? low,
    int? high,
    int? spentSoFar,
    DateTime? createdAt,
  }) => ForecastSnapshot(
    periodStart: periodStart ?? this.periodStart,
    takenOn: takenOn ?? this.takenOn,
    point: point ?? this.point,
    low: low ?? this.low,
    high: high ?? this.high,
    spentSoFar: spentSoFar ?? this.spentSoFar,
    createdAt: createdAt ?? this.createdAt,
  );
  ForecastSnapshot copyWithCompanion(ForecastSnapshotsCompanion data) {
    return ForecastSnapshot(
      periodStart: data.periodStart.present ? data.periodStart.value : this.periodStart,
      takenOn: data.takenOn.present ? data.takenOn.value : this.takenOn,
      point: data.point.present ? data.point.value : this.point,
      low: data.low.present ? data.low.value : this.low,
      high: data.high.present ? data.high.value : this.high,
      spentSoFar: data.spentSoFar.present ? data.spentSoFar.value : this.spentSoFar,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ForecastSnapshot(')
          ..write('periodStart: $periodStart, ')
          ..write('takenOn: $takenOn, ')
          ..write('point: $point, ')
          ..write('low: $low, ')
          ..write('high: $high, ')
          ..write('spentSoFar: $spentSoFar, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(periodStart, takenOn, point, low, high, spentSoFar, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForecastSnapshot &&
          other.periodStart == this.periodStart &&
          other.takenOn == this.takenOn &&
          other.point == this.point &&
          other.low == this.low &&
          other.high == this.high &&
          other.spentSoFar == this.spentSoFar &&
          other.createdAt == this.createdAt);
}

class ForecastSnapshotsCompanion extends UpdateCompanion<ForecastSnapshot> {
  final Value<int> periodStart;
  final Value<int> takenOn;
  final Value<int> point;
  final Value<int> low;
  final Value<int> high;
  final Value<int> spentSoFar;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ForecastSnapshotsCompanion({
    this.periodStart = const Value.absent(),
    this.takenOn = const Value.absent(),
    this.point = const Value.absent(),
    this.low = const Value.absent(),
    this.high = const Value.absent(),
    this.spentSoFar = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ForecastSnapshotsCompanion.insert({
    required int periodStart,
    required int takenOn,
    required int point,
    required int low,
    required int high,
    required int spentSoFar,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : periodStart = Value(periodStart),
       takenOn = Value(takenOn),
       point = Value(point),
       low = Value(low),
       high = Value(high),
       spentSoFar = Value(spentSoFar),
       createdAt = Value(createdAt);
  static Insertable<ForecastSnapshot> custom({
    Expression<int>? periodStart,
    Expression<int>? takenOn,
    Expression<int>? point,
    Expression<int>? low,
    Expression<int>? high,
    Expression<int>? spentSoFar,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (periodStart != null) 'period_start': periodStart,
      if (takenOn != null) 'taken_on': takenOn,
      if (point != null) 'point': point,
      if (low != null) 'low': low,
      if (high != null) 'high': high,
      if (spentSoFar != null) 'spent_so_far': spentSoFar,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ForecastSnapshotsCompanion copyWith({
    Value<int>? periodStart,
    Value<int>? takenOn,
    Value<int>? point,
    Value<int>? low,
    Value<int>? high,
    Value<int>? spentSoFar,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ForecastSnapshotsCompanion(
      periodStart: periodStart ?? this.periodStart,
      takenOn: takenOn ?? this.takenOn,
      point: point ?? this.point,
      low: low ?? this.low,
      high: high ?? this.high,
      spentSoFar: spentSoFar ?? this.spentSoFar,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (periodStart.present) {
      map['period_start'] = Variable<int>(periodStart.value);
    }
    if (takenOn.present) {
      map['taken_on'] = Variable<int>(takenOn.value);
    }
    if (point.present) {
      map['point'] = Variable<int>(point.value);
    }
    if (low.present) {
      map['low'] = Variable<int>(low.value);
    }
    if (high.present) {
      map['high'] = Variable<int>(high.value);
    }
    if (spentSoFar.present) {
      map['spent_so_far'] = Variable<int>(spentSoFar.value);
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
    return (StringBuffer('ForecastSnapshotsCompanion(')
          ..write('periodStart: $periodStart, ')
          ..write('takenOn: $takenOn, ')
          ..write('point: $point, ')
          ..write('low: $low, ')
          ..write('high: $high, ')
          ..write('spentSoFar: $spentSoFar, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $RegularPaymentsTable regularPayments = $RegularPaymentsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ForecastSnapshotsTable forecastSnapshots = $ForecastSnapshotsTable(this);
  late final Index txLocalDay = Index(
    'tx_local_day',
    'CREATE INDEX tx_local_day ON transactions (local_day)',
  );
  late final Index txCategory = Index(
    'tx_category',
    'CREATE INDEX tx_category ON transactions (category_id)',
  );
  late final Index txPayee = Index('tx_payee', 'CREATE INDEX tx_payee ON transactions (payee_key)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    accounts,
    transactions,
    regularPayments,
    settings,
    forecastSnapshots,
    txLocalDay,
    txCategory,
    txPayee,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String name,
  required String iconKey,
  required String colourToken,
  required CategoryKind kind,
  Value<int> sortOrder,
  Value<bool> hidden,
  Value<int?> monthlyBudget,
  Value<bool> budgetCarriesOver,
  Value<int> budgetWarnAt,
  Value<bool> isSystem,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> name,
  Value<String> iconKey,
  Value<String> colourToken,
  Value<CategoryKind> kind,
  Value<int> sortOrder,
  Value<bool> hidden,
  Value<int?> monthlyBudget,
  Value<bool> budgetCarriesOver,
  Value<int> budgetWarnAt,
  Value<bool> isSystem,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>> _transactionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RegularPaymentsTable, List<RegularPayment>> _regularPaymentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.regularPayments,
    aliasName: 'categories__id__regular_payments__category_id',
  );

  $$RegularPaymentsTableProcessedTableManager get regularPaymentsRefs {
    final manager = $$RegularPaymentsTableTableManager(
      $_db,
      $_db.regularPayments,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_regularPaymentsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get monthlyBudget =>
      $composableBuilder(column: $table.monthlyBudget, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get budgetCarriesOver => $composableBuilder(
    column: $table.budgetCarriesOver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetWarnAt =>
      $composableBuilder(column: $table.budgetWarnAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => ColumnFilters(column));

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> regularPaymentsRefs(
    Expression<bool> Function($$RegularPaymentsTableFilterComposer f) f,
  ) {
    final $$RegularPaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regularPayments,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RegularPaymentsTableFilterComposer(
            $db: $db,
            $table: $db.regularPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get monthlyBudget => $composableBuilder(
    column: $table.monthlyBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get budgetCarriesOver => $composableBuilder(
    column: $table.budgetCarriesOver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetWarnAt =>
      $composableBuilder(column: $table.budgetWarnAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get monthlyBudget =>
      $composableBuilder(column: $table.monthlyBudget, builder: (column) => column);

  GeneratedColumn<bool> get budgetCarriesOver =>
      $composableBuilder(column: $table.budgetCarriesOver, builder: (column) => column);

  GeneratedColumn<int> get budgetWarnAt =>
      $composableBuilder(column: $table.budgetWarnAt, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> regularPaymentsRefs<T extends Object>(
    Expression<T> Function($$RegularPaymentsTableAnnotationComposer a) f,
  ) {
    final $$RegularPaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regularPayments,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RegularPaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.regularPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool transactionsRefs, bool regularPaymentsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String> colourToken = const Value.absent(),
                Value<CategoryKind> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int?> monthlyBudget = const Value.absent(),
                Value<bool> budgetCarriesOver = const Value.absent(),
                Value<int> budgetWarnAt = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                name: name,
                iconKey: iconKey,
                colourToken: colourToken,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                monthlyBudget: monthlyBudget,
                budgetCarriesOver: budgetCarriesOver,
                budgetWarnAt: budgetWarnAt,
                isSystem: isSystem,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String name,
                required String iconKey,
                required String colourToken,
                required CategoryKind kind,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int?> monthlyBudget = const Value.absent(),
                Value<bool> budgetCarriesOver = const Value.absent(),
                Value<int> budgetWarnAt = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                name: name,
                iconKey: iconKey,
                colourToken: colourToken,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                monthlyBudget: monthlyBudget,
                budgetCarriesOver: budgetCarriesOver,
                budgetWarnAt: budgetWarnAt,
                isSystem: isSystem,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false, regularPaymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transactionsRefs) db.transactions,
                if (regularPaymentsRefs) db.regularPayments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedDataByColumns<
                      Category,
                      $CategoriesTable,
                      Transaction,
                      $TransactionsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).transactionsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                  if (regularPaymentsRefs)
                    await $_getPrefetchedDataByColumns<
                      Category,
                      $CategoriesTable,
                      RegularPayment,
                      $RegularPaymentsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences._regularPaymentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).regularPaymentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool transactionsRefs, bool regularPaymentsRefs})
    >;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String name,
  required AccountKind kind,
  required String colourToken,
  Value<int> openingBalance,
  Value<bool> askFeeEachTime,
  Value<bool> countInTotals,
  Value<bool> enabled,
  Value<bool> isDefault,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> name,
  Value<AccountKind> kind,
  Value<String> colourToken,
  Value<int> openingBalance,
  Value<bool> askFeeEachTime,
  Value<bool> countInTotals,
  Value<bool> enabled,
  Value<bool> isDefault,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>> _paidFromTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__account_id',
  );

  $$TransactionsTableProcessedTableManager get paidFrom {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paidFromTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>> _movedToTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__to_account_id',
  );

  $$TransactionsTableProcessedTableManager get movedTo {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.toAccountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_movedToTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AccountsTableFilterComposer extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AccountKind, AccountKind, String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get openingBalance =>
      $composableBuilder(column: $table.openingBalance, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get askFeeEachTime =>
      $composableBuilder(column: $table.askFeeEachTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get countInTotals =>
      $composableBuilder(column: $table.countInTotals, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  Expression<bool> paidFrom(Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> movedTo(Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.toAccountId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get askFeeEachTime => $composableBuilder(
    column: $table.askFeeEachTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get countInTotals => $composableBuilder(
    column: $table.countInTotals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get colourToken =>
      $composableBuilder(column: $table.colourToken, builder: (column) => column);

  GeneratedColumn<int> get openingBalance =>
      $composableBuilder(column: $table.openingBalance, builder: (column) => column);

  GeneratedColumn<bool> get askFeeEachTime =>
      $composableBuilder(column: $table.askFeeEachTime, builder: (column) => column);

  GeneratedColumn<bool> get countInTotals =>
      $composableBuilder(column: $table.countInTotals, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> paidFrom<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> movedTo<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.toAccountId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({bool paidFrom, bool movedTo})
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountKind> kind = const Value.absent(),
                Value<String> colourToken = const Value.absent(),
                Value<int> openingBalance = const Value.absent(),
                Value<bool> askFeeEachTime = const Value.absent(),
                Value<bool> countInTotals = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                name: name,
                kind: kind,
                colourToken: colourToken,
                openingBalance: openingBalance,
                askFeeEachTime: askFeeEachTime,
                countInTotals: countInTotals,
                enabled: enabled,
                isDefault: isDefault,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String name,
                required AccountKind kind,
                required String colourToken,
                Value<int> openingBalance = const Value.absent(),
                Value<bool> askFeeEachTime = const Value.absent(),
                Value<bool> countInTotals = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                name: name,
                kind: kind,
                colourToken: colourToken,
                openingBalance: openingBalance,
                askFeeEachTime: askFeeEachTime,
                countInTotals: countInTotals,
                enabled: enabled,
                isDefault: isDefault,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({paidFrom = false, movedTo = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (paidFrom) db.transactions,
                if (movedTo) db.transactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paidFrom)
                    await $_getPrefetchedDataByColumns<
                      Account,
                      $AccountsTable,
                      Transaction,
                      $TransactionsTable
                    >(
                      currentTable: table,
                      referencedTable: $$AccountsTableReferences._paidFromTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AccountsTableReferences(db, table, p0).paidFrom,
                      currentColumn: 'id',
                      referencedColumn: 'account_id',
                      typedResults: items,
                    ),
                  if (movedTo)
                    await $_getPrefetchedDataByColumns<
                      Account,
                      $AccountsTable,
                      Transaction,
                      $TransactionsTable
                    >(
                      currentTable: table,
                      referencedTable: $$AccountsTableReferences._movedToTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AccountsTableReferences(db, table, p0).movedTo,
                      currentColumn: 'id',
                      referencedColumn: 'to_account_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({bool paidFrom, bool movedTo})
    >;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required Direction direction,
  required int amount,
  Value<String> description,
  Value<String> payeeKey,
  Value<String?> categoryId,
  required String accountId,
  Value<String?> toAccountId,
  Value<int> fee,
  Value<int> tax,
  Value<String?> note,
  required DateTime occurredAt,
  required int localDay,
  Value<String?> suggestedCategoryId,
  Value<double?> suggestionConfidence,
  Value<bool> categoryWasCorrected,
  Value<bool> flaggedUnusual,
  Value<bool> flagDismissed,
  Value<String?> regularPaymentId,
  Value<int> rowid,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<Direction> direction,
  Value<int> amount,
  Value<String> description,
  Value<String> payeeKey,
  Value<String?> categoryId,
  Value<String> accountId,
  Value<String?> toAccountId,
  Value<int> fee,
  Value<int> tax,
  Value<String?> note,
  Value<DateTime> occurredAt,
  Value<int> localDay,
  Value<String?> suggestedCategoryId,
  Value<double?> suggestionConfidence,
  Value<bool> categoryWasCorrected,
  Value<bool> flaggedUnusual,
  Value<bool> flagDismissed,
  Value<String?> regularPaymentId,
  Value<int> rowid,
});

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('transactions__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $AccountsTable _toAccountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('transactions__to_account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get toAccountId {
    final $_column = $_itemColumn<String>('to_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TransactionsTableFilterComposer extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Direction, Direction, String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt =>
      $composableBuilder(column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get suggestedCategoryId => $composableBuilder(
    column: $table.suggestedCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get suggestionConfidence => $composableBuilder(
    column: $table.suggestionConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get categoryWasCorrected => $composableBuilder(
    column: $table.categoryWasCorrected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get flaggedUnusual =>
      $composableBuilder(column: $table.flaggedUnusual, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get flagDismissed =>
      $composableBuilder(column: $table.flagDismissed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get regularPaymentId => $composableBuilder(
    column: $table.regularPaymentId,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get toAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt =>
      $composableBuilder(column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get suggestedCategoryId => $composableBuilder(
    column: $table.suggestedCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get suggestionConfidence => $composableBuilder(
    column: $table.suggestionConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get categoryWasCorrected => $composableBuilder(
    column: $table.categoryWasCorrected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flaggedUnusual => $composableBuilder(
    column: $table.flaggedUnusual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flagDismissed => $composableBuilder(
    column: $table.flagDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regularPaymentId => $composableBuilder(
    column: $table.regularPaymentId,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get toAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Direction, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => column);

  GeneratedColumn<int> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<int> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt =>
      $composableBuilder(column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get suggestedCategoryId =>
      $composableBuilder(column: $table.suggestedCategoryId, builder: (column) => column);

  GeneratedColumn<double> get suggestionConfidence =>
      $composableBuilder(column: $table.suggestionConfidence, builder: (column) => column);

  GeneratedColumn<bool> get categoryWasCorrected =>
      $composableBuilder(column: $table.categoryWasCorrected, builder: (column) => column);

  GeneratedColumn<bool> get flaggedUnusual =>
      $composableBuilder(column: $table.flaggedUnusual, builder: (column) => column);

  GeneratedColumn<bool> get flagDismissed =>
      $composableBuilder(column: $table.flagDismissed, builder: (column) => column);

  GeneratedColumn<String> get regularPaymentId =>
      $composableBuilder(column: $table.regularPaymentId, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get toAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({bool categoryId, bool accountId, bool toAccountId})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<Direction> direction = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> payeeKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<int> fee = const Value.absent(),
                Value<int> tax = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> localDay = const Value.absent(),
                Value<String?> suggestedCategoryId = const Value.absent(),
                Value<double?> suggestionConfidence = const Value.absent(),
                Value<bool> categoryWasCorrected = const Value.absent(),
                Value<bool> flaggedUnusual = const Value.absent(),
                Value<bool> flagDismissed = const Value.absent(),
                Value<String?> regularPaymentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                direction: direction,
                amount: amount,
                description: description,
                payeeKey: payeeKey,
                categoryId: categoryId,
                accountId: accountId,
                toAccountId: toAccountId,
                fee: fee,
                tax: tax,
                note: note,
                occurredAt: occurredAt,
                localDay: localDay,
                suggestedCategoryId: suggestedCategoryId,
                suggestionConfidence: suggestionConfidence,
                categoryWasCorrected: categoryWasCorrected,
                flaggedUnusual: flaggedUnusual,
                flagDismissed: flagDismissed,
                regularPaymentId: regularPaymentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required Direction direction,
                required int amount,
                Value<String> description = const Value.absent(),
                Value<String> payeeKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                required String accountId,
                Value<String?> toAccountId = const Value.absent(),
                Value<int> fee = const Value.absent(),
                Value<int> tax = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime occurredAt,
                required int localDay,
                Value<String?> suggestedCategoryId = const Value.absent(),
                Value<double?> suggestionConfidence = const Value.absent(),
                Value<bool> categoryWasCorrected = const Value.absent(),
                Value<bool> flaggedUnusual = const Value.absent(),
                Value<bool> flagDismissed = const Value.absent(),
                Value<String?> regularPaymentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                direction: direction,
                amount: amount,
                description: description,
                payeeKey: payeeKey,
                categoryId: categoryId,
                accountId: accountId,
                toAccountId: toAccountId,
                fee: fee,
                tax: tax,
                note: note,
                occurredAt: occurredAt,
                localDay: localDay,
                suggestedCategoryId: suggestedCategoryId,
                suggestionConfidence: suggestionConfidence,
                categoryWasCorrected: categoryWasCorrected,
                flaggedUnusual: flaggedUnusual,
                flagDismissed: flagDismissed,
                regularPaymentId: regularPaymentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, accountId = false, toAccountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$TransactionsTableReferences._categoryIdTable(db),
                        referencedColumn: $$TransactionsTableReferences._categoryIdTable(db).id,
                      ) as T;
                    }
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$TransactionsTableReferences._accountIdTable(db),
                        referencedColumn: $$TransactionsTableReferences._accountIdTable(db).id,
                      ) as T;
                    }
                    if (toAccountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.toAccountId,
                        referencedTable: $$TransactionsTableReferences._toAccountIdTable(db),
                        referencedColumn: $$TransactionsTableReferences._toAccountIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({bool categoryId, bool accountId, bool toAccountId})
    >;
typedef $$RegularPaymentsTableCreateCompanionBuilder = RegularPaymentsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String label,
  Value<String?> categoryId,
  Value<String> payeeKey,
  required int typicalAmount,
  required int amountLow,
  required int amountHigh,
  required int intervalDays,
  required int nextDueOn,
  Value<int> timesSeen,
  required RegularSource source,
  Value<bool> remind,
  Value<bool> dismissed,
  Value<int> rowid,
});
typedef $$RegularPaymentsTableUpdateCompanionBuilder = RegularPaymentsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> label,
  Value<String?> categoryId,
  Value<String> payeeKey,
  Value<int> typicalAmount,
  Value<int> amountLow,
  Value<int> amountHigh,
  Value<int> intervalDays,
  Value<int> nextDueOn,
  Value<int> timesSeen,
  Value<RegularSource> source,
  Value<bool> remind,
  Value<bool> dismissed,
  Value<int> rowid,
});

final class $$RegularPaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $RegularPaymentsTable, RegularPayment> {
  $$RegularPaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('regular_payments__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RegularPaymentsTableFilterComposer extends Composer<_$AppDatabase, $RegularPaymentsTable> {
  $$RegularPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get typicalAmount =>
      $composableBuilder(column: $table.typicalAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountLow =>
      $composableBuilder(column: $table.amountLow, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountHigh =>
      $composableBuilder(column: $table.amountHigh, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intervalDays =>
      $composableBuilder(column: $table.intervalDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextDueOn =>
      $composableBuilder(column: $table.nextDueOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesSeen =>
      $composableBuilder(column: $table.timesSeen, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<RegularSource, RegularSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get remind =>
      $composableBuilder(column: $table.remind, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegularPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RegularPaymentsTable> {
  $$RegularPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get typicalAmount => $composableBuilder(
    column: $table.typicalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountLow =>
      $composableBuilder(column: $table.amountLow, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountHigh =>
      $composableBuilder(column: $table.amountHigh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intervalDays =>
      $composableBuilder(column: $table.intervalDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextDueOn =>
      $composableBuilder(column: $table.nextDueOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesSeen =>
      $composableBuilder(column: $table.timesSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get remind =>
      $composableBuilder(column: $table.remind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegularPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RegularPaymentsTable> {
  $$RegularPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => column);

  GeneratedColumn<int> get typicalAmount =>
      $composableBuilder(column: $table.typicalAmount, builder: (column) => column);

  GeneratedColumn<int> get amountLow =>
      $composableBuilder(column: $table.amountLow, builder: (column) => column);

  GeneratedColumn<int> get amountHigh =>
      $composableBuilder(column: $table.amountHigh, builder: (column) => column);

  GeneratedColumn<int> get intervalDays =>
      $composableBuilder(column: $table.intervalDays, builder: (column) => column);

  GeneratedColumn<int> get nextDueOn =>
      $composableBuilder(column: $table.nextDueOn, builder: (column) => column);

  GeneratedColumn<int> get timesSeen =>
      $composableBuilder(column: $table.timesSeen, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RegularSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get remind =>
      $composableBuilder(column: $table.remind, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegularPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RegularPaymentsTable,
          RegularPayment,
          $$RegularPaymentsTableFilterComposer,
          $$RegularPaymentsTableOrderingComposer,
          $$RegularPaymentsTableAnnotationComposer,
          $$RegularPaymentsTableCreateCompanionBuilder,
          $$RegularPaymentsTableUpdateCompanionBuilder,
          (RegularPayment, $$RegularPaymentsTableReferences),
          RegularPayment,
          PrefetchHooks Function({bool categoryId})
        > {
  $$RegularPaymentsTableTableManager(_$AppDatabase db, $RegularPaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegularPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegularPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegularPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> payeeKey = const Value.absent(),
                Value<int> typicalAmount = const Value.absent(),
                Value<int> amountLow = const Value.absent(),
                Value<int> amountHigh = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> nextDueOn = const Value.absent(),
                Value<int> timesSeen = const Value.absent(),
                Value<RegularSource> source = const Value.absent(),
                Value<bool> remind = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegularPaymentsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                label: label,
                categoryId: categoryId,
                payeeKey: payeeKey,
                typicalAmount: typicalAmount,
                amountLow: amountLow,
                amountHigh: amountHigh,
                intervalDays: intervalDays,
                nextDueOn: nextDueOn,
                timesSeen: timesSeen,
                source: source,
                remind: remind,
                dismissed: dismissed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String label,
                Value<String?> categoryId = const Value.absent(),
                Value<String> payeeKey = const Value.absent(),
                required int typicalAmount,
                required int amountLow,
                required int amountHigh,
                required int intervalDays,
                required int nextDueOn,
                Value<int> timesSeen = const Value.absent(),
                required RegularSource source,
                Value<bool> remind = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegularPaymentsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                label: label,
                categoryId: categoryId,
                payeeKey: payeeKey,
                typicalAmount: typicalAmount,
                amountLow: amountLow,
                amountHigh: amountHigh,
                intervalDays: intervalDays,
                nextDueOn: nextDueOn,
                timesSeen: timesSeen,
                source: source,
                remind: remind,
                dismissed: dismissed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RegularPaymentsTable, RegularPayment>(table),
                  $$RegularPaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$RegularPaymentsTableReferences._categoryIdTable(db),
                        referencedColumn: $$RegularPaymentsTableReferences._categoryIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RegularPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RegularPaymentsTable,
      RegularPayment,
      $$RegularPaymentsTableFilterComposer,
      $$RegularPaymentsTableOrderingComposer,
      $$RegularPaymentsTableAnnotationComposer,
      $$RegularPaymentsTableCreateCompanionBuilder,
      $$RegularPaymentsTableUpdateCompanionBuilder,
      (RegularPayment, $$RegularPaymentsTableReferences),
      RegularPayment,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, updatedAt: updatedAt, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ForecastSnapshotsTableCreateCompanionBuilder = ForecastSnapshotsCompanion Function({
  required int periodStart,
  required int takenOn,
  required int point,
  required int low,
  required int high,
  required int spentSoFar,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ForecastSnapshotsTableUpdateCompanionBuilder = ForecastSnapshotsCompanion Function({
  Value<int> periodStart,
  Value<int> takenOn,
  Value<int> point,
  Value<int> low,
  Value<int> high,
  Value<int> spentSoFar,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ForecastSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ForecastSnapshotsTable> {
  $$ForecastSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get periodStart =>
      $composableBuilder(column: $table.periodStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get takenOn =>
      $composableBuilder(column: $table.takenOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get point =>
      $composableBuilder(column: $table.point, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get low =>
      $composableBuilder(column: $table.low, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get high =>
      $composableBuilder(column: $table.high, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get spentSoFar =>
      $composableBuilder(column: $table.spentSoFar, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ForecastSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ForecastSnapshotsTable> {
  $$ForecastSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get periodStart =>
      $composableBuilder(column: $table.periodStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get takenOn =>
      $composableBuilder(column: $table.takenOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get point =>
      $composableBuilder(column: $table.point, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get low =>
      $composableBuilder(column: $table.low, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get high =>
      $composableBuilder(column: $table.high, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get spentSoFar =>
      $composableBuilder(column: $table.spentSoFar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ForecastSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ForecastSnapshotsTable> {
  $$ForecastSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get periodStart =>
      $composableBuilder(column: $table.periodStart, builder: (column) => column);

  GeneratedColumn<int> get takenOn =>
      $composableBuilder(column: $table.takenOn, builder: (column) => column);

  GeneratedColumn<int> get point =>
      $composableBuilder(column: $table.point, builder: (column) => column);

  GeneratedColumn<int> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);

  GeneratedColumn<int> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<int> get spentSoFar =>
      $composableBuilder(column: $table.spentSoFar, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ForecastSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ForecastSnapshotsTable,
          ForecastSnapshot,
          $$ForecastSnapshotsTableFilterComposer,
          $$ForecastSnapshotsTableOrderingComposer,
          $$ForecastSnapshotsTableAnnotationComposer,
          $$ForecastSnapshotsTableCreateCompanionBuilder,
          $$ForecastSnapshotsTableUpdateCompanionBuilder,
          (
            ForecastSnapshot,
            BaseReferences<_$AppDatabase, $ForecastSnapshotsTable, ForecastSnapshot>,
          ),
          ForecastSnapshot,
          PrefetchHooks Function()
        > {
  $$ForecastSnapshotsTableTableManager(_$AppDatabase db, $ForecastSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ForecastSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ForecastSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ForecastSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> periodStart = const Value.absent(),
                Value<int> takenOn = const Value.absent(),
                Value<int> point = const Value.absent(),
                Value<int> low = const Value.absent(),
                Value<int> high = const Value.absent(),
                Value<int> spentSoFar = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ForecastSnapshotsCompanion(
                periodStart: periodStart,
                takenOn: takenOn,
                point: point,
                low: low,
                high: high,
                spentSoFar: spentSoFar,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int periodStart,
                required int takenOn,
                required int point,
                required int low,
                required int high,
                required int spentSoFar,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ForecastSnapshotsCompanion.insert(
                periodStart: periodStart,
                takenOn: takenOn,
                point: point,
                low: low,
                high: high,
                spentSoFar: spentSoFar,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ForecastSnapshotsTable, ForecastSnapshot>(table),
                  BaseReferences<_$AppDatabase, $ForecastSnapshotsTable, ForecastSnapshot>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ForecastSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ForecastSnapshotsTable,
      ForecastSnapshot,
      $$ForecastSnapshotsTableFilterComposer,
      $$ForecastSnapshotsTableOrderingComposer,
      $$ForecastSnapshotsTableAnnotationComposer,
      $$ForecastSnapshotsTableCreateCompanionBuilder,
      $$ForecastSnapshotsTableUpdateCompanionBuilder,
      (ForecastSnapshot, BaseReferences<_$AppDatabase, $ForecastSnapshotsTable, ForecastSnapshot>),
      ForecastSnapshot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$AccountsTableTableManager get accounts => $$AccountsTableTableManager(_db, _db.accounts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$RegularPaymentsTableTableManager get regularPayments =>
      $$RegularPaymentsTableTableManager(_db, _db.regularPayments);
  $$SettingsTableTableManager get settings => $$SettingsTableTableManager(_db, _db.settings);
  $$ForecastSnapshotsTableTableManager get forecastSnapshots =>
      $$ForecastSnapshotsTableTableManager(_db, _db.forecastSnapshots);
}
