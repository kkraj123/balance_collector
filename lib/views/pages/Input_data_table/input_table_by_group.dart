import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/shared_pref.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:collector_app/feature/geoLocation/get_current_location.dart';
import 'package:collector_app/feature/pos_print/printer_util.dart';
import 'package:collector_app/views/pages/Input_data_table/individual_user_input_widget.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class GroupByGroupName extends StatefulWidget {
  final String groudName;
  const GroupByGroupName({super.key, required this.groudName});

  @override
  State<GroupByGroupName> createState() => _GroupByGroupNameState();
}

class _GroupByGroupNameState extends State<GroupByGroupName> {
  Map<String, List<Map<String, dynamic>>> _groupedAccounts = {};
  Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};
  bool _isLoading = true;
  final ScrollController _verticalController = ScrollController();

  List<List<TextEditingController>> allAmountControllers = [];
  List<List<TextEditingController>> allRemarksControllers = [];
  double? grandtotalAmount = 0;
  String coordinates = '';
  final CBDB _db = CBDB();

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    LocationService locationService = LocationService();
    final myCoordinates = await locationService.getCurrentCoordinates();
    setState(() {
      coordinates = myCoordinates;
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    for (var controllerList in allAmountControllers) {
      for (var controller in controllerList) {
        controller.dispose();
      }
    }

    for (var controllerList in allRemarksControllers) {
      for (var controller in controllerList) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAllAccounts();
      final grouped = _groupAccountsByName(accounts);

      setState(() {
        _groupedAccounts = grouped;
        _filteredAccounts = {};
        _isLoading = false;
      });
      _handleSearch();
      _initializeControllers();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  void _initializeControllers() {
    allAmountControllers = [];
    allRemarksControllers = [];

    _filteredAccounts.forEach((name, accounts) {
      List<TextEditingController> amountControllers = accounts
          .map((acc) =>
              TextEditingController(text: acc['col_amt']?.toString() ?? ''))
          .toList();

      List<TextEditingController> remarksControllers = accounts
          .map((acc) => TextEditingController(
              text: acc['input_remarks']?.toString() ??
                  acc['field_officer_name']?.toString() ??
                  ''))
          .toList();
      for (var controller in amountControllers) {
        controller.addListener(_updateGrandTotal);
      }
      allAmountControllers.add(amountControllers);
      allRemarksControllers.add(remarksControllers);
    });
    _updateGrandTotal();
  }

  void _handleSearch() {
    final query = widget.groudName.toLowerCase();
    final Map<String, List<Map<String, dynamic>>> filtered = {};
    _groupedAccounts.forEach((name, accounts) {
      final matchingAccounts = accounts.where((account) {
        final memberNumber = account['mf_grp_name'].toLowerCase();
        return memberNumber.contains(query);
      }).toList();
      if (matchingAccounts.isNotEmpty) {
        filtered[name] = matchingAccounts;
      }
    });
    setState(() => _filteredAccounts = filtered);
  }

  Future<void> _printMultipleReceipts() async {
    int userIndex = 0;

    for (var entry in _filteredAccounts.entries) {
      var accounts = entry.value;
      var amountControllers = allAmountControllers[userIndex];

      List<CollectionAccount> collectionAccounts = [];

      for (int i = 0; i < accounts.length; i++) {
        var account = accounts[i];
        double amount =
            double.tryParse(amountControllers[i].text ?? '0') ?? 0.0;

        collectionAccounts.add(CollectionAccount(
          accountType: account['account_type_name'] ?? 'N/A',
          accountNumber: account['ac_no'] ?? 'N/A',
          amount: amount,
          comment: account['col_remarks'] ?? '',
        ));
      }

      if (collectionAccounts.isEmpty) {
        print('No accounts available to print');
        continue;
      }

      try {
        bool printSuccess =
            await CollectionReceiptPrinter.printCollectionReceipt(
          userName: accounts.first['ac_name'],
          groupName: accounts.first['center_name'] ?? 'N/A',
          collectionDate: accounts.first['col_date_time'] is DateTime
              ? accounts.first['col_date_time']
              : DateTime.now(),
          collectionLocation: accounts.first['col_location'] ?? 'N/A',
          idNumber: accounts.first['id_no'] ?? 'N/A',
          accounts: collectionAccounts,
        );

        if (!printSuccess) {
          print('Failed to print receipt for ${accounts.first['ac_name']}');
        }
      } catch (e) {
        print('Error printing receipt: $e');
      }

      userIndex++;
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
      List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var account in accounts) {
      final name = account['id_no'] as String;
      if (account['is_inserted'] == 1) continue;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(account);
    }
    return grouped;
  }

  void _updateGrandTotal() {
    if (!mounted) return;
    double total = 0;
    for (var controllerList in allAmountControllers) {
      for (var controller in controllerList) {
        if (controller.text.isNotEmpty) {
          total += double.tryParse(controller.text) ?? 0;
        }
      }
    }
    grandtotalAmount = total;
  }

  Future<void> _updateAllAccounts() async {
    setState(() => _isLoading = true);

    try {
      int userIndex = 0;
      for (var name in _filteredAccounts.keys) {
        var accounts = _filteredAccounts[name]!;
        var amountControllers = allAmountControllers[userIndex];
        var remarksControllers = allRemarksControllers[userIndex];
        String recieptId = const Uuid().v4();
        final sessionUUID = await SharedPref.getSessionUUID();
        if (sessionUUID.isEmpty) {
          recieptId = const Uuid().v4();
          await SharedPref.setSessionUUID(recieptId);
        }
        for (int i = 0; i < accounts.length; i++) {
          final account = accounts[i];
          final amountText = amountControllers[i].text;
          final remarksText = remarksControllers[i].text;
          double? amount;
          if (amountText.isNotEmpty) {
            amount = double.tryParse(amountText);
            if (amount == null) {
              continue;
            }
          }

          await _db.updateInputValuesForNewEntry(account['id'].toString(),
              amount ?? 0.0, remarksText, coordinates, recieptId, sessionUUID);
        }

        userIndex++;
      }

      if (mounted) {
        showDialog(
            barrierDismissible: false,
            useSafeArea: true,
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text(
                    "Would you like to print the receipt?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  content: SizedBox(
                      width: double.maxFinite,
                      height: 400,
                      child: Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Image.asset(
                              CustomTheme.mainLogo,
                              height: 80,
                            ),
                          ),
                          const Spacer(),
                          Text("$widget.groudName"),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            "Added Total Amount: $grandtotalAmount ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            "Amount Added Sucessfully",
                            style: TextStyle(fontSize: 17),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Icon(
                            Icons.done,
                            color: CustomTheme.appThemeColorPrimary,
                            size: 35,
                          ),
                        ],
                      ))),
                  actions: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () async {
                              await _printMultipleReceipts();
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: Container(
                                height: 45,
                                width: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: CustomTheme.appThemeColorPrimary,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.print_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Text(
                                      "Print",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ))),
                        TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: Container(
                                height: 45,
                                width: 80,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: CustomTheme.appThemeColorPrimary,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.white),
                                )))
                      ],
                    )
                  ],
                ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating accounts: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmationRequest() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Would you like to save this change?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Amount: $grandtotalAmount",
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(widget.groudName, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                _updateAllAccounts();
              },
              child: const Text("Confirm",
                  style: TextStyle(color: CustomTheme.appThemeColorPrimary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomCommonPage(
      child: _isLoading
          ? SizedBox(
              height: size.height,
              width: size.width,
              child: const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Input Amount:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Rs.$grandtotalAmount",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CustomTheme.appThemeColorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //       vertical: 8.0, horizontal: 16.0),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       _buildLegendIndicator(
                //           CustomTheme.appThemeColorSecondary, "Updated Amount"),
                //       const SizedBox(width: 16),
                //       _buildLegendIndicator(Colors.black, "Suggested Amount"),
                //     ],
                //   ),
                // ),
                Expanded(
                  child: ListView.builder(
                    controller: _verticalController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final name = _filteredAccounts.keys.elementAt(index);
                      final accounts = _filteredAccounts[name]!;

                      return IndividualUserInput(
                        account: accounts,
                        goback: false,
                        passedAmountcontrollers: allAmountControllers.isNotEmpty
                            ? allAmountControllers[index]
                            : [],
                        passedRemarkscontrollers:
                            allRemarksControllers.isNotEmpty
                                ? allRemarksControllers[index]
                                : [],
                        onAmountChanged: _updateGrandTotal,
                      );
                    },
                  ),
                ),
                ElevatedButton(
                    onPressed: _confirmationRequest,
                    child: const Text(
                      "Update All",
                      style: TextStyle(color: CustomTheme.appThemeColorPrimary),
                    )),
                const SizedBox(
                  height: 7,
                ),
              ],
            ),
    );
  }

  Widget _buildLegendIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
