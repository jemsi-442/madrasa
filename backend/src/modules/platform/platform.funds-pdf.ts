import PDFDocument from 'pdfkit';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import type { PlatformFundsService } from './platform.funds';
import { reportLogo } from '../../shared/utils/report-brand';

type Snapshot = Awaited<ReturnType<PlatformFundsService['overview']>>;
const navy = '#122336', gold = '#B18D2C', muted = '#63758A', pale = '#F7F6F1';
const amount = (value: string) => value.replace(/\B(?=(\d{3})+(?!\d))/g, ',');

export function fundsPdf(snapshot: Snapshot): Promise<Buffer> {
  return new Promise((complete, reject) => {
    const fonts = [resolve(__dirname, '../../../assets/fonts'), resolve(__dirname, '../../../../assets/fonts')]
      .find(path => existsSync(resolve(path, 'DejaVuSans.ttf')));
    if (!fonts) return reject(new Error('Report fonts are missing'));
    const doc = new PDFDocument({ size: 'A4', margin: 40, bufferPages: true,
      info: { Title: `Afaq financial summary - ${snapshot.month}`, Author: 'Afaq' } });
    const chunks: Buffer[] = [];
    doc.on('data', chunk => chunks.push(chunk));
    doc.on('error', reject);
    doc.on('end', () => complete(Buffer.concat(chunks)));
    doc.registerFont('body', resolve(fonts, 'DejaVuSans.ttf'));
    doc.registerFont('bold', resolve(fonts, 'DejaVuSans-Bold.ttf'));
    const width = doc.page.width - 80;
    const text = (value: string, x: number, y: number, w: number, size = 10, color = navy, bold = false) =>
      doc.font(bold ? 'bold' : 'body').fontSize(size).fillColor(color).text(value, x, y, { width: w });
    let y = 0;
    const header = () => {
      doc.rect(0, 0, doc.page.width, 110).fill(navy);
      doc.rect(0, 110, doc.page.width, 4).fill(gold);
      reportLogo(doc, 40, 17, 125);
      text('FINANCIAL SUMMARY', 215, 35, 190, 11, '#FFFFFF', true);
      text('Institution workspace', 215, 59, 190, 9, '#E4D39D');
      text(snapshot.month, 415, 39, 140, 14, '#FFFFFF', true);
      y = 137;
    };
    header();
    text('Donors & Funds', 40, y, width, 21, navy, true); y += 35;
    text(`Scope: All madrasas    |    Currency: ${snapshot.currency}`, 40, y, width, 10, muted); y += 22;
    text(`Generated: ${snapshot.generatedAt.replace('T', ' ').replace(/\.\d{3}Z$/, ' UTC')}`, 40, y, width, 9, muted); y += 30;
    const cards = [
      ['Donors with pledges', String(snapshot.summary.donors)],
      ['Pledged this month', `${snapshot.currency} ${amount(snapshot.summary.pledged)}`],
      ['Receipts this month', `${snapshot.currency} ${amount(snapshot.summary.received)}`],
      ['Outstanding at month end', `${snapshot.currency} ${amount(snapshot.summary.outstanding)}`],
    ];
    for (let i = 0; i < cards.length; i++) {
      const x = 40 + (i % 2) * (width / 2 + 6), top = y + Math.floor(i / 2) * 77;
      const w = width / 2 - 6;
      doc.roundedRect(x, top, w, 65, 7).fill(pale);
      text(cards[i]![0]!, x + 12, top + 10, w - 24, 9, muted);
      const value = cards[i]![1]!;
      text(value, x + 12, top + 31, w - 24, value.length > 24 ? 10 : 14, navy, true);
    }
    y += 168;
    text('Monthly donor commitments', 40, y, width, 13, navy, true); y += 25;
    text(`Directory page ${snapshot.page} | ${snapshot.items.length} of ${snapshot.total} pledge records shown. Totals above cover the full month.`, 40, y, width, 9, muted);
    y = doc.y + 17;
    const widths = [169, 112, 88, 88, width - 457];
    const columns = ['Donor / fund', 'Madrasa', 'Pledged', 'Received*', 'Status'];
    const tableHeader = () => {
      doc.rect(40, y, width, 28).fill(navy);
      let x = 40;
      columns.forEach((label, i) => { text(label, x + 7, y + 8, widths[i]! - 14, 8, '#FFFFFF', true); x += widths[i]!; });
      y += 28;
    };
    tableHeader();
    snapshot.items.forEach((row, index) => {
      const cells = [`${row.donorReference}\n${row.fund}`, row.madrasa, amount(row.pledged), amount(row.received), row.status];
      doc.font('body').fontSize(8);
      const height = Math.max(43, ...cells.map((cell, i) => doc.heightOfString(cell, { width: widths[i]! - 14 }) + 20));
      if (y + height > 725) { doc.addPage(); header(); tableHeader(); }
      doc.rect(40, y, width, height).fill(index % 2 ? '#FFFFFF' : '#F4F6F8');
      let x = 40;
      cells.forEach((cell, i) => { text(cell, x + 7, y + 9, widths[i]! - 14, 8, i === 4 ? (row.status === 'Received' ? '#237A50' : '#896716') : navy); x += widths[i]!; });
      y += height;
    });
    if (!snapshot.items.length) { text('No pledge records for this selection.', 48, y + 12, width - 16, 10, muted); y += 42; }
    if (y + 110 > 750) { doc.addPage(); header(); }
    y += 18;
    text('READING THIS REPORT', 40, y, width, 9, gold, true); y += 20;
    text('* Received in the table includes receipts against these pledges up to month end. Receipts this month includes all received donations within the selected month. Pledges are not available cash. This summary is not a bank balance or an expenditure report.', 40, y, width, 9, muted);
    y = doc.y + 12;
    text('Read-only snapshot. Refresh the dashboard for current records. No donor contact details are included.', 40, y, width, 9, muted);
    const pages = doc.bufferedPageRange();
    for (let i = 0; i < pages.count; i++) {
      doc.switchToPage(i);
      doc.moveTo(40, 784).lineTo(555, 784).strokeColor('#DDE3E8').stroke();
      doc.font('body').fontSize(8).fillColor(muted).text(`Afaq | ${snapshot.month} | ${snapshot.currency}`, 40, 795, { lineBreak: false });
      doc.text(`Page ${i + 1} of ${pages.count}`, 465, 795, { lineBreak: false });
    }
    doc.end();
  });
}
