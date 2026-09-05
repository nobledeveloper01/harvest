import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every weight asks the variable font for it', () {
    /*
      Inter ships as one `InterVariable.ttf` with a `wght` axis and no
      per-weight assets, so `fontWeight` on its own reaches nothing: Skia has no
      instance to select and **synthesises** bold, smearing the regular outline
      sideways.

      It looked right for weeks. What gave it away was the naira sign — ₦ has
      two horizontal crossbars, the smear pushed them past the glyph's advance,
      and "₦180,000" rendered with the bars struck through the 1. The font's own
      metrics put its ink 46 units inside the advance, so nothing was wrong with
      the file. The app had never asked for the weight it was drawing.

      What the smear touched everywhere else is subtler and worse: it is the
      whole type hierarchy, which `DESIGN.md` says is carried by **weight and
      tracking** rather than by size.

      A source scan rather than a render assertion, because the failure is
      invisible in a widget test — synthetic bold produces a perfectly valid
      TextStyle and lays out without complaint.
    */
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('fontWeight: FontWeight.w')) continue;
        // The axis must sit on the next line. Adjacency, not presence anywhere
        // in the file: a `fontVariations` twenty lines away belongs to a
        // different style and would make this pass for the wrong reason.
        final next = i + 1 < lines.length ? lines[i + 1] : '';
        if (!next.contains('fontVariations:')) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these ask for a weight the variable font is never told about, '
          'so Skia fakes it:\n${offenders.join('\n')}',
    );
  });
}
