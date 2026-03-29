import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/customAppbar.dart';
import 'package:flutter/material.dart';

class CustomCommonPage extends StatelessWidget {
  final Widget child;
  final bool showbackButton;
  final bool resizeToAvoidBottomInset;
  const CustomCommonPage(
      {super.key,
      required this.child,
      this.showbackButton = true,
      this.resizeToAvoidBottomInset = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F1FF),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomAppbar(
              showBackButton: showbackButton,
            ),
            Expanded(child: child),
            const SizedBox(
              height: 30,
              width: double.infinity,
              child: ColoredBox(
                color: CustomTheme.appThemeColorSecondary,
                child: Center(
                  child: Text(
                    CustomTheme.footerText,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
