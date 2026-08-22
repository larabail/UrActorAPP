import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/credit_label.dart';

void main() {
  group('creditLabelFor', () {
    test('a cast credit is named by the character played', () {
      expect(
        creditLabelFor({'character': 'Forrest Gump', 'job': null},
            isCrew: false),
        'Forrest Gump',
      );
    });

    test('a crew credit is named by the job', () {
      expect(
        creditLabelFor({'character': null, 'job': 'Executive Producer'},
            isCrew: true),
        'Executive Producer',
      );
    });

    test('a crew credit prefers its job over a character it also carries', () {
      // A person's combined credits list the same title twice when they both
      // acted in it and worked on it, and the crew copy occasionally arrives
      // with the character still attached.
      expect(
        creditLabelFor({'character': 'Self', 'job': 'Director'}, isCrew: true),
        'Director',
      );
    });

    test('falls back to the other field rather than saying nothing', () {
      expect(
        creditLabelFor({'job': 'Narrator (voice)'}, isCrew: false),
        'Narrator (voice)',
      );
      expect(
        creditLabelFor({'character': 'Himself'}, isCrew: true),
        'Himself',
      );
    });

    test('a credit naming no part at all reads as empty, never as "null"', () {
      // The page interpolated the raw field, so a credit missing it printed
      // the literal word "null" across the poster.
      expect(creditLabelFor({}, isCrew: false), '');
      expect(
          creditLabelFor({'character': null, 'job': null}, isCrew: true), '');
    });

    test('blank and whitespace-only parts read as empty', () {
      expect(creditLabelFor({'character': ''}, isCrew: false), '');
      expect(creditLabelFor({'character': '   '}, isCrew: false), '');
    });

    test('a part wrapped over two lines is flattened to one', () {
      // A line break inside a one-line label draws as a blank box rather than
      // as a second row.
      expect(
        creditLabelFor({'character': 'Self\n/ Narrator'}, isCrew: false),
        'Self / Narrator',
      );
    });

    test('surrounding whitespace is trimmed', () {
      expect(
        creditLabelFor({'job': '  Screenplay  '}, isCrew: true),
        'Screenplay',
      );
    });

    test('a non-string part is still readable', () {
      expect(creditLabelFor({'character': 7}, isCrew: false), '7');
    });
  });
}
