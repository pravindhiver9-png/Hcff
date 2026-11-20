import 'package:intl/intl.dart';

num toNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
}

/// number -> plain string (5.0 -> "5")
String ns(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);
String rs(num v) => '₹${ns(v)}';

DateTime? pd(dynamic v) {
  final s = '${v ?? ''}';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

String fd(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
String fds(dynamic v) => fd(pd(v));
String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String wa(DateTime d) => DateFormat('dd.MM.yyyy').format(d);
String errText(Object e) => e.toString().replaceFirst('Exception: ', '');

const hiMonths = [
  'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
  'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
];
const hiMonthsShort = [
  'जन', 'फ़र', 'मार्च', 'अप्र', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्टू', 'नव', 'दिस'
];

const _w = [
  'शून्य','एक','दो','तीन','चार','पाँच','छह','सात','आठ','नौ','दस','ग्यारह','बारह','तेरह','चौदह','पंद्रह','सोलह','सत्रह','अठारह','उन्नीस',
  'बीस','इक्कीस','बाईस','तेईस','चौबीस','पच्चीस','छब्बीस','सत्ताईस','अट्ठाईस','उनतीस','तीस','इकतीस','बत्तीस','तैंतीस','चौंतीस','पैंतीस','छत्तीस','सैंतीस','अड़तीस','उनतालीस',
  'चालीस','इकतालीस','बयालीस','तैंतालीस','चवालीस','पैंतालीस','छियालीस','सैंतालीस','अड़तालीस','उनचास','पचास','इक्यावन','बावन','तिरपन','चौवन','पचपन','छप्पन','सत्तावन','अट्ठावन','उनसठ',
  'साठ','इकसठ','बासठ','तिरसठ','चौंसठ','पैंसठ','छियासठ','सड़सठ','अड़सठ','उनहत्तर','सत्तर','इकहत्तर','बहत्तर','तिहत्तर','चौहत्तर','पचहत्तर','छिहत्तर','सतहत्तर','अठहत्तर','उनासी',
  'अस्सी','इक्यासी','बयासी','तिरासी','चौरासी','पचासी','छियासी','सत्तासी','अट्ठासी','नवासी','नब्बे','इक्यानवे','बानवे','तिरानवे','चौरानवे','पंचानवे','छियानवे','सत्तानवे','अट्ठानवे','निन्यानवे',
];

String amountInWords(num value) {
  var n = value.round();
  if (n == 0) return 'शून्य रुपये मात्र';
  final cr = n ~/ 10000000; n %= 10000000;
  final lk = n ~/ 100000; n %= 100000;
  final th = n ~/ 1000; n %= 1000;
  final parts = <String>[];
  if (cr > 0) parts.add('${_w[cr % 100]} करोड़');
  if (lk > 0) parts.add('${_w[lk]} लाख');
  if (th > 0) parts.add('${_w[th]} हज़ार');
  final h = n ~/ 100, r = n % 100;
  if (h > 0) parts.add('${_w[h]} सौ');
  if (r > 0) parts.add(_w[r]);
  return '${parts.join(' ')} रुपये मात्र';
}
