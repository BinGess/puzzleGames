---
name: flutter-poster-share
description: Reusable Flutter workflow for generating a poster from a widget, exporting PNG bytes, saving the image to local gallery, and invoking the system share sheet with image/text fallback. Use when implementing result sharing, achievement posters, invite cards, or any feature requiring on-device image generation plus save-and-share behavior on Android/iOS.
---

# Flutter Poster Share

## Overview
Implement a robust share flow in Flutter: render poster preview, capture high-resolution PNG from `RepaintBoundary`, save to gallery, and share via native system sheet. Follow this workflow when building score/result sharing features.

## Prerequisites
- Add dependencies:
  - `share_plus`
  - `path_provider`
  - `image_gallery_saver`
- Configure platform permissions:
  - iOS `Info.plist`: `NSPhotoLibraryAddUsageDescription`, `NSPhotoLibraryUsageDescription`
  - Android `AndroidManifest.xml`: media/storage permissions for your target SDK matrix
- Keep the poster widget visible at capture time. Do not capture an `Offstage` widget.

## Implementation Workflow
1. Open a share preview container (`showModalBottomSheet` is a good default).
2. Wrap the poster widget with `RepaintBoundary` and bind a `GlobalKey`.
3. Capture bytes using `RenderRepaintBoundary.toImage(pixelRatio: 3.0)`.
4. Save image by passing captured bytes into `ImageGallerySaver.saveImage(...)`.
5. Share image by writing PNG bytes into a temp file and calling `Share.shareXFiles(...)`.
6. Fallback to text-only share with `Share.share(...)` if image capture/share fails.
7. Guard concurrent actions with state flags (for example `_isSaving`, `_isSharing`).
8. Surface success/failure via localized toast or `SnackBar`.

## Core Helper Pattern
Use this structure as a baseline and adapt naming/UI content:

```dart
final GlobalKey _shareCardKey = GlobalKey();
bool _isSaving = false;
bool _isSharing = false;

Future<Uint8List?> capturePosterBytes() async {
  final boundary = _shareCardKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return null;

  await Future.delayed(const Duration(milliseconds: 120));
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

Future<File> writeTempPng(Uint8List bytes, String filePrefix) async {
  final tempDir = await getTemporaryDirectory();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final safePrefix = filePrefix.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
  final file = File('${tempDir.path}/${safePrefix}_$ts.png');
  await file.writeAsBytes(bytes);
  return file;
}

Future<void> handleSave(String filePrefix) async {
  if (_isSaving || _isSharing) return;
  _isSaving = true;
  try {
    final bytes = await capturePosterBytes();
    if (bytes == null) return;

    final ts = DateTime.now().millisecondsSinceEpoch;
    await ImageGallerySaver.saveImage(
      bytes,
      quality: 100,
      name: '${filePrefix}_$ts',
    );
  } finally {
    _isSaving = false;
  }
}

Future<void> handleShare({
  required String filePrefix,
  required String text,
  required String subject,
  Rect? shareOrigin,
}) async {
  if (_isSharing || _isSaving) return;
  _isSharing = true;
  try {
    final bytes = await capturePosterBytes();
    if (bytes != null) {
      final file = await writeTempPng(bytes, filePrefix);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
        sharePositionOrigin: shareOrigin,
      );
      return;
    }

    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: shareOrigin,
    );
  } finally {
    _isSharing = false;
  }
}
```

## Porting Checklist
- Keep poster ratio fixed (for example 9:16) and preview with `FittedBox`.
- Keep capture pixel ratio at `3.0` for social-quality output.
- Normalize filename with safe characters only.
- Add text-only fallback path in share flow.
- Add localized messages for save/share success and failure.
- Validate on both Android and iOS physical devices.

## References
- For a production example already used in this repo, read `references/puzzlegames-share-flow.md`.
