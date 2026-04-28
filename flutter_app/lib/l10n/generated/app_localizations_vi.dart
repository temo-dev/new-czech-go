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
  String get planSectionTitle => 'Lộ trình 14 ngày';

  @override
  String get planSectionSubtitle => 'Theo thứ tự. Hoàn thành từng ngày để lên mock exam.';

  @override
  String planDayLabel(int day) {
    return 'Ngày $day';
  }

  @override
  String get planStatusDone => 'ĐÃ XONG';

  @override
  String get planStatusCurrent => 'HÔM NAY';

  @override
  String get planStatusUpcoming => 'SẮP TỚI';

  @override
  String get planMockExamLabel => 'MOCK EXAM';

  @override
  String get mockExamTitle => 'Mock thi nói';

  @override
  String get mockExamIntroTitle => '4 phần, mỗi phần 1 lần';

  @override
  String get mockExamIntroBody => 'Ghi âm lần lượt từng Uloha. Sau khi xong cả 4 phần, hệ thống sẽ phân tích và cho kết quả tổng.';

  @override
  String mockExamSectionLabel(int index) {
    return 'Phần $index';
  }

  @override
  String get mockExamStatusDone => 'XONG';

  @override
  String get mockExamStatusPending => 'CHỜ';

  @override
  String get mockExamStatusRecorded => 'ĐÃ GHI';

  @override
  String get mockExamAnalyzing => 'Đang phân tích bài thi...';

  @override
  String mockExamAnalyzingProgress(int n, int total) {
    return 'Đang phân tích phần $n / $total';
  }

  @override
  String get mockExamActionStart => 'Bắt đầu';

  @override
  String get mockExamActionDone => 'Xong';

  @override
  String get mockExamResultTitle => 'Kết quả mock exam';

  @override
  String get mockExamOverallTitle => 'Mức sẵn sàng tổng';

  @override
  String get mockExamBackHome => 'Về trang chủ';

  @override
  String get mockExamCardPill => 'BÀI THI THỬ';

  @override
  String get mockExamCardTitle => 'Bài thi thử nói A2';

  @override
  String get mockExamCardSubtitle => 'Kiểm tra cả 4 phần nói liên tiếp như thi thật.';

  @override
  String get mockExamOpenCta => 'Mở mock exam';

  @override
  String get courseListTitle => 'Khóa học';

  @override
  String get courseListEmpty => 'Chưa có khóa học nào. Hãy nhờ admin publish một khóa.';

  @override
  String get moduleListTitle => 'Chủ đề';

  @override
  String get skillListTitle => 'Kỹ năng';

  @override
  String get exerciseListTitle => 'Bài tập';

  @override
  String get skillNoi => 'Nói';

  @override
  String get skillNghe => 'Nghe';

  @override
  String get skillDoc => 'Đọc';

  @override
  String get skillViet => 'Viết';

  @override
  String get skillTuVung => 'Từ vựng';

  @override
  String get skillNguPhap => 'Ngữ pháp';

  @override
  String get skillComingSoon => 'Sắp ra mắt';

  @override
  String get mockTestListTitle => 'Chọn đề thi';

  @override
  String get mockTestListEmpty => 'Chưa có đề thi nào. Hãy nhờ admin publish một đề.';

  @override
  String mockTestCardMinutes(int n) {
    return '$n phút';
  }

  @override
  String mockTestCardSections(int n) {
    return '$n phần';
  }

  @override
  String get mockTestIntroStartCta => 'Bắt đầu thi';

  @override
  String mockTestIntroPoints(int pts) {
    return 'Tổng $pts điểm';
  }

  @override
  String mockTestIntroPassThreshold(int pts) {
    return 'Đạt: từ $pts điểm trở lên';
  }

  @override
  String get mockTestIntroSectionsTitle => 'Các phần thi';

  @override
  String mockExamScoreLabel(int score, int max) {
    return '$score / $max';
  }

  @override
  String get mockExamPassLabel => 'ĐẠT';

  @override
  String get mockExamFailLabel => 'CHƯA ĐẠT';

  @override
  String mockExamSectionScoreLabel(int n, int score, int max) {
    return 'Úloha $n: $score/$max điểm';
  }

  @override
  String mockExamSectionDetail(int n) {
    return 'Phân tích Phần $n';
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
  String get historyLabel => 'LỊCH SỬ';

  @override
  String get historyTitle => 'Lịch sử luyện tập';

  @override
  String get historySubtitle => 'Theo dõi tiến độ và kết quả các bài đã nộp.';

  @override
  String get historyStatTotal => 'Tổng số bài';

  @override
  String get historyStatSuccess => 'Tỷ lệ thành công';

  @override
  String get resultCoachTipLabel => 'NHẬN XÉT HUẤN LUYỆN VIÊN';

  @override
  String get resultCriteriaLabel => 'TIÊU CHÍ ĐÁNH GIÁ';

  @override
  String get recordingCoachTip => 'Nhận xét huấn luyện viên';

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
  String get attemptAudioTitle => 'Nghe lại audio đã nộp';

  @override
  String get attemptAudioLoadError => 'Không tải được audio.';

  @override
  String attemptAudioOpenError(String message) {
    return 'Không mở được audio: $message';
  }

  @override
  String get reviewAudioTitle => 'Nghe audio mẫu để shadow';

  @override
  String get reviewAudioLoadError => 'Không tải được audio mẫu.';

  @override
  String reviewAudioOpenError(String message) {
    return 'Không mở được audio mẫu: $message';
  }

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
  String get resultNextExerciseCta => 'Sang bài tiếp theo';

  @override
  String get resultTabFeedback => 'Phản hồi';

  @override
  String get resultTabTranscript => 'Bản ghi';

  @override
  String get resultTabSample => 'Bài mẫu';

  @override
  String get resultNoFeedback => 'Chưa có phản hồi.';

  @override
  String get resultNoTranscript => 'Chưa có bản ghi âm.';

  @override
  String get resultNoSample => 'Chưa có bài mẫu.';

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

  @override
  String get bottomNavTests => 'Đề thi';

  @override
  String get bottomNavProfile => 'Hồ sơ';

  @override
  String get profileTitle => 'Hồ sơ';

  @override
  String get profileLanguageSection => 'Ngôn ngữ';

  @override
  String get profileAboutSection => 'Thông tin';

  @override
  String get profileAppName => 'A2 Mluvení Sprint';

  @override
  String get profileAppTagline => 'Luyện thi nói A2 tiếng Czech cho người Việt';

  @override
  String profileVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get submitAnswersCta => 'Nộp đáp án';

  @override
  String get submitWritingCta => 'Nộp bài';

  @override
  String get scoringInProgress => 'Đang chấm bài…';

  @override
  String get resultScreenTitle => 'Kết quả';

  @override
  String get retryCta => 'Làm lại';

  @override
  String get writingTopicsLabel => 'Viết về các chủ đề sau:';

  @override
  String get writingEmailHint => 'Ahoj Lído, …';

  @override
  String writingWordCountBadge(int count, int min) {
    return '$count/$min từ';
  }

  @override
  String writingQuestionFallback(int no) {
    return 'Câu hỏi $no';
  }

  @override
  String get audioLoading => 'Đang tải audio…';

  @override
  String get audioError => 'Không tải được audio';

  @override
  String get audioHint => 'Audio bài nghe — nghe 2 lần';

  @override
  String get objectiveBreakdownTitle => 'Chi tiết từng câu';

  @override
  String objectiveQuestionLabel(int no) {
    return 'Câu $no:';
  }

  @override
  String get objectivePassBadge => 'ĐÚNG';

  @override
  String get objectiveFailBadge => 'SAI';

  @override
  String get objectiveNoAnswer => '(không trả lời)';

  @override
  String objectiveScoreDisplay(int score, int max) {
    return '$score/$max';
  }

  @override
  String get fullExamScreenTitle => 'Bài thi thử';

  @override
  String get fullExamDurationLabel => 'Thời gian';

  @override
  String get fullExamMaxPtsLabel => 'Tổng điểm';

  @override
  String get fullExamPassLabel => 'Điểm đậu';

  @override
  String get fullExamSectionsTitle => 'Các phần thi';

  @override
  String get fullExamSubmitCta => 'Nộp bài písemná';

  @override
  String get fullExamSubmitHint => 'Hoàn thành tất cả phần thi để nộp';

  @override
  String get fullExamResultTitle => 'Kết quả bài thi';

  @override
  String get fullExamPisemnaLabel => 'Phần viết (Písemná)';

  @override
  String get fullExamUstniLabel => 'Phần nói (Ústní)';

  @override
  String get fullExamPassedBadge => 'ĐẠT';

  @override
  String get fullExamFailedBadge => 'TRƯỢT';

  @override
  String get fullExamOverallPassed => 'ĐẠT';

  @override
  String get fullExamOverallFailed => 'CHƯA ĐẠT';

  @override
  String get fullExamUstniPending => 'Phần nói (Ústní) chưa hoàn thành. Làm bài thi nói riêng để có kết quả tổng.';

  @override
  String get fullExamGoHome => 'Về trang chủ';

  @override
  String get fullExamPisemnaPassHint => 'Písemná đạt — cần hoàn thành phần nói để có kết quả tổng';

  @override
  String fullExamScoreNeed(int pass) {
    return 'cần ≥$pass';
  }

  @override
  String fullExamMinDuration(int min) {
    return '$min phút';
  }

  @override
  String fullExamPts(int pts) {
    return '$pts điểm';
  }

  @override
  String fullExamPassSymbol(int pass) {
    return '≥$pass';
  }

  @override
  String get skillModulesLabel => 'KỸ NĂNG';

  @override
  String get skillModulesTitle => 'Phát triển kỹ năng';

  @override
  String get skillModulesSubtitle => 'Chọn kỹ năng bạn muốn luyện tập hôm nay.';

  @override
  String get exerciseListProgressLink => 'Tiến trình nói';

  @override
  String get exerciseListFlowBadge => 'LIÊN TỤC';

  @override
  String get exerciseListSubtitle => 'Tập trung vào sự trôi chảy và phát âm đúng trong các tình huống thực tế.';

  @override
  String get exerciseListDailySprintLabel => 'CHẾ ĐỘ ĐỀ XUẤT';

  @override
  String get exerciseListDailySprintTitle => 'Luyện tập hàng ngày';

  @override
  String get exerciseListDailySprintSubtitle => 'Luyện tất cả bài tập cùng lúc và nhận phản hồi ngay từ AI coach.';

  @override
  String get exerciseListDailySprintCta => 'Bắt đầu tất cả';

  @override
  String get exerciseOpenError => 'Không thể mở bài tập. Vui lòng thử lại.';
}
