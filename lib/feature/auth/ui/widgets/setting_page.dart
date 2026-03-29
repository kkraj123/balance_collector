import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/custom_text_field.dart';
import 'package:collector_app/feature/auth/ui/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MySettingScreen extends StatelessWidget {
  const MySettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          color: CustomTheme.appThemeColorSecondary,
          child: Column(
            children: [
              AppBar(
                backgroundColor: CustomTheme.appThemeColorSecondary,
                foregroundColor: Colors.white,
              ),
              Expanded(
                child: Center(
                  child: Image.asset(
                    CustomTheme.mainLogoWhite,
                    height: 180,
                    width: 180,
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 0.1),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1FF),
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 35.0, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: CustomTextField(
                          hintText: "Server Url",
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: CustomTextField(
                          hintText: "CLient ID",
                        ),
                      ),
                      // const SizedBox(height: 15),
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: CustomTextField(
                      //     hintText: "User Name",
                      //   ),
                      // ),
                      // const SizedBox(height: 15),
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: CustomTextField(
                      //     hintText: "Password",
                      //   ),
                      // ),
                      const SizedBox(height: 15),
                      const SizedBox(height: 15),
                      Center(
                        child: SizedBox(
                          width: 145,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CustomTheme.appThemeColorPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ));
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    CustomTheme.footerText,
                    style: TextStyle(color: Colors.white),
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
