import 'dart:convert';

import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:collector_app/feature/qr_scan/qr_scan_widget.dart';
import 'package:collector_app/views/pages/Input_data_table/input_data_table.dart';
import 'package:collector_app/views/pages/Input_data_table/input_table_by_group.dart';
import 'package:collector_app/views/pages/receipt_report/receipt_report_page.dart';
import 'package:collector_app/views/receipt_screen/account_table_widget.dart';
import 'package:collector_app/views/receipt_screen/search_service.dart';
import 'package:collector_app/views/receipt_screen/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final CBDB _db = CBDB();
  bool _isShowSearchBy = false;
  int _selectedIndex = 0;
  Map<String, List<Map<String, dynamic>>> _groupedAccounts = {};
  Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};
  List<Map<String, dynamic>> _allaccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearch);
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAllAccounts();
      _allaccounts = accounts;
      final grouped = _groupAccountsByName(accounts);

      setState(() {
        _groupedAccounts = grouped;
        _filteredAccounts = grouped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  Future<void> _loadAccountsByGroup() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAllAccounts();
      final grouped = _groupAccountsByGroupName(accounts);
      setState(() {
        _groupedAccounts = grouped;
        _filteredAccounts = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
      List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var account in accounts) {
      // print("this is the result: ${account['is_inserted']}");
      if (account['is_inserted'] == 1) continue;
      final name = account['id_no'] as String;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(account);
    }
    return grouped;
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByGroupName(
      List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var account in accounts) {
      final name = account['mf_grp_name'] as String;
      if (account['is_inserted'] == 1) continue;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(account);
    }
    return grouped;
  }

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();

    setState(() =>
        _filteredAccounts = filterGroupedAccounts(_groupedAccounts, query));
  }

  @override
  Widget build(BuildContext context) {
    return CustomCommonPage(
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10.0,
          right: 15.0,
          left: 15.0,
          bottom: 0,
        ),
        child: Column(
          children: [
            SearchBarWidget(
              searchController: _searchController,
              showSearchBy: _isShowSearchBy,
              selectedIndex: _selectedIndex,
              onFilterPressed: () {
                setState(() {
                  _isShowSearchBy = !_isShowSearchBy;
                });
              },
              onTogglePressed: ((index) {
                setState(() {
                  _selectedIndex = index;
                  _selectedIndex == 0
                      ? _loadAccounts()
                      : _loadAccountsByGroup();
                });
              }),
              onQRPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScanWidget(),
                  ),
                );
              },
              isQrShow: true,
            ),
            const SizedBox(height: 5),
            Expanded(child: _buildTable()),
          ],
        ),
      ),
    );
  }

  Future<bool> _isAlreadyInserted(String idNo) async {
    // final accounts = await _db.getAllAccounts();
    final isInserted = _allaccounts
        .any((acc) => acc['ac_no'] == idNo && acc['is_inserted'] == 1);
    print(" IS inseetedf : ${isInserted}");
    print(" IS inseetedf : ${_groupedAccounts}");
    // return accounts
    //     .any((acc) => acc['id_no'] == idNo && acc['is_inserted'] == 1);
    return isInserted;
  }

  Future<bool?> _showAlreadyInsertedDialog(String idNo, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Already Entered'),
          content: const Text(
              'This user data is already entered. Do you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // OK → false
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ReceiptReportPage(
                              acNo: idNo,
                              name: name,
                            )));
              }, // Edit → true
              child: const Text('View'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Edit → true
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _verticalController,
      itemCount: _filteredAccounts.length,
      itemBuilder: (context, index) {
        final name = _filteredAccounts.keys.elementAt(index);
        final accounts = _filteredAccounts[name]!;

        final totalAmount = accounts.fold<double>(
          0,
          (sum, acc) => sum + (acc['input_amount'] ?? 0 as num).toDouble(),
        );
        final dueAmount = accounts.fold<double>(
          0,
          (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
        );

        return GestureDetector(
          onTap: () async {
            final accNo = accounts.first['ac_no'];
            final name = accounts.first['ac_name'];
            bool alreadyInserted = await _isAlreadyInserted(accNo);

            if (alreadyInserted) {
              final idNo = accounts.first['ac_no'];
              final isEdit = await _showAlreadyInsertedDialog(accNo, name);
              if (isEdit != true) {
                return;
              }
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return (_selectedIndex == 1)
                    ? GroupByGroupName(
                        groudName: name,
                      )
                    : InputDataTable(
                        account: accounts,
                      );
              }),
            ).then((_) {
              setState(() {
                if (_selectedIndex == 0) {
                  _loadAccounts();
                } else {
                  _loadAccountsByGroup();
                }
              });
            });
          },
          child: Padding(
            padding: (_selectedIndex == 1)
                ? const EdgeInsets.symmetric(vertical: 3, horizontal: 5)
                : const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                (_selectedIndex == 1)
                    ? _buildGroupNameList(name, accounts)
                    : _buildCustomerInfo(name, accounts),
                // const SizedBox(height: 10),
                (_selectedIndex == 1)
                    ? Container()
                    : AccountTableWidget(
                        accounts: accounts,
                        dueAmount: dueAmount,
                        totalAmount: totalAmount,
                        horizontalController: _horizontalController,
                      )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupNameList(String name, List<Map<String, dynamic>> accounts) {
    return Container(
      decoration: BoxDecoration(
          color: CustomTheme.tableColorSecondary,
          borderRadius: BorderRadius.circular(5),
          border: const Border.symmetric(
              vertical: BorderSide.none,
              horizontal:
                  BorderSide(color: CustomTheme.tableColorPrimary, width: 2))),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Group Name: $name",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(String name, List<Map<String, dynamic>> accounts) {
    final uniqueNames = accounts.map((e) => e['ac_name']).toSet().toList();
    final joinedNames = uniqueNames.join(', ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Name: $joinedNames",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Address: ${accounts.first['p_address'] ?? 'N/A'}",
              ),
              Text(
                "Group Name: ${accounts.first['center_name'] ?? 'N/A'}",
              ),
              (accounts.first['contact'] != '/' &&
                      accounts.first['contact'] != null)
                  ? Row(
                      children: [
                        Text(
                          "Contact: ${accounts.first['contact'] ?? 'N/A'}",
                        ),
                        const Icon(
                          Icons.call_outlined,
                          color: CustomTheme.appThemeColorPrimary,
                        ),
                      ],
                    )
                  : Container(),
              Text(
                "Id Number: ${accounts.first['id_no'] ?? 'N/A'}",
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            _showQrDialog(context, name, accounts);
          },
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), color: Colors.white),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/icons/qrImage.svg'),
                  const SizedBox(
                    height: 5,
                  ),
                  const Text(
                    'Print QR',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.normal),
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(1),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  String _buildQrData(String name, List<Map<String, dynamic>> accounts) {
    final idNo = accounts.first['id_no']?.toString() ?? '';
    final accName = accounts.first['ac_name']?.toString() ??
        ''; 
    return idNo;
  }

  void _showQrDialog(
      BuildContext context, String name, List<Map<String, dynamic>> accounts) {
    final qrData = _buildQrData(name, accounts);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: SizedBox(
            width: 260,
            height: 260,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 240.0,
              backgroundColor: Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // hook into your existing print flow here
              },
              child: const Text('Print'),
            ),
          ],
        );
      },
    );
  }
}
