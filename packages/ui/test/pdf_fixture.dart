// A small real PDF for the tests: one line of text (ASCII, Helvetica) per
// page, with a correct cross-reference table.
import 'dart:convert';
import 'dart:typed_data';

Uint8List pdfWithPages(List<String> lines) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  void obj(String body) {
    offsets.add(out.length);
    raw('${offsets.length} 0 obj\n$body\nendobj\n');
  }

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  final n = lines.length;
  // 1 catalog, 2 pages, 3 font, then a page and its content for each line.
  final kids = [for (var i = 0; i < n; i++) '${4 + 2 * i} 0 R'].join(' ');
  raw('%PDF-1.4\n');
  obj('<< /Type /Catalog /Pages 2 0 R >>');
  obj('<< /Type /Pages /Kids [$kids] /Count $n >>');
  obj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
  for (var i = 0; i < n; i++) {
    obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>');
    final stream = 'BT /F1 18 Tf 20 100 Td (${esc(lines[i])}) Tj ET';
    obj('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  }
  final xref = out.length;
  raw('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    raw('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  raw('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.toBytes();
}
