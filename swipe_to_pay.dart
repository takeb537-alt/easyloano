import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToPayWidget extends StatefulWidget {
  final double amount;
  final VoidCallback onPaymentComplete;

  const SwipeToPayWidget({
    super.key,
    required this.amount,
    required this.onPaymentComplete,
  });

  @override
  State<SwipeToPayWidget> createState() => _SwipeToPayWidgetState();
}

class _SwipeToPayWidgetState extends State<SwipeToPayWidget>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _completed = false;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  double _trackWidth = 0;

  static const double _thumbSize = 56;
  static const double _trackHeight = 64;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _snapAnimation = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOut))
      ..addListener(() {
        setState(() => _dragPosition = _snapAnimation.value);
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(
          0.0, _trackWidth - _thumbSize);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_completed) return;
    final threshold = (_trackWidth - _thumbSize) * 0.85;
    if (_dragPosition >= threshold) {
      // Complete!
      HapticFeedback.heavyImpact();
      setState(() {
        _dragPosition = _trackWidth - _thumbSize;
        _completed = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onPaymentComplete();
      });
    } else {
      // Snap back
      _snapAnimation = Tween<double>(begin: _dragPosition, end: 0).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
      _snapController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _trackWidth = constraints.maxWidth;
      final progress = _trackWidth > 0
          ? (_dragPosition / (_trackWidth - _thumbSize)).clamp(0.0, 1.0)
          : 0.0;

      return Container(
        height: _trackHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFFE3F2FD),
          border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Progress fill
            AnimatedContainer(
              duration: Duration.zero,
              width: _dragPosition + _thumbSize,
              height: _trackHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: _completed
                      ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
                      : [
                          const Color(0xFF1565C0).withOpacity(0.3),
                          const Color(0xFF1976D2).withOpacity(0.5),
                        ],
                ),
              ),
            ),

            // Arrow hints (fade as dragged)
            Center(
              child: Opacity(
                opacity: (1 - progress * 2).clamp(0.0, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 56),
                    _Arrow(), _Arrow(), _Arrow(),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe to Pay ₹${widget.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: const Color(0xFF1565C0).withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Draggable thumb
            GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedContainer(
                duration: Duration.zero,
                margin: EdgeInsets.only(left: _dragPosition),
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _completed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0),
                  boxShadow: [
                    BoxShadow(
                      color: (_completed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF1565C0))
                          .withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(
                  _completed ? Icons.check : Icons.arrow_forward,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Arrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Icon(
        Icons.chevron_right,
        color: const Color(0xFF1565C0).withOpacity(0.5),
        size: 18,
      );
}
