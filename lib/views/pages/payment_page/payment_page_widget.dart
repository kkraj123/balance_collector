import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:flutter/material.dart';

class PaymentPageWidget extends StatefulWidget {
  const PaymentPageWidget({super.key});

  @override
  State<PaymentPageWidget> createState() => _PaymentPageWidgetState();
}

class _PaymentPageWidgetState extends State<PaymentPageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotationAnimation =
        Tween<double>(begin: -0.05, end: 0.05).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomCommonPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Image.asset(
                    CustomTheme.mainLogo,
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Feature in Development",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CustomTheme.appThemeColorPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "We're working on something amazing!\nStay tuned.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
