import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Apps Script Web App के साथ सिंक।
/// ऑफ़लाइन होने पर Store 'pending' चिह्न रखता है और नेट आते ही पूरा डेटा दोबारा भेज देता है।
class SheetSyncService {
  static Future<bool> push(String url, String body) async {
    try {
      final r = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: body)
          .timeout(const Duration(seconds: 25));
      return r.statusCode >= 200 && r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> pull(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) return utf8.decode(r.bodyBytes);
    } catch (_) {}
    return null;
  }
}
