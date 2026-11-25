// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one database for the app's lifetime. Tests override it with an in-memory one.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The one database for the app's lifetime. Tests override it with an in-memory one.

final class AppDatabaseProvider extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The one database for the app's lifetime. Tests override it with an in-memory one.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(transactionRepository)
final transactionRepositoryProvider = TransactionRepositoryProvider._();

final class TransactionRepositoryProvider
    extends $FunctionalProvider<TransactionRepository, TransactionRepository, TransactionRepository>
    with $Provider<TransactionRepository> {
  TransactionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TransactionRepository create(Ref ref) {
    return transactionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionRepository>(value),
    );
  }
}

String _$transactionRepositoryHash() => r'3aa8ec799ae327e93274d19afe4e5b474c10cee7';

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends $FunctionalProvider<CategoryRepository, CategoryRepository, CategoryRepository>
    with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() => r'3c55f83a36220df37819fe04644016dc0af7ee06';

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

final class AccountRepositoryProvider
    extends $FunctionalProvider<AccountRepository, AccountRepository, AccountRepository>
    with $Provider<AccountRepository> {
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountRepository create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository>(value),
    );
  }
}

String _$accountRepositoryHash() => r'85899810d83fee8a89c5c2f2d496e05f82b2a54f';

@ProviderFor(goalRepository)
final goalRepositoryProvider = GoalRepositoryProvider._();

final class GoalRepositoryProvider
    extends $FunctionalProvider<GoalRepository, GoalRepository, GoalRepository>
    with $Provider<GoalRepository> {
  GoalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goalRepositoryHash();

  @$internal
  @override
  $ProviderElement<GoalRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoalRepository create(Ref ref) {
    return goalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoalRepository>(value),
    );
  }
}

String _$goalRepositoryHash() => r'80eb0d0589305b0efb96c0d0a4fb33825d232ca7';

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends $FunctionalProvider<SettingsRepository, SettingsRepository, SettingsRepository>
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() => r'2de17899c89cd144d3e134172002d79d8b2f2dfd';

/// Every stored setting, kept current.

@ProviderFor(storedSettings)
final storedSettingsProvider = StoredSettingsProvider._();

/// Every stored setting, kept current.

final class StoredSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          Stream<Map<String, String>>
        >
    with $FutureModifier<Map<String, String>>, $StreamProvider<Map<String, String>> {
  /// Every stored setting, kept current.
  StoredSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storedSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storedSettingsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, String>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Map<String, String>> create(Ref ref) {
    return storedSettings(ref);
  }
}

String _$storedSettingsHash() => r'34d126337c25e36c02f1760d7e28e9da2c21451a';

/// The Appearance settings from storage.

@ProviderFor(storedAppearance)
final storedAppearanceProvider = StoredAppearanceProvider._();

/// The Appearance settings from storage.

final class StoredAppearanceProvider
    extends $FunctionalProvider<AkAppearance, AkAppearance, AkAppearance>
    with $Provider<AkAppearance> {
  /// The Appearance settings from storage.
  StoredAppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storedAppearanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storedAppearanceHash();

  @$internal
  @override
  $ProviderElement<AkAppearance> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AkAppearance create(Ref ref) {
    return storedAppearance(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AkAppearance value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AkAppearance>(value),
    );
  }
}

String _$storedAppearanceHash() => r'b8e169df8b44b95f9f30e1967a99d261e6f5368a';

/// Periods from "Month starts on" and "Week starts on".

@ProviderFor(periodCalculator)
final periodCalculatorProvider = PeriodCalculatorProvider._();

/// Periods from "Month starts on" and "Week starts on".

final class PeriodCalculatorProvider
    extends $FunctionalProvider<PeriodCalculator, PeriodCalculator, PeriodCalculator>
    with $Provider<PeriodCalculator> {
  /// Periods from "Month starts on" and "Week starts on".
  PeriodCalculatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodCalculatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodCalculatorHash();

  @$internal
  @override
  $ProviderElement<PeriodCalculator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PeriodCalculator create(Ref ref) {
    return periodCalculator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeriodCalculator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeriodCalculator>(value),
    );
  }
}

String _$periodCalculatorHash() => r'32efca28c900e13baedfefecda2c788c350b5cd5';
