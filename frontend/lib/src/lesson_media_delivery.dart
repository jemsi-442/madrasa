class LessonMediaDelivery {
  const LessonMediaDelivery({
    required this.uri,
    required this.kind,
    required this.title,
    required this.expiresAt,
    required this.downloadAllowed,
  });
  final Uri uri;
  final String kind, title;
  final DateTime expiresAt;
  final bool downloadAllowed;

  factory LessonMediaDelivery.parse(
    Map<String, dynamic> response, {
    required String apiBaseUrl,
    required String assetId,
    DateTime? now,
  }) {
    final delivery = response['delivery'];
    final asset = response['asset'];
    if (delivery is Map && delivery['status'] != 'READY') {
      throw const FormatException(
        'This resource is not connected yet. Please contact your teacher.',
      );
    }
    if (delivery is! Map ||
        asset is! Map ||
        ![
          'VIDEO',
          'AUDIO',
          'EMBED',
          'PDF',
          'IMAGE',
          'TEXT',
        ].contains(delivery['playerKind'])) {
      throw const FormatException(
        'This file cannot be displayed here yet. Ask your teacher for a video, audio, image, PDF or plain-text version.',
      );
    }
    final base = Uri.parse(apiBaseUrl);
    final value = delivery['inlineUrl'];
    final expiry = delivery['expiresAt'];
    if (value is! String || value.trim().isEmpty || expiry is! String) {
      throw const FormatException('The media link is incomplete.');
    }
    final uri = base.resolve(value);
    final expiresAt = DateTime.tryParse(expiry);
    // Only the server-authorized delivery route may supply an inline source.
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.origin != base.origin ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(assetId) ||
        uri.path != '/api/learner/assets/$assetId/deliver' ||
        uri.fragment.isNotEmpty ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['token']?.length != 1 ||
        (uri.queryParameters['token'] ?? '').trim().isEmpty) {
      throw const FormatException(
        'The media link is not a signed school resource.',
      );
    }
    if (expiresAt == null || !expiresAt.isAfter(now ?? DateTime.now())) {
      throw const FormatException(
        'This media link expired. Reload the player to get a fresh link.',
      );
    }
    return LessonMediaDelivery(
      uri: uri,
      kind: delivery['playerKind'] as String,
      title: asset['title'] is String
          ? asset['title'] as String
          : 'Lesson media',
      expiresAt: expiresAt,
      downloadAllowed: asset['downloadAllowed'] == true,
    );
  }
}

bool lessonEmbedNavigationAllowed(
  String value,
  Uri signedSource, {
  required bool isMainFrame,
}) {
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  if (value == 'about:blank' || uri == signedSource) return true;
  if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.port != 443) {
    return false;
  }
  if (!isMainFrame) return true;
  return (uri.host == 'www.youtube-nocookie.com' &&
          RegExp(r'^/embed/[A-Za-z0-9_-]{11}$').hasMatch(uri.path)) ||
      (uri.host == 'player.vimeo.com' &&
          RegExp(r'^/video/[0-9]+$').hasMatch(uri.path));
}
