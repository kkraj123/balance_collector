import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/bloc/data_state.dart';
import 'package:collector_app/common/shared_pref.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/feature/auth/cubit/pull_data_cubit.dart';
import 'package:collector_app/feature/auth/models/customer_account_model.dart';
import 'package:collector_app/feature/auth/ui/screens/login_screen.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PullData extends StatefulWidget {
  const PullData({super.key});

  @override
  State<PullData> createState() => _PullDataState();
}

class _PullDataState extends State<PullData> {
  bool isFetching = false;
  bool isSyncing = false;
  bool isNewOnly = false;
  bool isConfirmValid = false;
  bool isFetchNew = false;
  bool isFetchAll = false;
  final TextEditingController _confirmController = TextEditingController();

  String? _currentUrl;
  String? _currentUsername;
  String? _currentClientAlias;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final url = await SharedPref.getUrl();
    final username = await SharedPref.getUsername();
    final clientAlias = await SharedPref.getAlias();
    setState(() {
      _currentUrl = url;
      _currentUsername = username;
      _currentClientAlias = clientAlias;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<CustomerAccountModel> customers = [];

    return CustomCommonPage(
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: (isSyncing || isFetching)
                  ? _buildWarningCard()
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _buildMainContent(customers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color:
                          CustomTheme.appThemeColorSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: CustomTheme.appThemeColorSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Id",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        _currentUsername ?? "Not available",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  SharedPref.setRememberMe(false);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_outlined,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.link, "URL", _currentUrl ?? "Not available"),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.business, "Client Alias",
              _currentClientAlias ?? "Not available"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: CustomTheme.appThemeColorPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: CustomTheme.appThemeColorPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber.shade800,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Please do not close this page until the data sync is complete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF664D03),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<CustomerAccountModel> customers) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // const SizedBox(height: 24),
          if (isSyncing || isFetching) _buildSyncTimeline(customers),
          const SizedBox(height: 10),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSyncTimeline(List<CustomerAccountModel> customers) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sync Progress",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 24),
          if (isFetching)
            _buildTimelineItem(
              title: 'Fetching Data from Server',
              subtitle: 'Retrieving customer account information',
              isLoading: isFetching,
              isCompleted: customers.isNotEmpty && !isFetching,
              step: 1,
            ),
          if (isSyncing)
            _buildTimelineItem(
              title: 'Syncing to Local Database',
              subtitle: 'Updating customer records',
              isLoading: isSyncing,
              isCompleted: customers.isNotEmpty && !isSyncing && !isFetching,
              step: 2,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return BlocConsumer<PullDataCubit, CommonState>(
      listener: (context, state) async {
        if (!context.mounted) return;

        if (state is CommonError) {
          setState(() {
            isFetching = false;
            isSyncing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else if (state is CommonDataFetchSuccess<CustomerAccountModel>) {
          setState(() {
            isFetching = false;
            isSyncing = true;
          });

          List<CustomerAccountModel> customers = state.data;
          final db = CBDB();
          final rows = customers.map((c) => c.toJson()).toList();
          if(isNewOnly){
            await db.bulkInsertIfNotExists(rows);
          }else{
            await db.deleteAllAccounts();
            await db.bulkUpsertAccounts(rows);
          }

          // List<CustomerAccountModel> customers = state.data;
          // final db = CBDB();
          // if (isNewOnly) {
          //   for (var customer in customers) {
          //     await db.insertIfNotExists(customer.toJson());
          //   }
          // } else {
          //   await db.deleteAllAccounts();
          //   for (var customer in customers) {
          //     await db.upsertCustomerAccount(customer.toJson());
          //   }
          // }

          if (context.mounted) {
            setState(() {
              isSyncing = false;
              isNewOnly = false;
              isFetchAll = false;
              isFetchNew = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade100),
                    const SizedBox(width: 10),
                    const Text('Data synced successfully'),
                  ],
                ),
                backgroundColor: CustomTheme.appThemeColorSecondary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      },
      builder: (context, state) {
        return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Data Sync Options",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Choose an option below to sync data with the server",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              if (!isFetchNew)
                _buildSyncButton(
                  icon: Icons.download_rounded,
                  label: "Fetch New Records Only",
                  description:
                      "Only download new customer records from the server",
                  isProcessing: isFetching || isSyncing,
                  onPressed: () {
                    setState(() {
                      isFetching = true;
                      isNewOnly = true;
                      isFetchAll = true;
                    });
                    context.read<PullDataCubit>().pullData();
                  },
                ),
              const SizedBox(height: 16),
              if (!isFetchAll)
                _buildSyncButton(
                  icon: Icons.sync_rounded,
                  label: "Fetch All Data",
                  description: "Replace all existing records with fresh data",
                  isProcessing: isFetching || isSyncing,
                  isWarning: true,
                  onPressed: _confirmationRequest,
                ),
            ],
          ),
        );
      },
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

  Future<void> _confirmationRequest() async {
    _confirmController.clear();
    isConfirmValid = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade700,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Warning: Data Replacement",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: CustomTheme.appThemeColorPrimary,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dangerous_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "This will replace all your previous records!",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Please type \"Confirm\" below to proceed:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  onChanged: (value) {
                    setState(() {
                      isConfirmValid = value.toLowerCase() == 'confirm';
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Type here...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: CustomTheme.appThemeColorPrimary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onPressed: () {
                        // setState(() {
                        //   isNewOnly = false;
                        //   isFetchAll = false;
                        //   isFetchNew = false;
                        // });
                        Navigator.pop(dialogContext, false);
                      },
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: CustomTheme.appThemeColorPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                      onPressed: (isFetching || isSyncing || !isConfirmValid)
                          ? null
                          : () {
                              Navigator.pop(dialogContext, true);
                            },
                      child: const Text(
                        "Proceed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    if (result == true) {
      if (mounted) {
        setState(() {
          isFetchNew = true;
          isFetching = true;
          isNewOnly = false;
        });
        context.read<PullDataCubit>().pullData();
      }
    }
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isLoading,
    required bool isCompleted,
    required int step,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? CustomTheme.appThemeColorSecondary
                : isLoading
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
            border: Border.all(
              color: isCompleted
                  ? CustomTheme.appThemeColorSecondary
                  : isLoading
                      ? Theme.of(context).primaryColor.withOpacity(0.5)
                      : Colors.grey.shade200,
              width: 2,
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isCompleted || isLoading
                      ? CustomTheme.appThemeColorSecondary
                      : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
