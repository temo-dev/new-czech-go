/// Parses the V17 deep links the verify-email + password-reset emails
/// link to. The actual URL-scheme registration must happen in
/// `ios/Runner/Info.plist` during the V17 cutover (manual step in
/// the Phase E ops checklist).
///
/// This module is intentionally a pure function so it stays unit-
/// testable without spinning up a navigator.
library;

enum DeepLinkKind { unknown, verified, resetPassword }

class ParsedDeepLink {
  const ParsedDeepLink._({required this.kind, this.token});
  final DeepLinkKind kind;
  final String? token;

  static const ParsedDeepLink unknown = ParsedDeepLink._(kind: DeepLinkKind.unknown);
}

/// Parses an inbound deep link URI. Recognized shapes:
///
///   czechgo://verified
///   czechgo://reset?token=`raw`
///
/// Anything else (or a malformed URI) returns [ParsedDeepLink.unknown]
/// so callers can fall back to the default route without exceptions.
ParsedDeepLink parseDeepLink(Uri? uri) {
  if (uri == null) return ParsedDeepLink.unknown;
  if (uri.scheme != 'czechgo') return ParsedDeepLink.unknown;

  // Both `host` and `path` carry the action depending on whether the
  // URL was structured as scheme://action or scheme:action — be
  // forgiving and check both.
  final action = (uri.host.isNotEmpty ? uri.host : uri.path.replaceFirst('/', '')).trim();

  switch (action) {
    case 'verified':
      return const ParsedDeepLink._(kind: DeepLinkKind.verified);
    case 'reset':
      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return ParsedDeepLink.unknown;
      return ParsedDeepLink._(kind: DeepLinkKind.resetPassword, token: token);
    default:
      return ParsedDeepLink.unknown;
  }
}
