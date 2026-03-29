import 'dart:async';

import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/common/widget/customtabletextstyle.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:collector_app/feature/pos_print/printer_util.dart';
import 'package:collector_app/views/pages/Input_data_table/open_google_map.dart';
import 'package:collector_app/views/receipt_screen/search_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ReceiptReportPage extends StatefulWidget {
  final String? acNo;
  final String? name;
  const ReceiptReportPage({super.key, this.acNo, this.name});

  @override
  State<ReceiptReportPage> createState() => _ReceiptReportPageState();
}

class _ReceiptReportPageState extends State<ReceiptReportPage> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isShowSearchBy = false;
  int _selectedIndex = 0;
  Timer? _debounce;
  Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};
  bool _isLoading = true;
  final CBDB _db = CBDB();
  double grandTotalAmount = 0;
  int receiptCount = 0;
  bool _sortByDateAscending = true;
  Map<String, List<Map<String, dynamic>>> _allAccounts = {};

  void _toggleSortByDate() {
    setState(() {
      _sortByDateAscending = !_sortByDateAscending;
      _sortFilteredAccounts();
    });
  }

  void _sortFilteredAccounts() {
    final sortedKeys = _filteredAccounts.keys.toList()
      ..sort((a, b) {
        final dateA = _filteredAccounts[a]!.first['col_date_time'] is DateTime
            ? _filteredAccounts[a]!.first['col_date_time']
            : DateTime.tryParse(
                    _filteredAccounts[a]!.first['col_date_time'].toString()) ??
                DateTime.now();

        final dateB = _filteredAccounts[b]!.first['col_date_time'] is DateTime
            ? _filteredAccounts[b]!.first['col_date_time']
            : DateTime.tryParse(
                    _filteredAccounts[b]!.first['col_date_time'].toString()) ??
                DateTime.now();

        return _sortByDateAscending
            ? dateA.compareTo(dateB)
            : dateB.compareTo(dateA);
      });

    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = _filteredAccounts[key]!;
    }

    _filteredAccounts = sortedMap;
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    var filteredGrouped = {};
    try {
      final accounts = await _db.getAllAccounts();
      print('accountList: ${accounts.length}');

      Map<String, List<Map<String, dynamic>>> grouped;

      if (widget.acNo != null) {
        final newrecords =
            accounts.where((element) => element['ac_no'] == widget.acNo).toList();

        grouped = _groupAccountsByName(newrecords); // ✅ group after filtering
      } else {
        grouped = _groupAccountsByName(accounts);
      }
      _allAccounts = grouped;
      final filteredGrouped = _filterAccountsWithInputValues(grouped);

      setState(() {
        receiptCount = filteredGrouped.length;
        _filteredAccounts = filteredGrouped;
        _sortFilteredAccounts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> _filterAccountsWithInputValues(
      Map<String, List<Map<String, dynamic>>> groupedAccounts) {
    grandTotalAmount = 0;
    final Map<String, List<Map<String, dynamic>>> filtered = {};

    groupedAccounts.forEach((name, accounts) {
      final filteredAccounts = accounts.where((account) {
        if (account['input_amount'] != null) {
          double amount = account['input_amount'] is double
              ? account['input_amount']
              : double.tryParse(account['input_amount'].toString()) ?? 0;
          grandTotalAmount += amount;
        }
        return account['input_amount'] != null &&
            account['col_remarks'] != null;
      }).toList();

      if (filteredAccounts.isNotEmpty) {
        filtered[name] = filteredAccounts;
      }
    });
    return filtered;
  }

  // Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
  //     List<Map<String, dynamic>> accounts) {
  //   final Map<String, List<Map<String, dynamic>>> grouped = {};

  //   for (var account in accounts) {
  //     final name = account['col_group_id']?.toString() ?? 'unknown';
  //     if (!grouped.containsKey(name)) {
  //       grouped[name] = [];
  //     }
  //     grouped[name]!.add(account);
  //   }

  //   return grouped;
  // }
  // void _handleSearch() {
  //   final query = _searchController.text.toLowerCase();

  //   // setState(() =>
  //   //     _filteredAccounts = filterGroupedAccounts(_groupedAccounts, query));
  // }
  void _handleSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();

      if (query.isEmpty) {
        setState(() {
          _filteredAccounts = _filterAccountsWithInputValues(_allAccounts);
          receiptCount = _filteredAccounts.length;
          _sortFilteredAccounts();
        });
        return;
      }

      final result = <String, List<Map<String, dynamic>>>{};

      _allAccounts.forEach((key, accounts) {
        final filtered = accounts.where((acc) {
          final id = acc['id_no']?.toString().toLowerCase() ?? '';
          final name = acc['ac_name']?.toString().toLowerCase() ?? '';
          final accNo = acc['ac_no']?.toString().toLowerCase() ?? '';

          return id.contains(query) ||
              name.contains(query) ||
              accNo.contains(query);
        }).toList();

        if (filtered.isNotEmpty) {
          result[key] = filtered;
        }
      });

      setState(() {
        _filteredAccounts = _filterAccountsWithInputValues(result);
        receiptCount = _filteredAccounts.length;
        _sortFilteredAccounts();
      });
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
      List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final account in accounts) {
      final dynamic rawAmount = account['input_amount'];
      final double amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;

      if (amount < 0.01) {
        continue;
      }

      final String name = account['col_group_id']?.toString() ?? 'unknown';

      grouped.putIfAbsent(name, () => []).add(account);
    }

    return grouped;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _searchController.addListener(_handleSearch);
    if(widget.acNo != null){
      _searchController.text = widget.acNo!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCommonPage(
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 4.0,
          right: 12.0,
          left: 12.0,
          bottom: 0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Amount: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Rs.$grandTotalAmount",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CustomTheme.appThemeColorPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          "Count: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$receiptCount",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CustomTheme.appThemeColorPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                InkWell(
                  onTap: _toggleSortByDate,
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _sortByDateAscending
                            ? CupertinoIcons.arrow_up_circle
                            : CupertinoIcons.arrow_down_circle,
                        color: CustomTheme.appThemeColorPrimary,
                      )),
                )
              ],
            ),
            // Container(
            //   child: Text(
            //       "Grand Total: $grandTotalAmount \t\t\t Receipt Count: $receiptCount"),
            // ),
            const SizedBox(height: 5),
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
                // setState(() {
                //   _selectedIndex = index;
                //   _selectedIndex == 0
                //       ? _loadAccounts()
                //       : _loadAccountsByGroup();
                // });
              }),
              onQRPressed: () {},
              isQrShow: false,
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildTable()),
          ],
        ),
      ),
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
          (sum, acc) => sum + (acc['input_amount'] as num).toDouble(),
        );
        final dueAmount = accounts.fold<double>(
          0,
          (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 13),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                    border:
                        Border.all(color: CustomTheme.appThemeColorPrimary)),
                child: Padding(
                  padding: const EdgeInsets.only(top: 5, left: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(name, accounts),
                      const SizedBox(height: 10),
                      _buildAccountsTable(accounts, totalAmount, dueAmount),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 15,
                child: InkWell(
                  onTap: () async {
                    List<CollectionAccount> collectionAccounts =
                        accounts.asMap().entries.map((account) {
                      return CollectionAccount(
                        accountType:
                            account.value['account_type_name'] ?? 'N/A',
                        accountNumber: account.value['ac_no'] ?? 'N/A',
                        amount: double.tryParse(
                                account.value['input_amount'].toString()) ??
                            0.0,
                        comment: account.value['col_remarks'] ?? '',
                      );
                    }).toList();

                    if (collectionAccounts.isEmpty) {
                      print('No accounts available to print');
                      return;
                    }

                    bool printSuccess =
                        await CollectionReceiptPrinter.printCollectionReceipt(
                      userName: name,
                      groupName: accounts.first['center_name'] ?? 'N/A',
                      collectionDate:
                          accounts.first['col_date_time'] is DateTime
                              ? accounts.first['col_date_time']
                              : DateTime.now(),
                      collectionLocation:
                          accounts.first['col_location'] ?? 'N/A',
                      idNumber: accounts.first['id_no'] ?? 'N/A',
                      accounts: collectionAccounts,
                    );
                    if (!printSuccess) {
                      print('Failed to print receipt');
                    }
                  },
                  child:
                      const Icon(Icons.print, size: 30, color: Colors.black38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerInfo(String name, List<Map<String, dynamic>> accounts) {
    final uniqueNames = accounts.map((e) => e['ac_name']).toSet().toList();
    final joinedNames = uniqueNames.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // "Name: ${name.replaceAll(RegExp(r'\(.*?\)'), '').trim()}",,
          joinedNames,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          "Address: ${accounts.first['p_address'] ?? 'N/A'}",
        ),
        Text(
          "Group Name: ${accounts.first['center_name'] ?? 'N/A'}",
        ),
        Text(
          "Collected Date: ${accounts.first['col_date_time'] ?? 'N/A'}",
        ),
        Row(
          children: [
            Text(
              "Collected Location: ${accounts.first['col_location'] ?? 'N/A'}",
            ),
            InkWell(
              onTap: () {
                openGoogleMaps(accounts.first['col_location'], context);
              },
              child: const Icon(
                Icons.place,
                color: CustomTheme.appThemeColorPrimary,
              ),
            ),
          ],
        ),
        Text(
          "Id Number: ${accounts.first['id_no'] ?? 'N/A'}",
        ),
      ],
    );
  }

  Widget _buildAccountsTable(List<Map<String, dynamic>> accounts,
      double totalAmount, double dueAmount) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: CustomTheme.tableColorHead,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'AC TYPES',
                      style: CustomText.tableheading.copyWith(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'ACCOUNT',
                      style: CustomText.tableheading.copyWith(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'AMOUNT',
                      style: CustomText.tableheading.copyWith(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            ...accounts.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> acc = entry.value;

              return Container(
                color: index.isOdd
                    ? CustomTheme.tableColorPrimary
                    : CustomTheme.tableColorSecondary,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            acc['account_type_name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            acc['ac_no'],
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            acc['input_amount'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (acc['col_remarks'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Text(
                              "Remarks: ",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                acc['col_remarks'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
            Container(
              color: CustomTheme.tableColorHead,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    flex: 6,
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      totalAmount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
