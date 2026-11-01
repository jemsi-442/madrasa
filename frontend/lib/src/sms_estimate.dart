class SmsEstimate {
  const SmsEstimate(this.unicode, this.units, this.parts, this.recipients);
  final bool unicode;
  final int units, parts, recipients;
  int get credits => parts * recipients;
}

SmsEstimate estimateSms(String text, int recipients) {
  // GSM extension characters use an escape septet as well as their own septet.
  const basic =
      '@\u00a3\$\u00a5\u00e8\u00e9\u00f9\u00ec\u00f2\u00c7\n\u00d8\u00f8\r\u00c5\u00e5'
      '\u0394_\u03a6\u0393\u039b\u03a9\u03a0\u03a8\u03a3\u0398\u039e'
      '\u00c6\u00e6\u00df\u00c9 !"#\u00a4%&\'()*+,-./0123456789:;<=>?'
      '\u00a1ABCDEFGHIJKLMNOPQRSTUVWXYZ\u00c4\u00d6\u00d1\u00dc\u00a7'
      '\u00bfabcdefghijklmnopqrstuvwxyz\u00e4\u00f6\u00f1\u00fc\u00e0';
  const extension = '\f^{}\\[~]|\u20ac';
  final body = text.trim();
  var units = 0;
  var unicode = false;
  for (final rune in body.runes) {
    final char = String.fromCharCode(rune);
    if (basic.contains(char)) {
      units++;
    } else if (extension.contains(char)) {
      units += 2;
    } else {
      unicode = true;
      break;
    }
  }
  if (unicode) {
    units = body.length; // UTF-16 units, including emoji surrogate pairs.
  }
  final single = unicode ? 70 : 160;
  final multipart = unicode ? 67 : 153;
  final parts = units == 0
      ? 0
      : units <= single
      ? 1
      : (units / multipart).ceil();
  return SmsEstimate(unicode, units, parts, recipients < 0 ? 0 : recipients);
}
