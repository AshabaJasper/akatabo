import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/features/forecast/forecast_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Ten days of November spending.
final _november = [
  for (var d = 1; d <= 10; d++)
    txRow(id: 'n$d', amount: 20000, description: 'market', at: DateTime(2026, 11, d, 10)),
];

void main() {
  test('on the 1st, rows still holding last month make no forecast', () async {
    // The month stream has not reloaded yet: it still holds November's rows.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appNowProvider.overrideWithValue(DateTime(2026, 12, 1, 0, 5)),
        // The range is off here: these tests are about which rows the forecast reads.
        storedSettingsProvider.overrideWith(
          (ref) => Stream.value(const {'smart.forecastMonth': '0'}),
        ),
        monthRowsProvider.overrideWith((ref) => Stream.value(_november)),
        forecastWindowRowsProvider.overrideWith((ref) => Stream.value(_november)),
        activeRegularProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(monthForecastProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(monthRowsProvider.future);
    await container.read(forecastWindowRowsProvider.future);
    await container.read(activeRegularProvider.future);

    final view = container.read(monthForecastProvider);
    expect(view.ready, isTrue);
    expect(container.read(currentMonthProvider).start, DateTime(2026, 12));
    expect(view.daysWithEntries, 0, reason: 'November entries are not December days');
    expect(view.forecast, isNull, reason: 'no forecast from last month\'s rows');
  });

  test('within the month, the same rows do make a forecast', () async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appNowProvider.overrideWithValue(DateTime(2026, 11, 11, 9)),
        // The range is off here: these tests are about which rows the forecast reads.
        storedSettingsProvider.overrideWith(
          (ref) => Stream.value(const {'smart.forecastMonth': '0'}),
        ),
        monthRowsProvider.overrideWith((ref) => Stream.value(_november)),
        forecastWindowRowsProvider.overrideWith((ref) => Stream.value(_november)),
        activeRegularProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(monthForecastProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(monthRowsProvider.future);
    await container.read(forecastWindowRowsProvider.future);
    await container.read(activeRegularProvider.future);

    final view = container.read(monthForecastProvider);
    expect(view.ready, isTrue);
    expect(view.daysWithEntries, 10);
    expect(view.forecast, isNotNull);
    expect(view.forecast!.spentSoFar, 200000);
  });
}
