/// Legal URLs surfaced from the paywall + auth screens.
///
/// Production hosting is owned by the operator (App Store Connect
/// metadata + the marketing site). The const placeholders below
/// resolve to the canonical home of each document; when ops swaps
/// the host, edit this file rather than chasing string literals
/// across screens.
class LegalUrls {
  LegalUrls._();

  /// End-User License Agreement. Apple App Store guideline 3.1.2(a)
  /// requires this link be reachable from any auto-renewable
  /// subscription paywall.
  static const String eula = 'https://czechgo.hadoo.eu/legal/eula';

  /// Privacy Policy. Apple metadata REQUIRED before submission;
  /// also referenced from the paywall and signup screens.
  static const String privacy = 'https://czechgo.hadoo.eu/legal/privacy';
}
