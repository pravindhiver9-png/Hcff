/**
 * हमारी चिट फंड फैमिली 2.0 - Google Apps Script backend (Web App API)
 * Bound to the Google Sheet. Run setup() ONCE from the editor, then deploy as
 * Web app: Execute as = Me, Who has access = Anyone.
 */
const TABS = {
  Members: ['No', 'Member_ID', 'First_Name', 'Surname', 'Full_Name', 'Mobile_No', 'Initial_PIN', 'MPIN_Set', 'Role', 'Status', 'Advance_Balance'],
  Monthly_Jama: ['Member_ID', 'Name', 'Year', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7', 'M8', 'M9', 'M10', 'M11', 'M12', 'Total'],
  Udhar_Khata: ['Loan_ID', 'Name', 'Mobile', 'Principal', 'Date', 'Rate', 'Final_Interest', 'Interest_Paid', 'Principal_Paid', 'Total_Paid', 'Return_Date', 'Status', 'Carry_Interest', 'Note'],
  Kharch: ['ID', 'Date', 'Details', 'Amount'],
  Atirikt_Rashi: ['ID', 'Date', 'Amount', 'Note'],
  Paisa_Vitran: ['ID', 'Date', 'Total_Amount', 'Per_Member', 'Member_ID', 'Member_Name', 'Adjustment', 'Final_Amount'],
  Jama_Log: ['ID', 'Date', 'Member_ID', 'Name', 'Month_Label', 'Amount'],
  Settings: ['Key', 'Value']
};
const ID_KEY = { Members: 'Member_ID', Udhar_Khata: 'Loan_ID', Kharch: 'ID', Atirikt_Rashi: 'ID', Paisa_Vitran: 'ID', Jama_Log: 'ID' };
const WRITABLE = Object.keys(ID_KEY);
const TEXT_COLS = ['Member_ID', 'First_Name', 'Surname', 'Full_Name', 'Mobile_No', 'Mobile', 'Initial_PIN', 'MPIN_Set', 'Role', 'Status',
  'Name', 'Date', 'Return_Date', 'Note', 'Details', 'Month_Label', 'Member_Name', 'Key', 'Value'];
const DEFAULT_SETTINGS = { Monthly_Jama: '200', Member_Rate: '2', NonMember_Rate: '5', Group_Start: '2025-02', Backup_List: '[]' };

/** Run once from the Apps Script editor. Creates tabs, headers and a first Admin. */
function setup() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  Object.keys(TABS).forEach(function (name) {
    let sh = ss.getSheetByName(name) || ss.insertSheet(name);
    const h = TABS[name];
    sh.getRange(1, 1, 1, h.length).setValues([h]).setFontWeight('bold').setBackground('#1C5238').setFontColor('#FFFFFF');
    sh.setFrozenRows(1);
    h.forEach(function (col, i) {
      if (TEXT_COLS.indexOf(col) >= 0) sh.getRange(2, i + 1, sh.getMaxRows() - 1, 1).setNumberFormat('@');
    });
  });
  const st = ss.getSheetByName('Settings');
  if (st.getLastRow() < 2) {
    st.getRange(2, 1, Object.keys(DEFAULT_SETTINGS).length, 2).setValues(Object.keys(DEFAULT_SETTINGS).map(function (k) { return [k, DEFAULT_SETTINGS[k]]; }));
  }
  const mem = ss.getSheetByName('Members');
  if (mem.getLastRow() < 2) {
    mem.getRange(2, 1, 1, 11).setValues([[1, 'HCFF2-01', 'Admin', 'User', 'Admin User', '', '1234', '', 'Admin', 'सक्रिय', 0]]);
  }
  const def = ss.getSheetByName('Sheet1');
  if (def && ss.getSheets().length > 1 && def.getLastRow() === 0) ss.deleteSheet(def);
}

function doGet() { return ContentService.createTextOutput('OK'); }

function doPost(e) {
  let out;
  try { out = route_(JSON.parse(e.postData.contents)); }
  catch (err) { out = { ok: false, error: String(err && err.message ? err.message : err) }; }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function route_(r) {
  switch (r.action) {
    case 'login': return login_(r);
    case 'getAll': return getAll_(auth_(r));
    case 'batch': { const me = auth_(r); needWrite_(me); return locked_(function () { return batch_(r.ops || []); }); }
    case 'saveSettings': { const me = auth_(r); needWrite_(me); return locked_(function () { return saveSettings_(r.settings || {}); }); }
    case 'mpinSet': { const me = auth_(r); return locked_(function () { setCell_('Members', 'Member_ID', me.Member_ID, 'MPIN_Set', 'हाँ'); return { ok: true }; }); }
    case 'backup': { const me = auth_(r); needWrite_(me); return locked_(backup_); }
    case 'listBackups': { const me = auth_(r); needWrite_(me); return { ok: true, backups: JSON.parse(getSetting_('Backup_List') || '[]') }; }
    case 'restore': { const me = auth_(r); needWrite_(me); return locked_(function () { return restore_(r.id); }); }
  }
  throw new Error('अमान्य अनुरोध');
}

// ---------- helpers ----------
function ss_() { return SpreadsheetApp.getActiveSpreadsheet(); }
function locked_(fn) {
  const lock = LockService.getScriptLock();
  lock.waitLock(25000);
  try { return fn(); } finally { lock.releaseLock(); }
}
function norm_(v) {
  if (v instanceof Date) return Utilities.formatDate(v, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  return v;
}
function headers_(sh) { return sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0]; }
function readRows_(name) {
  const sh = ss_().getSheetByName(name);
  if (!sh || sh.getLastRow() < 2) return [];
  const v = sh.getDataRange().getValues();
  const h = v.shift();
  const out = [];
  v.forEach(function (row, i) {
    if (!row.some(function (c) { return c !== ''; })) return;
    const o = {};
    h.forEach(function (k, j) { o[k] = norm_(row[j]); });
    out.push(o);
  });
  return out;
}
function pub_(m) { const o = {}; Object.keys(m).forEach(function (k) { if (k !== 'Initial_PIN') o[k] = m[k]; }); return o; }
function needWrite_(me) { if (me.Role !== 'Admin' && me.Role !== 'Co-Admin') throw new Error('इस कार्य की अनुमति नहीं है'); }

function auth_(r) {
  const m = readRows_('Members').filter(function (x) { return String(x.Member_ID) === String(r.memberId); })[0];
  if (!m || String(m.Initial_PIN) !== String(r.pin) || m.Status === 'निष्क्रिय') throw new Error('अनधिकृत - कृपया दोबारा लॉगिन करें');
  return m;
}

function login_(r) {
  const id = String(r.id || '').trim(), pin = String(r.pin || '').trim();
  const digits = id.replace(/\D/g, '').slice(-10);
  const hits = readRows_('Members').filter(function (m) {
    const byId = String(m.Member_ID).toLowerCase() === id.toLowerCase();
    const byMob = digits.length === 10 && String(m.Mobile_No).replace(/\D/g, '').slice(-10) === digits;
    return (byId || byMob) && String(m.Initial_PIN) === pin && m.Status !== 'निष्क्रिय';
  });
  if (!hits.length) throw new Error('मोबाइल / Member ID या PIN गलत है');
  if (hits.length > 1) return { ok: true, accounts: hits.map(function (m) { return { Member_ID: m.Member_ID, Full_Name: m.Full_Name }; }) };
  return { ok: true, member: pub_(hits[0]) };
}

function getSettings_() {
  const o = {};
  readRows_('Settings').forEach(function (r) { o[r.Key] = r.Value; });
  return o;
}
function getSetting_(k) { return getSettings_()[k]; }

function getAll_(me) {
  const data = {};
  ['Members', 'Monthly_Jama', 'Udhar_Khata', 'Kharch', 'Atirikt_Rashi', 'Paisa_Vitran', 'Jama_Log'].forEach(function (n) { data[n] = readRows_(n); });
  const canWrite = me.Role === 'Admin' || me.Role === 'Co-Admin';
  if (!canWrite) data.Members = data.Members.map(pub_); // members never see PINs
  const st = getSettings_(); delete st.Backup_List;
  return { ok: true, data: data, settings: st, me: pub_(me) };
}

function nextId_(sh, idCol) {
  const last = sh.getLastRow();
  if (last < 2) return 1;
  const vals = sh.getRange(2, idCol, last - 1, 1).getValues();
  let max = 0;
  vals.forEach(function (r) { const n = Number(String(r[0]).replace(/\D/g, '')); if (n > max) max = n; });
  return max + 1;
}
function today_() { return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd'); }
function findRow_(sh, col, val) {
  const last = sh.getLastRow();
  if (last < 2) return -1;
  const vals = sh.getRange(2, col, last - 1, 1).getValues();
  for (let i = 0; i < vals.length; i++) if (String(vals[i][0]) === String(val)) return i + 2;
  return -1;
}
function setCell_(sheet, keyCol, keyVal, col, value) {
  const sh = ss_().getSheetByName(sheet), h = headers_(sh);
  const row = findRow_(sh, h.indexOf(keyCol) + 1, keyVal);
  if (row > 0) sh.getRange(row, h.indexOf(col) + 1).setValue(value);
}

// ---------- write operations ----------
function batch_(ops) {
  ops.forEach(function (op) {
    if (op.op === 'saveJama') return saveJama_(op.cells || [], op.advance || []);
    if (WRITABLE.indexOf(op.sheet) < 0) throw new Error('अमान्य शीट');
    if (op.op === 'add') addRow_(op.sheet, op.row);
    else if (op.op === 'update') updateRow_(op.sheet, op.id, op.row);
    else if (op.op === 'delete') deleteRow_(op.sheet, op.id);
    else throw new Error('अमान्य ऑपरेशन');
  });
  SpreadsheetApp.flush();
  return { ok: true };
}

function addRow_(name, row) {
  const sh = ss_().getSheetByName(name), h = headers_(sh);
  const idKey = ID_KEY[name];
  const r = Object.assign({}, row);
  const n = nextId_(sh, h.indexOf(idKey) + 1);
  if (name === 'Members') {
    r.No = n;
    r.Member_ID = 'HCFF2-' + (n < 10 ? '0' + n : n);
    r.Full_Name = (String(r.First_Name || '') + ' ' + String(r.Surname || '')).trim();
    r.Role = r.Role || 'Member';
    r.Status = r.Status || 'सक्रिय';
    r.Advance_Balance = r.Advance_Balance || 0;
    r.Initial_PIN = String(r.Initial_PIN || '1234');
  } else {
    r[idKey] = n;
  }
  if (name === 'Udhar_Khata') { r.Total_Paid = Number(r.Interest_Paid || 0) + Number(r.Principal_Paid || 0); }
  if (['Kharch', 'Atirikt_Rashi', 'Jama_Log'].indexOf(name) >= 0 && !r.Date) r.Date = today_();
  const arr = h.map(function (k) { return r[k] === undefined ? '' : r[k]; });
  const target = sh.getLastRow() + 1;
  sh.getRange(target, 1, 1, arr.length).setValues([arr]);
}

function updateRow_(name, id, row) {
  const sh = ss_().getSheetByName(name), h = headers_(sh);
  const idKey = ID_KEY[name];
  const rowIdx = findRow_(sh, h.indexOf(idKey) + 1, id);
  if (rowIdx < 0) throw new Error('रिकॉर्ड नहीं मिला');
  const cur = {};
  const vals = sh.getRange(rowIdx, 1, 1, h.length).getValues()[0];
  h.forEach(function (k, i) { cur[k] = vals[i]; });
  const r = Object.assign({}, row);
  delete r[idKey]; delete r.No;
  if (name === 'Members') {
    const f = r.First_Name !== undefined ? r.First_Name : cur.First_Name;
    const s = r.Surname !== undefined ? r.Surname : cur.Surname;
    r.Full_Name = (String(f) + ' ' + String(s)).trim();
    if (r.Initial_PIN !== undefined) r.Initial_PIN = String(r.Initial_PIN);
  }
  Object.keys(r).forEach(function (k) {
    const c = h.indexOf(k);
    if (c >= 0) sh.getRange(rowIdx, c + 1).setValue(r[k]);
  });
  if (name === 'Udhar_Khata') {
    const ip = r.Interest_Paid !== undefined ? r.Interest_Paid : cur.Interest_Paid;
    const pp = r.Principal_Paid !== undefined ? r.Principal_Paid : cur.Principal_Paid;
    sh.getRange(rowIdx, h.indexOf('Total_Paid') + 1).setValue(Number(ip || 0) + Number(pp || 0));
  }
}

function deleteRow_(name, id) {
  const sh = ss_().getSheetByName(name), h = headers_(sh);
  const rowIdx = findRow_(sh, h.indexOf(ID_KEY[name]) + 1, id);
  if (rowIdx > 0) sh.deleteRow(rowIdx);
}

/** cells: [{Member_ID, Name, Year, Month, Amount}] (Amount 0 clears) ; advance: [{Member_ID, Balance}] */
function saveJama_(cells, advance) {
  const sh = ss_().getSheetByName('Monthly_Jama'), h = headers_(sh);
  cells.forEach(function (c) {
    const vals = sh.getLastRow() > 1 ? sh.getRange(2, 1, sh.getLastRow() - 1, 3).getValues() : [];
    let row = -1;
    for (let i = 0; i < vals.length; i++) {
      if (String(vals[i][0]) === String(c.Member_ID) && Number(vals[i][2]) === Number(c.Year)) { row = i + 2; break; }
    }
    if (row < 0) {
      const blank = h.map(function (k) { return k === 'Member_ID' ? c.Member_ID : k === 'Name' ? c.Name : k === 'Year' ? c.Year : ''; });
      row = sh.getLastRow() + 1;
      sh.getRange(row, 1, 1, blank.length).setValues([blank]);
    }
    sh.getRange(row, 3 + Number(c.Month)).setValue(Number(c.Amount) > 0 ? Number(c.Amount) : '');
    const m = sh.getRange(row, 4, 1, 12).getValues()[0];
    sh.getRange(row, 16).setValue(m.reduce(function (a, b) { return a + (Number(b) || 0); }, 0));
  });
  advance.forEach(function (a) { setCell_('Members', 'Member_ID', a.Member_ID, 'Advance_Balance', Number(a.Balance)); });
}

function saveSettings_(obj) {
  const sh = ss_().getSheetByName('Settings');
  Object.keys(obj).forEach(function (k) {
    const row = findRow_(sh, 1, k);
    const v = String(obj[k]);
    if (row > 0) sh.getRange(row, 2).setValue(v); else sh.appendRow([k, v]);
  });
  return { ok: true };
}

// ---------- backup / restore ----------
function backup_() {
  const ss = ss_();
  const name = 'HCFF2_Backup_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd_HH-mm');
  const file = DriveApp.getFileById(ss.getId()).makeCopy(name);
  const list = JSON.parse(getSetting_('Backup_List') || '[]');
  list.push({ id: file.getId(), name: name });
  while (list.length > 20) list.shift();
  saveSettings_({ Backup_List: JSON.stringify(list) });
  return { ok: true, id: file.getId(), name: name };
}

function restore_(id) {
  const keep = getSetting_('Backup_List') || '[]';
  const src = SpreadsheetApp.openById(id), dst = ss_();
  Object.keys(TABS).forEach(function (name) {
    const s = src.getSheetByName(name), d = dst.getSheetByName(name);
    if (!s || !d) return;
    const v = s.getDataRange().getValues();
    d.getRange(2, 1, Math.max(d.getMaxRows() - 1, 1), d.getMaxColumns()).clearContent();
    if (v.length > 1) d.getRange(2, 1, v.length - 1, v[0].length).setValues(v.slice(1));
  });
  saveSettings_({ Backup_List: keep });
  return { ok: true };
}
