import PDFDocument from 'pdfkit';
import { reportAsset, reportLogo } from './report-brand';

type AuditEvent = {
  id: string; actorId: string | null; actorRole: string | null;
  action: string; entityType: string | null; entityId: string | null; createdAt: Date;
};

const labels: Record<string, string> = {
  'platform.login.failed': 'Failed login',
  'platform.login.succeeded': 'Successful login',
  'platform.audit.exported': 'Audit PDF generated',
  'platform.session.revoked': 'Session revoked',
  'platform.sessions.revoked': 'All sessions revoked',
  'platform.account.disabled': 'IT account disabled',
  'platform.account.restored': 'IT account restored',
  'platform.account.bootstrapped': 'Reviewer created',
  'tenant.technical-review.recorded': 'IT sign-off recorded',
  'tenant.technical-review.withdrawn': 'IT sign-off withdrawn',
  'tenant.application.requested': 'Madrassa requested',
  'tenant.application.approved': 'Madrassa approved',
  'tenant.application.rejected': 'Madrassa rejected',
  'tenant.school.provisioned': 'Inactive madrassa created',
  'tenant.school.activated': 'Madrassa activated',
  'tenant.admin.invitation.issued': 'Admin invitation recorded',
};
const roleLabel = (role: string | null) =>
  role === 'IT_SECURITY' ? 'IT / Security' : role === 'SUPER_ADMIN' ? 'Super Admin' : role ?? 'Not recorded';
const timestamp = (date: Date) => new Intl.DateTimeFormat('en-GB', {
  day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
  timeZone: 'UTC', hour12: false,
}).format(date);

// Keep long identifiers out of the summary, without discarding audit references.
export function auditReportPdf(events: AuditEvent[], generatedAt: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 36, bufferPages: true,
      info: { Title: 'Security audit report', Author: 'Afaq' } });
    const chunks: Buffer[] = [];
    doc.on('data', chunk => chunks.push(chunk));
    doc.on('error', reject);
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.registerFont('body', reportAsset('fonts/DejaVuSans.ttf'));
    doc.registerFont('bold', reportAsset('fonts/DejaVuSans-Bold.ttf'));
    const width = doc.page.width - 72;
    const bottom = 758;
    let y = 0;
    const text = (value: string, x: number, top: number, w: number, bold = false, size = 9, color = '#122336') => {
      doc.font(bold ? 'bold' : 'body').fontSize(size).fillColor(color)
        .text(value, x, top, { width: w, lineGap: 3 });
    };
    const header = (section: string) => {
      doc.rect(0, 0, doc.page.width, 108).fill('#122336');
      doc.rect(0, 108, doc.page.width, 4).fill('#B18D2C');
      reportLogo(doc, 36, 20, 105);
      text('Security audit report', 165, 28, width - 129, true, 19, '#FFFFFF');
      text(section, 165, 65, width - 129, false, 10, '#E4D39D');
      y = 134;
    };
    const newPage = (section: string) => { doc.addPage(); header(section); };
    header('Selected events / IT workspace');
    doc.roundedRect(36, y, width, 78, 8).fill('#F3F5F7');
    text('EXPORT SCOPE', 50, y + 12, 180, true, 8, '#63758A');
    text(`${events.length} selected events`, 50, y + 30, 180, true, 12);
    text('Not the full audit log', 50, y + 52, 180, false, 8, '#63758A');
    text('GENERATED (UTC)', 265, y + 12, width - 243, true, 8, '#63758A');
    text(timestamp(new Date(generatedAt)), 265, y + 32, width - 243);
    y += 100;
    doc.outline.addItem('01 Event summary');
    text('01  Event summary', 36, y, width, true, 14);
    y += 29;
    text('Select an event number to open its full references.', 36, y, width, false, 8, '#63758A');
    y += 22;
    const widths = [30, 157, 112, width - 299];
    const xs = [36, 66, 223, 335];
    const tableHeader = () => {
      doc.rect(36, y, width, 30).fill('#122336');
      ['No.', 'Recorded (UTC)', 'Actor role', 'Action'].forEach((label, i) =>
        text(label, xs[i]! + 7, y + 9, widths[i]! - 14, true, 8, '#FFFFFF'));
      y += 30;
    };
    tableHeader();
    events.forEach((event, index) => {
      const cells = [`${index + 1}`, timestamp(event.createdAt), roleLabel(event.actorRole), labels[event.action] ?? event.action];
      doc.font('body').fontSize(9);
      const height = Math.max(36, ...cells.map((cell, i) => doc.heightOfString(cell, { width: widths[i]! - 14, lineGap: 3 }) + 20));
      if (y + height > bottom) { newPage('Event summary / continued'); tableHeader(); }
      doc.addNamedDestination(`summary-${index + 1}`, 'XYZ', 36, y, null);
      doc.rect(36, y, width, height).fill(index % 2 ? '#FFFFFF' : '#F3F5F7');
      cells.forEach((cell, i) => text(cell, xs[i]! + 7, y + 10, widths[i]! - 14,
        i === 0, 9, i === 0 ? '#2463A5' : '#122336'));
      doc.goTo(36, y, widths[0]!, height, `reference-${index + 1}`);
      y += height;
    });
    newPage('Event references / restricted identifiers');
    doc.outline.addItem('02 Event references');
    text('02  Event references', 36, y, width, true, 14);
    y += 28;
    text('Match each numbered record to the event summary. Identifiers are preserved in full.', 36, y, width, false, 9, '#63758A');
    y += 40;
    const referenceWidth = (width - 16) / 2;
    const referenceFields = (event: AuditEvent) => [
        ['Event ID', event.id], ['Actor ID', event.actorId ?? 'Not recorded'],
        ['Action code', event.action], ['Record type', event.entityType ?? 'Not recorded'],
        ['Reference ID', event.entityId ?? 'Not recorded'],
      ];
    for (let index = 0; index < events.length; index += 2) {
      const cards = events.slice(index, index + 2).map(event => {
        const fields = referenceFields(event);
        doc.font('body').fontSize(9);
        const heights = fields.map(([, value]) =>
          16 + doc.heightOfString(value!, { width: referenceWidth - 28, lineGap: 3 }) + 8);
        return { fields, heights, height: 42 + heights.reduce((a, b) => a + b, 0) };
      });
      const height = Math.max(...cards.map(card => card.height));
      if (y + height > bottom) newPage('Event references / continued');
      cards.forEach((card, column) => {
        const x = 36 + column * (referenceWidth + 16);
        const number = index + column + 1;
        doc.addNamedDestination(`reference-${number}`, 'XYZ', x, y, null);
        doc.roundedRect(x, y, referenceWidth, height, 7).fill('#F3F5F7');
        text(`Event ${number}`, x + 14, y + 12, 100, true, 11);
        text('Back to summary', x + referenceWidth - 104, y + 14, 90, false, 8, '#2463A5');
        doc.goTo(x + referenceWidth - 104, y + 10, 90, 20, `summary-${number}`);
        let fieldY = y + 37;
        card.fields.forEach(([label, value], i) => {
          text(label!, x + 14, fieldY, referenceWidth - 28, true, 8, '#63758A');
          text(value!, x + 14, fieldY + 16, referenceWidth - 28);
          fieldY += card.heights[i]!;
        });
      });
      y += height + 14;
    }
    const notes = [
      'Scope: only the selected page events are included, not the full audit history.',
      'Privacy: event metadata, secrets and message bodies are excluded. Failed login actors identify target accounts, not verified people.',
      'Traceability: generation is audited; it does not prove the file was read. Share only with authorised recipients.',
    ];
    doc.font('body').fontSize(9);
    const notesHeight = 30 + notes.reduce((sum, note) =>
      sum + doc.heightOfString(note, { width, lineGap: 3 }) + 10, 0);
    if (y + notesHeight > bottom) newPage('Report handling');
    doc.outline.addItem('03 Reading and sharing');
    text('03  Reading and sharing', 36, y, width, true, 14);
    y += 30;
    for (const note of notes) {
      text(note, 36, y, width, false, 9, '#526477');
      y = doc.y + 10;
    }
    const pages = doc.bufferedPageRange();
    for (let i = 0; i < pages.count; i++) {
      doc.switchToPage(i);
      doc.moveTo(36, 783).lineTo(doc.page.width - 36, 783).strokeColor('#DDE3E8').stroke();
      text('Afaq / Read-only audit history', 36, 795, 330, false, 8, '#63758A');
      text(`Page ${i + 1} of ${pages.count}`, doc.page.width - 116, 795, 80, false, 8, '#63758A');
    }
    doc.end();
  });
}
