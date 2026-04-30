import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../models/models.dart';

/// Displays a context image for an exercise when the exercise has an asset
/// with asset_kind == 'context_image'. Returns SizedBox.shrink() when absent.
///
/// Used by all exercise screens to show optional visual context above question.
class ExerciseContextImage extends StatelessWidget {
  const ExerciseContextImage({
    super.key,
    required this.detail,
    required this.client,
  });

  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final asset = detail.assets
        .where((a) => a.assetKind == 'context_image' && a.isImage)
        .firstOrNull;
    if (asset == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            client.exerciseAssetUri(detail.id, asset.id).toString(),
            headers: client.authHeaders,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(color: const Color(0xFFF5F0EA)),
          ),
        ),
      ),
    );
  }
}
