// Google Sheet में: Extensions → Apps Script → यह कोड चिपकाएँ → Deploy → New deployment
// Type: Web app | Execute as: Me | Who has access: Anyone → मिले URL को ऐप की Settings में डालें।

function doPost(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var raw = e.postData.contents;
  var data = JSON.parse(raw);

  // 1) पूरा बैकअप (रीस्टोर के लिए) — 40000 अक्षरों के टुकड़ों में
  var b = ss.getSheetByName('Backup') || ss.insertSheet('Backup');
  b.clear();
  var rows = [];
  for (var i = 0; i < raw.length; i += 40000) rows.push([raw.substring(i, i + 40000)]);
  b.getRange(1, 1, rows.length, 1).setValues(rows);

  // 2) पढ़ने लायक शीट
  var name = {};
  data.members.forEach(function (m) { name[m.id] = m.name; });
  write(ss, 'Udhar', ['नाम', 'मूलधन', 'दिनांक', 'दर %', 'ब्याज जमा', 'मूलधन जमा', 'जमा दिनांक', 'स्थिति', 'नोट'],
    data.loans.map(function (l) { return [l.borrower, l.principal, l.date.substring(0, 10), l.rate, l.interestPaid, l.principalPaid, l.repayDate ? l.repayDate.substring(0, 10) : '', l.status, l.note]; }));
  write(ss, 'MasikJama', ['सदस्य', 'महीना', 'राशि', 'दिनांक'],
    data.jama.map(function (j) { return [name[j.memberId] || '', j.month, j.amount, j.date.substring(0, 10)]; }));
  write(ss, 'Kharch', ['दिनांक', 'राशि', 'विवरण'],
    data.kharch.map(function (k) { return [k.date.substring(0, 10), k.amount, k.note]; }));
  write(ss, 'Atirikt', ['दिनांक', 'राशि', 'विवरण'],
    data.atirikt.map(function (k) { return [k.date.substring(0, 10), k.amount, k.note]; }));
  write(ss, 'Vitran', ['सदस्य', 'दिनांक', 'हिस्सा', 'उधार समायोजन', 'नेट'],
    data.vitran.map(function (v) { return [name[v.memberId] || '', v.date.substring(0, 10), v.share, v.loanSettled, v.share - v.loanSettled]; }));

  return ContentService.createTextOutput('ok');
}

function doGet(e) {
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Backup');
  if (!sh || sh.getLastRow() == 0) return ContentService.createTextOutput('{}');
  var v = sh.getRange(1, 1, sh.getLastRow(), 1).getValues();
  return ContentService.createTextOutput(v.map(function (r) { return r[0]; }).join(''));
}

function write(ss, title, head, rows) {
  var sh = ss.getSheetByName(title) || ss.insertSheet(title);
  sh.clear();
  sh.getRange(1, 1, 1, head.length).setValues([head]).setFontWeight('bold');
  if (rows.length) sh.getRange(2, 1, rows.length, head.length).setValues(rows);
}
