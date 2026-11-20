import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/tokens.g.dart' show AkTextTokens;
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../services/export/export_destination.dart';
import '../../services/export/export_report.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_pickers.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../home/home_providers.dart';
import 'export_providers.dart';

/// "1 transaction", "63 transactions".
String transactionCount(int n) => n == 1 ? '1 transaction' : '${_count.format(n)} transactions';

final _count = NumberFormat('#,##0', 'en');

/// The database size as the drawn note writes it: "0.4 MB", "12 MB", "under 0.1 MB".
String databaseSize(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb < 0.05) return 'under 0.1 MB';
  if (mb < 10) return '${mb.toStringAsFixed(1)} MB';
  return '${mb.round()} MB';
}

final _shortDate = DateFormat('d MMM yyyy');

enum _Send { save, share }

/// The note "Your data lives on this phone only" and Export to read or share, on Export and
/// back up: format, period, what to include, and the export button. [startOnPdf] opens it on
/// the PDF report for This month ("Export a monthly report").
class ExportSection extends ConsumerStatefulWidget {
  const ExportSection({super.key, this.startOnPdf = false});

  final bool startOnPdf;

  @override
  ConsumerState<ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends ConsumerState<ExportSection> {
  late ExportFormat _format = widget.startOnPdf ? ExportFormat.pdf : ExportFormat.csv;
  ExportRange _range = ExportRange.thisMonth;
  ExportOptions _options = const ExportOptions();

  /// The custom range, both days included. Set the first time Custom is chosen.
  DateTime? _first;
  DateTime? _last;
  bool _busy = false;

  Period? _period(DateTime now, PeriodCalculator calc) =>
      exportPeriod(_range, now: now, calc: calc, customFirst: _first, customLast: _last);

  void _chooseRange(ExportRange r) {
    setState(() {
      _range = r;
      if (r == ExportRange.custom && _first == null) {
        // Custom starts on this month, up to today: the range most people narrow from.
        final now = ref.read(appNowProvider);
        _first = ref.read(currentMonthProvider).start;
        _last = dateOnly(now);
      }
    });
  }

  Future<void> _pickDay({required bool first}) async {
    final calc = ref.read(periodCalculatorProvider);
    final now = ref.read(appNowProvider);
    final picked = await showAkDatePicker(
      context,
      initial: first ? _first! : _last!,
      first: DateTime(2000),
      last: DateTime(now.year + 1, 12, 31),
      helpText: first ? 'First day' : 'Last day',
      weekStartsOn: calc.weekStartsOn,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // The range always runs forwards: a first day after the last moves the last with it.
      if (first) {
        _first = picked;
        if (_last!.isBefore(picked)) _last = picked;
      } else {
        _last = picked;
        if (_first!.isAfter(picked)) _first = picked;
      }
    });
  }

  Future<void> _export(List<Transaction> all, Period? period) async {
    final now = ref.read(appNowProvider);
    final name = exportFileName(period, _format, now: now);
    final send = await showAkChoiceSheet<_Send>(
      context,
      title: 'Export $name',
      note: 'The file holds your entries, so share it only with someone you trust.',
      options: const [(_Send.save, 'Save it to a folder'), (_Send.share, 'Send or share it')],
    );
    if (send == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Where the share sheet points from on a tablet (an iPad refuses to open it without one).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final report = buildExportReport(
        all: all,
        categories: await ref.read(allCategoriesProvider.future),
        accounts: await ref.read(allAccountsProvider.future),
        period: period,
        calc: ref.read(periodCalculatorProvider),
        options: _options,
        now: now,
      );
      final fonts = _format == ExportFormat.pdf ? await ref.read(pdfFontsProvider.future) : null;
      final bytes = await ref.read(exportBytesBuilderProvider)(report, _format, fonts);
      final destination = ref.read(exportDestinationProvider);
      final done = send == _Send.save
          ? await destination.save(bytes: bytes, fileName: name, mimeType: _format.mimeType)
          : await destination.share(
              bytes: bytes,
              fileName: name,
              mimeType: _format.mimeType,
              origin: origin,
            );
      // The share sheet is its own answer; a save gets a line, since its dialog just closes.
      if (done && send == _Send.save) {
        messenger?.showSnackBar(SnackBar(content: Text('Saved $name.')));
      }
    } on Object catch (e, s) {
      debugPrint('Export failed: $e\n$s');
      messenger?.showSnackBar(
        const SnackBar(content: Text('The file could not be made. Nothing was saved or sent.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final calc = ref.watch(periodCalculatorProvider);
    final rowsAsync = ref.watch(exportAllRowsProvider);
    // Listened here so the export can read them at once: Riverpod pauses a provider no one
    // listens to, and its future would not complete.
    ref
      ..watch(allCategoriesProvider)
      ..watch(allAccountsProvider);
    if (_format == ExportFormat.pdf) ref.watch(pdfFontsProvider);
    final size = ref.watch(exportDatabaseSizeProvider).value;
    final all = rowsAsync.value;
    final period = _period(now, calc);
    final inPeriod = all == null ? null : rowsIn(all, period).length;

    final o = _options;
    final nothingChosen = _format != ExportFormat.pdf && !o.transactions && !o.categoryTotals;
    final String? reason = switch ((inPeriod, nothingChosen)) {
      (null, _) when rowsAsync.hasError => 'Your entries could not be read.',
      (null, _) => null,
      (0, _) =>
        all!.isEmpty
            ? 'There are no transactions yet.'
            : 'There are no transactions in this period.',
      (_, true) => 'Choose what to include.',
      _ => null,
    };
    final ready = all != null && inPeriod != null && inPeriod > 0 && !nothingChosen && !_busy;
    final String label;
    if (_busy) {
      label = 'Making the file';
    } else if (inPeriod == null) {
      label = 'Export';
    } else if (o.transactions) {
      label = 'Export ${transactionCount(inPeriod)}';
    } else if (_format == ExportFormat.pdf) {
      // The report still has its totals, but no list of entries to count.
      label = 'Export the report';
    } else {
      label = 'Export category totals';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhoneOnlyNote(
            detail: all == null
                ? (rowsAsync.hasError
                      ? 'Your entries could not be read. If you lose the phone without a '
                            'backup, they are gone.'
                      : 'If you lose the phone without a backup, it is gone.')
                : '${transactionCount(all.length)}'
                      '${size == null ? '' : ', ${databaseSize(size)}'}. '
                      'If you lose the phone without a backup, it is gone.',
          ),
          const SizedBox(height: AkSpace.s4),
          const AkEyebrow('Export to read or share'),
          const SizedBox(height: AkSpace.s2),
          AkCard(
            padding: const EdgeInsets.fromLTRB(AkSpace.s3h, 0, AkSpace.s3h, AkSpace.s3h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Group(
                  label: 'Format',
                  child: AkSegmented<ExportFormat>(
                    semanticLabel: 'Format',
                    segments: [for (final f in ExportFormat.values) AkSegment(f, f.label)],
                    selected: _format,
                    onChanged: (f) => setState(() => _format = f),
                  ),
                ),
                _Group(
                  label: 'Period',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Four choices share the width, so their labels are drawn a step
                      // smaller (body-sm, 13 against 14), as DataExport.html draws them. The
                      // person's own text size still applies on top.
                      MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: _StepDown(MediaQuery.textScalerOf(context))),
                        child: AkSegmented<ExportRange>(
                          semanticLabel: 'Period',
                          segments: [for (final r in ExportRange.values) AkSegment(r, r.label)],
                          selected: _range,
                          onChanged: _chooseRange,
                        ),
                      ),
                      if (_range == ExportRange.custom) ...[
                        const SizedBox(height: AkSpace.s1),
                        _DayRow(
                          title: 'From',
                          day: _first!,
                          onTap: () => _pickDay(first: true),
                          divider: true,
                        ),
                        _DayRow(title: 'To', day: _last!, onTap: () => _pickDay(first: false)),
                      ] else ...[
                        const SizedBox(height: AkSpace.s2),
                        Text(
                          period == null ? 'Every entry, whatever its date.' : periodLabel(period),
                          style: t.bodySm.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                _TickRow(
                  label: 'Transactions',
                  value: o.transactions,
                  count: inPeriod == null ? null : _count.format(inPeriod),
                  onChanged: (v) => setState(() => _options = o.copyWith(transactions: v)),
                  divider: true,
                ),
                _TickRow(
                  label: 'Fees and tax as their own column',
                  value: o.feesColumn,
                  onChanged: o.transactions
                      ? (v) => setState(() => _options = o.copyWith(feesColumn: v))
                      : null,
                  divider: true,
                ),
                _TickRow(
                  label: 'Category totals and budgets',
                  value: o.categoryTotals,
                  onChanged: (v) => setState(() => _options = o.copyWith(categoryTotals: v)),
                  divider: true,
                ),
                _TickRow(
                  label: 'Notes',
                  value: o.notes,
                  onChanged: o.transactions
                      ? (v) => setState(() => _options = o.copyWith(notes: v))
                      : null,
                ),
                const SizedBox(height: AkSpace.s2),
                _ExportButton(
                  label: label,
                  busy: _busy,
                  onPressed: ready ? () => _export(all, period) : null,
                ),
                const SizedBox(height: AkSpace.s2),
                Text(
                  reason ?? 'You choose where the file is saved or who to send it to.',
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The person's text scaling, then one type step down: `body-sm` over `body`.
class _StepDown extends TextScaler {
  const _StepDown(this.base);

  final TextScaler base;

  static final _ratio = AkTextTokens.bodySm.size / AkTextTokens.body.size;

  @override
  double scale(double fontSize) => base.scale(fontSize) * _ratio;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * _ratio;

  @override
  bool operator ==(Object other) => other is _StepDown && other.base == base;

  @override
  int get hashCode => base.hashCode;
}

/// "Your data lives on this phone only": the deep brand card at the top of the screen.
class _PhoneOnlyNote extends StatelessWidget {
  const _PhoneOnlyNote({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return AkCard(
      // `brand-deep`, as both drawn themes fill it: in dark, `brand` is lighter and the
      // muted line on it would fall under 4.5:1.
      color: c.brandDeep,
      borderColor: c.brandDeep,
      padding: const EdgeInsets.all(AkSpace.s3h),
      child: Row(
        children: [
          AkIconTile(
            icon: AkIcons.phone,
            background: c.brandRaised,
            foreground: c.accent,
            size: AkSize.tileMd,
            iconSize: AkSize.iconNav,
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data lives on this phone only',
                  style: t.bodyMd.copyWith(color: c.onBrand, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AkSpace.s0h),
                Text(detail, style: t.bodySm.copyWith(color: c.onBrandMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled control with a line under it, as Format and Period are drawn.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AkSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(label, style: context.type.body.copyWith(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: AkSpace.s2),
          child,
        ],
      ),
    );
  }
}

/// A day of the custom range; the whole row opens the date picker.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.title,
    required this.day,
    required this.onTap,
    this.divider = false,
  });

  final String title;
  final DateTime day;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$title, ${_shortDate.format(day)}. Change',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: AkListRow(
        title: title,
        divider: divider,
        minHeight: AkSize.target,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_shortDate.format(day), style: context.type.body.copyWith(color: c.inkMuted)),
            const SizedBox(width: AkSpace.s2),
            AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
          ],
        ),
      ),
    );
  }
}

/// A tick box row: the box, its label and an optional count. The whole row is the target,
/// and screen readers hear one checkbox with the label. Without [onChanged] it is shown
/// faded and cannot be changed (fee and note columns need Transactions).
class _TickRow extends StatelessWidget {
  const _TickRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.count,
    this.divider = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? count;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final enabled = onChanged != null;
    final ink = enabled ? c.ink : c.inkMuted;
    return MergeSemantics(
      child: Semantics(
        enabled: enabled,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: AkSize.target + 2),
              decoration: divider
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    )
                  : null,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: AkSize.iconNav,
                    child: Checkbox(
                      value: value,
                      onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: c.brand,
                      checkColor: c.onBrand,
                      side: BorderSide(
                        color: enabled ? c.inkMuted : c.lineStrong,
                        width: AkSize.stroke,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.metrics.xs),
                      ),
                    ),
                  ),
                  const SizedBox(width: AkSpace.s3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
                      child: Text(
                        label,
                        style: t.body.copyWith(fontWeight: FontWeight.w500, color: ink),
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: AkSpace.s3),
                    Text(
                      count!,
                      style: t.body.copyWith(
                        color: c.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The export button: `brand` fill with the download icon, as drawn; `surface-sunk` with
/// muted text when there is nothing to export.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.onPressed, required this.busy});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final ink = enabled ? c.onBrand : c.inkMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      child: Material(
        color: enabled ? c.brand : c.surfaceSunk,
        borderRadius: BorderRadius.circular(context.metrics.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.button),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: AkSize.iconSm,
                      child: CircularProgressIndicator(strokeWidth: AkSize.stroke, color: ink),
                    )
                  else
                    AkIcon(AkIcons.download, color: ink),
                  const SizedBox(width: AkSpace.s2),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: context.type.button.copyWith(color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
