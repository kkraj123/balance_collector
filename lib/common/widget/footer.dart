import 'package:collector_app/common/app/theme.dart';
import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 30,
      width: 500,
      child: ColoredBox(
        color: CustomTheme.appThemeColorSecondary,
        child: SizedBox(
          height: BorderSide.strokeAlignCenter,
          width: BorderSide.strokeAlignCenter,
          child: Center(
            child: Text(
              CustomTheme.footerText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
