# puzzleGames Share Flow Reference

This file maps the live implementation in puzzleGames to the reusable workflow in `$flutter-poster-share`.

## 1) Dependencies and Platform Setup
- Dependencies:
  - `pubspec.yaml` lines 42-45 (`share_plus`, `path_provider`, `image_gallery_saver`)
- iOS permissions:
  - `ios/Runner/Info.plist` lines 29-32
- Android permissions:
  - `android/app/src/main/AndroidManifest.xml` lines 2-8

## 2) Entry Point
- Share button action opens preview sheet:
  - `lib/presentation/result/result_screen.dart` lines 626-630
- `showModalBottomSheet` wiring:
  - `lib/presentation/result/result_screen.dart` lines 448-469

## 3) Preview + Capture Foundation
- Stateful preview container and capture key:
  - `_SharePreviewSheet` / `_SharePreviewSheetState`
  - `lib/presentation/result/result_screen.dart` lines 1510-1538
- Visible `RepaintBoundary` around poster widget:
  - `lib/presentation/result/result_screen.dart` lines 1773-1785

## 4) Poster Byte Capture
- Capture logic:
  - `_capturePosterBytes()`
  - `lib/presentation/result/result_screen.dart` lines 1546-1555
- Important details:
  - Wait ~120ms before capture to avoid transient frame issues
  - `pixelRatio: 3.0` for high-resolution export
  - Export format `ui.ImageByteFormat.png`

## 5) Temporary File Writing
- `_writeTempPng(...)`:
  - `lib/presentation/result/result_screen.dart` lines 1557-1564
- Uses `getTemporaryDirectory()` and sanitized filename.

## 6) Save to Gallery
- `_handleSave()`:
  - `lib/presentation/result/result_screen.dart` lines 1566-1610
- Save call:
  - `ImageGallerySaver.saveImage(...)` lines 1585-1590
- Robust result normalization:
  - Supports `isSuccess/success` with bool/int variants (lines 1591-1597)

## 7) Share via System Sheet
- `_handleShare()`:
  - `lib/presentation/result/result_screen.dart` lines 1612-1679
- Primary path:
  - Capture -> temp file -> `Share.shareXFiles(...)` (lines 1639-1654)
- Fallback path:
  - `Share.share(...)` text-only (lines 1658-1662 and 1665-1669)
- iPad-safe anchor origin:
  - `_sharePositionOrigin()` lines 1540-1544, usage lines 1636 and 1653

## 8) UX and Concurrency Guards
- Mutual exclusion flags prevent duplicate taps:
  - `_isSaving`, `_isSharing` (line 1537-1538)
  - Guards in handlers (lines 1567 and 1613)
- Loading indicators in action buttons:
  - Save button state lines 1797-1829
  - Share button state lines 1834-1879
- Localized status messages:
  - `saveImageSuccess` / `saveImageFailed` keys in l10n files

## 9) Poster Layout Design Notes
- Poster component:
  - `_ShareCardWidget` starts at line 1893
- Fixed canvas size:
  - 300 x 533 (9:16) lines 1891-1922
- Content includes score hero, LQ tier, percentile, and challenge CTA for social sharing.

## 10) Reuse Guidance
When migrating to another page/app:
1. Keep the capture chain unchanged: `RepaintBoundary -> PNG bytes -> (save/share)`.
2. Replace poster content widget only (business-specific UI).
3. Keep fallback and guard logic intact.
4. Re-check iOS/Android permissions for target SDK/version.
