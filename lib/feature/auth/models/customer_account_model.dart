import 'dart:math';

class CustomerAccountModel {
  final int totalRecord;
  final int rowNo;
  final String id;
  final int clientId;
  final bool commonAc;
  final int brId;
  final String? brAlias;
  final int centerId;
  final String? centerName;
  final int mfGrpId;
  final String? mfGrpName;
  final int idenId;
  final String? idNo;
  final int accountId;
  final String acNo;
  final String acName;
  final String? pAddress;
  final String? tAddress;
  final String? addLocation;
  final String? contact;
  final int accountTypeId;
  final String accountTypeName;
  final int fieldOfficerId;
  final String fieldOfficerName;
  final dynamic acOpenDate;
  final int returnTypeId;
  final String? returnType;
  final double rateOfReturn;
  final double postFreq;
  final double colAmt;
  final double balance;
  final double instAmt;
  final String balDate;
  final double dueAmt;
  final dynamic maturityDate;
  final dynamic pbCheckDate;
  final bool closedStatus;
  final bool status;
  final String? remarks;
  final int insertUser;
  final dynamic insertDate;
  final int editUser;
  final dynamic editDate;

  CustomerAccountModel({
    required this.id,
    required this.acName,
    this.totalRecord = 0,
    this.rowNo = 0,
    this.clientId = 0,
    this.commonAc = false,
    this.brId = 0,
    this.brAlias,
    this.centerId = 0,
    this.centerName,
    this.mfGrpId = 0,
    this.mfGrpName,
    this.idenId = 0,
    this.idNo,
    this.accountId = 0,
    this.acNo = '',
    this.pAddress,
    this.tAddress,
    this.addLocation,
    this.contact,
    this.accountTypeId = 0,
    this.accountTypeName = '',
    this.fieldOfficerId = 0,
    this.fieldOfficerName = '',
    this.acOpenDate = '',
    this.returnTypeId = 0,
    this.returnType,
    this.rateOfReturn = 0.0,
    this.postFreq = 0.0,
    this.colAmt = 0.0,
    this.balance = 0.0,
    this.instAmt = 0.0,
    this.balDate = '',
    this.dueAmt = 0.0,
    this.maturityDate = '',
    this.pbCheckDate = '',
    this.closedStatus = false,
    this.status = false,
    this.remarks,
    this.insertUser = 0,
    this.insertDate = '',
    this.editUser = 0,
    this.editDate = '',
  });

  factory CustomerAccountModel.fromJson(Map<String, dynamic> json) {
    String idValue = json["id"]?.toString() ?? '';
    if (idValue.isEmpty) {
      idValue = 'ID${Random().nextInt(999999).toString().padLeft(6, '0')}';
    }
    String acNameValue = json["ac_name"]?.toString() ?? '';
    if (acNameValue.isEmpty) {
      acNameValue =
          'Account_${Random().nextInt(999999).toString().padLeft(6, '0')}';
    }

    dynamic parseDateTimeOrKeepOriginal(dynamic dateValue) {
      if (dateValue == null) {
        return '';
      }

      if (dateValue is DateTime) {
        return dateValue;
      }

      String dateStr = dateValue.toString();
      if (dateStr.isEmpty) {
        return '';
      }

      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return dateStr;
      }
    }

    return CustomerAccountModel(
      id: idValue,
      acName: acNameValue,
      totalRecord: json['total_record'] ?? 0,
      rowNo: json['row_no'] ?? 0,
      clientId: json["client_id"] ?? 0,
      commonAc: json["common_ac"] ?? false,
      brId: json["br_id"] ?? 0,
      brAlias: json["br_alias"]?.toString() ?? '',
      centerId: json["center_id"] ?? 0,
      centerName: json["center_name"]?.toString() ?? '',
      mfGrpId: json["mf_grp_id"] ?? 0,
      mfGrpName: json["mf_grp_name"]?.toString() ?? '',
      idenId: json["iden_id"] ?? 0,
      idNo: json["id_no"]?.toString() ?? '',
      accountId: json["account_id"] ?? 0,
      acNo: json["ac_no"] ?? '',
      pAddress: json["p_address"]?.toString() ?? '',
      tAddress: json["t_address"]?.toString() ?? '',
      addLocation: json["add_location"]?.toString() ?? '',
      contact: json["contact"]?.toString() ?? '',
      accountTypeId: json["account_type_id"] ?? 0,
      accountTypeName: json["account_type_name"] ?? '',
      fieldOfficerId: json["field_officer_id"] ?? 0,
      fieldOfficerName: json["field_officer_name"] ?? '',
      acOpenDate: parseDateTimeOrKeepOriginal(json["ac_open_date"]),
      returnTypeId: json["return_type_id"] ?? 0,
      returnType: json["return_type"]?.toString() ?? '',
      rateOfReturn: (json["rate_of_return"] ?? 0.0).toDouble(),
      postFreq: (json["post_freq"] ?? 0.0).toDouble(),
      colAmt: (json["col_amt"] ?? 0.0).toDouble(),
      balance: (json["balance"] ?? 0.0).toDouble(),
      instAmt: (json["inst_amt"] ?? 0.0).toDouble(),
      balDate: json["bal_date"] ?? '',
      dueAmt: (json["due_amt"] ?? 0.0).toDouble(),
      maturityDate: parseDateTimeOrKeepOriginal(json["maturity_date"]),
      pbCheckDate: parseDateTimeOrKeepOriginal(json["pb_check_date"]),
      closedStatus: json["closed_status"] ?? false,
      status: json["status"] ?? false,
      remarks: json["remarks"]?.toString() ?? '',
      insertUser: json["insert_user"] ?? 0,
      insertDate: parseDateTimeOrKeepOriginal(json["insert_date"]),
      editUser: json["edit_user"] ?? 0,
      editDate: parseDateTimeOrKeepOriginal(json["edit_date"]),
    );
  }

  Map<String, dynamic> toJson() {
    dynamic formatDateOrKeepOriginal(dynamic date) {
      if (date == null) {
        return '';
      }
      if (date is DateTime) {
        try {
          return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        } catch (e) {
          return '';
        }
      }
      return date.toString();
    }

    return {
      "total_record": totalRecord,
      "row_no": rowNo,
      "id": id,
      "client_id": clientId,
      "common_ac": commonAc,
      "br_id": brId,
      "br_alias": brAlias ?? '',
      "center_id": centerId,
      "center_name": centerName ?? '',
      "mf_grp_id": mfGrpId,
      "mf_grp_name": mfGrpName ?? '',
      "iden_id": idenId,
      "id_no": idNo ?? '',
      "account_id": accountId,
      "ac_no": acNo,
      "ac_name": acName,
      "p_address": pAddress ?? '',
      "t_address": tAddress ?? '',
      "add_location": addLocation ?? '',
      "contact": contact ?? '',
      "account_type_id": accountTypeId,
      "account_type_name": accountTypeName,
      "field_officer_id": fieldOfficerId,
      "field_officer_name": fieldOfficerName,
      "ac_open_date": formatDateOrKeepOriginal(acOpenDate),
      "return_type_id": returnTypeId,
      "return_type": returnType ?? '',
      "rate_of_return": rateOfReturn,
      "post_freq": postFreq,
      "col_amt": colAmt,
      "balance": balance,
      "inst_amt": instAmt,
      "bal_date": balDate,
      "due_amt": dueAmt,
      "maturity_date": formatDateOrKeepOriginal(maturityDate),
      "pb_check_date": formatDateOrKeepOriginal(pbCheckDate),
      "closed_status": closedStatus,
      "status": status,
      "remarks": remarks ?? '',
      "insert_user": insertUser,
      "insert_date": formatDateOrKeepOriginal(insertDate),
      "edit_user": editUser,
      "edit_date": formatDateOrKeepOriginal(editDate),
    };
  }
}
