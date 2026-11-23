import 'package:flutter/material.dart';

/// Centralized registry for authentic Flaticon vector PNG assets.
/// Strict rule: Zero unicode emojis across the entire UI.
class AppIcons {
  AppIcons._();

  static const String baseDir = 'assets/icons/flaticon';

  static const String bed = '$baseDir/bed.png';
  static const String check = '$baseDir/check.png';
  static const String cyclone = '$baseDir/cyclone.png';
  static const String evacuate = '$baseDir/evacuate.png';
  static const String flood = '$baseDir/flood.png';
  static const String home = '$baseDir/home.png';
  static const String map = '$baseDir/map.png';
  static const String medical = '$baseDir/medical.png';
  static const String offline = '$baseDir/offline.png';
  static const String phone = '$baseDir/phone.png';
  static const String pin = '$baseDir/pin.png';
  static const String power = '$baseDir/power.png';
  static const String search = '$baseDir/search.png';
  static const String shelter = '$baseDir/shelter.png';
  static const String shield = '$baseDir/shield.png';
  static const String sos = '$baseDir/sos.png';
  static const String warning = '$baseDir/warning.png';
  static const String water = '$baseDir/water.png';
}

/// Reusable vector asset widget with downsampled image decoding for low-memory Android devices.
class FlaticonView extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;
  final BoxFit fit;
  final int? cacheSize;

  const FlaticonView({
    super.key,
    required this.assetPath,
    this.size = 24.0,
    this.color,
    this.fit = BoxFit.contain,
    this.cacheSize,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic decode dimension calculated from display size & device pixel ratio.
    // Clamped between 32px (minimum crisp resolution) and 256px (large icons)
    // to prevent full 512x512 uncompressed bitmap allocations in RAM.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.5;
    final int targetDim = cacheSize ?? (size * dpr).round().clamp(32, 256);

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      cacheWidth: targetDim,
      cacheHeight: targetDim,
      fit: fit,
      color: color,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.shield,
          size: size,
          color: color ?? Colors.blueGrey,
        );
      },
    );
  }
}
