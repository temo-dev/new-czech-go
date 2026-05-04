import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'A2 Mluvení Sprint'**
  String get appTitle;

  /// No description provided for @heroPill.
  ///
  /// In vi, this message translates to:
  /// **'FOCUSED SPEAKING PRACTICE'**
  String get heroPill;

  /// No description provided for @heroGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào, {name}. Ưu tiên sự rõ ràng, nhẹ nhàng, và tiến độ liên tục — như coach bình tĩnh, không phải bài test đáng sợ.'**
  String heroGreeting(String name);

  /// No description provided for @heroPillDays.
  ///
  /// In vi, this message translates to:
  /// **'14 NGÀY'**
  String get heroPillDays;

  /// No description provided for @heroPillTask.
  ///
  /// In vi, this message translates to:
  /// **'1 TASK / MÀN HÌNH'**
  String get heroPillTask;

  /// No description provided for @heroPillFeedback.
  ///
  /// In vi, this message translates to:
  /// **'FEEDBACK NGAY SAU MỖI LẦN NÓI'**
  String get heroPillFeedback;

  /// No description provided for @moduleExerciseCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} bài tập'**
  String moduleExerciseCount(int count);

  /// No description provided for @planSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lộ trình 14 ngày'**
  String get planSectionTitle;

  /// No description provided for @planSectionSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Theo thứ tự. Hoàn thành từng ngày để lên mock exam.'**
  String get planSectionSubtitle;

  /// No description provided for @planDayLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {day}'**
  String planDayLabel(int day);

  /// No description provided for @planStatusDone.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ XONG'**
  String get planStatusDone;

  /// No description provided for @planStatusCurrent.
  ///
  /// In vi, this message translates to:
  /// **'HÔM NAY'**
  String get planStatusCurrent;

  /// No description provided for @planStatusUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'SẮP TỚI'**
  String get planStatusUpcoming;

  /// No description provided for @planMockExamLabel.
  ///
  /// In vi, this message translates to:
  /// **'MOCK EXAM'**
  String get planMockExamLabel;

  /// No description provided for @mockExamTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mock thi nói'**
  String get mockExamTitle;

  /// No description provided for @mockExamIntroTitle.
  ///
  /// In vi, this message translates to:
  /// **'4 phần, mỗi phần 1 lần'**
  String get mockExamIntroTitle;

  /// No description provided for @mockExamIntroBody.
  ///
  /// In vi, this message translates to:
  /// **'Ghi âm lần lượt từng Uloha. Sau khi xong cả 4 phần, hệ thống sẽ phân tích và cho kết quả tổng.'**
  String get mockExamIntroBody;

  /// No description provided for @mockExamProgressIntroTitle.
  ///
  /// In vi, this message translates to:
  /// **'{count} phần, mỗi phần 1 lần'**
  String mockExamProgressIntroTitle(int count);

  /// No description provided for @mockExamProgressIntroBodyWithSpeaking.
  ///
  /// In vi, this message translates to:
  /// **'Làm từng phần theo thứ tự. Điểm bài thi chỉ được tính sau phần cuối; phần nói sẽ được phân tích cùng nhau ở cuối.'**
  String get mockExamProgressIntroBodyWithSpeaking;

  /// No description provided for @mockExamProgressIntroBodyNoSpeaking.
  ///
  /// In vi, this message translates to:
  /// **'Làm từng phần theo thứ tự. Kết quả sẽ được tính sau phần cuối cùng.'**
  String get mockExamProgressIntroBodyNoSpeaking;

  /// No description provided for @mockExamSectionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần {index}'**
  String mockExamSectionLabel(int index);

  /// No description provided for @mockExamStatusDone.
  ///
  /// In vi, this message translates to:
  /// **'XONG'**
  String get mockExamStatusDone;

  /// No description provided for @mockExamStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'CHỜ'**
  String get mockExamStatusPending;

  /// No description provided for @mockExamStatusRecorded.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GHI'**
  String get mockExamStatusRecorded;

  /// No description provided for @mockExamAnalyzing.
  ///
  /// In vi, this message translates to:
  /// **'Đang phân tích bài thi...'**
  String get mockExamAnalyzing;

  /// No description provided for @mockExamAnalyzingProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang phân tích phần {n} / {total}'**
  String mockExamAnalyzingProgress(int n, int total);

  /// No description provided for @mockExamActionStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get mockExamActionStart;

  /// No description provided for @mockExamActionDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get mockExamActionDone;

  /// No description provided for @mockExamSectionMeta.
  ///
  /// In vi, this message translates to:
  /// **'{skill} · {exercise} · {points} điểm'**
  String mockExamSectionMeta(String skill, String exercise, int points);

  /// No description provided for @mockExamTaskTypeUloha.
  ///
  /// In vi, this message translates to:
  /// **'Úloha {n}'**
  String mockExamTaskTypeUloha(int n);

  /// No description provided for @mockExamTaskTypeListening.
  ///
  /// In vi, this message translates to:
  /// **'Nghe {n}'**
  String mockExamTaskTypeListening(int n);

  /// No description provided for @mockExamTaskTypeReading.
  ///
  /// In vi, this message translates to:
  /// **'Đọc {n}'**
  String mockExamTaskTypeReading(int n);

  /// No description provided for @mockExamTaskTypeWriting.
  ///
  /// In vi, this message translates to:
  /// **'Viết {n}'**
  String mockExamTaskTypeWriting(int n);

  /// No description provided for @mockExamTaskTypeWritingForm.
  ///
  /// In vi, this message translates to:
  /// **'Viết 1 - form'**
  String get mockExamTaskTypeWritingForm;

  /// No description provided for @mockExamTaskTypeWritingEmail.
  ///
  /// In vi, this message translates to:
  /// **'Viết 2 - email'**
  String get mockExamTaskTypeWritingEmail;

  /// No description provided for @mockExamResultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả mock exam'**
  String get mockExamResultTitle;

  /// No description provided for @mockExamOverallTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mức sẵn sàng tổng'**
  String get mockExamOverallTitle;

  /// No description provided for @mockExamBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get mockExamBackHome;

  /// No description provided for @mockExamCardPill.
  ///
  /// In vi, this message translates to:
  /// **'BÀI THI THỬ'**
  String get mockExamCardPill;

  /// No description provided for @mockExamCardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bài thi thử nói A2'**
  String get mockExamCardTitle;

  /// No description provided for @mockExamCardSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cả 4 phần nói liên tiếp như thi thật.'**
  String get mockExamCardSubtitle;

  /// No description provided for @mockExamOpenCta.
  ///
  /// In vi, this message translates to:
  /// **'Mở mock exam'**
  String get mockExamOpenCta;

  /// No description provided for @courseListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khóa học'**
  String get courseListTitle;

  /// No description provided for @courseListEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khóa học nào. Hãy nhờ admin publish một khóa.'**
  String get courseListEmpty;

  /// No description provided for @moduleListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chủ đề'**
  String get moduleListTitle;

  /// No description provided for @skillListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng'**
  String get skillListTitle;

  /// No description provided for @exerciseListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bài tập'**
  String get exerciseListTitle;

  /// No description provided for @skillNoi.
  ///
  /// In vi, this message translates to:
  /// **'Nói'**
  String get skillNoi;

  /// No description provided for @skillNghe.
  ///
  /// In vi, this message translates to:
  /// **'Nghe'**
  String get skillNghe;

  /// No description provided for @skillDoc.
  ///
  /// In vi, this message translates to:
  /// **'Đọc'**
  String get skillDoc;

  /// No description provided for @skillViet.
  ///
  /// In vi, this message translates to:
  /// **'Viết'**
  String get skillViet;

  /// No description provided for @skillTuVung.
  ///
  /// In vi, this message translates to:
  /// **'Từ vựng'**
  String get skillTuVung;

  /// No description provided for @skillNguPhap.
  ///
  /// In vi, this message translates to:
  /// **'Ngữ pháp'**
  String get skillNguPhap;

  /// No description provided for @skillComingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp ra mắt'**
  String get skillComingSoon;

  /// No description provided for @mockTestListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn đề thi'**
  String get mockTestListTitle;

  /// No description provided for @mockTestListEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đề thi nào. Hãy nhờ admin publish một đề.'**
  String get mockTestListEmpty;

  /// No description provided for @mockTestCardMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{n} phút'**
  String mockTestCardMinutes(int n);

  /// No description provided for @mockTestCardSections.
  ///
  /// In vi, this message translates to:
  /// **'{n} phần'**
  String mockTestCardSections(int n);

  /// No description provided for @mockTestIntroStartCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu thi'**
  String get mockTestIntroStartCta;

  /// No description provided for @mockTestMissingTemplateId.
  ///
  /// In vi, this message translates to:
  /// **'Đề thi này đang thiếu ID mẫu. Hãy tải lại danh sách đề và thử lại.'**
  String get mockTestMissingTemplateId;

  /// No description provided for @mockTestIntroPoints.
  ///
  /// In vi, this message translates to:
  /// **'Tổng {pts} điểm'**
  String mockTestIntroPoints(int pts);

  /// No description provided for @mockTestIntroPassThreshold.
  ///
  /// In vi, this message translates to:
  /// **'Đạt: từ {pts} điểm trở lên'**
  String mockTestIntroPassThreshold(int pts);

  /// No description provided for @mockTestIntroSectionsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các phần thi'**
  String get mockTestIntroSectionsTitle;

  /// No description provided for @mockExamScoreLabel.
  ///
  /// In vi, this message translates to:
  /// **'{score} / {max}'**
  String mockExamScoreLabel(int score, int max);

  /// No description provided for @mockExamPassLabel.
  ///
  /// In vi, this message translates to:
  /// **'ĐẠT'**
  String get mockExamPassLabel;

  /// No description provided for @mockExamFailLabel.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA ĐẠT'**
  String get mockExamFailLabel;

  /// No description provided for @mockExamResultPassThreshold.
  ///
  /// In vi, this message translates to:
  /// **'Ngưỡng đạt: {pct}%'**
  String mockExamResultPassThreshold(int pct);

  /// No description provided for @mockExamSectionScoreLabel.
  ///
  /// In vi, this message translates to:
  /// **'Úloha {n}: {score}/{max} điểm'**
  String mockExamSectionScoreLabel(int n, int score, int max);

  /// No description provided for @mockExamSectionDetail.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích Phần {n}'**
  String mockExamSectionDetail(int n);

  /// No description provided for @recentAttemptsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lần tập gần đây'**
  String get recentAttemptsTitle;

  /// No description provided for @recentAttemptsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem transcript và feedback để theo dõi tiến bộ.'**
  String get recentAttemptsSubtitle;

  /// No description provided for @openExercise.
  ///
  /// In vi, this message translates to:
  /// **'Mở bài tập'**
  String get openExercise;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @bottomNavHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get bottomNavHome;

  /// No description provided for @bottomNavHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử'**
  String get bottomNavHistory;

  /// No description provided for @historyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lần tập nào. Hãy mở bài tập ở tab Trang chủ để bắt đầu.'**
  String get historyEmpty;

  /// No description provided for @historyLabel.
  ///
  /// In vi, this message translates to:
  /// **'LỊCH SỬ'**
  String get historyLabel;

  /// No description provided for @historyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử luyện tập'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi tiến độ và kết quả các bài đã nộp.'**
  String get historySubtitle;

  /// No description provided for @historyStatTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng số bài'**
  String get historyStatTotal;

  /// No description provided for @historyStatSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ thành công'**
  String get historyStatSuccess;

  /// No description provided for @resultCoachTipLabel.
  ///
  /// In vi, this message translates to:
  /// **'NHẬN XÉT HUẤN LUYỆN VIÊN'**
  String get resultCoachTipLabel;

  /// No description provided for @resultCriteriaLabel.
  ///
  /// In vi, this message translates to:
  /// **'TIÊU CHÍ ĐÁNH GIÁ'**
  String get resultCriteriaLabel;

  /// No description provided for @recordingCoachTip.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét huấn luyện viên'**
  String get recordingCoachTip;

  /// No description provided for @pillSyntheticTranscript.
  ///
  /// In vi, this message translates to:
  /// **'TRANSCRIPT GIẢ LẬP'**
  String get pillSyntheticTranscript;

  /// No description provided for @pillFailure.
  ///
  /// In vi, this message translates to:
  /// **'FAILURE: {code}'**
  String pillFailure(String code);

  /// No description provided for @pillReadinessReady.
  ///
  /// In vi, this message translates to:
  /// **'SẴN SÀNG'**
  String get pillReadinessReady;

  /// No description provided for @pillReadinessAlmost.
  ///
  /// In vi, this message translates to:
  /// **'GẦN ĐỦ'**
  String get pillReadinessAlmost;

  /// No description provided for @pillReadinessNeedsWork.
  ///
  /// In vi, this message translates to:
  /// **'CẦN LUYỆN'**
  String get pillReadinessNeedsWork;

  /// No description provided for @pillReadinessNotReady.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA SẴN SÀNG'**
  String get pillReadinessNotReady;

  /// No description provided for @pillFailed.
  ///
  /// In vi, this message translates to:
  /// **'FAILED'**
  String get pillFailed;

  /// No description provided for @statusCopyStarting.
  ///
  /// In vi, this message translates to:
  /// **'Chuẩn bị bắt đầu attempt mới.'**
  String get statusCopyStarting;

  /// No description provided for @statusCopyRecording.
  ///
  /// In vi, this message translates to:
  /// **'Tập trung vào sự rõ ràng và trả lời đúng ý chính.'**
  String get statusCopyRecording;

  /// No description provided for @statusCopyUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang đóng gói bản ghi để gửi lên pipeline.'**
  String get statusCopyUploading;

  /// No description provided for @statusCopyProcessing.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống đang transcript và tổng hợp feedback.'**
  String get statusCopyProcessing;

  /// No description provided for @statusCopyCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại ngay.'**
  String get statusCopyCompleted;

  /// No description provided for @statusCopyFailed.
  ///
  /// In vi, this message translates to:
  /// **'Attempt gặp lỗi. Bạn có thể thử lại với một lần ghi mới.'**
  String get statusCopyFailed;

  /// No description provided for @statusCopyReady.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng cho một lần nói mới.'**
  String get statusCopyReady;

  /// No description provided for @recordStatusReady.
  ///
  /// In vi, this message translates to:
  /// **'SẴN SÀNG'**
  String get recordStatusReady;

  /// No description provided for @recordStatusRecording.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG GHI'**
  String get recordStatusRecording;

  /// No description provided for @recordStatusUploading.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TẢI LÊN'**
  String get recordStatusUploading;

  /// No description provided for @recordStatusProcessing.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG XỬ LÝ'**
  String get recordStatusProcessing;

  /// No description provided for @recordStatusCompleted.
  ///
  /// In vi, this message translates to:
  /// **'HOÀN THÀNH'**
  String get recordStatusCompleted;

  /// No description provided for @recordStatusFailed.
  ///
  /// In vi, this message translates to:
  /// **'LỖI'**
  String get recordStatusFailed;

  /// No description provided for @recordCtaStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu luyện'**
  String get recordCtaStart;

  /// No description provided for @recordCtaStop.
  ///
  /// In vi, this message translates to:
  /// **'Dừng'**
  String get recordCtaStop;

  /// No description provided for @recordCtaAnalyze.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích'**
  String get recordCtaAnalyze;

  /// No description provided for @recordCtaRerecord.
  ///
  /// In vi, this message translates to:
  /// **'Ghi lại'**
  String get recordCtaRerecord;

  /// No description provided for @recordStatusStopped.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ DỪNG'**
  String get recordStatusStopped;

  /// No description provided for @recordHintTapToStart.
  ///
  /// In vi, this message translates to:
  /// **'NHẤN ĐỂ BẮT ĐẦU'**
  String get recordHintTapToStart;

  /// No description provided for @recordHintTapToStop.
  ///
  /// In vi, this message translates to:
  /// **'NHẤN ĐỂ DỪNG'**
  String get recordHintTapToStop;

  /// No description provided for @historyBadgeReady.
  ///
  /// In vi, this message translates to:
  /// **'SẴN SÀNG'**
  String get historyBadgeReady;

  /// No description provided for @historyBadgeAlmost.
  ///
  /// In vi, this message translates to:
  /// **'GẦN ĐẠT'**
  String get historyBadgeAlmost;

  /// No description provided for @historyBadgeNeedsWork.
  ///
  /// In vi, this message translates to:
  /// **'CẦN LUYỆN'**
  String get historyBadgeNeedsWork;

  /// No description provided for @historyBadgeNotReady.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA SẴN SÀNG'**
  String get historyBadgeNotReady;

  /// No description provided for @historyBadgeFailed.
  ///
  /// In vi, this message translates to:
  /// **'LỖI'**
  String get historyBadgeFailed;

  /// No description provided for @historyBadgeCreated.
  ///
  /// In vi, this message translates to:
  /// **'MỚI TẠO'**
  String get historyBadgeCreated;

  /// No description provided for @historyCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục luyện tập!'**
  String get historyCtaTitle;

  /// No description provided for @historyCtaSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ôn thêm một chủ đề nữa để tăng độ lưu loát tiếng Séc.'**
  String get historyCtaSubtitle;

  /// No description provided for @historyCtaButton.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu luyện'**
  String get historyCtaButton;

  /// No description provided for @recordHintStopped.
  ///
  /// In vi, this message translates to:
  /// **'Nghe lại bản ghi. Ấn \"Phân tích\" khi ưng ý.'**
  String get recordHintStopped;

  /// No description provided for @analysisScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang phân tích'**
  String get analysisScreenTitle;

  /// No description provided for @analysisUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải lên bản ghi...'**
  String get analysisUploading;

  /// No description provided for @analysisProcessing.
  ///
  /// In vi, this message translates to:
  /// **'AI đang lắng nghe và chấm bài...'**
  String get analysisProcessing;

  /// No description provided for @analysisFailedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích thất bại'**
  String get analysisFailedTitle;

  /// No description provided for @analysisRetryCta.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại ghi lại'**
  String get analysisRetryCta;

  /// No description provided for @recordHintReady.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn \"Bắt đầu luyện\" khi sẵn sàng.'**
  String get recordHintReady;

  /// No description provided for @recordHintRecording.
  ///
  /// In vi, this message translates to:
  /// **'Tập trung vào sự rõ ràng và trả lời đúng ý chính.'**
  String get recordHintRecording;

  /// No description provided for @recordHintUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang đóng gói bản ghi để gửi lên pipeline.'**
  String get recordHintUploading;

  /// No description provided for @recordHintProcessing.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống đang transcript và tổng hợp feedback.'**
  String get recordHintProcessing;

  /// No description provided for @recordHintCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại.'**
  String get recordHintCompleted;

  /// No description provided for @recordHintFailed.
  ///
  /// In vi, this message translates to:
  /// **'Attempt gặp lỗi. Thử lại với một lần ghi mới.'**
  String get recordHintFailed;

  /// No description provided for @playbackTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghe lại bản ghi'**
  String get playbackTitle;

  /// No description provided for @playbackErrorPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Playback gặp lỗi: {message}'**
  String playbackErrorPrefix(String message);

  /// No description provided for @playbackOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được bản ghi để nghe lại.'**
  String get playbackOpenError;

  /// No description provided for @attemptAudioTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghe lại audio đã nộp'**
  String get attemptAudioTitle;

  /// No description provided for @attemptAudioLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được audio.'**
  String get attemptAudioLoadError;

  /// No description provided for @attemptAudioOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được audio: {message}'**
  String attemptAudioOpenError(String message);

  /// No description provided for @reviewAudioTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghe audio mẫu để shadow'**
  String get reviewAudioTitle;

  /// No description provided for @reviewAudioLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được audio mẫu.'**
  String get reviewAudioLoadError;

  /// No description provided for @reviewAudioOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được audio mẫu: {message}'**
  String reviewAudioOpenError(String message);

  /// No description provided for @resultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả'**
  String get resultTitle;

  /// No description provided for @resultTranscriptTitle.
  ///
  /// In vi, this message translates to:
  /// **'Transcript của bạn'**
  String get resultTranscriptTitle;

  /// No description provided for @resultStrengthsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm mạnh'**
  String get resultStrengthsTitle;

  /// No description provided for @resultImprovementsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần cải thiện'**
  String get resultImprovementsTitle;

  /// No description provided for @resultRetryAdviceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lời khuyên cho lần sau'**
  String get resultRetryAdviceTitle;

  /// No description provided for @resultSampleAnswerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu trả lời mẫu'**
  String get resultSampleAnswerTitle;

  /// No description provided for @resultRetryCta.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại bài này'**
  String get resultRetryCta;

  /// No description provided for @resultNextExerciseCta.
  ///
  /// In vi, this message translates to:
  /// **'Sang bài tiếp theo'**
  String get resultNextExerciseCta;

  /// No description provided for @resultTabFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi'**
  String get resultTabFeedback;

  /// No description provided for @resultTabTranscript.
  ///
  /// In vi, this message translates to:
  /// **'Bản ghi'**
  String get resultTabTranscript;

  /// No description provided for @resultTabSample.
  ///
  /// In vi, this message translates to:
  /// **'Bài mẫu'**
  String get resultTabSample;

  /// No description provided for @resultNoFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phản hồi.'**
  String get resultNoFeedback;

  /// No description provided for @resultNoTranscript.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bản ghi âm.'**
  String get resultNoTranscript;

  /// No description provided for @resultNoSample.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài mẫu.'**
  String get resultNoSample;

  /// No description provided for @reviewArtifactTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa & luyện theo mẫu'**
  String get reviewArtifactTitle;

  /// No description provided for @reviewArtifactSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản gốc, bản đã sửa, và bản mẫu để shadow theo.'**
  String get reviewArtifactSubtitle;

  /// No description provided for @reviewLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được review'**
  String get reviewLoadError;

  /// No description provided for @reviewNotApplicableTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản sửa chưa hỗ trợ cho dạng bài này'**
  String get reviewNotApplicableTitle;

  /// No description provided for @reviewNotApplicableBody.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng sửa & luyện theo mẫu sẽ sớm có cho Úloha 3 và Úloha 4.'**
  String get reviewNotApplicableBody;

  /// No description provided for @reviewFailedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Review artifact gặp lỗi'**
  String get reviewFailedTitle;

  /// No description provided for @reviewFailedBodyUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Backend chưa tạo được bản sửa.'**
  String get reviewFailedBodyUnknown;

  /// No description provided for @reviewFailedBodyCode.
  ///
  /// In vi, this message translates to:
  /// **'failure_code: {code}'**
  String reviewFailedBodyCode(String code);

  /// No description provided for @reviewPendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang tạo bản sửa và audio mẫu...'**
  String get reviewPendingTitle;

  /// No description provided for @reviewPendingBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn vẫn có thể đọc feedback phía trên trong lúc chờ.'**
  String get reviewPendingBody;

  /// No description provided for @reviewSourceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Transcript của bạn'**
  String get reviewSourceTitle;

  /// No description provided for @reviewCorrectedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nên nói'**
  String get reviewCorrectedTitle;

  /// No description provided for @reviewModelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản mẫu để shadow'**
  String get reviewModelTitle;

  /// No description provided for @reviewSourceFallback.
  ///
  /// In vi, this message translates to:
  /// **'Transcript chưa sẵn sàng.'**
  String get reviewSourceFallback;

  /// No description provided for @exerciseUloha1Label.
  ///
  /// In vi, this message translates to:
  /// **'ÚLOHA 1 · TRẢ LỜI CHỦ ĐỀ'**
  String get exerciseUloha1Label;

  /// No description provided for @exerciseUloha2Label.
  ///
  /// In vi, this message translates to:
  /// **'ÚLOHA 2 · HỘI THOẠI'**
  String get exerciseUloha2Label;

  /// No description provided for @exerciseUloha3Label.
  ///
  /// In vi, this message translates to:
  /// **'ÚLOHA 3 · KỂ CHUYỆN'**
  String get exerciseUloha3Label;

  /// No description provided for @exerciseUloha4Label.
  ///
  /// In vi, this message translates to:
  /// **'ÚLOHA 4 · CHỌN & GIẢI THÍCH'**
  String get exerciseUloha4Label;

  /// No description provided for @coachNoteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Coach note'**
  String get coachNoteTitle;

  /// No description provided for @coachNoteUloha1.
  ///
  /// In vi, this message translates to:
  /// **'Nói ngắn, rõ ý, dùng câu đơn giản trước. Ưu tiên trả lời đúng task hơn là cố nói phức tạp.'**
  String get coachNoteUloha1;

  /// No description provided for @coachNoteUloha2.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi đủ thông tin trong scenario. Dùng câu hỏi đơn giản, rõ ràng.'**
  String get coachNoteUloha2;

  /// No description provided for @coachNoteUloha3.
  ///
  /// In vi, this message translates to:
  /// **'Kể theo thứ tự: nejdřív, pak, nakonec. Không cần câu hoàn hảo — cần đủ mốc.'**
  String get coachNoteUloha3;

  /// No description provided for @coachNoteUloha4.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một phương án và giải thích lý do. Dùng \"protože\" hoặc \"protože mi líbí\".'**
  String get coachNoteUloha4;

  /// No description provided for @promptRequiredInfoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin bạn cần hỏi'**
  String get promptRequiredInfoTitle;

  /// No description provided for @promptHintPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý: {text}'**
  String promptHintPrefix(String text);

  /// No description provided for @promptCustomQuestion.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi bổ sung: {text}'**
  String promptCustomQuestion(String text);

  /// No description provided for @promptStoryImageLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hình {index}'**
  String promptStoryImageLabel(int index);

  /// No description provided for @promptStoryNoImages.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh — bài vẫn có thể luyện theo checkpoint văn bản.'**
  String get promptStoryNoImages;

  /// No description provided for @promptStoryImagesLoaded.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải {loaded}/{total} ảnh.'**
  String promptStoryImagesLoaded(int loaded, int total);

  /// No description provided for @promptStoryHintOrder.
  ///
  /// In vi, this message translates to:
  /// **'Kể câu chuyện theo thứ tự: nejdřív, pak, nakonec.'**
  String get promptStoryHintOrder;

  /// No description provided for @promptStoryHintByImages.
  ///
  /// In vi, this message translates to:
  /// **'Hãy kể câu chuyện theo {count} bức tranh.'**
  String promptStoryHintByImages(int count);

  /// No description provided for @promptStoryCheckpointsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các mốc cần nhắc đến'**
  String get promptStoryCheckpointsTitle;

  /// No description provided for @promptStoryGrammarFocus.
  ///
  /// In vi, this message translates to:
  /// **'Ngữ pháp nên ưu tiên: {list}'**
  String promptStoryGrammarFocus(String list);

  /// No description provided for @promptChoiceOptionsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các lựa chọn'**
  String get promptChoiceOptionsTitle;

  /// No description provided for @promptChoiceReasoningHint.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý lý do: {list}'**
  String promptChoiceReasoningHint(String list);

  /// No description provided for @bottomNavTests.
  ///
  /// In vi, this message translates to:
  /// **'Đề thi'**
  String get bottomNavTests;

  /// No description provided for @bottomNavProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get bottomNavProfile;

  /// No description provided for @profileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get profileTitle;

  /// No description provided for @profileLanguageSection.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get profileLanguageSection;

  /// No description provided for @profileAboutSection.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin'**
  String get profileAboutSection;

  /// No description provided for @profileAppName.
  ///
  /// In vi, this message translates to:
  /// **'A2 Mluvení Sprint'**
  String get profileAppName;

  /// No description provided for @profileAppTagline.
  ///
  /// In vi, this message translates to:
  /// **'Luyện thi nói A2 tiếng Czech cho người Việt'**
  String get profileAppTagline;

  /// No description provided for @profileVersion.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản {version}'**
  String profileVersion(String version);

  /// No description provided for @profileVoiceSection.
  ///
  /// In vi, this message translates to:
  /// **'Giọng đọc mẫu'**
  String get profileVoiceSection;

  /// No description provided for @profileVoicePreview.
  ///
  /// In vi, this message translates to:
  /// **'Nghe thử'**
  String get profileVoicePreview;

  /// No description provided for @profileVoiceFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get profileVoiceFemale;

  /// No description provided for @profileVoiceMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get profileVoiceMale;

  /// No description provided for @profileVoiceProviderPolly.
  ///
  /// In vi, this message translates to:
  /// **'AWS Polly'**
  String get profileVoiceProviderPolly;

  /// No description provided for @profileVoiceProviderElevenLabs.
  ///
  /// In vi, this message translates to:
  /// **'ElevenLabs'**
  String get profileVoiceProviderElevenLabs;

  /// No description provided for @profileVoicePreviewError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể phát thử giọng này'**
  String get profileVoicePreviewError;

  /// No description provided for @submitAnswersCta.
  ///
  /// In vi, this message translates to:
  /// **'Nộp đáp án'**
  String get submitAnswersCta;

  /// No description provided for @submitWritingCta.
  ///
  /// In vi, this message translates to:
  /// **'Nộp bài'**
  String get submitWritingCta;

  /// No description provided for @scoringInProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang chấm bài…'**
  String get scoringInProgress;

  /// No description provided for @scoringTimeout.
  ///
  /// In vi, this message translates to:
  /// **'Hết thời gian chờ kết quả. Vui lòng thử lại.'**
  String get scoringTimeout;

  /// No description provided for @resultScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả'**
  String get resultScreenTitle;

  /// No description provided for @retryCta.
  ///
  /// In vi, this message translates to:
  /// **'Làm lại'**
  String get retryCta;

  /// No description provided for @writingTopicsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Viết về các chủ đề sau:'**
  String get writingTopicsLabel;

  /// No description provided for @writingEmailHint.
  ///
  /// In vi, this message translates to:
  /// **'Ahoj Lído, …'**
  String get writingEmailHint;

  /// No description provided for @writingWordCountBadge.
  ///
  /// In vi, this message translates to:
  /// **'{count}/{min} từ'**
  String writingWordCountBadge(int count, int min);

  /// No description provided for @writingQuestionFallback.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi {no}'**
  String writingQuestionFallback(int no);

  /// No description provided for @audioLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải audio…'**
  String get audioLoading;

  /// No description provided for @audioError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được audio'**
  String get audioError;

  /// No description provided for @audioHint.
  ///
  /// In vi, this message translates to:
  /// **'Audio bài nghe — nghe 2 lần'**
  String get audioHint;

  /// No description provided for @objectiveBreakdownTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết từng câu'**
  String get objectiveBreakdownTitle;

  /// No description provided for @objectiveQuestionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Câu {no}:'**
  String objectiveQuestionLabel(int no);

  /// No description provided for @objectivePassBadge.
  ///
  /// In vi, this message translates to:
  /// **'ĐÚNG'**
  String get objectivePassBadge;

  /// No description provided for @objectiveFailBadge.
  ///
  /// In vi, this message translates to:
  /// **'SAI'**
  String get objectiveFailBadge;

  /// No description provided for @objectiveNoAnswer.
  ///
  /// In vi, this message translates to:
  /// **'(không trả lời)'**
  String get objectiveNoAnswer;

  /// No description provided for @objectiveYourAnswer.
  ///
  /// In vi, this message translates to:
  /// **'Bạn trả lời:'**
  String get objectiveYourAnswer;

  /// No description provided for @objectiveCorrectAnswer.
  ///
  /// In vi, this message translates to:
  /// **'Đáp án đúng:'**
  String get objectiveCorrectAnswer;

  /// No description provided for @viewPassage.
  ///
  /// In vi, this message translates to:
  /// **'Xem bài đọc'**
  String get viewPassage;

  /// No description provided for @hidePassage.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn bài đọc'**
  String get hidePassage;

  /// No description provided for @objectiveScoreDisplay.
  ///
  /// In vi, this message translates to:
  /// **'{score}/{max}'**
  String objectiveScoreDisplay(int score, int max);

  /// No description provided for @fullExamScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bài thi thử'**
  String get fullExamScreenTitle;

  /// No description provided for @fullExamDurationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian'**
  String get fullExamDurationLabel;

  /// No description provided for @fullExamMaxPtsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tổng điểm'**
  String get fullExamMaxPtsLabel;

  /// No description provided for @fullExamPassLabel.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đậu'**
  String get fullExamPassLabel;

  /// No description provided for @fullExamSectionsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các phần thi'**
  String get fullExamSectionsTitle;

  /// No description provided for @fullExamSubmitCta.
  ///
  /// In vi, this message translates to:
  /// **'Nộp bài písemná'**
  String get fullExamSubmitCta;

  /// No description provided for @fullExamSubmitHint.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành tất cả phần thi để nộp'**
  String get fullExamSubmitHint;

  /// No description provided for @fullExamResultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả bài thi'**
  String get fullExamResultTitle;

  /// No description provided for @fullExamPisemnaLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần viết (Písemná)'**
  String get fullExamPisemnaLabel;

  /// No description provided for @fullExamUstniLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần nói (Ústní)'**
  String get fullExamUstniLabel;

  /// No description provided for @fullExamPassedBadge.
  ///
  /// In vi, this message translates to:
  /// **'ĐẠT'**
  String get fullExamPassedBadge;

  /// No description provided for @fullExamFailedBadge.
  ///
  /// In vi, this message translates to:
  /// **'TRƯỢT'**
  String get fullExamFailedBadge;

  /// No description provided for @fullExamOverallPassed.
  ///
  /// In vi, this message translates to:
  /// **'ĐẠT'**
  String get fullExamOverallPassed;

  /// No description provided for @fullExamOverallFailed.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA ĐẠT'**
  String get fullExamOverallFailed;

  /// No description provided for @fullExamUstniPending.
  ///
  /// In vi, this message translates to:
  /// **'Phần nói (Ústní) chưa hoàn thành. Làm bài thi nói riêng để có kết quả tổng.'**
  String get fullExamUstniPending;

  /// No description provided for @fullExamGoHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get fullExamGoHome;

  /// No description provided for @fullExamPisemnaPassHint.
  ///
  /// In vi, this message translates to:
  /// **'Písemná đạt — cần hoàn thành phần nói để có kết quả tổng'**
  String get fullExamPisemnaPassHint;

  /// No description provided for @fullExamScoreNeed.
  ///
  /// In vi, this message translates to:
  /// **'cần ≥{pass}'**
  String fullExamScoreNeed(int pass);

  /// No description provided for @fullExamMinDuration.
  ///
  /// In vi, this message translates to:
  /// **'{min} phút'**
  String fullExamMinDuration(int min);

  /// No description provided for @fullExamPts.
  ///
  /// In vi, this message translates to:
  /// **'{pts} điểm'**
  String fullExamPts(int pts);

  /// No description provided for @fullExamPassSymbol.
  ///
  /// In vi, this message translates to:
  /// **'≥{pass}'**
  String fullExamPassSymbol(int pass);

  /// No description provided for @skillModulesLabel.
  ///
  /// In vi, this message translates to:
  /// **'KỸ NĂNG'**
  String get skillModulesLabel;

  /// No description provided for @skillModulesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phát triển kỹ năng'**
  String get skillModulesTitle;

  /// No description provided for @skillModulesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn kỹ năng bạn muốn luyện tập hôm nay.'**
  String get skillModulesSubtitle;

  /// No description provided for @exerciseListProgressLink.
  ///
  /// In vi, this message translates to:
  /// **'Tiến trình nói'**
  String get exerciseListProgressLink;

  /// No description provided for @exerciseListFlowBadge.
  ///
  /// In vi, this message translates to:
  /// **'LIÊN TỤC'**
  String get exerciseListFlowBadge;

  /// No description provided for @exerciseListSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tập trung vào sự trôi chảy và phát âm đúng trong các tình huống thực tế.'**
  String get exerciseListSubtitle;

  /// No description provided for @exerciseListDailySprintLabel.
  ///
  /// In vi, this message translates to:
  /// **'CHẾ ĐỘ ĐỀ XUẤT'**
  String get exerciseListDailySprintLabel;

  /// No description provided for @exerciseListDailySprintTitle.
  ///
  /// In vi, this message translates to:
  /// **'Luyện tập hàng ngày'**
  String get exerciseListDailySprintTitle;

  /// No description provided for @exerciseListDailySprintSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Luyện tất cả bài tập cùng lúc và nhận phản hồi ngay từ AI coach.'**
  String get exerciseListDailySprintSubtitle;

  /// No description provided for @exerciseListDailySprintCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tất cả'**
  String get exerciseListDailySprintCta;

  /// No description provided for @exerciseOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể mở bài tập. Vui lòng thử lại.'**
  String get exerciseOpenError;

  /// No description provided for @vocabKnown.
  ///
  /// In vi, this message translates to:
  /// **'Đã biết'**
  String get vocabKnown;

  /// No description provided for @vocabReview.
  ///
  /// In vi, this message translates to:
  /// **'Ôn lại'**
  String get vocabReview;

  /// No description provided for @vocabFlip.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn để xem đáp án'**
  String get vocabFlip;

  /// No description provided for @vocabDone.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhận!'**
  String get vocabDone;

  /// No description provided for @vocabMatchInstruction.
  ///
  /// In vi, this message translates to:
  /// **'Ghép từ với nghĩa tương ứng'**
  String get vocabMatchInstruction;

  /// No description provided for @vocabFillInstruction.
  ///
  /// In vi, this message translates to:
  /// **'Điền từ thích hợp vào chỗ trống'**
  String get vocabFillInstruction;

  /// No description provided for @vocabChoiceInstruction.
  ///
  /// In vi, this message translates to:
  /// **'Chọn từ đúng để hoàn thành câu'**
  String get vocabChoiceInstruction;

  /// No description provided for @vocabExplanation.
  ///
  /// In vi, this message translates to:
  /// **'Giải thích'**
  String get vocabExplanation;

  /// No description provided for @exerciseTypeFlashcard.
  ///
  /// In vi, this message translates to:
  /// **'Flashcard'**
  String get exerciseTypeFlashcard;

  /// No description provided for @exerciseTypeMatching.
  ///
  /// In vi, this message translates to:
  /// **'Ghép đôi'**
  String get exerciseTypeMatching;

  /// No description provided for @exerciseTypeFillBlank.
  ///
  /// In vi, this message translates to:
  /// **'Điền từ'**
  String get exerciseTypeFillBlank;

  /// No description provided for @exerciseTypeChoiceWord.
  ///
  /// In vi, this message translates to:
  /// **'Chọn từ'**
  String get exerciseTypeChoiceWord;

  /// No description provided for @typeGroupSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn loại bài tập để luyện'**
  String get typeGroupSubtitle;

  /// No description provided for @deckStartAll.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu học tất cả'**
  String get deckStartAll;

  /// No description provided for @deckOrStudyOne.
  ///
  /// In vi, this message translates to:
  /// **'Hoặc học từng bài'**
  String get deckOrStudyOne;

  /// No description provided for @deckSessionComplete.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành session!'**
  String get deckSessionComplete;

  /// No description provided for @deckKnownOf.
  ///
  /// In vi, this message translates to:
  /// **'{known} / {total} đã biết'**
  String deckKnownOf(int known, int total);

  /// No description provided for @deckRetryRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Ôn lại {count} từ còn lại'**
  String deckRetryRemaining(int count);

  /// No description provided for @deckDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong — về danh sách'**
  String get deckDone;

  /// No description provided for @deckCorrect.
  ///
  /// In vi, this message translates to:
  /// **'Đúng rồi!'**
  String get deckCorrect;

  /// No description provided for @deckWrong.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đúng'**
  String get deckWrong;

  /// No description provided for @deckNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp theo'**
  String get deckNext;

  /// No description provided for @deckConfirmExit.
  ///
  /// In vi, this message translates to:
  /// **'Thoát deck session?'**
  String get deckConfirmExit;

  /// No description provided for @deckConfirmExitBody.
  ///
  /// In vi, this message translates to:
  /// **'Tiến trình sẽ không được lưu.'**
  String get deckConfirmExitBody;

  /// No description provided for @deckKnownLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã biết'**
  String get deckKnownLabel;

  /// No description provided for @deckRetryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ôn lại'**
  String get deckRetryLabel;

  /// No description provided for @emptyExerciseList.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài tập'**
  String get emptyExerciseList;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get confirm;

  /// No description provided for @anoButton.
  ///
  /// In vi, this message translates to:
  /// **'ANO'**
  String get anoButton;

  /// No description provided for @neButton.
  ///
  /// In vi, this message translates to:
  /// **'NE'**
  String get neButton;

  /// No description provided for @anoNeInstruction.
  ///
  /// In vi, this message translates to:
  /// **'Đúng hay sai?'**
  String get anoNeInstruction;

  /// No description provided for @anoNeCorrectHint.
  ///
  /// In vi, this message translates to:
  /// **'Đúng ✓'**
  String get anoNeCorrectHint;

  /// No description provided for @anoNeWrongHint.
  ///
  /// In vi, this message translates to:
  /// **'Sai — đáp án: {answer}'**
  String anoNeWrongHint(String answer);

  /// No description provided for @interviewSkillLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phỏng vấn AI'**
  String get interviewSkillLabel;

  /// No description provided for @interviewSkillDesc.
  ///
  /// In vi, this message translates to:
  /// **'Hội thoại thực tế với examiner Czech AI'**
  String get interviewSkillDesc;

  /// No description provided for @interviewNewBadge.
  ///
  /// In vi, this message translates to:
  /// **'MỚI'**
  String get interviewNewBadge;

  /// No description provided for @interviewTopicLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chủ đề hội thoại'**
  String get interviewTopicLabel;

  /// No description provided for @interviewChoiceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phương án'**
  String get interviewChoiceLabel;

  /// No description provided for @interviewChoiceInstruction.
  ///
  /// In vi, this message translates to:
  /// **'Chọn 1 và giải thích lý do'**
  String get interviewChoiceInstruction;

  /// No description provided for @interviewTipsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Examiner sẽ hỏi về'**
  String get interviewTipsTitle;

  /// No description provided for @interviewTipsHint.
  ///
  /// In vi, this message translates to:
  /// **'Mẹo luyện tập'**
  String get interviewTipsHint;

  /// No description provided for @interviewStartBtn.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu phỏng vấn'**
  String get interviewStartBtn;

  /// No description provided for @interviewStartWithChoice.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu với lựa chọn này'**
  String get interviewStartWithChoice;

  /// No description provided for @interviewSelectedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn:'**
  String get interviewSelectedLabel;

  /// No description provided for @interviewStatusConnecting.
  ///
  /// In vi, this message translates to:
  /// **'Đang kết nối với examiner...'**
  String get interviewStatusConnecting;

  /// No description provided for @interviewStatusReady.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng'**
  String get interviewStatusReady;

  /// No description provided for @interviewStatusSpeaking.
  ///
  /// In vi, this message translates to:
  /// **'Examiner đang nói'**
  String get interviewStatusSpeaking;

  /// No description provided for @interviewStatusListening.
  ///
  /// In vi, this message translates to:
  /// **'Đang lắng nghe bạn...'**
  String get interviewStatusListening;

  /// No description provided for @interviewEndBtn.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get interviewEndBtn;

  /// No description provided for @interviewEndConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có muốn kết thúc phỏng vấn không?'**
  String get interviewEndConfirm;

  /// No description provided for @interviewAnalyzing.
  ///
  /// In vi, this message translates to:
  /// **'Đang chấm điểm...'**
  String get interviewAnalyzing;

  /// No description provided for @interviewResultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả phỏng vấn'**
  String get interviewResultTitle;

  /// No description provided for @interviewTabFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét'**
  String get interviewTabFeedback;

  /// No description provided for @interviewTabTranscript.
  ///
  /// In vi, this message translates to:
  /// **'Hội thoại'**
  String get interviewTabTranscript;

  /// No description provided for @interviewExaminer.
  ///
  /// In vi, this message translates to:
  /// **'Examiner'**
  String get interviewExaminer;

  /// No description provided for @interviewYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get interviewYou;

  /// No description provided for @interviewConnectError.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được, thử lại'**
  String get interviewConnectError;

  /// No description provided for @interviewMicDenied.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền microphone'**
  String get interviewMicDenied;

  /// No description provided for @interviewPromptLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đề bài'**
  String get interviewPromptLabel;

  /// No description provided for @interviewTapToView.
  ///
  /// In vi, this message translates to:
  /// **'Tap để xem đề bài'**
  String get interviewTapToView;

  /// No description provided for @interviewVocabHints.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý từ'**
  String get interviewVocabHints;

  /// No description provided for @interviewPttIdleHint.
  ///
  /// In vi, this message translates to:
  /// **'Tap để bắt đầu nói'**
  String get interviewPttIdleHint;

  /// No description provided for @interviewPttSendHint.
  ///
  /// In vi, this message translates to:
  /// **'Đang ghi · Tap để gửi'**
  String get interviewPttSendHint;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'vi': return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
