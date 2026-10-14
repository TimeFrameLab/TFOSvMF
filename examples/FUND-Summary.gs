/**
 * Validate mutual-fund identifiers and write a separate FUND-Summary tab.
 * This optional manual example does not fetch NAV or modify the source tab.
 */

const TFOSVMF_SOURCE_SHEET = "All-ThaiMutualFunds-MTFS";
const TFOSVMF_SUMMARY_SHEET = "FUND-Summary";
const TFOSVMF_SOURCE_HEADERS = ["AKA", "PROJECT ID"];
const TFOSVMF_SUMMARY_HEADERS = ["AKA (Finnomena)", "PROJECT ID"];
const TFOSVMF_CODE_PATTERN = /^(?=.{1,40}$)[A-Za-z0-9](?:[A-Za-z0-9._&()\/#-]| [A-Za-z0-9._&()\/#-])*$/;

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("TFOSvMF | FUND")
    .addItem("สร้าง/ตรวจหัวตาราง Summary", "setupFundSummary")
    .addItem("อัปเดต FUND-Summary", "refreshFundSummary")
    .addToUi();
}

function setupFundSummary() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let summary = spreadsheet.getSheetByName(TFOSVMF_SUMMARY_SHEET);
  if (!summary) {
    summary = spreadsheet.insertSheet(TFOSVMF_SUMMARY_SHEET);
  }

  const lastRow = summary.getLastRow();
  const lastColumn = summary.getLastColumn();
  if (lastRow === 0 && lastColumn === 0) {
    summary.getRange(1, 1, 1, TFOSVMF_SUMMARY_HEADERS.length)
      .setValues([TFOSVMF_SUMMARY_HEADERS]);
  } else {
    if (lastColumn !== TFOSVMF_SUMMARY_HEADERS.length) {
      throw new Error(
        'แท็บ "' + TFOSVMF_SUMMARY_SHEET +
        '" มีข้อมูลอยู่และจำนวนคอลัมน์ไม่ตรง schema; ไม่มีการแก้ไขข้อมูล'
      );
    }
    const existingHeaders = summary.getRange(1, 1, 1, lastColumn).getDisplayValues()[0];
    if (existingHeaders.some((header, index) => header !== TFOSVMF_SUMMARY_HEADERS[index])) {
      throw new Error(
        'หัวตาราง "' + TFOSVMF_SUMMARY_SHEET +
        '" ไม่ตรง schema; ไม่มีการแก้ไขข้อมูล'
      );
    }
  }

  summary.setFrozenRows(1);
  summary.getRange(1, 1, 1, TFOSVMF_SUMMARY_HEADERS.length)
    .setFontWeight("bold")
    .setBackground("#1F4E79")
    .setFontColor("#FFFFFF");
  summary.autoResizeColumns(1, TFOSVMF_SUMMARY_HEADERS.length);
}

function refreshFundSummary() {
  const lock = LockService.getDocumentLock();
  if (!lock.tryLock(1000)) {
    throw new Error("มีการอัปเดต FUND-Summary ทำงานอยู่แล้ว; รอบนี้ไม่ได้เริ่ม");
  }

  try {
    const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    const source = spreadsheet.getSheetByName(TFOSVMF_SOURCE_SHEET);
    if (!source) {
      throw new Error('ไม่พบแท็บต้นทาง "' + TFOSVMF_SOURCE_SHEET + '"');
    }

    const values = source.getDataRange().getValues();
    if (!values.length) {
      throw new Error('แท็บต้นทาง "' + TFOSVMF_SOURCE_SHEET + '" ว่าง');
    }
    const headers = values[0].map((value) => String(value || "").trim().toUpperCase());
    const indexes = {};
    headers.forEach((header, index) => {
      if (header && Object.prototype.hasOwnProperty.call(indexes, header)) {
        throw new Error('หัวคอลัมน์ "' + header + '" ซ้ำในแท็บต้นทาง');
      }
      if (header) indexes[header] = index;
    });
    const missing = TFOSVMF_SOURCE_HEADERS.filter(
      (header) => !Object.prototype.hasOwnProperty.call(indexes, header)
    );
    if (missing.length) {
      throw new Error("ขาดหัวคอลัมน์ต้นทาง: " + missing.join(", "));
    }

    const errors = [];
    const seen = new Set();
    const records = [];
    values.slice(1).forEach((row, index) => {
      if (row.every((value) => value === "" || value === null)) return;
      const rowNumber = index + 2;
      const code = String(row[indexes.AKA] || "").trim();
      const normalized = code.toUpperCase();
      if (!TFOSVMF_CODE_PATTERN.test(code)) {
        errors.push("แถว " + rowNumber + ": AKA ว่างหรือรูปแบบไม่ถูกต้อง");
      } else if (seen.has(normalized)) {
        errors.push("แถว " + rowNumber + ": AKA " + code + " ซ้ำ");
      } else {
        seen.add(normalized);
        records.push({
          code: code,
          projectId: String(row[indexes["PROJECT ID"]] || "").trim()
        });
      }
    });
    if (errors.length) {
      throw new Error(errors.join("\n"));
    }
    if (!records.length) {
      throw new Error("ไม่พบแถวกองทุนที่มี AKA");
    }

    setupFundSummary();
    const summary = spreadsheet.getSheetByName(TFOSVMF_SUMMARY_SHEET);
    const output = records.map((record) => [record.code, record.projectId]);
    const requiredRows = output.length + 1;
    if (summary.getMaxRows() < requiredRows) {
      summary.insertRowsAfter(summary.getMaxRows(), requiredRows - summary.getMaxRows());
    }
    const oldLastRow = summary.getLastRow();
    if (oldLastRow > 1) {
      summary.getRange(2, 1, oldLastRow - 1, TFOSVMF_SUMMARY_HEADERS.length).clearContent();
    }
    summary.getRange(2, 1, output.length, TFOSVMF_SUMMARY_HEADERS.length).setValues(output);
    const fundLinks = records.map((record) => [
      SpreadsheetApp.newRichTextValue()
        .setText(record.code)
        .setLinkUrl("https://www.finnomena.com/fund/" + encodeURIComponent(record.code) + "/graph")
        .build()
    ]);
    summary.getRange(2, 1, fundLinks.length, 1).setRichTextValues(fundLinks);
  } finally {
    lock.releaseLock();
  }
}
