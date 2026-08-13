import 'dart:io';

/// A naming violation found in first-party Dart source.
class IdentifierNamingViolation {
  const IdentifierNamingViolation({
    required this.filePath,
    required this.lineNumber,
    required this.identifier,
  });

  final String filePath;
  final int lineNumber;
  final String identifier;

  @override
  String toString() =>
      '$filePath:$lineNumber: disallowed identifier '
      '"$identifier"; use a complete, domain-specific name';
}

/// Scans [sourceRoots] for single-character and numeric-only identifiers.
///
/// The lightweight lexer deliberately ignores comments and string literals,
/// so persisted keys, JSON keys, user-facing copy, and examples do not produce
/// false positives. A lone `_` wildcard is allowed because it declares no name.
List<IdentifierNamingViolation> findIdentifierNamingViolations({
  required Directory projectDirectory,
  List<String> sourceRoots = const ['lib', 'test'],
}) {
  final violations = <IdentifierNamingViolation>[];
  for (final sourceRoot in sourceRoots) {
    final sourceDirectory = Directory(
      '${projectDirectory.path}${Platform.pathSeparator}$sourceRoot',
    );
    if (!sourceDirectory.existsSync()) continue;
    final sourceFiles =
        sourceDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((sourceFile) => sourceFile.path.endsWith('.dart'))
            .where((sourceFile) => !_isExcludedPath(sourceFile.path))
            .toList()
          ..sort(
            (leftFile, rightFile) => leftFile.path.compareTo(rightFile.path),
          );
    for (final sourceFile in sourceFiles) {
      violations.addAll(_scanSourceFile(projectDirectory, sourceFile));
    }
  }
  return violations;
}

bool _isExcludedPath(String filePath) {
  final pathSegments = filePath.split(RegExp(r'[/\\]+'));
  return pathSegments.any(
    (pathSegment) =>
        pathSegment == 'build' ||
        pathSegment == 'generated' ||
        pathSegment == '.dart_tool',
  );
}

List<IdentifierNamingViolation> _scanSourceFile(
  Directory projectDirectory,
  File sourceFile,
) {
  final sourceText = sourceFile.readAsStringSync();
  final sanitizedSource = _removeCommentsAndStrings(sourceText);
  final identifierPattern = RegExp(
    r'(?<![A-Za-z0-9_$])[A-Za-z_$][A-Za-z0-9_$]*',
  );
  final relativePath = sourceFile.path
      .substring(projectDirectory.path.length + 1)
      .replaceAll('\\', '/');
  final violations = <IdentifierNamingViolation>[];
  for (final identifierMatch in identifierPattern.allMatches(sanitizedSource)) {
    final identifier = identifierMatch.group(0)!;
    final isRawStringPrefix =
        identifier == 'r' &&
        identifierMatch.end < sourceText.length &&
        (sourceText[identifierMatch.end] == "'" ||
            sourceText[identifierMatch.end] == '"');
    if (isRawStringPrefix) continue;
    if (identifier == '_' ||
        identifier == r'$' ||
        !_isDisallowedIdentifier(identifier)) {
      continue;
    }
    final lineNumber =
        '\n'
            .allMatches(sanitizedSource.substring(0, identifierMatch.start))
            .length +
        1;
    violations.add(
      IdentifierNamingViolation(
        filePath: relativePath,
        lineNumber: lineNumber,
        identifier: identifier,
      ),
    );
  }
  return violations;
}

bool _isDisallowedIdentifier(String identifier) {
  final withoutPrivacyPrefix = identifier.startsWith('_')
      ? identifier.substring(1)
      : identifier;
  return withoutPrivacyPrefix.length == 1 ||
      RegExp(r'^\d+$').hasMatch(withoutPrivacyPrefix);
}

String _removeCommentsAndStrings(String sourceText) {
  final sanitizedCharacters = sourceText.split('');
  var characterIndex = 0;
  while (characterIndex < sourceText.length) {
    final currentCharacter = sourceText[characterIndex];
    final nextCharacter = characterIndex + 1 < sourceText.length
        ? sourceText[characterIndex + 1]
        : '';
    if (currentCharacter == '/' && nextCharacter == '/') {
      characterIndex = _blankUntilLineEnd(
        sanitizedCharacters,
        sourceText,
        characterIndex,
      );
    } else if (currentCharacter == '/' && nextCharacter == '*') {
      characterIndex = _blankBlockComment(
        sanitizedCharacters,
        sourceText,
        characterIndex,
      );
    } else if (currentCharacter == "'" || currentCharacter == '"') {
      characterIndex = _blankStringLiteral(
        sanitizedCharacters,
        sourceText,
        characterIndex,
        currentCharacter,
      );
    } else {
      characterIndex++;
    }
  }
  return sanitizedCharacters.join();
}

int _blankUntilLineEnd(
  List<String> sanitizedCharacters,
  String sourceText,
  int startIndex,
) {
  var characterIndex = startIndex;
  while (characterIndex < sourceText.length &&
      sourceText[characterIndex] != '\n') {
    sanitizedCharacters[characterIndex] = ' ';
    characterIndex++;
  }
  return characterIndex;
}

int _blankBlockComment(
  List<String> sanitizedCharacters,
  String sourceText,
  int startIndex,
) {
  var characterIndex = startIndex;
  while (characterIndex < sourceText.length) {
    if (sourceText[characterIndex] != '\n') {
      sanitizedCharacters[characterIndex] = ' ';
    }
    if (characterIndex > startIndex &&
        sourceText[characterIndex - 1] == '*' &&
        sourceText[characterIndex] == '/') {
      return characterIndex + 1;
    }
    characterIndex++;
  }
  return characterIndex;
}

int _blankStringLiteral(
  List<String> sanitizedCharacters,
  String sourceText,
  int startIndex,
  String quoteCharacter,
) {
  final tripleQuote = '$quoteCharacter$quoteCharacter$quoteCharacter';
  final isTripleQuoted = sourceText.startsWith(tripleQuote, startIndex);
  final delimiterLength = isTripleQuoted ? 3 : 1;
  final closingDelimiter = isTripleQuoted ? tripleQuote : quoteCharacter;
  var characterIndex = startIndex;
  while (characterIndex < sourceText.length) {
    if (sourceText[characterIndex] != '\n') {
      sanitizedCharacters[characterIndex] = ' ';
    }
    final reachedClosingDelimiter =
        characterIndex >= startIndex + delimiterLength &&
        sourceText.startsWith(closingDelimiter, characterIndex) &&
        (isTripleQuoted || sourceText[characterIndex - 1] != '\\');
    if (reachedClosingDelimiter) {
      for (
        var delimiterIndex = 1;
        delimiterIndex < delimiterLength;
        delimiterIndex++
      ) {
        sanitizedCharacters[characterIndex + delimiterIndex] = ' ';
      }
      return characterIndex + delimiterLength;
    }
    characterIndex++;
  }
  return characterIndex;
}

void main(List<String> arguments) {
  final projectDirectory = Directory.current;
  final violations = findIdentifierNamingViolations(
    projectDirectory: projectDirectory,
  );
  if (violations.isEmpty) {
    stdout.writeln('Identifier naming check passed.');
    return;
  }
  stderr.writeln('Identifier naming check failed:');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}
