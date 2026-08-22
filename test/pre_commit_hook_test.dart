import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `.githooks/pre-commit` is the gate that makes "new code comes with tests"
/// enforce itself rather than rely on review, and it runs in the one
/// environment where flutter cannot be taken for granted: git exports GIT_DIR
/// into every hook, flutter shells out to git to discover its own version, and
/// GIT_DIR outranks the repository flutter selects for itself. The SDK then
/// reports 0.0.0-unknown and pub resolution fails naming a package, so the
/// symptom points nowhere near the cause and the natural response is
/// `--no-verify`.
///
/// The hook is run for real here, against a throwaway repository, with a stub
/// `flutter` on PATH that records the environment it was handed. Nothing needs
/// a real SDK: what is pinned is the environment the hook hands over, and the
/// order of the two things it cannot do in either order.
void main() {
  final hook = File('.githooks/pre-commit').absolute.path;

  // The variables that decide which repository a git command talks to. Any one
  // of them surviving into flutter is the bug.
  const gitVariables = [
    'GIT_DIR',
    'GIT_WORK_TREE',
    'GIT_INDEX_FILE',
    'GIT_OBJECT_DIRECTORY',
    'GIT_ALTERNATE_OBJECT_DIRECTORIES',
    'GIT_COMMON_DIR',
  ];

  const stubFlutter = r'''
#!/bin/sh
printf 'ran: flutter %s\n' "$*" >> "$FLUTTER_STUB_LOG"
env | grep '^GIT_' >> "$FLUTTER_STUB_LOG"
exit 0
''';

  late Directory temp;
  late String repo;
  late String log;
  late String stubBin;

  ProcessResult run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) =>
      Process.runSync(
        executable,
        arguments,
        workingDirectory: repo,
        environment: environment,
      );

  void git(List<String> arguments, {String? indexFile}) {
    final result = run(
      'git',
      arguments,
      environment: indexFile == null ? null : {'GIT_INDEX_FILE': indexFile},
    );
    if (result.exitCode != 0) {
      fail('git ${arguments.join(' ')} failed:\n${result.stderr}');
    }
  }

  void write(String path, String contents) {
    File('$repo/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  void stage(String path, String contents) {
    write(path, contents);
    git(['add', path]);
  }

  /// What git hands a hook: the repository spelled out, and the index the
  /// commit is being assembled in.
  Map<String, String> hookEnvironment(String indexFile) => {
        'PATH': '$stubBin:${Platform.environment['PATH']}',
        'FLUTTER_STUB_LOG': log,
        'GIT_DIR': '$repo/.git',
        'GIT_WORK_TREE': repo,
        'GIT_INDEX_FILE': indexFile,
        'GIT_OBJECT_DIRECTORY': '$repo/.git/objects',
        'GIT_ALTERNATE_OBJECT_DIRECTORIES': '$repo/.git/objects',
        'GIT_COMMON_DIR': '$repo/.git',
      };

  ProcessResult runHook({String? indexFile}) => run(
        'sh',
        [hook],
        environment: hookEnvironment(indexFile ?? '$repo/.git/index'),
      );

  List<String> stubLog() {
    final file = File(log);
    if (!file.existsSync()) return const [];
    return file.readAsLinesSync().where((line) => line.isNotEmpty).toList();
  }

  group(
    'the pre-commit hook',
    () {
      setUp(() {
        temp = Directory.systemTemp.createTempSync('uractor_pre_commit');
        repo = '${temp.path}/repo';
        log = '${temp.path}/flutter.log';
        stubBin = '${temp.path}/bin';

        Directory(repo).createSync(recursive: true);
        Directory(stubBin).createSync(recursive: true);
        File('$stubBin/flutter').writeAsStringSync(stubFlutter);
        Process.runSync('chmod', ['755', '$stubBin/flutter']);

        git(['init', '--quiet']);
        git(['config', 'user.email', 'hook@uractor.invalid']);
        git(['config', 'user.name', 'Pre-commit test']);
        git(['config', 'commit.gpgsign', 'false']);
        write('README.md', 'seed\n');
        git(['add', 'README.md']);
        // --no-verify because a globally configured hooks path would otherwise
        // recurse into the very hook under test.
        git(['commit', '--quiet', '--no-verify', '-m', 'seed']);
      });

      tearDown(() => temp.deleteSync(recursive: true));

      test('runs flutter without git aiming it at this repository', () {
        stage('lib/thing.dart', 'void main() {}\n');

        final result = runHook();
        final recorded = stubLog();

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(recorded, contains('ran: flutter analyze'));
        expect(recorded, contains('ran: flutter test'));

        final leaked = recorded
            .where(
                (line) => gitVariables.any((name) => line.startsWith('$name=')))
            .toList();
        expect(
          leaked,
          isEmpty,
          reason: 'flutter was handed $leaked, so it reads this repository '
              'for its own version and calls itself 0.0.0-unknown',
        );
      });

      test('reads the staged files before it clears the environment', () {
        // A partial commit and `git commit -a` both assemble a temporary index
        // and point the hook at it with GIT_INDEX_FILE. Clearing the
        // environment any earlier sends `git diff --cached` to the repository
        // index, which does not hold what is being committed, and the gate
        // passes without having checked anything.
        final temporaryIndex = '$repo/.git/next-index-test';
        File('$repo/.git/index').copySync(temporaryIndex);
        write('lib/thing.dart', 'void main() {}\n');
        git(['add', 'lib/thing.dart'], indexFile: temporaryIndex);

        final result = runHook(indexFile: temporaryIndex);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          stubLog(),
          contains('ran: flutter analyze'),
          reason: 'the hook found nothing staged, so it read the wrong index',
        );
      });

      test('still skips flutter altogether for a prose-only commit', () {
        stage('docs/notes.md', 'prose\n');

        final result = runHook();

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(stubLog(), isEmpty);
      });
    },
    // Git for Windows ships an `sh` but does not put it on PATH, so there is
    // nothing there to run a POSIX hook with.
    skip: Platform.isWindows
        ? 'the hook is a POSIX shell script and needs sh on PATH'
        : null,
  );
}
