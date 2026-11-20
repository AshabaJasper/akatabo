import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/forecast.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
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
              AkEmptyNote(
                'Nothing repeating yet. Add a bill you pay every week or month, and it '
                'comes up here.',
                actionLabel: 'Add a regular payment',
                onAction: () => context.push(Routes.regularNew),
              )
            else ...[
              Text(formatUgx(total), style: t.figureXl.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s1),
              Text(
                '${dueThisMonth.length} ${dueThisMonth.length == 1 ? 'payment' : 'payments'} '
                'this month.${payments.every((p) => p.source == RegularSource.manual) ? ' You added these by hand.' : ''}',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
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
                  reading: 'Next ${DateFormat('d MMMM y').format(e.value)}',
                  amount: e.key.typicalAmount,
                ),
            ],
            const LooksRegularSection(),
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
