import 'package:collector_app/app/ExcelExportService.dart';
import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/models/users.dart';
import 'package:collector_app/common/shared_pref.dart';
import 'package:collector_app/common/widget/customtabletextstyle.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:collector_app/feature/geoLocation/get_current_location.dart';
import 'package:collector_app/feature/pos_print/printer_util.dart';
import 'package:collector_app/senraise_printer/helper.dart';
import 'package:collector_app/senraise_printer/printer_etector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class IndividualUserInput extends StatefulWidget {
  final List<Map<String, dynamic>> account;
  final bool goback;
  final List<TextEditingController> passedAmountcontrollers;
  final List<TextEditingController> passedRemarkscontrollers;
  final VoidCallback? onAmountChanged;

  const IndividualUserInput({
    super.key,
    required this.account,
    this.goback = true,
    this.passedAmountcontrollers = const [],
    this.passedRemarkscontrollers = const [],
    this.onAmountChanged,
  });
  @override
  State<IndividualUserInput> createState() => _IndividualUserInputState();
}

class _IndividualUserInputState extends State<IndividualUserInput> {
  final ScrollController _horizontalController = ScrollController();
  late List<TextEditingController> amountControllers;
  late List<TextEditingController> remarksControllers;
  final dbService = CBDB();
  bool isSaving = false;
  late List<bool> isFromInputAmount;
  double totalBalance = 0;
  double totalInstAmount = 0;
  double totalDueAmount = 0;
  double totalInputAmount = 0;
  String coordinates = '';
  late User? userDetails;
  String clientAlia = '';

  @override
  void dispose() {
    _horizontalController.dispose();

    if (widget.passedAmountcontrollers.isEmpty) {
      for (var controller in amountControllers) {
        controller.dispose();
      }
    }

    if (widget.passedRemarkscontrollers.isEmpty) {
      for (var controller in remarksControllers) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    laodUserDetails();
    isFromInputAmount =
        widget.account.map((acc) => acc['input_amount'] != null).toList();

    if (widget.passedAmountcontrollers.isNotEmpty) {
      amountControllers = widget.passedAmountcontrollers;
    } else {
      amountControllers = widget.account
          .map((acc) =>
              TextEditingController(text: acc['col_amt']?.toString() ?? ''))
          .toList();
    }
    _fetchLocation();
    if (widget.passedRemarkscontrollers.isNotEmpty) {
      remarksControllers = widget.passedRemarkscontrollers;
    } else {
      remarksControllers = widget.account
          .map((acc) => TextEditingController(
              text: acc['col_remarks']?.toString() ??
                  acc['field_officer_name']?.toString() ??
                  ''))
          .toList();
    }

    for (var controller in amountControllers) {
      controller.addListener(_updateTotalInputAmount);
    }
    for (var controller in amountControllers) {
      controller.addListener(_updateTotalInputAmount);
    }
    _updateTotalInputAmount();
  }

  laodUserDetails() async {
    userDetails = await SharedPref.getUser();
    clientAlia = await SharedPref.getAlias();
  }

  Future<void> _fetchLocation() async {
    LocationService locationService = LocationService();
    final Mycoordinates = await locationService.getCurrentCoordinates();
    if (!mounted) return;
    setState(() {
      coordinates = Mycoordinates;
    });
    // setState(() {
    //   coordinates = Mycoordinates;
    // });
  }

  double getTotalEnteredAmount() {
    return amountControllers.fold<double>(0, (sum, controller) {
      double value = double.tryParse(controller.text) ?? 0;
      return sum + value;
    });
  }

  Future<void> openGoogleMaps(String url) async {
    if (url.isEmpty) {
      return;
    }
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not launch $url',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: CustomTheme.appThemeColorPrimary,
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error launching URL: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: CustomTheme.appThemeColorPrimary,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      return;
    }
    final Uri uri = Uri.parse("tel:$phoneNumber");

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: CustomTheme.appThemeColorPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _updateTotalInputAmount() {
    setState(() {
      totalInputAmount = amountControllers.fold(0.0, (sum, controller) {
        double value = double.tryParse(controller.text) ?? 0.0;
        return sum + value;
      });
    });
    if (widget.onAmountChanged != null) {
      widget.onAmountChanged!();
    }
  }

  Future<void> _saveData() async {
    setState(() {
      isSaving = true;
    });
    final List<Map<String, dynamic>> savedRows = [];
    try {
      final String recieptId = const Uuid().v4();
      String sessionId = await SharedPref.getSessionUUID();
      if (sessionId.isEmpty) {
        sessionId = const Uuid().v4();
        await SharedPref.setSessionUUID(sessionId);
      }
      for (int i = 0; i < widget.account.length; i++) {
        final account = widget.account[i];
        final amountText = amountControllers[i].text;
        final remarksText = remarksControllers[i].text;
        double? amount;
        if (amountText.isNotEmpty) {
          amount = double.tryParse(amountText);
          if (amount == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text("Invalid amount for account ${account['ac_no']}")),
            );
            continue;
          }
        }
        await dbService.updateInputValuesForNewEntry(account['id'].toString(),
            amount ?? 0.0, remarksText, coordinates, recieptId, sessionId);

        // savedRows.add(saveRow);
      }
      _syncToDownloads();
      if (mounted) {
        showDialog(
            context: context,
            barrierDismissible: false,
            useSafeArea: true,
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
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          Text("${widget.account.first['ac_name']}"),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            "Added Total Amount: $totalInputAmount ",
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
                              final printerType =
                                  await PrinterDetector.detect();
                              if (printerType == PrinterType.none) {
                                print('No supported printer on this device');
                                return;
                              }

                              if (printerType == PrinterType.aidl) {
                                bool ready = false;
                                for (int i = 0; i < 6; i++) {
                                  ready = await PrinterService.isReady();
                                  if (ready) break;
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));
                                }
                                if (!ready) {
                                  print('Printer service not available');
                                  return;
                                }

                                final collectionAccounts =
                                    widget.account.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final account = entry.value;
                                  return CollectionAccount(
                                    accountType:
                                        account['account_type_name'] ?? 'N/A',
                                    accountNumber: account['ac_no'] ?? 'N/A',
                                    amount: double.tryParse(
                                            amountControllers[index].text) ??
                                        0.0, // ← fix
                                    comment: remarksControllers[index]
                                        .text, // ← also use controller
                                  );
                                }).toList();

                                if (collectionAccounts.isEmpty) {
                                  print('No accounts available to print');
                                  return;
                                }
                                final uniqueNames = widget.account
                                    .map((e) => e['ac_name']?.toString() ?? '')
                                    .toSet()
                                    .join(', ');

                                final success =
                                    await PrinterService.printReceipt(
                                        userData: userDetails,
                                        userName: uniqueNames,
                                        groupName: widget
                                                .account.first['center_name'] ??
                                            'N/A',
                                        collectionDate:
                                            widget.account
                                                        .first['col_date_time']
                                                    is DateTime
                                                ? widget.account
                                                    .first['col_date_time']
                                                : DateTime.now(),
                                        collectionLocation: widget.account
                                                .first['col_location'] ??
                                            'N/A',
                                        idNumber:
                                            widget.account.first['id_no'] ??
                                                'N/A',
                                        accounts: collectionAccounts,
                                        clientAlia: clientAlia);

                                if (!success) print('Failed to print receipt');
                              } else {
                                List<CollectionAccount> collectionAccounts =
                                    widget.account
                                        .asMap()
                                        .entries
                                        .map((account) {
                                  return CollectionAccount(
                                    accountType:
                                        account.value['account_type_name'] ??
                                            'N/A',
                                    accountNumber:
                                        account.value['ac_no'] ?? 'N/A',
                                    amount: double.tryParse(account
                                            .value['input_amount']
                                            .toString()) ??
                                        0.0,
                                    comment: account.value['col_remarks'] ?? '',
                                  );
                                }).toList();

                                if (collectionAccounts.isEmpty) {
                                  print('No accounts available to print');
                                  return;
                                }
                                final uniqueNames = widget.account
                                    .map((e) => e['ac_name']?.toString() ?? '')
                                    .toSet()
                                    .join(', ');

                                bool printSuccess =
                                    await CollectionReceiptPrinter
                                        .printCollectionReceipt(
                                  userData: userDetails,
                                  userName: uniqueNames,
                                  groupName:
                                      widget.account.first['center_name'] ??
                                          'N/A',
                                  collectionDate: widget.account
                                          .first['col_date_time'] is DateTime
                                      ? widget.account.first['col_date_time']
                                      : DateTime.now(),
                                  collectionLocation:
                                      widget.account.first['col_location'] ??
                                          'N/A',
                                  idNumber:
                                      widget.account.first['id_no'] ?? 'N/A',
                                  accounts: collectionAccounts,
                                );
                                if (!printSuccess) {
                                  print('Failed to print receipt');
                                }
                              }
                            },
                            // onPressed: () async {
                            //   List<CollectionAccount> collectionAccounts =
                            //       widget.account.asMap().entries.map((account) {
                            //     return CollectionAccount(
                            //       accountType:
                            //           account.value['account_type_name'] ??
                            //               'N/A',
                            //       accountNumber:
                            //           account.value['ac_no'] ?? 'N/A',
                            //       amount: double.tryParse(
                            //               amountControllers[account.key]
                            //                   .text) ??
                            //           0.0,
                            //       comment: account.value['col_remarks'] ?? '',
                            //     );
                            //   }).toList();

                            //   if (collectionAccounts.isEmpty) {
                            //     print('No accounts available to print');
                            //     return;
                            //   }

                            //   bool printSuccess = await CollectionReceiptPrinter
                            //       .printCollectionReceipt(

                            //     userName: widget.account.first['ac_name'],
                            //     groupName:
                            //         widget.account.first['center_name'] ??
                            //             'N/A',
                            //     collectionDate: widget.account
                            //             .first['col_date_time'] is DateTime
                            //         ? widget.account.first['col_date_time']
                            //         : DateTime.now(),
                            //     collectionLocation:
                            //         widget.account.first['col_location'] ??
                            //             'N/A',
                            //     idNumber:
                            //         widget.account.first['id_no'] ?? 'N/A',
                            //     accounts: collectionAccounts,
                            //   );
                            //   if (!printSuccess) {
                            //     print('Failed to print receipt');
                            //   }
                            //   Navigator.pop(context);
                            //   Navigator.pop(context);
                            // },
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
                            onPressed: () {
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
          SnackBar(content: Text("Error updating data: $e")),
        );
        print("Error updating data: $e");
      }
    } finally {
      setState(() {
        isSaving = false;
      });
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
              Text("Amount: $totalInputAmount",
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text("${widget.account.first['ac_name']}",
                  style: const TextStyle(fontSize: 16)),
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
                _saveData();
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
                color: Colors.white24,
                border: Border.symmetric(
                    horizontal: BorderSide(color: Colors.black12))),
            child: const Center(
                child: Text(
              'User Info',
              style: TextStyle(
                  color: CustomTheme.appThemeColorSecondary, fontSize: 15),
            )),
          ),
          _buildCustomerInfo(widget.account),
          _buildAccountsTable(widget.account),
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 14, right: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.goback)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        backgroundColor: Colors.white),
                    onPressed: () {
                      // _saveData();
                      _confirmationRequest();
                    },
                    child: const Text(
                      "Update",
                      style: TextStyle(color: CustomTheme.appThemeColorPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(List<Map<String, dynamic>> account) {
    final uniqueNames = account.map((e) => e['ac_name']).toSet().toList();
    final joinedNames = uniqueNames.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          joinedNames,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (account.first['p_address'] != '')
          Text(
            "Address: ${account.first['p_address'] ?? 'N/A'}",
          ),
        Text(
          "Group Name: ${account.first['center_name'] ?? 'N/A'}",
        ),
        (account.first['contact'] != '/' && account.first['contact'] != null)
            ? InkWell(
                onTap: () {
                  makePhoneCall(account.first['contact']);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Contact: ${account.first['contact'] ?? 'N/A'}",
                      ),
                    ),
                    const Icon(
                      Icons.call_outlined,
                      color: CustomTheme.appThemeColorPrimary,
                    ),
                  ],
                ),
              )
            : Container(),
        InkWell(
          onTap: () {
            openGoogleMaps(account.first['add_location']);
          },
          child: const Row(
            children: [
              Text(
                "Geo Address [Click here to redirect]",
                style: TextStyle(color: Colors.blueGrey),
              ),
              Icon(
                Icons.place_outlined,
                color: CustomTheme.appThemeColorPrimary,
              ),
            ],
          ),
        ),
        Text(
          "Id Number: ${account.first['id_no'] ?? 'N/A'}",
        ),
      ],
    );
  }

  Widget _buildAccountsTable(
    List<Map<String, dynamic>> accounts,
  ) {
    print('accountListLength ${accounts.length}');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                MaterialStateProperty.all(CustomTheme.tableColorHead),
            headingRowHeight: 50,
            dataRowHeight: 60,
            horizontalMargin: 10,
            columnSpacing: 10,
            columns: const [
              DataColumn(
                label: Text('AC TYPES', style: CustomText.tableheading),
                tooltip: 'Account Types',
              ),
              DataColumn(
                label: Text('ACCOUNT', style: CustomText.tableheading),
                tooltip: 'Account Number',
              ),
              DataColumn(
                label:
                    Text('INPUT AMOUNT(NPR)', style: CustomText.tableheading),
                tooltip: 'Input Amount in NPR',
              ),
              DataColumn(
                label: Text('REMARKS INPUT', style: CustomText.tableheading),
                tooltip: 'Remarks',
              ),
              DataColumn(
                label:
                    Text('ACCOUNT OPEN DATE', style: CustomText.tableheading),
                tooltip: 'Date when account was opened',
              ),
              DataColumn(
                label: Text('MATURITY DATE', style: CustomText.tableheading),
                tooltip: 'Maturity Date',
              ),
              DataColumn(
                label: Text('BALANCE', style: CustomText.tableheading),
                tooltip: 'Current Balance',
                numeric: true,
              ),
              DataColumn(
                label: Text('BALANCE DATE', style: CustomText.tableheading),
                tooltip: 'Date of last balance update',
              ),
              DataColumn(
                label: Text('INST AMOUNT(NPR)', style: CustomText.tableheading),
                tooltip: 'Installment Amount in NPR',
                numeric: true,
              ),
              DataColumn(
                label: Text('DUE AMOUNT(NPR)', style: CustomText.tableheading),
                tooltip: 'Due Amount in NPR',
                numeric: true,
              ),
              DataColumn(
                label: Text('PB CHECK DATE', style: CustomText.tableheading),
                tooltip: 'Passbook Check Date',
              ),
            ],
            rows: [
              ...List.generate(
                accounts.length,
                (index) {
                  final acc = accounts[index];
                  setState(() {
                    totalBalance = accounts.fold<double>(
                      0,
                      (sum, acc) => sum + (acc['balance'] as num).toDouble(),
                    );
                    totalInstAmount = accounts.fold<double>(
                      0,
                      (sum, acc) => sum + (acc['inst_amt'] as num).toDouble(),
                    );
                    totalDueAmount = accounts.fold<double>(
                      0,
                      (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
                    );
                  });
                  return DataRow(
                    color: MaterialStateProperty.resolveWith((states) {
                      return index.isOdd
                          ? CustomTheme.tableColorPrimary
                          : CustomTheme.tableColorSecondary;
                    }),
                    cells: [
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            acc['account_type_name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            acc['ac_no'],
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          width: 100,
                          child: TextField(
                            style: TextStyle(
                              color: isFromInputAmount[index]
                                  ? CustomTheme.appThemeColorSecondary
                                  : Colors.black87,
                              fontSize: 13,
                            ),
                            controller: amountControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          width: 120,
                          child: TextField(
                            style: const TextStyle(
                              color: CustomTheme.appThemeColorSecondary,
                              fontSize: 13,
                            ),
                            controller: remarksControllers[index],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['ac_open_date'].toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['maturity_date'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['balance'].toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['bal_date']?.split(' ')[0] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['inst_amt'].toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['due_amt'].toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          acc['pb_check_date']?.split(' ')[0] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
              DataRow(
                color: MaterialStateProperty.all(CustomTheme.tableColorHead),
                cells: [
                  const DataCell(
                    Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const DataCell(Text('')),
                  DataCell(
                    Text(
                      totalInputAmount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(
                    Text(
                      totalBalance.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const DataCell(Text('')),
                  DataCell(
                    Text(
                      totalInstAmount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      totalDueAmount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncToDownloads() async {
    try {
      final allCollected = await dbService.CheckIfInserted();
      await ExcelExportService().saveCsvToDownloads(allCollected);
    } catch (e) {
      // Silent by design — the save itself already succeeded, and this
      // is just a background convenience copy. Don't interrupt the user's
      // flow (print/export dialog) with a separate error for this.
      debugPrint('Background Excel sync failed: $e');
    }
  }
}
