import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/formats.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/forecast.dart';
import '../../services/notifications/reminder_switch.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_headline_amount.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/bubble_timeline.dart';
import '../home/home_providers.dart';
import '../settings/settings_page.dart' show SettingsSwitchRow, ordinalDay;
import 'looks_regular_section.dart';
import 'regular_providers.dart';

/// Regular payments still due this month, and the ones coming later. Each one counts for every
/// occurrence left in the month, the same figure the forecast adds.
class RegularPaymentsScreen extends ConsumerWidget {
  const RegularPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final month = ref.watch(periodCalculatorProvider).month(today);
    final async = ref.watch(activeRegularProvider);
    final payments = async.value ?? const <RegularPayment>[];

    final dueThisMonth = <RegularPayment, List<DateTime>>{};
    final laterDue = <RegularPayment, DateTime>{};
    for (final p in payments) {
      final dues = regularDuesIn(p, from: today, through: month.lastDate);
      if (dues.isNotEmpty) {
        dueThisMonth[p] = dues;
      } else {
        final next = regularDuesIn(
          p,
          from: addDays(month.lastDate, 1),
          through: addDays(month.lastDate, 400),
        );
        if (next.isNotEmpty) laterDue[p] = next.first;
      }
    }
    final total = dueThisMonth.entries.fold<int>(
      0,
      (sum, e) => sum + e.key.typicalAmount * e.value.length,
    );
    final ended = DateFormat('d MMMM').format(month.lastDate);
    final hidden = ref.watch(amountsHiddenProvider);
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Insights', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s3),
            Semantics(
              header: true,
              child: Text(
                'Regular payments due before $ended',
                style: t.titleLg.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: AkSpace.s2),
            if (async.hasError && !async.hasValue)
              const AkEmptyNote(loadFailedText)
            else if (!async.hasValue)
              const SizedBox(height: AkSize.chart)
            else if (payments.isEmpty && ref.watch(looksRegularProvider).isNotEmpty)
              const AkEmptyNote('None saved yet. Smart help found the ones below.')
            else if (payments.isEmpty)
              // No action of its own: "Add a regular payment yourself" sits just below.
              const AkEmptyNote(
                'Nothing repeating yet. Add a bill you pay every week or month, and it '
                'comes up here.',
              )
            else ...[
              AkHeadlineAmount(total, style: t.figureXl.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s1),
              Text(
                '${dueThisMonth.length} ${dueThisMonth.length == 1 ? 'payment' : 'payments'} '
                'this month.${payments.every((p) => p.source == RegularSource.manual) ? ' You added these by hand.' : ''}',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              if (dueThisMonth.isNotEmpty) ...[
                const SizedBox(height: AkSpace.s4),
                AkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BubbleTimeline(
                        from: today,
                        through: month.lastDate,
                        hidden: hidden,
                        endLabel: DateFormat('d MMM').format(month.lastDate),
                        bubbles: [
                          for (final e in dueThisMonth.entries)
                            for (final d in e.value)
                              TimelineBubble(
                                day: d,
                                amount: e.key.typicalAmount,
                                colour: colourForToken(
                                  c,
                                  categories[e.key.categoryId]?.colourToken ?? 'cat-slate',
                                ),
                              ),
                        ],
                        semanticLabel:
                            'Timeline from ${today.day} to $ended. ${[for (final e in dueThisMonth.entries)
                              for (final d in e.value) '${e.key.label} ${hidden ? hiddenFigureLabel : formatUgx(e.key.typicalAmount)} on the ${ordinalDay(d.day).replaceFirst('The ', '')}'].join(', ')}.',
                      ),
                      const SizedBox(height: AkSpace.s1),
                      Text(
                        'A bigger circle is a bigger payment.',
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AkSpace.s4),
              for (final e in dueThisMonth.entries)
                _PaymentRow(
                  payment: e.key,
                  reading:
                      'Next ${[for (final d in e.value) DateFormat('EEE d MMM').format(d)].join(' and ')}',
                  amount: e.key.typicalAmount * e.value.length,
                ),
              for (final e in laterDue.entries)
                _PaymentRow(
                  payment: e.key,
                  reading:
                      'Next ${formatDate(e.value, ref.watch(dateStyleProvider), words: 'd MMMM y')}',
                  amount: e.key.typicalAmount,
                ),
            ],
            const LooksRegularSection(),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: AkSpace.s4),
              const _RemindDayBefore(),
            ],
            const SizedBox(height: AkSpace.s4),
            AkOutlineButton(
              label: 'Add a regular payment yourself',
              icon: AkIcons.plus,
              onPressed: () => context.push(Routes.regularNew),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Remind me the day before": the same setting as "Tell me before a regular payment" in
/// Smart help and reminders. Switching it on asks the phone first; a refusal leaves it off
/// and says why.
class _RemindDayBefore extends ConsumerStatefulWidget {
  const _RemindDayBefore();

  @override
  ConsumerState<_RemindDayBefore> createState() => _RemindDayBeforeState();
}

class _RemindDayBeforeState extends ConsumerState<_RemindDayBefore> {
  bool _asking = false;
  String? _problem;

  Future<void> _switch(bool on) async {
    if (_asking) return;
    setState(() {
      _asking = true;
      _problem = null;
    });
    final problem = await switchReminder(ref, SettingKeys.regularReminder, on: on);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(storedSettingsProvider).value;
    final on = SettingKeys.regularReminder.decode(stored?[SettingKeys.regularReminder.name]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkCard(
          padding: EdgeInsets.zero,
          child: SettingsSwitchRow(
            label: 'Remind me the day before',
            detail: 'One notification, in the morning',
            value: on,
            onChanged: (v) {
              if (stored != null && !_asking) unawaited(_switch(v));
            },
          ),
        ),
        if (_problem != null) ...[const SizedBox(height: AkSpace.s2), AkEmptyNote(_problem!)],
      ],
    );
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment, required this.reading, required this.amount});

  final RegularPayment payment;
  final String reading;
  final int amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    return AkListRow(
      title: payment.label,
      subtitle: 'Every ${payment.intervalDays} days. $reading',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatAmount(amount), style: t.figure.copyWith(color: c.ink)),
          const SizedBox(width: AkSpace.s2),
          AkTextLink('Remove', onTap: () => _confirmRemove(context, ref)),
        ],
      ),
      divider: true,
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${payment.label}?'),
        content: const Text(
          'It stops coming up in the forecast and this list. Past entries stay as they are.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final removed = await saveOrSay(
      context,
      () => ref.read(regularPaymentRepositoryProvider).dismiss(payment.id),
      failed: '${payment.label} could not be removed. Try again.',
    );
    if (removed && context.mounted) showAkMessage(context, '${payment.label} removed.');
  }
}
