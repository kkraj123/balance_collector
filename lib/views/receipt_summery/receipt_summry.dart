import 'dart:async';

import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/models/users.dart';
import 'package:collector_app/common/shared_pref.dart';
import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/common/widget/customtabletextstyle.dart';
import 'package:collector_app/feature/database/cb_db.dart';
import 'package:flutter/material.dart';

class ReceiptSummryScreen extends StatefulWidget {
  final String? acNo;
  final String? name;
  const ReceiptSummryScreen({super.key, this.acNo, this.name});

  @override
  State<ReceiptSummryScreen> createState() => _ReceiptSummeryPageState();
}

class _ReceiptSummeryPageState extends State<ReceiptSummryScreen> {
  final ScrollController _verticalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;
  final CBDB _db = CBDB();

  double grandTotalAmount = 0;
  int receiptCount = 0;

  List<Map<String, dynamic>> _allAccountsFlat = [];
  List<Map<String, dynamic>> _filteredAccountsFlat = [];

  Map<String, double> _accountTypeTotals = {};
  Map<String, int> _accountTypeCounts = {};

  late User? userData;
  String clientAlia = '';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (widget.acNo != null) {
      _searchController.text = widget.acNo!;
    }
    fetchuserDetials();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  fetchuserDetials() async {
    userData = await SharedPref.getUser();
    clientAlia = await SharedPref.getAlias();
    print('userData : ${userData!.toJson()}');
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAllAccounts();
      print('accountList: ${accounts.length}');

      List<Map<String, dynamic>> filtered;
      if (widget.acNo != null) {
        filtered = accounts
            .where((element) => element['ac_no'] == widget.acNo)
            .toList();
      } else {
        filtered = List<Map<String, dynamic>>.from(accounts);
      }

      filtered = filtered.where((account) {
        final rawAmount = account['input_amount'];
        final amount = rawAmount is num
            ? rawAmount.toDouble()
            : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
        return amount >= 0.01 &&
            account['input_amount'] != null &&
            account['col_remarks'] != null;
      }).toList();

      _allAccountsFlat = filtered;
      print(
          'LOADED ${_allAccountsFlat.length} usable records (with amount>=0.01 and remarks)');

      setState(() {
        _filteredAccountsFlat = _allAccountsFlat;
        _accountTypeTotals = _aggregateByAccountType(_filteredAccountsFlat);
        grandTotalAmount =
            _accountTypeTotals.values.fold(0.0, (sum, v) => sum + v);
        receiptCount = _filteredAccountsFlat.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading accounts: $e');
    }
  }

  Map<String, double> _aggregateByAccountType(
      List<Map<String, dynamic>> accounts) {
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};
    for (final acc in accounts) {
      final typeName = acc['account_type_name']?.toString() ?? 'Unknown';
      final rawAmount = acc['input_amount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
      totals[typeName] = (totals[typeName] ?? 0) + amount;
      counts[typeName] = (counts[typeName] ?? 0) + 1;
    }
    _accountTypeCounts = counts;
    return totals;
  }

  void _handleSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim().toLowerCase();
      print(
          'SEARCH query: "$query" against ${_allAccountsFlat.length} records');

      List<Map<String, dynamic>> result;
      if (query.isEmpty) {
        result = _allAccountsFlat;
      } else {
        result = _allAccountsFlat.where((acc) {
          final id = acc['id_no']?.toString().toLowerCase() ?? '';
          final name = acc['ac_name']?.toString().toLowerCase() ?? '';
          final accNo = acc['ac_no']?.toString().toLowerCase() ?? '';
          final accType =
              acc['account_type_name']?.toString().toLowerCase() ?? '';
          return id.contains(query) ||
              name.contains(query) ||
              accNo.contains(query) ||
              accType.contains(query);
        }).toList();
      }

      print('SEARCH result count: ${result.length}');

      setState(() {
        _filteredAccountsFlat = result;
        _accountTypeTotals = _aggregateByAccountType(_filteredAccountsFlat);
        grandTotalAmount =
            _accountTypeTotals.values.fold(0.0, (sum, v) => sum + v);
        receiptCount = _filteredAccountsFlat.length;
      });
    });
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          setState(() {});
          _handleSearch();
        },
        decoration: InputDecoration(
          hintText: 'Search by account name or number',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _handleSearch();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
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
            const SizedBox(height: 5),
            _buildSearchBar(),
            const SizedBox(height: 10),
            Expanded(child: _buildTable()),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                color: Colors.green,
                // color: CustomTheme.tableColorHead,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text(
                        'Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                        textScaler: TextScaler.linear(1.3),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        receiptCount.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white),
                        textAlign: TextAlign.right,
                        textScaler: const TextScaler.linear(1.3),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        grandTotalAmount.toStringAsFixed(2),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white),
                        textAlign: TextAlign.right,
                        textScaler: const TextScaler.linear(1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accountTypeTotals.isEmpty) {
      return const Center(child: Text('No records found'));
    }

    final sortedTypes = _accountTypeTotals.keys.toList()..sort();

    return SingleChildScrollView(
      controller: _verticalController,
      child: Container(
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'AC TYPES',
                        style: CustomText.tableheading.copyWith(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Transaction Count',
                        style: CustomText.tableheading.copyWith(fontSize: 13),
                        textAlign: TextAlign.right,
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
              ...sortedTypes.asMap().entries.map((entry) {
                final int index = entry.key;
                final String typeName = entry.value;
                final double amount = _accountTypeTotals[typeName]!;
                final int count = _accountTypeCounts[typeName] ?? 0;

                return Container(
                  color: index.isOdd
                      ? CustomTheme.tableColorPrimary
                      : CustomTheme.tableColorSecondary,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          typeName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          amount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
