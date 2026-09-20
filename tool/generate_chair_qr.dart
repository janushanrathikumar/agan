// tool/generate_chair_qr.dart
//
// Renders one PNG sticker per chair, each holding the QR code that opens the
// menu for that seat.
//
// The QR encodes <origin>/scan?n=<chair number>, so a sticker can be printed
// for a chair before the admin has added it to a table: it starts working the
// moment a chair with that number exists.
//
//   dart run tool/generate_chair_qr.dart --from 1 --to 350 --out ~/Desktop/chair-qr
//
// Options: --origin (default https://restaurantkleefeld.ch), --from, --to, --out

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

const _defaultOrigin = 'https://restaurantkleefeld.ch';
const _project = 'agan-ee7ee';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final origin = options['origin'] ?? _defaultOrigin;
  final from = int.parse(options['from'] ?? '1');
  final to = int.parse(options['to'] ?? '350');
  final outDir = Directory(options['out'] ?? 'chair-qr')..createSync(recursive: true);

  stdout.writeln('Reading the tables so each chair can be listed with its table…');
  final tableOf = await _chairNumberToTableName();
  stdout.writeln('${tableOf.length} chairs are set up today.');

  final index = StringBuffer('chair_number,table,file\n');
  for (var no = from; no <= to; no++) {
    final url = '$origin/scan?n=$no';
    final png = _sticker(chairNumber: no, url: url);
    final name = 'chair-${no.toString().padLeft(3, '0')}.png';
    File('${outDir.path}/$name').writeAsBytesSync(png);
    index.write('$no,"${tableOf[no] ?? ''}",$name\n');
    if (no % 50 == 0) stdout.writeln('  …$no');
  }
  File('${outDir.path}/index.csv').writeAsStringSync(index.toString());

  stdout.writeln('Done: ${to - from + 1} stickers in ${outDir.path}');
  stdout.writeln('index.csv says which table each chair belongs to.');
}

/// White sticker: restaurant name, the QR, and the chair number underneath.
///
/// The table name is deliberately not printed - a chair can be moved to another
/// table, and a sticker that then names the wrong one would mislead; the QR
/// itself always resolves the table live.
List<int> _sticker({required int chairNumber, required String url}) {
  const size = 720; // px wide; ~6 cm printed at 300 dpi
  const quiet = 48; // white border the scanner needs
  const header = 56;
  const footer = 108;

  final qr = QrCode.fromData(
    data: url,
    // M survives a scuffed or partly covered sticker better than L.
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final matrix = QrImage(qr);
  final modules = matrix.moduleCount;

  final available = size - quiet * 2;
  final scale = available ~/ modules; // whole pixels keep the edges crisp
  final qrSize = scale * modules;
  final left = (size - qrSize) ~/ 2;
  final top = header + quiet;

  final image = img.Image(width: size, height: top + qrSize + footer);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final black = img.ColorRgb8(0, 0, 0);

  for (var row = 0; row < modules; row++) {
    for (var col = 0; col < modules; col++) {
      if (!matrix.isDark(row, col)) continue;
      img.fillRect(
        image,
        x1: left + col * scale,
        y1: top + row * scale,
        x2: left + (col + 1) * scale - 1,
        y2: top + (row + 1) * scale - 1,
        color: black,
      );
    }
  }

  img.drawString(
    image,
    'RESTAURANT KLEEFELD',
    font: img.arial24,
    y: 18,
    color: black,
  );
  img.drawString(
    image,
    'Stuhl $chairNumber',
    font: img.arial48,
    y: top + qrSize + 26,
    color: black,
  );

  return img.encodePng(image);
}

/// chair number -> table name, read straight from Firestore.
Future<Map<int, String>> _chairNumberToTableName() async {
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)'
    '/documents/tables?pageSize=300',
  );
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      stderr.writeln('Could not read the tables (${response.statusCode}); '
          'index.csv will have no table names.');
      return {};
    }
    final docs = (jsonDecode(body) as Map)['documents'] as List? ?? [];
    final out = <int, String>{};
    for (final doc in docs) {
      final fields = doc['fields'] as Map;
      final name = fields['name']?['stringValue'] as String? ?? '';
      final chairs = fields['chairs']?['arrayValue']?['values'] as List? ?? [];
      for (final chair in chairs) {
        final f = chair['mapValue']['fields'] as Map;
        final raw = f['no']?['integerValue'] ?? f['no']?['doubleValue'];
        final no = raw == null ? null : int.tryParse(raw.toString().split('.').first);
        if (no != null) out[no] = name;
      }
    }
    return out;
  } finally {
    client.close();
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) out[args[i].substring(2)] = args[i + 1];
  }
  return out;
}
