import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

export function reportAsset(relative: string): string {
  const path = [resolve(__dirname, '../../../assets', relative), resolve(__dirname, '../../../../assets', relative)]
    .find(candidate => existsSync(candidate));
  if (!path) throw new Error('Report branding asset is missing');
  return path;
}

export function reportLogo(doc: PDFKit.PDFDocument, x = 40, y = 22, width = 133) {
  doc.roundedRect(x, y, width + 20, 65, 6).fill('#F8F6F0');
  doc.image(reportAsset('branding/afaq-logo.png'), x + 10, y + 10, { fit: [width, 45], align: 'center', valign: 'center' });
}
