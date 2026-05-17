import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';

String objectiveSubmitErrorMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException) {
    if (error.errorCode == 'content_invalid') {
      return l10n.submitAnswersContentInvalid;
    }
    if (error.statusCode >= 500) {
      return l10n.submitAnswersScoringUnavailable;
    }
    if (error.message.isNotEmpty) {
      return error.message;
    }
  }
  return error.toString();
}
