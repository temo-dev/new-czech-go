import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../exercise/widgets/result_card.dart';

/// Shows the full analysis for one mock exam section attempt.
/// Loads AttemptResult via getAttempt and renders the shared ResultCard.
class MockExamSectionDetailScreen extends StatefulWidget {
  const MockExamSectionDetailScreen({
    super.key,
    required this.client,
    required this.attemptId,
    required this.sequenceNo,
  });

  final ApiClient client;
  final String attemptId;
  final int sequenceNo;

  @override
  State<MockExamSectionDetailScreen> createState() =>
      _MockExamSectionDetailScreenState();
}

class _MockExamSectionDetailScreenState
    extends State<MockExamSectionDetailScreen> {
  AttemptResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.client.getAttempt(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _result = AttemptResult.fromJson(data);
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.mockExamSectionDetail(widget.sequenceNo))),
      body: SafeArea(child: _buildBody(l)),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final err = _error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.x3),
              FilledButton(onPressed: _load, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }

    final result = _result!;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        ResultCard(
          client: widget.client,
          result: result,
          onRetry: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
