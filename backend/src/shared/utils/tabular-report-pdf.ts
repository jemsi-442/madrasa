import PDFDocument from 'pdfkit';
import { reportAsset, reportLogo } from './report-brand';

// Reads CSV produced by our existing scoped export services, including quoted newlines.
export function reportCsvRows(csv: string): string[][] {
  const rows: string[][] = []; let row: string[] = [], cell = '', quoted = false;
  for (let i = 0; i < csv.length; i++) {
    const c = csv[i];
    if (c === '"') {
      if (quoted && csv[i + 1] === '"') { cell += '"'; i++; }
      else quoted = !quoted;
    } else if (c === ',' && !quoted) { row.push(cell); cell = ''; }
    else if (c === '\n' && !quoted) { row.push(cell.replace(/\r$/, '')); rows.push(row); row = []; cell = ''; }
    else cell += c;
  }
  if (cell || row.length) { row.push(cell.replace(/\r$/, '')); rows.push(row); }
  return rows;
}

export type ReportLayout = {
  metadata?: { label: string; value: string }[];
  notes?: string[];
  columnWeights?: number[];
};

export function tabularReportPdf(title: string, subtitle: string, columns: string[], rows: string[][], layout: ReportLayout = {}): Promise<Buffer> {
  return new Promise((done, reject) => {
    const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 36, bufferPages: true,
      info: { Title: title, Author: 'Afaq' } });
    const chunks: Buffer[] = [];
    doc.on('data', c => chunks.push(c)); doc.on('error', reject); doc.on('end', () => done(Buffer.concat(chunks)));
    doc.registerFont('body', reportAsset('fonts/DejaVuSans.ttf'));
    doc.registerFont('bold', reportAsset('fonts/DejaVuSans-Bold.ttf'));
    const width = doc.page.width - 72;
    const weights = columns.map((_, i) => Math.max(1, layout.columnWeights?.[i] ?? 1));
    const totalWeight = weights.reduce((sum, value) => sum + value, 0);
    const widths = weights.map(value => width * value / totalWeight);
    const positions = widths.map((_, i) => 36 + widths.slice(0, i).reduce((sum, value) => sum + value, 0));
    let y = 0;
    const wrap = (raw: string, column: number): string[] => {
      const lines: string[] = [];
      for (const paragraph of raw.split(/\r?\n/)) {
        let line = '';
        for (const word of paragraph.split(/\s+/)) {
          const candidate = line ? `${line} ${word}` : word;
          if (doc.widthOfString(candidate) <= widths[column]! - 14) { line = candidate; continue; }
          if (line) { lines.push(line); line = ''; }
          // Only split a token when it cannot fit on a line by itself.
          for (const char of word) {
            if (line && doc.widthOfString(line + char) > widths[column]! - 14) { lines.push(line); line = ''; }
            line += char;
          }
        }
        lines.push(line);
      }
      return lines;
    };
    const page = (includeTable = true) => {
      doc.font('bold').fontSize(18);
      const subtitleY = Math.max(61, 28 + doc.heightOfString(title, { width: width - 170 }) + 8);
      doc.font('body').fontSize(9);
      const headerHeight = Math.max(100, subtitleY + doc.heightOfString(subtitle, { width: width - 170 }) + 16);
      doc.rect(0, 0, doc.page.width, headerHeight).fill('#122336');
      doc.rect(0, headerHeight, doc.page.width, 4).fill('#B18D2C'); reportLogo(doc, 36, 16, 120);
      doc.font('bold').fontSize(18).fillColor('#FFFFFF').text(title, 205, 28, { width: width - 170 });
      doc.font('body').fontSize(9).fillColor('#E4D39D').text(subtitle, 205, subtitleY, { width: width - 170 });
      y = headerHeight + 25;
      if (layout.metadata?.length) {
        const cellWidth = width / layout.metadata.length;
        doc.font('body').fontSize(10);
        const height = Math.max(...layout.metadata.map(item => doc.heightOfString(item.value, { width: cellWidth - 28 }))) + 42;
        layout.metadata.forEach((item, i) => {
          const x = 36 + i * cellWidth;
          doc.roundedRect(x, y, cellWidth - 10, height, 6).fill('#F3F5F7');
          doc.font('bold').fontSize(8).fillColor('#63758A').text(item.label.toUpperCase(), x + 12, y + 12, { width: cellWidth - 28 });
          doc.font('body').fontSize(10).fillColor('#122336').text(item.value, x + 12, y + 30, { width: cellWidth - 28 });
        });
        y += height + 22;
      }
      if (!includeTable) return;
      doc.font('bold').fontSize(8);
      const labels = columns.map(wrap), height = Math.max(...labels.map(c => c.length), 1) * 11 + 14;
      doc.rect(36, y, width, height).fill('#122336');
      labels.forEach((lines, i) => lines.forEach((line, n) => doc.fillColor('#FFFFFF').text(line, positions[i]! + 7, y + 7 + n * 11, { lineBreak: false })));
      y += height;
      doc.font('body').fontSize(8);
    };
    page();
    if (!rows.length) rows = [['No records for this selection.']];
    rows.forEach((row, index) => {
      doc.font('body').fontSize(8);
      const cells = columns.map((_, i) => wrap(row[i] ?? '', i));
      let offset = 0, remaining = Math.max(1, ...cells.map(c => c.length));
      const rowPadding = layout.metadata ? 10 : 14;
      while (remaining > 0) {
        if (y + 25 > 530) { doc.addPage(); page(); }
        const count = Math.min(remaining, Math.max(1, Math.floor((530 - y - rowPadding) / 11)));
        const height = count * 11 + rowPadding;
        doc.rect(36, y, width, height).fill(index % 2 ? '#FFFFFF' : '#F3F5F7');
        cells.forEach((lines, i) => lines.slice(offset, offset + count).forEach((line, n) =>
          doc.fillColor('#122336').text(line, positions[i]! + 7, y + 7 + n * 11, { lineBreak: false })));
        y += height; offset += count; remaining -= count;
      }
    });
    if (layout.notes?.length) {
      doc.font('body').fontSize(9);
      const heights = layout.notes.map(text => doc.heightOfString(text, { width: width - 40 }) + 4);
      const height = 32 + heights.reduce((sum, value) => sum + value, 0);
      if (y + height + 12 > 530) { doc.addPage(); page(false); }
      y += 12;
      doc.roundedRect(36, y, width, height, 6).fill('#F8F2E3');
      doc.font('bold').fontSize(10).fillColor('#8B6B23').text('How to read this report', 50, y + 12);
      let noteY = y + 28;
      layout.notes.forEach((text, i) => {
        doc.font('body').fontSize(9).fillColor('#526477').text(`${i + 1}.`, 50, noteY, { lineBreak: false });
        doc.text(text, 66, noteY, { width: width - 40 });
        noteY += heights[i]!;
      });
    }
    const pages = doc.bufferedPageRange();
    for (let i = 0; i < pages.count; i++) {
      doc.switchToPage(i);
      doc.moveTo(36, 550).lineTo(doc.page.width - 36, 550).strokeColor('#DDE3E8').stroke();
      doc.font('body').fontSize(8).fillColor('#63758A').text('Afaq | Read-only snapshot | Share only with authorized recipients', 36, 562, { lineBreak: false });
      doc.text(`Page ${i + 1} of ${pages.count}`, doc.page.width - 115, 562, { lineBreak: false });
    }
    doc.end();
  });
}
