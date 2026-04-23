import 'dart:async';

import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiTeacherReviewController {
  const AiTeacherReviewController(this.request);

  final AiTeacherReviewRequest request;

  static const _subjectivePollRetries = 20;
  static const _objectivePollRetries = 10;
  static const _subjectivePollInterval = Duration(seconds: 2);
  static const _objectivePollInterval = Duration(seconds: 3);

  static int pollRetriesFor(AiTeacherReviewRequest request) =>
      request.isSubjective ? _subjectivePollRetries : _objectivePollRetries;

  static Duration pollIntervalFor(AiTeacherReviewRequest request) =>
      request.isSubjective ? _subjectivePollInterval : _objectivePollInterval;

  Future<String?> submit() async {
    final response = await supabase.functions.invoke(
      'ai-review-submit',
      body: request.toBody(),
    );
    final data = response.data as Map<String, dynamic>?;
    return data?['review_id'] as String?;
  }

  Future<AiTeacherReviewResponse> fetch(String reviewId) async {
    final response = await supabase.functions.invoke(
      'ai-review-result',
      body: {'review_id': reviewId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return AiTeacherReviewResponse.fromJson(data);
  }

  Future<AiTeacherReviewResponse> fetchOrSubmit() async {
    final reviewId = await submit();
    if (reviewId == null) {
      return const AiTeacherReviewResponse(
        status: AiTeacherReviewStatus.error,
        reviewId: null,
        message: 'Không thể tạo teacher review.',
      );
    }

    final pollRetries = pollRetriesFor(request);
    final pollInterval = pollIntervalFor(request);
    AiTeacherReviewResponse? lastPending;

    for (var i = 0; i < pollRetries; i++) {
      final result = await fetch(reviewId);
      if (!result.isPending) return result;
      lastPending = result;
      if (i < pollRetries - 1) {
        await Future.delayed(pollInterval);
      }
    }

    return lastPending ??
        AiTeacherReviewResponse(
          status: AiTeacherReviewStatus.pending,
          reviewId: reviewId,
          message: 'AI Teacher vẫn đang chuẩn bị nhận xét.',
        );
  }
}

final aiTeacherReviewControllerProvider =
    Provider.family<AiTeacherReviewController, AiTeacherReviewRequest>(
  (_, request) => AiTeacherReviewController(request),
);

final aiTeacherReviewProvider = FutureProvider.autoDispose
    .family<AiTeacherReviewResponse, String>((ref, reviewId) async {
  final response = await supabase.functions.invoke(
    'ai-review-result',
    body: {'review_id': reviewId},
  );
  final data = Map<String, dynamic>.from(response.data as Map);
  return AiTeacherReviewResponse.fromJson(data);
});

final aiTeacherReviewEntryProvider = FutureProvider.autoDispose
    .family<AiTeacherReviewResponse, AiTeacherReviewRequest>(
        (ref, request) async {
  final controller = ref.watch(aiTeacherReviewControllerProvider(request));
  final response = await controller.fetchOrSubmit();

  if (response.isPending) {
    final timer = Timer(
      AiTeacherReviewController.pollIntervalFor(request),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
  }

  return response;
});
