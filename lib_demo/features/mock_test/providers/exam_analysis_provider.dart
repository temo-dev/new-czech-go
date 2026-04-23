import 'dart:async';

import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/mock_test/models/exam_analysis.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exam_analysis_provider.g.dart';

const _analysisPollInterval = Duration(seconds: 3);

@riverpod
Future<ExamAnalysis?> examAnalysis(
  Ref ref,
  String attemptId,
) async {
  final data = await supabase
      .from('exam_analysis')
      .select()
      .eq('attempt_id', attemptId)
      .maybeSingle();

  if (data == null) {
    _scheduleAnalysisRefresh(ref);
    return null;
  }

  final analysis = ExamAnalysis.fromJson(
    Map<String, dynamic>.from(data as Map),
  );

  if (analysis.isProcessing) {
    _scheduleAnalysisRefresh(ref);
  }

  return analysis;
}

void _scheduleAnalysisRefresh(Ref ref) {
  final timer = Timer(_analysisPollInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}
