// Generates original, non-lesson samples. Requires Node.js and ffmpeg with x264.
import {spawnSync} from 'node:child_process';
import {mkdirSync, writeFileSync, statSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const output = path.join(root, 'assets/media-preview');
mkdirSync(output, {recursive: true});
function ffmpeg(args) {
  const result = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], {cwd: root, stdio: 'inherit'});
  if (result.status !== 0) throw new Error(`ffmpeg failed: ${result.status}`);
}
const font = 'assets/fonts/NotoSansDisplay-Regular.ttf';
const bold = 'assets/fonts/NotoSansDisplay-Bold.ttf';
const draw = (text, x, y, size, color = 'white', face = font) =>
  `drawtext=fontfile=${face}:text='${text}':x='${x}':y=${y}:fontsize=${size}:fontcolor=${color}`;
ffmpeg([
  '-f', 'lavfi', '-i', 'color=c=0x10263a:s=640x360:r=15:d=40',
  '-vf', [
    'drawbox=x=40:y=38:w=6:h=40:c=0xb68b2d:t=fill',
    draw('PLAYER PREVIEW', 60, 44, 24, '0xe2c47b', bold),
    draw('A moment to explore', 40, 116, 32, 'white', bold),
    draw('Play. Pause. Seek. Make it your own.', 40, 174, 20),
    draw('Sample only - no learning records', 40, 217, 16, '0xbacbda'),
    'drawbox=x=40:y=290:w=560:h=2:c=0x476072:t=fill',
    draw('>', '40+mod(t*14,540)', 271, 32, '0xe2c47b', bold),
    draw('%{pts\\:hms}', 40, 317, 14, '0xbacbda'),
  ].join(','),
  '-an', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '30',
  '-preset', 'slow', '-map_metadata', '-1', '-movflags', '+faststart',
  path.join(output, 'video.mp4'),
]);
ffmpeg([
  '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=22050:duration=40',
  '-af', 'volume=0.05,tremolo=f=0.5:d=0.8,afade=t=in:d=1,afade=t=out:st=39:d=1',
  '-c:a', 'aac', '-b:a', '32k', '-map_metadata', '-1', '-movflags', '+faststart',
  path.join(output, 'audio.m4a'),
]);

const lines = [
  ['YOUR PLAYER GUIDE', 'Page 1 of 2 - sample material', '',
    'Try the player before your first lesson.', '',
    'Video: press Play, pause, or move along the timeline.',
    'Try the 10-second jumps and change playback speed.',
    'Audio: try the same controls at a comfortable volume.',
    'Image: zoom in, move around, then use Reset zoom.', '',
    'Use the page arrow to continue to page 2.', '',
    'No school records or learning progress are saved here.'],
  ['EXPLORE WITH CONFIDENCE', 'Page 2 of 2 - sample material', '',
    'PDF: use the page arrows, scrolling and zoom buttons.',
    'Text: read and select words inside the viewer.',
    'Focus view: make more room without opening another window.',
    'Back: leave Focus view before returning to your workspace.', '',
    'Samples do not start playing automatically.',
    'Switching samples stops the previous recording.', '',
    'These controls also work with real lesson resources.',
    'Mark complete only when you finish an actual lesson.'],
];
const escape = text => text.replace(/[\\()]/g, '\\$&');
const streams = lines.map(rows => 'BT /F1 14 Tf 44 780 Td 28 TL\n' + rows.map((line, i) => `${i ? 'T* ' : ''}(${escape(line)}) Tj`).join('\n') + '\nET');
const objects = [
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
  ...[6, 7].map(content => `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents ${content} 0 R >>`),
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ...streams.map(stream => `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`),
];
let pdf = '%PDF-1.4\n';
const offsets = [0];
objects.forEach((value, index) => {
  offsets.push(Buffer.byteLength(pdf));
  pdf += `${index + 1} 0 obj\n${value}\nendobj\n`;
});
const xref = Buffer.byteLength(pdf);
pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
pdf += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
writeFileSync(path.join(output, 'guide.pdf'), pdf);
for (const file of ['video.mp4', 'audio.m4a', 'guide.pdf']) {
  console.log(`${file}: ${statSync(path.join(output, file)).size} bytes`);
}
