# हमारी चिट फंड फैमिली 2.0

Flutter (Android) + Google Sheets + Google Apps Script. 100% free.

## 1) Google Sheet + Apps Script
1. नई Google Sheet बनाएँ -> Extensions -> Apps Script.
2. `backend/Code.gs` का पूरा code paste करें, Save.
3. Editor में function `setup` चुनकर **Run** करें (permissions Allow करें). यह सभी tabs/headers बनाता है
   और पहला Admin जोड़ता है: Member_ID `HCFF2-01`, PIN `1234` (Members tab में बदल लें).
4. Deploy -> New deployment -> Web app -> Execute as: **Me**, Who has access: **Anyone** -> Deploy.
5. मिला हुआ `.../exec` URL कॉपी करें।

## 2) APK (GitHub Actions, free)
1. यह पूरा folder एक GitHub repo में push करें (branch `main`).
2. Actions tab -> *Build APK* चलता है (या Run workflow).
3. Run खुलने पर Artifacts -> `hamari-chit-fund-apk` -> `app-release.apk` डाउनलोड करें।
   (Android folder workflow खुद बनाता है।)

## 3) पहला login
App खोलें -> Apps Script URL पेस्ट करें -> `HCFF2-01` / `1234` -> अपना 4 अंकों का mPIN सेट करें।

## Notes
- Sheet headers English keys में हैं (code इन्हीं पर चलता है); app UI पूरा Hindi है।
- ब्याज का अनुमान: मूलधन x दर% x दिन / 30 (अंतिम ब्याज हमेशा हाथ से लिखा जाता है).
- कुल फंड = कुल जमा (मैट्रिक्स + एडवांस) + ब्याज + अतिरिक्त - खर्च - वितरण - सक्रिय उधार.
- Dark theme के रंग इसी code में तय किए गए हैं (`lib/core/palette.dart`).
- PDF Flutter widgets से बनते हैं (हिन्दी सही दिखती है). सिर्फ Statement PDF में मोबाइल नंबर दिखता है.
