import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/widget/customtabletextstyle.dart';
import 'package:flutter/material.dart';

class AccountTableWidget extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final double totalAmount;
  final double dueAmount;
  final ScrollController horizontalController;
  const AccountTableWidget(
      {super.key,
      required this.accounts,
      required this.totalAmount,
      required this.horizontalController,
      required this.dueAmount});

  @override
  Widget build(BuildContext context) {
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
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth:
                  MediaQuery.of(context).size.width - 32, // Subtracting padding
            ),
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 16,
              headingRowHeight: 50,
              dataRowHeight: 56,
              headingRowColor:
                  MaterialStateProperty.all(CustomTheme.tableColorHead),
              columns: const [
                DataColumn(
                  label: Text(
                    'AC TYPES',
                    style: CustomText.tableheading,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACCOUNT',
                    style: CustomText.tableheading,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACCOUNT OPEN DATE',
                    style: CustomText.tableheading,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'MATURITY DATE',
                    style: CustomText.tableheading,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'INPUT AMOUNT',
                    style: CustomText.tableheading,
                  ),
                  numeric: true,
                ),
              ],
              rows: [
                ...accounts.map((acc) {
                  return DataRow(
                    color: MaterialStateProperty.resolveWith((states) {
                      return accounts.indexOf(acc).isOdd
                          ? CustomTheme.tableColorPrimary
                          : CustomTheme.tableColorSecondary;
                    }),
                    cells: [
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
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
                            style: const TextStyle(
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                          acc['input_amount'].toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
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
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(
                      Text(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
