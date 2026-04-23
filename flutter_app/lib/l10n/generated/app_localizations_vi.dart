// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'A2 Mluvení Sprint';

  @override
  String get heroPill => 'FOCUSED SPEAKING PRACTICE';

  @override
  String heroGreeting(String name) {
    return 'Xin chào, $name. Ưu tiên sự rõ ràng, nhẹ nhàng, và tiến độ liên tục — như coach bình tĩnh, không phải bài test đáng sợ.';
  }

  @override
  String get heroPillDays => '14 NGÀY';

  @override
  String get heroPillTask => '1 TASK / MÀN HÌNH';

  @override
  String get heroPillFeedback => 'FEEDBACK NGAY SAU MỖI LẦN NÓI';

  @override
  String moduleExerciseCount(int count) {
    return '$count bài tập';
  }

  @override
  String get recentAttemptsTitle => 'Lần tập gần đây';

  @override
  String get recentAttemptsSubtitle => 'Xem transcript và feedback để theo dõi tiến bộ.';

  @override
  String get openExercise => 'Mở bài tập';

  @override
  String get retry => 'Thử lại';

  @override
  String get bottomNavHome => 'Trang chủ';

  @override
  String get bottomNavHistory => 'Lịch sử';

  @override
  String get historyEmpty => 'Chưa có lần tập nào. Hãy mở bài tập ở tab Trang chủ để bắt đầu.';

  @override
  String get pillSyntheticTranscript => 'TRANSCRIPT GIẢ LẬP';

  @override
  String pillFailure(String code) {
    return 'FAILURE: $code';
  }

  @override
  String get pillReadinessReady => 'SẴN SÀNG';

  @override
  String get pillReadinessAlmost => 'GẦN ĐỦ';

  @override
  String get pillReadinessNeedsWork => 'CẦN LUYỆN';

  @override
  String get pillReadinessNotReady => 'CHƯA SẴN SÀNG';

  @override
  String get pillFailed => 'FAILED';

  @override
  String get statusCopyStarting => 'Chuẩn bị bắt đầu attempt mới.';

  @override
  String get statusCopyRecording => 'Tập trung vào sự rõ ràng và trả lời đúng ý chính.';

  @override
  String get statusCopyUploading => 'Đang đóng gói bản ghi để gửi lên pipeline.';

  @override
  String get statusCopyProcessing => 'Hệ thống đang transcript và tổng hợp feedback.';

  @override
  String get statusCopyCompleted => 'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại ngay.';

  @override
  String get statusCopyFailed => 'Attempt gặp lỗi. Bạn có thể thử lại với một lần ghi mới.';

  @override
  String get statusCopyReady => 'Sẵn sàng cho một lần nói mới.';

  @override
  String get recordStatusReady => 'SẴN SÀNG';

  @override
  String get recordStatusRecording => 'ĐANG GHI';

  @override
  String get recordStatusUploading => 'ĐANG TẢI LÊN';

  @override
  String get recordStatusProcessing => 'ĐANG XỬ LÝ';

  @override
  String get recordStatusCompleted => 'HOÀN THÀNH';

  @override
  String get recordStatusFailed => 'LỖI';

  @override
  String get recordCtaStart => 'Bắt đầu luyện';

  @override
  String get recordCtaStop => 'Dừng';

  @override
  String get recordCtaAnalyze => 'Phân tích';

  @override
  String get recordCtaRerecord => 'Ghi lại';

  @override
  String get recordStatusStopped => 'ĐÃ DỪNG';

  @override
  String get recordHintStopped => 'Nghe lại bản ghi. Ấn \"Phân tích\" khi ưng ý.';

  @override
  String get analysisScreenTitle => 'Đang phân tích';

  @override
  String get analysisUploading => 'Đang tải lên bản ghi...';

  @override
  String get analysisProcessing => 'AI đang lắng nghe và chấm bài...';

  @override
  String get analysisFailedTitle => 'Phân tích thất bại';

  @override
  String get analysisRetryCta => 'Quay lại ghi lại';

  @override
  String get recordHintReady => 'Nhấn \"Bắt đầu luyện\" khi sẵn sàng.';

  @override
  String get recordHintRecording => 'Tập trung vào sự rõ ràng và trả lời đúng ý chính.';

  @override
  String get recordHintUploading => 'Đang đóng gói bản ghi để gửi lên pipeline.';

  @override
  String get recordHintProcessing => 'Hệ thống đang transcript và tổng hợp feedback.';

  @override
  String get recordHintCompleted => 'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại.';

  @override
  String get recordHintFailed => 'Attempt gặp lỗi. Thử lại với một lần ghi mới.';

  @override
  String get playbackTitle => 'Nghe lại bản ghi';

  @override
  String playbackErrorPrefix(String message) {
    return 'Playback gặp lỗi: $message';
  }

  @override
  String get playbackOpenError => 'Không mở được bản ghi để nghe lại.';

  @override
  String get resultTitle => 'Kết quả';

  @override
  String get resultTranscriptTitle => 'Transcript của bạn';

  @override
  String get resultStrengthsTitle => 'Điểm mạnh';

  @override
  String get resultImprovementsTitle => 'Cần cải thiện';

  @override
  String get resultRetryAdviceTitle => 'Lời khuyên cho lần sau';

  @override
  String get resultSampleAnswerTitle => 'Câu trả lời mẫu';

  @override
  String get resultRetryCta => 'Thử lại bài này';

  @override
  String get reviewArtifactTitle => 'Sửa & luyện theo mẫu';

  @override
  String get reviewArtifactSubtitle => 'Bản gốc, bản đã sửa, và bản mẫu để shadow theo.';

  @override
  String get reviewLoadError => 'Không tải được review';

  @override
  String get reviewNotApplicableTitle => 'Bản sửa chưa hỗ trợ cho dạng bài này';

  @override
  String get reviewNotApplicableBody => 'Tính năng sửa & luyện theo mẫu sẽ sớm có cho Úloha 3 và Úloha 4.';

  @override
  String get reviewFailedTitle => 'Review artifact gặp lỗi';

  @override
  String get reviewFailedBodyUnknown => 'Backend chưa tạo được bản sửa.';

  @override
  String reviewFailedBodyCode(String code) {
    return 'failure_code: $code';
  }

  @override
  String get reviewPendingTitle => 'Đang tạo bản sửa và audio mẫu...';

  @override
  String get reviewPendingBody => 'Bạn vẫn có thể đọc feedback phía trên trong lúc chờ.';

  @override
  String get reviewSourceTitle => 'Transcript của bạn';

  @override
  String get reviewCorrectedTitle => 'Bạn nên nói';

  @override
  String get reviewModelTitle => 'Bản mẫu để shadow';

  @override
  String get reviewSourceFallback => 'Transcript chưa sẵn sàng.';

  @override
  String get exerciseUloha1Label => 'ÚLOHA 1 · TRẢ LỜI CHỦ ĐỀ';

  @override
  String get exerciseUloha2Label => 'ÚLOHA 2 · HỘI THOẠI';

  @override
  String get exerciseUloha3Label => 'ÚLOHA 3 · KỂ CHUYỆN';

  @override
  String get exerciseUloha4Label => 'ÚLOHA 4 · CHỌN & GIẢI THÍCH';

  @override
  String get coachNoteTitle => 'Coach note';

  @override
  String get coachNoteUloha1 => 'Nói ngắn, rõ ý, dùng câu đơn giản trước. Ưu tiên trả lời đúng task hơn là cố nói phức tạp.';

  @override
  String get coachNoteUloha2 => 'Hỏi đủ thông tin trong scenario. Dùng câu hỏi đơn giản, rõ ràng.';

  @override
  String get coachNoteUloha3 => 'Kể theo thứ tự: nejdřív, pak, nakonec. Không cần câu hoàn hảo — cần đủ mốc.';

  @override
  String get coachNoteUloha4 => 'Chọn một phương án và giải thích lý do. Dùng \"protože\" hoặc \"protože mi líbí\".';

  @override
  String get promptRequiredInfoTitle => 'Thông tin bạn cần hỏi';

  @override
  String promptHintPrefix(String text) {
    return 'Gợi ý: $text';
  }

  @override
  String promptCustomQuestion(String text) {
    return 'Câu hỏi bổ sung: $text';
  }

  @override
  String promptStoryImageLabel(int index) {
    return 'Hình $index';
  }

  @override
  String get promptStoryNoImages => 'Chưa có ảnh — bài vẫn có thể luyện theo checkpoint văn bản.';

  @override
  String promptStoryImagesLoaded(int loaded, int total) {
    return 'Đã tải $loaded/$total ảnh.';
  }

  @override
  String get promptStoryHintOrder => 'Kể câu chuyện theo thứ tự: nejdřív, pak, nakonec.';

  @override
  String promptStoryHintByImages(int count) {
    return 'Hãy kể câu chuyện theo $count bức tranh.';
  }

  @override
  String get promptStoryCheckpointsTitle => 'Các mốc cần nhắc đến';

  @override
  String promptStoryGrammarFocus(String list) {
    return 'Ngữ pháp nên ưu tiên: $list';
  }

  @override
  String get promptChoiceOptionsTitle => 'Các lựa chọn';

  @override
  String promptChoiceReasoningHint(String list) {
    return 'Gợi ý lý do: $list';
  }
}
