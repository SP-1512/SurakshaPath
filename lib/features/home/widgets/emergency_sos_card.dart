import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';

/// Tactile, accidental-press-resistant 3-second hold Emergency SOS card.
/// Clear, grounded explanation of actions (view coordinates, dial 112).
class EmergencySosCard extends StatefulWidget {
  final VoidCallback onTriggerSos;

  const EmergencySosCard({
    super.key,
    required this.onTriggerSos,
  });

  @override
  State<EmergencySosCard> createState() => _EmergencySosCardState();
}

class _EmergencySosCardState extends State<EmergencySosCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;
  String _hintText = 'PRESS & HOLD (3 SECONDS)';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onHoldCompleted();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() {
      _isHolding = true;
      _hintText = 'HOLDING FOR EMERGENCY SOS...';
    });
    _controller.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
      setState(() {
        _isHolding = false;
        _hintText = 'RELEASED TOO EARLY - HOLD 3s';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isHolding) {
          setState(() {
            _hintText = 'PRESS & HOLD (3 SECONDS)';
          });
        }
      });
    }
  }

  void _onHoldCompleted() {
    setState(() {
      _isHolding = false;
      _hintText = 'EMERGENCY SOS TRIGGERED!';
    });
    widget.onTriggerSos();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.emergencyRed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33DC2626),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Tactile 3-Second Hold Ring
              GestureDetector(
                onTapDown: (_) => _onHoldStart(),
                onTapUp: (_) => _onHoldEnd(),
                onTapCancel: () => _onHoldEnd(),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Press and hold the red SOS button for 3 seconds.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.emergencyRedDark,
                    ),
                  );
                },
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = _controller.value;
                    final secondsLeft = (3.0 * (1.0 - progress)).ceil();

                    return SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress track
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: progress > 0 ? progress : 0.06,
                              strokeWidth: 4.0,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          // Core button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _isHolding ? 54 : 58,
                            height: _isHolding ? 54 : 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isHolding
                                  ? Text(
                                      '${secondsLeft}s',
                                      style: const TextStyle(
                                        color: AppColors.emergencyRed,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : const FlaticonView(
                                      assetPath: AppIcons.sos,
                                      size: 30,
                                      color: AppColors.emergencyRed,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.space14),

              // 2. Clear emergency metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.emergencySosTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.emergencySosSubtitle,
                      style: const TextStyle(
                        color: Color(0xFFFFE4E6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                      child: Text(
                        _hintText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Arrow trigger
              IconButton(
                onPressed: widget.onTriggerSos,
                tooltip: 'Emergency SOS Options',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
