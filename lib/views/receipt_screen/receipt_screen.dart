import 'dart:async';

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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Grouping is done off the UI thread via `compute()` so grouping ~33k rows
/// doesn't block a frame. Must be a top-level (or static) function to be
/// sendable to an isolate.
Map<String, List<Map<String, dynamic>>> _groupByNameIsolate(
    List<Map<String, dynamic>> accounts) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  for (final account in accounts) {
    if (account['is_inserted'] == 1) continue;
    final name = account['id_no'] as String;
    (grouped[name] ??= []).add(account);
  }
  return grouped;
}

Map<String, List<Map<String, dynamic>>> _groupByGroupNameIsolate(
    List<Map<String, dynamic>> accounts) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  for (final account in accounts) {
    if (account['is_inserted'] == 1) continue;
    final name = account['mf_grp_name'] as String;
    (grouped[name] ??= []).add(account);
  }
  return grouped;
}

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

  /// Cached `entries` list kept in sync with `_filteredAccounts`.
  /// ListView.builder reads from this instead of calling
  /// `_filteredAccounts.keys.elementAt(index)`, which is O(n) per call
  /// (LinkedHashSet) and was the main cause of scroll jank on ~33k rows.
  List<MapEntry<String, List<Map<String, dynamic>>>> _filteredEntries = [];

  List<Map<String, dynamic>> _allaccounts = [];
  bool _isLoading = true;

  // --- Pagination state (infinite scroll) ---
  static const int _groupPageSize = 40; // how many groups per page
  int _groupOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isSearchActive = false; // pagination is disabled while searching

  Timer? _debounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _verticalController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _verticalController.removeListener(_onScroll);
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _setGrouped(Map<String, List<Map<String, dynamic>>> grouped) {
    _groupedAccounts = grouped;
    _filteredAccounts = grouped;
    _filteredEntries = grouped.entries.toList();
  }

  void _setFiltered(Map<String, List<Map<String, dynamic>>> filtered) {
    _filteredAccounts = filtered;
    _filteredEntries = filtered.entries.toList();
  }

  String get _groupColumn => _selectedIndex == 1 ? 'mf_grp_name' : 'id_no';

  /// Loads the first page of groups (view mode switch / initial load).
  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _groupOffset = 0;
      _hasMore = true;
    });
    try {
      _setGrouped({}); // clear old data first
      await _loadMore(isFirstPage: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Loads the next page of groups and appends them, used both for the
  /// initial page and every subsequent "near bottom" trigger.
  Future<void> _loadMore({bool isFirstPage = false}) async {
    if (_isLoadingMore || (!_hasMore && !isFirstPage)) return;
    setState(() => _isLoadingMore = true);

    try {
      final column = _groupColumn;

      // 1. Get the next page of DISTINCT group keys — cheap, index-backed.
      final keys = await _db.getGroupKeysPaginated(
        groupColumn: column,
        offset: _groupOffset,
        limit: _groupPageSize,
      );

      if (keys.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }

      // 2. Fetch every row for exactly those keys — full groups, never split.
      final rows = await _db.getAccountsForGroupKeys(
        groupColumn: column,
        keys: keys,
      );
      _allaccounts.addAll(rows);

      // 3. Group the small page of rows off the UI isolate.
      final pageGrouped = column == 'mf_grp_name'
          ? await compute(_groupByGroupNameIsolate, rows)
          : await compute(_groupByNameIsolate, rows);

      if (!mounted) return;
      setState(() {
        final merged =
            Map<String, List<Map<String, dynamic>>>.from(_groupedAccounts)
              ..addAll(pageGrouped);
        _setGrouped(merged);
        _groupOffset += keys.length;
        _hasMore = keys.length == _groupPageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      debugPrint('Error loading more accounts: $e');
    }
  }

  /// Triggers the next page a bit before the user hits the very bottom,
  /// so the next batch is ready before they notice.
  void _onScroll() {
    if (_isSearchActive) return; // no pagination while a search is active
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    final position = _verticalController.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Debounced search that queries SQLite directly (via FTS5 in
  /// CBDB.searchAccounts) instead of filtering the in-memory grouped map.
  /// SQLite does the matching; only the (usually small) result set comes
  /// back, so the full ~33k-row set never has to be scanned in Dart.
  /// `_searchRequestId` guards a slow older request from overwriting a
  /// newer one if the person keeps typing.
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runDbSearch(_searchController.text.trim());
    });
  }

  Future<void> _runDbSearch(String query) async {
    final requestId = ++_searchRequestId;

    try {
      if (query.isEmpty) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearchActive = false;
          _setFiltered(_groupedAccounts); // back to the paginated view
        });
        return;
      }

      setState(() => _isSearchActive = true);

      // SQL-side search — only matching rows come back, not all 33k.
      final matches = await _db.searchAccounts(query);

      // Group the (small) result set off the UI isolate, same rule as
      // the current view mode.
      final grouped = _selectedIndex == 1
          ? await compute(_groupByGroupNameIsolate, matches)
          : await compute(_groupByNameIsolate, matches);

      if (!mounted || requestId != _searchRequestId) return; // stale result
      setState(() => _setFiltered(grouped));
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      debugPrint('Search error: $e');
    }
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
                });
                _loadFirstPage();
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
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                'Total Items: ${_filteredEntries.length}',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: _buildTable()),
          ],
        ),
      ),
    );
  }

  Future<bool> _isAlreadyInserted(String idNo) async {
    // Checks the database directly rather than the in-memory _allaccounts
    // list, since with pagination that list only holds the pages loaded
    // so far — not the full 33k rows.
    final db = await CBDB().getAccountsByAcNo(idNo);
    return db.any((acc) => acc['is_inserted'] == 1);
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
              },
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
    // +1 extra slot for the "loading more" indicator at the bottom,
    // shown only while paginating (not during an active search).
    final showLoadingFooter =
        !_isSearchActive && _isLoadingMore && _filteredEntries.isNotEmpty;
    final itemCount = _filteredEntries.length + (showLoadingFooter ? 1 : 0);

    return ListView.builder(
      controller: _verticalController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _filteredEntries.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final entry = _filteredEntries[index];
        final name = entry.key;
        final accounts = entry.value;

        final totalAmount = accounts.fold<double>(
          0,
          (sum, acc) => sum + (acc['input_amount'] ?? 0 as num).toDouble(),
        );
        final dueAmount = accounts.fold<double>(
          0,
          (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
        );

        return GestureDetector(
          key: ValueKey(name),
          onTap: () async {
            final accNo = accounts.first['ac_no'];
            final accName = accounts.first['ac_name'];
            bool alreadyInserted = await _isAlreadyInserted(accNo);

            if (alreadyInserted) {
              final isEdit = await _showAlreadyInsertedDialog(accNo, accName);
              if (isEdit != true) {
                return;
              }
            }
            if (!mounted) return;
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
              _loadFirstPage();
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

  Widget _buildGroupNameList(
      String name, List<Map<String, dynamic>> accounts) {
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
                        Expanded(
                          child: Text(
                            "Contact: ${accounts.first['contact'] ?? 'N/A'}",
                          ),
                        ),
                        Expanded(
                          child: const Icon(
                            Icons.call_outlined,
                            color: CustomTheme.appThemeColorPrimary,
                          ),
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
            width: 200,
            height: 200,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
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

// import 'dart:async';

// import 'package:collector_app/common/app/theme.dart';
// import 'package:collector_app/common/widget/common_page.dart';
// import 'package:collector_app/feature/database/cb_db.dart';
// import 'package:collector_app/feature/qr_scan/qr_scan_widget.dart';
// import 'package:collector_app/views/pages/Input_data_table/input_data_table.dart';
// import 'package:collector_app/views/pages/Input_data_table/input_table_by_group.dart';
// import 'package:collector_app/views/pages/receipt_report/receipt_report_page.dart';
// import 'package:collector_app/views/receipt_screen/account_table_widget.dart';
// import 'package:collector_app/views/receipt_screen/search_service.dart';
// import 'package:collector_app/views/receipt_screen/search_widget.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:qr_flutter/qr_flutter.dart';

// /// Grouping is done off the UI thread via `compute()` so grouping ~33k rows
// /// doesn't block a frame. Must be a top-level (or static) function to be
// /// sendable to an isolate.
// Map<String, List<Map<String, dynamic>>> _groupByNameIsolate(
//     List<Map<String, dynamic>> accounts) {
//   final Map<String, List<Map<String, dynamic>>> grouped = {};
//   for (final account in accounts) {
//     if (account['is_inserted'] == 1) continue;
//     final name = account['id_no'] as String;
//     (grouped[name] ??= []).add(account);
//   }
//   return grouped;
// }

// Map<String, List<Map<String, dynamic>>> _groupByGroupNameIsolate(
//     List<Map<String, dynamic>> accounts) {
//   final Map<String, List<Map<String, dynamic>>> grouped = {};
//   for (final account in accounts) {
//     if (account['is_inserted'] == 1) continue;
//     final name = account['mf_grp_name'] as String;
//     (grouped[name] ??= []).add(account);
//   }
//   return grouped;
// }

// class ReceiptScreen extends StatefulWidget {
//   const ReceiptScreen({super.key});
//   @override
//   State<ReceiptScreen> createState() => _ReceiptScreenState();
// }

// class _ReceiptScreenState extends State<ReceiptScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ScrollController _horizontalController = ScrollController();
//   final ScrollController _verticalController = ScrollController();
//   final CBDB _db = CBDB();
//   bool _isShowSearchBy = false;
//   int _selectedIndex = 0;

//   Map<String, List<Map<String, dynamic>>> _groupedAccounts = {};
//   Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};

//   /// Cached `entries` list kept in sync with `_filteredAccounts`.
//   /// ListView.builder reads from this instead of calling
//   /// `_filteredAccounts.keys.elementAt(index)`, which is O(n) per call
//   /// (LinkedHashSet) and was the main cause of scroll jank on ~33k rows.
//   List<MapEntry<String, List<Map<String, dynamic>>>> _filteredEntries = [];

//   List<Map<String, dynamic>> _allaccounts = [];
//   bool _isLoading = true;

//   Timer? _debounce;
//   int _searchRequestId = 0;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(_onSearchChanged);
//     _loadAccounts();
//   }

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     _horizontalController.dispose();
//     _verticalController.dispose();
//     super.dispose();
//   }

//   void _setGrouped(Map<String, List<Map<String, dynamic>>> grouped) {
//     _groupedAccounts = grouped;
//     _filteredAccounts = grouped;
//     _filteredEntries = grouped.entries.toList();
//   }

//   void _setFiltered(Map<String, List<Map<String, dynamic>>> filtered) {
//     _filteredAccounts = filtered;
//     _filteredEntries = filtered.entries.toList();
//   }

//   Future<void> _loadAccounts() async {
//     setState(() => _isLoading = true);
//     try {
//       // SQL-side filter of is_inserted rows instead of pulling every row
//       // and filtering in the Dart grouping loop.
//       final accounts = await _db.getAllActiveAccounts();
//       _allaccounts = accounts;

//       // Grouping ~33k rows off the UI isolate.
//       final grouped = await compute(_groupByNameIsolate, accounts);

//       if (!mounted) return;
//       setState(() {
//         _setGrouped(grouped);
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _isLoading = false);
//       debugPrint('Error loading accounts: $e');
//     }
//   }

//   Future<void> _loadAccountsByGroup() async {
//     setState(() => _isLoading = true);
//     try {
//       final accounts = await _db.getAllActiveAccounts();
//       final grouped = await compute(_groupByGroupNameIsolate, accounts);

//       if (!mounted) return;
//       setState(() {
//         _setGrouped(grouped);
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _isLoading = false);
//       debugPrint('Error loading accounts: $e');
//     }
//   }

//   /// Debounced + off-thread search. Waits 300ms after the user stops typing,
//   /// then filters the already-grouped data in a background isolate so
//   /// keystrokes never block a frame. `_searchRequestId` guards against a
//   /// slow older request overwriting a newer one's result.
//   /// Debounced search that queries SQLite directly (via FTS5 in
//   /// CBDB.searchAccounts) instead of filtering the in-memory grouped map.
//   /// SQLite does the matching; only the (usually small) result set comes
//   /// back, so the full ~33k-row set never has to be scanned in Dart.
//   /// `_searchRequestId` guards a slow older request from overwriting a
//   /// newer one if the person keeps typing.
//   void _onSearchChanged() {
//     _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 300), () {
//       _runDbSearch(_searchController.text.trim());
//     });
//   }

//   Future<void> _runDbSearch(String query) async {
//     final requestId = ++_searchRequestId;

//     try {
//       if (query.isEmpty) {
//         if (!mounted || requestId != _searchRequestId) return;
//         setState(() => _setFiltered(_groupedAccounts));
//         return;
//       }

//       // SQL-side search — only matching rows come back, not all 33k.
//       final matches = await _db.searchAccounts(query);

//       // Group the (small) result set off the UI isolate, same rule as
//       // the current view mode.
//       final grouped = _selectedIndex == 1
//           ? await compute(_groupByGroupNameIsolate, matches)
//           : await compute(_groupByNameIsolate, matches);

//       if (!mounted || requestId != _searchRequestId) return; // stale result
//       setState(() => _setFiltered(grouped));
//     } catch (e) {
//       if (!mounted || requestId != _searchRequestId) return;
//       debugPrint('Search error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CustomCommonPage(
//       resizeToAvoidBottomInset: false,
//       child: Padding(
//         padding: const EdgeInsets.only(
//           top: 10.0,
//           right: 15.0,
//           left: 15.0,
//           bottom: 0,
//         ),
//         child: Column(
//           children: [
//             SearchBarWidget(
//               searchController: _searchController,
//               showSearchBy: _isShowSearchBy,
//               selectedIndex: _selectedIndex,
//               onFilterPressed: () {
//                 setState(() {
//                   _isShowSearchBy = !_isShowSearchBy;
//                 });
//               },
//               onTogglePressed: ((index) {
//                 setState(() {
//                   _selectedIndex = index;
//                   _selectedIndex == 0
//                       ? _loadAccounts()
//                       : _loadAccountsByGroup();
//                 });
//               }),
//               onQRPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const QRScanWidget(),
//                   ),
//                 );
//               },
//               isQrShow: true,
//             ),
//             const SizedBox(height: 5),
//             Container(
//               width: MediaQuery.sizeOf(context).width,
//               height: 40,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(15),
//                 color: Colors.white,
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 'Total Items: ${_filteredEntries.length}',
//                 style: const TextStyle(
//                     color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//             Expanded(child: _buildTable()),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<bool> _isAlreadyInserted(String idNo) async {
//     final isInserted = _allaccounts
//         .any((acc) => acc['ac_no'] == idNo && acc['is_inserted'] == 1);
//     return isInserted;
//   }

//   Future<bool?> _showAlreadyInsertedDialog(String idNo, String name) {
//     return showDialog<bool>(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Already Entered'),
//           content: const Text(
//               'This user data is already entered. Do you want to continue?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false), // OK → false
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) => ReceiptReportPage(
//                               acNo: idNo,
//                               name: name,
//                             )));
//               },
//               child: const Text('View'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context, true), // Edit → true
//               child: const Text('Continue'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildTable() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     return ListView.builder(
//       controller: _verticalController,
//       itemCount: _filteredEntries.length,
//       itemBuilder: (context, index) {
//         final entry = _filteredEntries[index];
//         final name = entry.key;
//         final accounts = entry.value;

//         final totalAmount = accounts.fold<double>(
//           0,
//           (sum, acc) => sum + (acc['input_amount'] ?? 0 as num).toDouble(),
//         );
//         final dueAmount = accounts.fold<double>(
//           0,
//           (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
//         );

//         return GestureDetector(
//           key: ValueKey(name),
//           onTap: () async {
//             final accNo = accounts.first['ac_no'];
//             final accName = accounts.first['ac_name'];
//             bool alreadyInserted = await _isAlreadyInserted(accNo);

//             if (alreadyInserted) {
//               final isEdit = await _showAlreadyInsertedDialog(accNo, accName);
//               if (isEdit != true) {
//                 return;
//               }
//             }
//             if (!mounted) return;
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) {
//                 return (_selectedIndex == 1)
//                     ? GroupByGroupName(
//                         groudName: name,
//                       )
//                     : InputDataTable(
//                         account: accounts,
//                       );
//               }),
//             ).then((_) {
//               if (_selectedIndex == 0) {
//                 _loadAccounts();
//               } else {
//                 _loadAccountsByGroup();
//               }
//             });
//           },
//           child: Padding(
//             padding: (_selectedIndex == 1)
//                 ? const EdgeInsets.symmetric(vertical: 3, horizontal: 5)
//                 : const EdgeInsets.all(8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 (_selectedIndex == 1)
//                     ? _buildGroupNameList(name, accounts)
//                     : _buildCustomerInfo(name, accounts),
//                 (_selectedIndex == 1)
//                     ? Container()
//                     : AccountTableWidget(
//                         accounts: accounts,
//                         dueAmount: dueAmount,
//                         totalAmount: totalAmount,
//                         horizontalController: _horizontalController,
//                       )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildGroupNameList(
//       String name, List<Map<String, dynamic>> accounts) {
//     return Container(
//       decoration: BoxDecoration(
//           color: CustomTheme.tableColorSecondary,
//           borderRadius: BorderRadius.circular(5),
//           border: const Border.symmetric(
//               vertical: BorderSide.none,
//               horizontal:
//                   BorderSide(color: CustomTheme.tableColorPrimary, width: 2))),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Text(
//           "Group Name: $name",
//           style: const TextStyle(fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomerInfo(String name, List<Map<String, dynamic>> accounts) {
//     final uniqueNames = accounts.map((e) => e['ac_name']).toSet().toList();
//     final joinedNames = uniqueNames.join(', ');
//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Name: $joinedNames",
//                 style: const TextStyle(fontWeight: FontWeight.bold),
//               ),
//               Text(
//                 "Address: ${accounts.first['p_address'] ?? 'N/A'}",
//               ),
//               Text(
//                 "Group Name: ${accounts.first['center_name'] ?? 'N/A'}",
//               ),
//               (accounts.first['contact'] != '/' &&
//                       accounts.first['contact'] != null)
//                   ? Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             "Contact: ${accounts.first['contact'] ?? 'N/A'}",
//                           ),
//                         ),
//                         Expanded(
//                           child: const Icon(
//                             Icons.call_outlined,
//                             color: CustomTheme.appThemeColorPrimary,
//                           ),
//                         ),
//                       ],
//                     )
//                   : Container(),
//               Text(
//                 "Id Number: ${accounts.first['id_no'] ?? 'N/A'}",
//               ),
//             ],
//           ),
//         ),
//         InkWell(
//           onTap: () {
//             _showQrDialog(context, name, accounts);
//           },
//           child: Container(
//             height: 80,
//             width: 80,
//             decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(10), color: Colors.white),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   SvgPicture.asset('assets/icons/qrImage.svg'),
//                   const SizedBox(
//                     height: 5,
//                   ),
//                   const Text(
//                     'Print QR',
//                     style: TextStyle(
//                         color: Colors.green, fontWeight: FontWeight.normal),
//                     textAlign: TextAlign.center,
//                     textScaler: TextScaler.linear(1),
//                   )
//                 ],
//               ),
//             ),
//           ),
//         )
//       ],
//     );
//   }

//   String _buildQrData(String name, List<Map<String, dynamic>> accounts) {
//     final idNo = accounts.first['id_no']?.toString() ?? '';
//     return idNo;
//   }

//   void _showQrDialog(
//       BuildContext context, String name, List<Map<String, dynamic>> accounts) {
//     final qrData = _buildQrData(name, accounts);

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(name),
//           content: SizedBox(
//             width: 200,
//             height: 200,
//             child: QrImageView(
//               data: qrData,
//               version: QrVersions.auto,
//               size: 200.0,
//               backgroundColor: Colors.white,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 // hook into your existing print flow here
//               },
//               child: const Text('Print'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
// import 'package:collector_app/common/app/theme.dart';
// import 'package:collector_app/common/widget/common_page.dart';
// import 'package:collector_app/feature/database/cb_db.dart';
// import 'package:collector_app/feature/qr_scan/qr_scan_widget.dart';
// import 'package:collector_app/views/pages/Input_data_table/input_data_table.dart';
// import 'package:collector_app/views/pages/Input_data_table/input_table_by_group.dart';
// import 'package:collector_app/views/pages/receipt_report/receipt_report_page.dart';
// import 'package:collector_app/views/receipt_screen/account_table_widget.dart';
// import 'package:collector_app/views/receipt_screen/search_service.dart';
// import 'package:collector_app/views/receipt_screen/search_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:qr_flutter/qr_flutter.dart';

// class ReceiptScreen extends StatefulWidget {
//   const ReceiptScreen({super.key});
//   @override
//   State<ReceiptScreen> createState() => _ReceiptScreenState();
// }

// class _ReceiptScreenState extends State<ReceiptScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ScrollController _horizontalController = ScrollController();
//   final ScrollController _verticalController = ScrollController();
//   final CBDB _db = CBDB();
//   bool _isShowSearchBy = false;
//   int _selectedIndex = 0;
//   Map<String, List<Map<String, dynamic>>> _groupedAccounts = {};
//   Map<String, List<Map<String, dynamic>>> _filteredAccounts = {};
//   List<Map<String, dynamic>> _allaccounts = [];
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   bool _hasMore = true;
//   static const int _pageSize = 10;
//   int _offset = 0;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(_handleSearch);
//     _loadAccounts();
//   }

//   @override
//   void dispose() {
//     _searchController.removeListener(_handleSearch);
//     _searchController.dispose();
//     _horizontalController.dispose();
//     _verticalController.dispose();
//     super.dispose();
//   }

//   // void _onScroll() {
//   //   if (_selectedIndex != 0) return;
//   //   if (!_hasMore || _isLoadingMore || _isLoading) return;

//   //   final position = _verticalController.position;

//   //   if (position.maxScrollExtent <= 0) return;

//   //   if (position.pixels >= position.maxScrollExtent - 200) {
//   //     _loadAccounts();
//   //   }
//   // }

//   Future<void> _loadAccounts() async {
//     setState(() => _isLoading = true);
//     try {
//       final accounts = await _db.getAllAccounts();
//       _allaccounts = accounts;
//       final grouped = _groupAccountsByName(accounts);

//       setState(() {
//         _groupedAccounts = grouped;
//         _filteredAccounts = grouped;
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _isLoading = false);
//       debugPrint('Error loading accounts: $e');
//     }
//   }
//   // Future<void> _loadAccounts({bool reset = false}) async {
//   //   if (reset) {
//   //     setState(() {
//   //       _isLoading = true;
//   //       _offset = 0;
//   //       _hasMore = true;
//   //       _allaccounts = [];
//   //       _groupedAccounts = {};
//   //       _filteredAccounts = {};
//   //     });
//   //   } else {
//   //     if (!_hasMore || _isLoadingMore) return;
//   //     setState(() => _isLoadingMore = true);
//   //   }

//   //   try {
//   //     final accounts = await _db.getAccountsPaginated(
//   //       offset: _offset,
//   //       limit: _pageSize,
//   //     );
//   //     debugPrint(
//   //         'Fetched ${accounts.length} raw rows at offset ${_offset - accounts.length}');

//   //     _allaccounts.addAll(accounts);
//   //     _offset += accounts.length;
//   //     final stillMore = accounts.length == _pageSize;

//   //     // merge new batch into existing grouped map instead of rebuilding it
//   //     final merged =
//   //         Map<String, List<Map<String, dynamic>>>.from(_groupedAccounts);
//   //     for (var account in accounts) {
//   //       if (account['is_inserted'] == 1) continue;
//   //       final name = account['id_no'] as String;
//   //       merged.putIfAbsent(name, () => []);
//   //       merged[name]!.add(account);
//   //     }

//   //     setState(() {
//   //       _groupedAccounts = merged;
//   //       _filteredAccounts = _searchController.text.isEmpty
//   //           ? merged
//   //           : filterGroupedAccounts(
//   //               merged, _searchController.text.toLowerCase());
//   //       _hasMore = stillMore;
//   //       _isLoading = false;
//   //       _isLoadingMore = false;
//   //     });
//   //   } catch (e) {
//   //     if (!mounted) return;
//   //     setState(() {
//   //       _isLoading = false;
//   //       _isLoadingMore = false;
//   //     });
//   //     debugPrint('Error loading accounts: $e');
//   //   }
//   // }

//   Future<void> _loadAccountsByGroup() async {
//     setState(() => _isLoading = true);
//     try {
//       final accounts = await _db.getAllAccounts();
//       final grouped = _groupAccountsByGroupName(accounts);
//       setState(() {
//         _groupedAccounts = grouped;
//         _filteredAccounts = grouped;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() => _isLoading = false);
//       debugPrint('Error loading accounts: $e');
//     }
//   }

//   Map<String, List<Map<String, dynamic>>> _groupAccountsByName(
//       List<Map<String, dynamic>> accounts) {
//     final Map<String, List<Map<String, dynamic>>> grouped = {};

//     for (var account in accounts) {
//       // print("this is the result: ${account['is_inserted']}");
//       if (account['is_inserted'] == 1) continue;
//       final name = account['id_no'] as String;
//       if (!grouped.containsKey(name)) {
//         grouped[name] = [];
//       }
//       grouped[name]!.add(account);
//     }
//     return grouped;
//   }

//   Map<String, List<Map<String, dynamic>>> _groupAccountsByGroupName(
//       List<Map<String, dynamic>> accounts) {
//     final Map<String, List<Map<String, dynamic>>> grouped = {};

//     for (var account in accounts) {
//       final name = account['mf_grp_name'] as String;
//       if (account['is_inserted'] == 1) continue;
//       if (!grouped.containsKey(name)) {
//         grouped[name] = [];
//       }
//       grouped[name]!.add(account);
//     }
//     return grouped;
//   }

//   void _handleSearch() {
//     final query = _searchController.text.toLowerCase();

//     setState(() =>
//         _filteredAccounts = filterGroupedAccounts(_groupedAccounts, query));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CustomCommonPage(
//       resizeToAvoidBottomInset: false,
//       child: Padding(
//         padding: const EdgeInsets.only(
//           top: 10.0,
//           right: 15.0,
//           left: 15.0,
//           bottom: 0,
//         ),
//         child: Column(
//           children: [
//             SearchBarWidget(
//               searchController: _searchController,
//               showSearchBy: _isShowSearchBy,
//               selectedIndex: _selectedIndex,
//               onFilterPressed: () {
//                 setState(() {
//                   _isShowSearchBy = !_isShowSearchBy;
//                 });
//               },
//               onTogglePressed: ((index) {
//                 setState(() {
//                   _selectedIndex = index;
//                   _selectedIndex == 0
//                       ? _loadAccounts()
//                       : _loadAccountsByGroup();
//                 });
//               }),
//               onQRPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const QRScanWidget(),
//                   ),
//                 );
//               },
//               isQrShow: true,
//             ),
//             const SizedBox(height: 5),
//             Container(
//               width: MediaQuery.sizeOf(context).width,
//               height: 40,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(15),
//                 color: Colors.white,
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 'Total Items: ${_filteredAccounts.length}',
//                 style:
//                     const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//             Expanded(child: _buildTable()),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<bool> _isAlreadyInserted(String idNo) async {
//     // final accounts = await _db.getAllAccounts();
//     final isInserted = _allaccounts
//         .any((acc) => acc['ac_no'] == idNo && acc['is_inserted'] == 1);
//     print(" IS inseetedf : ${isInserted}");
//     print(" IS inseetedf : ${_groupedAccounts}");
//     // return accounts
//     //     .any((acc) => acc['id_no'] == idNo && acc['is_inserted'] == 1);
//     return isInserted;
//   }

//   Future<bool?> _showAlreadyInsertedDialog(String idNo, String name) {
//     return showDialog<bool>(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Already Entered'),
//           content: const Text(
//               'This user data is already entered. Do you want to continue?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false), // OK → false
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) => ReceiptReportPage(
//                               acNo: idNo,
//                               name: name,
//                             )));
//               }, // Edit → true
//               child: const Text('View'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context, true), // Edit → true
//               child: const Text('Continue'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildTable() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     return ListView.builder(
//       controller: _verticalController,
//       itemCount: _filteredAccounts.length,
//       itemBuilder: (context, index) {
//         if (index >= _filteredAccounts.length) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final name = _filteredAccounts.keys.elementAt(index);
//         final accounts = _filteredAccounts[name]!;

//         final totalAmount = accounts.fold<double>(
//           0,
//           (sum, acc) => sum + (acc['input_amount'] ?? 0 as num).toDouble(),
//         );
//         final dueAmount = accounts.fold<double>(
//           0,
//           (sum, acc) => sum + (acc['due_amt'] as num).toDouble(),
//         );

//         return GestureDetector(
//           onTap: () async {
//             final accNo = accounts.first['ac_no'];
//             final name = accounts.first['ac_name'];
//             bool alreadyInserted = await _isAlreadyInserted(accNo);

//             if (alreadyInserted) {
//               final idNo = accounts.first['ac_no'];
//               final isEdit = await _showAlreadyInsertedDialog(accNo, name);
//               if (isEdit != true) {
//                 return;
//               }
//             }
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) {
//                 return (_selectedIndex == 1)
//                     ? GroupByGroupName(
//                         groudName: name,
//                       )
//                     : InputDataTable(
//                         account: accounts,
//                       );
//               }),
//             ).then((_) {
//               setState(() {
//                 if (_selectedIndex == 0) {
//                   _loadAccounts();
//                 } else {
//                   _loadAccountsByGroup();
//                 }
//               });
//             });
//           },
//           child: Padding(
//             padding: (_selectedIndex == 1)
//                 ? const EdgeInsets.symmetric(vertical: 3, horizontal: 5)
//                 : const EdgeInsets.all(8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 (_selectedIndex == 1)
//                     ? _buildGroupNameList(name, accounts)
//                     : _buildCustomerInfo(name, accounts),
//                 // const SizedBox(height: 10),
//                 (_selectedIndex == 1)
//                     ? Container()
//                     : AccountTableWidget(
//                         accounts: accounts,
//                         dueAmount: dueAmount,
//                         totalAmount: totalAmount,
//                         horizontalController: _horizontalController,
//                       )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildGroupNameList(String name, List<Map<String, dynamic>> accounts) {
//     return Container(
//       decoration: BoxDecoration(
//           color: CustomTheme.tableColorSecondary,
//           borderRadius: BorderRadius.circular(5),
//           border: const Border.symmetric(
//               vertical: BorderSide.none,
//               horizontal:
//                   BorderSide(color: CustomTheme.tableColorPrimary, width: 2))),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Text(
//           "Group Name: $name",
//           style: const TextStyle(fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomerInfo(String name, List<Map<String, dynamic>> accounts) {
//     final uniqueNames = accounts.map((e) => e['ac_name']).toSet().toList();
//     final joinedNames = uniqueNames.join(', ');
//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Name: $joinedNames",
//                 style: const TextStyle(fontWeight: FontWeight.bold),
//               ),
//               Text(
//                 "Address: ${accounts.first['p_address'] ?? 'N/A'}",
//               ),
//               Text(
//                 "Group Name: ${accounts.first['center_name'] ?? 'N/A'}",
//               ),
//               (accounts.first['contact'] != '/' &&
//                       accounts.first['contact'] != null)
//                   ? Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             "Contact: ${accounts.first['contact'] ?? 'N/A'}",
//                           ),
//                         ),
//                         Expanded(
//                           child: const Icon(
//                             Icons.call_outlined,
//                             color: CustomTheme.appThemeColorPrimary,
//                           ),
//                         ),
//                       ],
//                     )
//                   : Container(),
//               Text(
//                 "Id Number: ${accounts.first['id_no'] ?? 'N/A'}",
//               ),
//             ],
//           ),
//         ),
//         InkWell(
//           onTap: () {
//             _showQrDialog(context, name, accounts);
//           },
//           child: Container(
//             height: 80,
//             width: 80,
//             decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(10), color: Colors.white),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   SvgPicture.asset('assets/icons/qrImage.svg'),
//                   const SizedBox(
//                     height: 5,
//                   ),
//                   const Text(
//                     'Print QR',
//                     style: TextStyle(
//                         color: Colors.green, fontWeight: FontWeight.normal),
//                     textAlign: TextAlign.center,
//                     textScaler: TextScaler.linear(1),
//                   )
//                 ],
//               ),
//             ),
//           ),
//         )
//       ],
//     );
//   }

//   String _buildQrData(String name, List<Map<String, dynamic>> accounts) {
//     final idNo = accounts.first['id_no']?.toString() ?? '';
//     final accName = accounts.first['ac_name']?.toString() ?? '';
//     return idNo;
//   }

//   void _showQrDialog(
//       BuildContext context, String name, List<Map<String, dynamic>> accounts) {
//     final qrData = _buildQrData(name, accounts);

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(name),
//           content: SizedBox(
//             width: 200,
//             height: 200,
//             child: QrImageView(
//               data: qrData,
//               version: QrVersions.auto,
//               size: 200.0,
//               backgroundColor: Colors.white,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 // hook into your existing print flow here
//               },
//               child: const Text('Print'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
