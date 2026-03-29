import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:collector_app/common/bloc/data_state.dart';
import 'package:collector_app/common/http/response.dart';
// import 'package:collector_app/feature/auth/models/customer_account_model.dart';
import 'package:collector_app/feature/auth/resources/user_repository.dart';
import 'package:collector_app/feature/database/database_service.dart';
import 'package:uuid/uuid.dart';

class PushDataCubit extends Cubit<CommonState> {
  PushDataCubit({required this.userRepository}) : super(CommonInitial());

  UserRepository userRepository;

  Future<void> pushData() async {
    emit(CommonLoading());
    try {
      final db = await DatabaseService().database;
      final List<Map<String, dynamic>> accounts = await db.query(
        'cd_accounts',
        where: 'input_amount > ?',
        whereArgs: [0.01],
      );

      String uniqueCollectionId = const Uuid().v4();

      final List<Map<String, dynamic>> filteredAccounts =
          accounts.map((account) {
        return {
          'br_id': account['br_id'],
          'account_id': account['account_id'],
          'account_type_id': account['account_type_id'],
          'ac_no': account['ac_no'],
          'col_amt': account['input_amount'],
          'return_type_id': account['return_type_id'],
          'col_remarks': account['col_remarks'],
          'col_date_time': account['col_date_time'],
          'col_location': account['col_location'],
          'collection_id': uniqueCollectionId,
        };
      }).toList();
      print("this is sent data: ${jsonEncode(filteredAccounts)}");
      if (accounts.isEmpty) {
        emit(const CommonError(
            message: "No accounts with input_amount found.", statusCode: 400));
        return;
      }
      final res = await userRepository.pushData(filteredAccounts);

      if (res.status == Status.Success) {
        final responseData = res.data["data"];
        final msg = responseData?["msg"];

        if (msg is String) {
          emit(CommonDataFetchSuccess<String>(data: [msg]));
        } else {
          emit(CommonError(
            message: "Unexpected response format: ${msg.runtimeType}",
            statusCode: 500,
          ));
        }
      }
    } catch (e) {
      print("Error pushing data: $e");
      emit(CommonError(message: e.toString(), statusCode: 500));
    }
  }
}
