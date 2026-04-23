import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.peerAvatarUrl,
    this.peerName,
  });

  final ChatMessage message;
  final bool isMine;
  final String? peerAvatarUrl;
  final String? peerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 56 : AppSpacing.x4,
        right: isMine ? AppSpacing.x4 : 56,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _PeerAvatar(avatarUrl: peerAvatarUrl, name: peerName),
            const SizedBox(width: AppSpacing.x2),
          ],
          _BubbleContent(message: message, isMine: isMine),
          if (isMine) const SizedBox(width: AppSpacing.x2),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({this.avatarUrl, this.name});
  final String? avatarUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: AppColors.primaryFixed,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryFixed,
      child: Text(
        (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimaryFixed,
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bgColor = isMine ? AppColors.primary : AppColors.surfaceContainerLow;
    final textColor = isMine ? AppColors.onPrimary : AppColors.onSurface;

    return switch (message.messageType) {
      MessageType.image => _ImageBubble(
          url: message.attachmentUrl ?? '',
          isMine: isMine,
          bgColor: bgColor,
        ),
      MessageType.file => _FileBubble(
          message: message,
          isMine: isMine,
          bgColor: bgColor,
          textColor: textColor,
        ),
      MessageType.text => _TextBubble(
          body: message.body ?? '',
          isMine: isMine,
          bgColor: bgColor,
          textColor: textColor,
        ),
    };
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.body,
    required this.isMine,
    required this.bgColor,
    required this.textColor,
  });
  final String body;
  final bool isMine;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2 + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Text(
        body,
        style: AppTypography.bodyMedium.copyWith(color: textColor),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({
    required this.url,
    required this.isMine,
    required this.bgColor,
  });
  final String url;
  final bool isMine;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        child: Image.network(
          url,
          width: 220,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 200,
            color: AppColors.surfaceContainerHigh,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImage(url: url),
    ));
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble({
    required this.message,
    required this.isMine,
    required this.bgColor,
    required this.textColor,
  });
  final ChatMessage message;
  final bool isMine;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final name = message.attachmentName ?? 'Tệp đính kèm';
    final size = message.attachmentSize;
    final sizeLabel = size != null ? _formatSize(size) : null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: textColor.withOpacity(0.8),
            size: 28,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.labelMedium.copyWith(color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeLabel != null)
                  Text(
                    sizeLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
          if (message.attachmentUrl != null) ...[
            const SizedBox(width: AppSpacing.x2),
            IconButton(
              onPressed: () => _download(message.attachmentUrl!),
              icon: Icon(Icons.download_outlined, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
