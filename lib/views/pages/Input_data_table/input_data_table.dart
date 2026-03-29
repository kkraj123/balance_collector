import 'package:collector_app/common/widget/common_page.dart';
import 'package:collector_app/views/pages/Input_data_table/individual_user_input_widget.dart';
import 'package:flutter/material.dart';

class InputDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> account;
  const InputDataTable({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return CustomCommonPage(
        child: SingleChildScrollView(
            child: IndividualUserInput(account: account)));
  }
}
