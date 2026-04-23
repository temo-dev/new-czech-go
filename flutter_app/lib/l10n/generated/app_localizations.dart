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
