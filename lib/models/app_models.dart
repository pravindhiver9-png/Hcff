double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime _dt(dynamic v) => DateTime.parse(v as String);

class Member {
  String id, name, mobile, loginId, password, role; // admin | coadmin | member
  Member({required this.id, required this.name, required this.mobile, required this.loginId, required this.password, required this.role});
  bool get isAdmin => role == 'admin';
  bool get canEdit => role == 'admin' || role == 'coadmin';
  String get roleLabel => role == 'admin' ? 'Admin' : role == 'coadmin' ? 'Co-Admin' : 'Member';
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mobile': mobile, 'loginId': loginId, 'password': password, 'role': role};
  factory Member.fromJson(Map<String, dynamic> j) => Member(id: j['id'], name: j['name'], mobile: j['mobile'] ?? '', loginId: j['loginId'] ?? '', password: j['password'] ?? '', role: j['role'] ?? 'member');
}

class Loan {
  String id;
  String? memberId; // null = बाहरी व्यक्ति
  String borrower;
  double principal;
  DateTime date;
  double rate; // % प्रति माह
  double interestPaid, principalPaid;
  DateTime? repayDate;
  String status; // सक्रिय | पूर्ण जमा
  String note;
  String? parentId; // रोलओवर से बनी एंट्री
  Loan({required this.id, this.memberId, required this.borrower, required this.principal, required this.date, required this.rate, this.interestPaid = 0, this.principalPaid = 0, this.repayDate, this.status = 'सक्रिय', this.note = '', this.parentId});
  bool get active => status == 'सक्रिय';
  Map<String, dynamic> toJson() => {'id': id, 'memberId': memberId, 'borrower': borrower, 'principal': principal, 'date': date.toIso8601String(), 'rate': rate, 'interestPaid': interestPaid, 'principalPaid': principalPaid, 'repayDate': repayDate?.toIso8601String(), 'status': status, 'note': note, 'parentId': parentId};
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(id: j['id'], memberId: j['memberId'], borrower: j['borrower'], principal: _d(j['principal']), date: _dt(j['date']), rate: _d(j['rate']), interestPaid: _d(j['interestPaid']), principalPaid: _d(j['principalPaid']), repayDate: j['repayDate'] == null ? null : _dt(j['repayDate']), status: j['status'] ?? 'सक्रिय', note: j['note'] ?? '', parentId: j['parentId']);
}

class MasikJama {
  String id, memberId, month; // month = yyyy-MM
  double amount;
  DateTime date;
  MasikJama({required this.id, required this.memberId, required this.month, required this.amount, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'memberId': memberId, 'month': month, 'amount': amount, 'date': date.toIso8601String()};
  factory MasikJama.fromJson(Map<String, dynamic> j) => MasikJama(id: j['id'], memberId: j['memberId'], month: j['month'], amount: _d(j['amount']), date: _dt(j['date']));
}

/// खर्च और अतिरिक्त राशि दोनों के लिए
class MoneyEntry {
  String id, note;
  double amount;
  DateTime date;
  MoneyEntry({required this.id, required this.amount, required this.date, this.note = ''});
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'date': date.toIso8601String(), 'note': note};
  factory MoneyEntry.fromJson(Map<String, dynamic> j) => MoneyEntry(id: j['id'], amount: _d(j['amount']), date: _dt(j['date']), note: j['note'] ?? '');
}

typedef Kharch = MoneyEntry;
typedef Atirikt = MoneyEntry;

class Vitran {
  String id, memberId, note;
  double share, loanSettled;
  DateTime date;
  Vitran({required this.id, required this.memberId, required this.share, required this.loanSettled, required this.date, this.note = ''});
  double get net => share - loanSettled;
  Map<String, dynamic> toJson() => {'id': id, 'memberId': memberId, 'share': share, 'loanSettled': loanSettled, 'date': date.toIso8601String(), 'note': note};
  factory Vitran.fromJson(Map<String, dynamic> j) => Vitran(id: j['id'], memberId: j['memberId'], share: _d(j['share']), loanSettled: _d(j['loanSettled']), date: _dt(j['date']), note: j['note'] ?? '');
}
