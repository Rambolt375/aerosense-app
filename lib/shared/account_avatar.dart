import 'package:flutter/material.dart';

/// Account avatar: the account photo, or the initial as a fallback.
///
/// On web (CanvasKit) a cross-origin photo cannot be read unless the host sends
/// CORS headers, so [WebHtmlElementStrategy.fallback] is used: Flutter fetches
/// the bytes first and only switches to an HTML `<img>` in a platform view when
/// that fetch fails. If neither route works, [Image.errorBuilder] renders the
/// initial, so a broken photo never shows a broken-image box or an exception.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.initial,
    this.photoUrl,
    this.size = 40,
  });

  /// Single grapheme cluster shown when there is no usable photo.
  final String initial;

  /// Remote avatar image, or null.
  final String? photoUrl;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = photoUrl;

    final placeholder = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
    );

    final initialFallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: Text(
        initial,
        maxLines: 1,
        style: TextStyle(
          height: 1,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );

    final image = url == null
        ? initialFallback
        : ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
              errorBuilder: (context, error, stackTrace) => initialFallback,
            ),
          );

    // Decorative: the surrounding control always carries the accessible name.
    return ExcludeSemantics(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
