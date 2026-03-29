import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/bloc/data_state.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/feature/auth/cubit/push_data_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PushDataScreen extends StatefulWidget {
  const PushDataScreen({super.key});

  @override
  State<PushDataScreen> createState() => _PushDataScreenState();
}

class _PushDataScreenState extends State<PushDataScreen> {
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return CustomCommonPage(
      child: BlocListener<PushDataCubit, CommonState>(
        listener: (context, state) async {
          if (!context.mounted) return;
          if (state is CommonLoading) {
            setState(() {
              _isLoading = true;
              _statusMessage = null;
            });
          }
          if (state is CommonError) {
            // print("Some error occured");
            setState(() {
              _statusMessage = "error while uploading";
            });
          }

          if (state is CommonDataFetchSuccess<dynamic>) {
            setState(() {
              _isLoading = false;
              _statusMessage = "Successfully uploaded! ${state.data[0]}";
            });
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                    color: CustomTheme.appThemeColorPrimary),
                const SizedBox(height: 16),
                const Text("Uploading...",
                    style: TextStyle(
                        color: CustomTheme.appThemeColorPrimary, fontSize: 16)),
              ] else if (_statusMessage != null) ...[
                Icon(
                  _statusMessage?.contains("Successfully uploaded!") ?? false
                      ? Icons.check_circle
                      : Icons.error,
                  color: _statusMessage?.contains("Successfully uploaded!") ??
                          false
                      ? CustomTheme.appThemeColorPrimary
                      : Colors.red,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildSyncButton(
                      description: "Push Data to the Server",
                      icon: Icons.upload_rounded,
                      isProcessing: _isLoading,
                      onPressed: () {
                        context.read<PushDataCubit>().pushData();
                      },
                      label: "Upload Data"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncButton({
    required IconData icon,
    required String label,
    required String description,
    required bool isProcessing,
    bool isWarning = false,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: isWarning
              ? Colors.orange.shade200
              : CustomTheme.appThemeColorSecondary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: isWarning
            ? Colors.orange.shade50
            : CustomTheme.appThemeColorSecondary.withOpacity(0.05),
      ),
      child: InkWell(
        onTap: isProcessing ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isWarning
                      ? Colors.orange.shade100
                      : CustomTheme.appThemeColorSecondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isProcessing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isWarning
                                  ? Colors.orange.shade700
                                  : CustomTheme.appThemeColorSecondary,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: isWarning
                              ? Colors.orange.shade700
                              : CustomTheme.appThemeColorSecondary,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProcessing ? "Processing..." : label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isWarning
                            ? Colors.orange.shade800
                            : CustomTheme.appThemeColorSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isWarning
                    ? Colors.orange.shade400
                    : CustomTheme.appThemeColorSecondary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
