import 'dart:io';

import 'package:crypto/crypto.dart';

/// Environment variable that overrides source resolution with a local checkout.
const ghosttySrcEnvKey = 'GHOSTTY_SRC';

const _defaultTarballBase = 'https://github.com/ghostty-org/ghostty/archive';
const _patchMarkerName = '.libghostty-patch-key';

/// Source patches applied to downloaded and cloned Ghostty checkouts.
List<File> ghosttyPatchFiles(Uri packageRoot) {
  final directory = Directory.fromUri(packageRoot.resolve('patches/'));
  if (!directory.existsSync()) return const [];
  return directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.patch'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Returns a cache key that changes when the Ghostty pin or patches change.
String ghosttySourceCacheKey(Uri packageRoot) {
  final commit = pinnedCommit(packageRoot);
  final patches = ghosttyPatchFiles(packageRoot);
  if (patches.isEmpty) return '${commit.substring(0, 12)}-none';
  final bytes = <int>[];
  for (final patch in patches) {
    bytes.addAll(patch.readAsBytesSync());
  }
  final patchHash = sha256.convert(bytes).toString().substring(0, 12);
  return '${commit.substring(0, 12)}-$patchHash';
}

/// Applies all packaged patches to a freshly acquired Ghostty checkout.
void applyGhosttyPatches(Directory source, Uri packageRoot) {
  final gitDirectory = Directory.fromUri(source.uri.resolve('.git/'));
  final isolated = !gitDirectory.existsSync();
  if (isolated) {
    final result = Process.runSync('git', [
      'init',
      '--quiet',
    ], workingDirectory: source.path);
    if (result.exitCode != 0) {
      throw Exception('Failed to isolate Ghostty source: ${result.stderr}');
    }
  }
  try {
    for (final patch in ghosttyPatchFiles(packageRoot)) {
      final result = Process.runSync('git', [
        'apply',
        patch.path,
      ], workingDirectory: source.path);
      if (result.exitCode != 0) {
        throw Exception(
          'Failed to apply Ghostty patch ${patch.path}: ${result.stderr}',
        );
      }
    }
  } finally {
    if (isolated) {
      gitDirectory.deleteSync(recursive: true);
      gitDirectory.createSync();
    }
  }
}

/// Downloads a source tarball, extracts it, and caches the result.
///
/// Uses [tarballUrl] if provided, otherwise builds URL from the pinned commit
/// in `ghostty.version`.
Future<Directory> downloadSource(
  Uri cacheBase, {
  required Uri packageRoot,
  String? tarballUrl,
}) async {
  final commit = pinnedCommit(packageRoot);
  final cacheKey = ghosttySourceCacheKey(packageRoot);
  final cacheDir = Directory.fromUri(
    cacheBase.resolve('ghostty-source-$cacheKey/'),
  );
  final patchMarker = File.fromUri(cacheDir.uri.resolve(_patchMarkerName));
  if (cacheDir.existsSync()) {
    if (patchMarker.existsSync() &&
        patchMarker.readAsStringSync() == cacheKey) {
      return cacheDir;
    }
    cacheDir.deleteSync(recursive: true);
  }

  tarballUrl ??= '$_defaultTarballBase/$commit.tar.gz';

  final tarball = File.fromUri(cacheBase.resolve('$commit.tar.gz'));
  tarball.parent.createSync(recursive: true);

  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(Uri.parse(tarballUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download Ghostty source: HTTP ${response.statusCode}. '
        'Check your network connection or set '
        '$ghosttySrcEnvKey to a local checkout.',
      );
    }
    final sink = tarball.openWrite();
    await response.pipe(sink);
  } finally {
    httpClient.close();
  }

  cacheDir.createSync(recursive: true);
  final extractResult = Process.runSync('tar', [
    'xzf',
    tarball.path,
    '-C',
    cacheDir.path,
    '--strip-components=1',
  ]);
  if (extractResult.exitCode != 0) {
    cacheDir.deleteSync(recursive: true);
    tarball.deleteSync();
    throw Exception(
      'Failed to extract Ghostty source: ${extractResult.stderr}',
    );
  }

  try {
    applyGhosttyPatches(cacheDir, packageRoot);
    patchMarker.writeAsStringSync(cacheKey);
  } on Object {
    cacheDir.deleteSync(recursive: true);
    tarball.deleteSync();
    rethrow;
  }

  tarball.deleteSync();

  return cacheDir;
}

/// Reads the pinned Ghostty commit from `ghostty.version` at [packageRoot].
String pinnedCommit(Uri packageRoot) {
  final file = File.fromUri(packageRoot.resolve('ghostty.version'));
  if (!file.existsSync()) {
    throw StateError(
      'ghostty.version not found at ${file.path}. '
      'This file must contain the pinned Ghostty commit hash.',
    );
  }
  return file.readAsStringSync().trim();
}

/// Resolves the Ghostty source directory.
///
/// Resolution order:
/// 1. [ghosttySrcEnvKey] environment variable
/// 2. Local `ghostty/` directory at the workspace root
/// 3. Download from GitHub (cached in [cacheBase])
Future<Directory> resolveSource({
  required Uri packageRoot,
  required Uri cacheBase,
}) async {
  final envPath = Platform.environment[ghosttySrcEnvKey];
  if (envPath != null && envPath.isNotEmpty) {
    final dir = Directory(envPath);
    if (dir.existsSync()) return dir;
  }

  final workspaceRoot = packageRoot.resolve('../../');
  final localGhostty = Directory.fromUri(workspaceRoot.resolve('ghostty/'));
  if (localGhostty.existsSync()) return localGhostty;

  return downloadSource(cacheBase, packageRoot: packageRoot);
}
