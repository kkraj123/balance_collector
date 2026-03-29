Map<String, List<Map<String, dynamic>>> filterGroupedAccounts(
  Map<String, List<Map<String, dynamic>>> groupedAccounts,
  String query,
) {
  if (query.isEmpty) {
    return groupedAccounts;
  }

  final filtered = <String, List<Map<String, dynamic>>>{};
  final lowerQuery = query.toLowerCase();

  groupedAccounts.forEach((groupName, accounts) {
    final matchingAccounts = accounts.where((account) {
      final accountName = groupName.toLowerCase();
      final accountUser = (account['ac_name'] as String).toLowerCase();
      final accountNumber = (account['ac_no'] as String).toLowerCase();
      final memberNumber = (account['mf_grp_name'] as String).toLowerCase();
      final identityNumber = (account['id_no'] as String).toLowerCase();
      final contactNumber =
          (account['contact'] as String?)?.toLowerCase() ?? '';

      return accountName.contains(lowerQuery) ||
          accountNumber.contains(lowerQuery) ||
          memberNumber.contains(lowerQuery) ||
          identityNumber.contains(lowerQuery) ||
          accountUser.contains(lowerQuery) ||
          contactNumber.contains(lowerQuery);
    }).toList();

    if (matchingAccounts.isNotEmpty) {
      filtered[groupName] = matchingAccounts;
    }
  });

  return filtered;
}
