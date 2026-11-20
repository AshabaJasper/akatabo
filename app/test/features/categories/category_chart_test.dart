import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/categories/categories_screen.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/widgets/charts/category_donut.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

/// The drawn month on Categories.html: five categories plus fees and tax.
final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(id: DefaultIds.school, name: 'School fees', iconKey: 'book', colourToken: 'cat-blue'),
  categoryRow(
    id: DefaultIds.transport,
    name: 'Transport',
    iconKey: 'bus',
    colourToken: 'cat-amber',
  ),
  categoryRow(id: DefaultIds.bills, name: 'Bills', iconKey: 'bolt', colourToken: 'cat-purple'),
  categoryRow(id: DefaultIds.other, name: 'Other', iconKey: 'dots', colourToken: 'cat-slate'),
  categoryRow(
    id: DefaultIds.fees,
    name: 'Fees and tax',
    iconKey: 'cash',
    colourToken: 'cat-pink',
    isSystem: true,
  ),
];

List<Transaction> _month() => [
  txRow(id: 'f', amount: 412000, day: 20261118, at: DateTime(2026, 11, 18, 10)),
  txRow(
    id: 's',
    amount: 350000,
    categoryId: DefaultIds.school,
    day: 20261116,
    at: DateTime(2026, 11, 16, 10),
  ),
  txRow(
    id: 't',
    amount: 236000,
    categoryId: DefaultIds.transport,
    day: 20261112,
    at: DateTime(2026, 11, 12, 10),
    fee: 18400,
  ),
  txRow(
    id: 'b',
    amount: 198000,
    categoryId: DefaultIds.bills,
    day: 20261105,
    at: DateTime(2026, 11, 5, 10),
  ),
  txRow(
    id: 'o',
    amount: 69600,
    categoryId: DefaultIds.other,
    day: 20261103,
    at: DateTime(2026, 11, 3, 10),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  CategoryChart chart, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith(
          (ref) => Stream.value({SettingKeys.categoryChart.name: chart.name}),
        ),
        appNowProvider.overrideWithValue(_now),
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
        monthRowsProvider.overrideWith((ref) => Stream.value(_month())),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const CategoriesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pie draws the donut beside the reading and plain rows', (tester) async {
    await _pump(tester, CategoryChart.pie);
    expect(find.byType(CategoryDonut), findsOneWidget);
    expect(find.byType(ShareBar), findsNothing);
    expect(find.text('1.28M'), findsOneWidget, reason: 'the total in the centre, as drawn');
    expect(find.text('money out'), findsOneWidget);
    expect(find.text('1 TO 19 NOVEMBER'), findsOneWidget);
    expect(find.text('Food and shopping and School fees are 59% of what you spent.'), findsOne);
    expect(
      find.bySemanticsLabel(RegExp('^Pie chart of money out by category: food and shopping 32%')),
      findsOneWidget,
    );
  });

  testWidgets('Bars puts a share bar in every row and no donut', (tester) async {
    await _pump(tester, CategoryChart.bars);
    expect(find.byType(CategoryDonut), findsNothing);
    expect(find.byType(ShareBar), findsNWidgets(6));
  });

  testWidgets('List only shows the rows alone', (tester) async {
    await _pump(tester, CategoryChart.listOnly);
    expect(find.byType(CategoryDonut), findsNothing);
    expect(find.byType(ShareBar), findsNothing);
    expect(find.text('Fees and tax'), findsOneWidget);
  });

  test('the setting reads Pie until another is stored', () {
    final container = ProviderContainer(
      overrides: [storedSettingsProvider.overrideWith((ref) => Stream.value(const {}))],
    );
    addTearDown(container.dispose);
    expect(container.read(categoryChartProvider), CategoryChart.pie);
    expect(SettingKeys.categoryChart.decode('nonsense'), CategoryChart.pie);
    expect(SettingKeys.categoryChart.decode('listOnly'), CategoryChart.listOnly);
  });

  group('donut slices', () {
    final colours = buildAkTheme(Brightness.light, const AkAppearance()).extension<AkColors>()!;
    final names = {
      for (var i = 0; i < 8; i++)
        'c$i': categoryRow(id: 'c$i', name: 'Cat $i', colourToken: 'cat-blue'),
    };

    test('six or fewer categories each get their own slice in list order', () {
      final slices = donutSlices(
        colours.tokens,
        ['c0', 'c1', 'c2'],
        {'c0': 30, 'c1': 20, 'c2': 10},
        names,
      );
      expect(slices.map((s) => s.name), ['Cat 0', 'Cat 1', 'Cat 2']);
      expect(slices.first.colour, colours.tokens.catBlue);
    });

    test('from a seventh category on, the smallest join one slice', () {
      final ids = [for (var i = 0; i < 8; i++) 'c$i'];
      final amounts = {for (var i = 0; i < 8; i++) 'c$i': 80 - i * 10};
      final slices = donutSlices(colours.tokens, ids, amounts, names);
      expect(slices, hasLength(6));
      expect(slices.last.name, 'the rest');
      expect(slices.last.amount, 30 + 20 + 10);
      expect(slices.last.colour, colours.tokens.lineStrong);
      expect(slices.fold<int>(0, (a, s) => a + s.amount), amounts.values.reduce((a, b) => a + b));
    });

    test('the spoken label names every slice with its share', () {
      final label = donutLabel(const [
        DonutSlice(name: 'Food and shopping', amount: 75, colour: Color(0xFF000000)),
        DonutSlice(name: 'Bills', amount: 25, colour: Color(0xFF000000)),
      ], 100);
      expect(label, 'Pie chart of money out by category: food and shopping 75%, bills 25%');
    });
  });

  testWidgets('a long total at large text stays inside the ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance(textSize: AkTextSize.large)),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Center(
            child: CategoryDonut(
              slices: [DonutSlice(name: 'Food', amount: 1, colour: Color(0xFF1F7A5C))],
              centre: '12.35M',
              centreCaption: 'money out',
              semanticLabel: 'Pie chart',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = tester.getRect(find.byType(CategoryDonut));
    final figure = tester.getRect(find.text('12.35M'));
    // The hole is the ring's inner diameter: 2 x (62 - 12) of the 160 box.
    final hole = ring.width * 100 / 160;
    expect(figure.width, lessThanOrEqualTo(hole));
    expect(ring.center.dx - figure.left, lessThanOrEqualTo(hole / 2));
  });

  for (final b in Brightness.values) {
    testWidgets('categories with the donut, ${b.name}', (tester) async {
      await _pump(tester, CategoryChart.pie, brightness: b);
      await expectLater(
        find.byType(CategoriesScreen),
        matchesGoldenFile('goldens/categories_pie_${b.name}.png'),
      );
    });
  }
}
