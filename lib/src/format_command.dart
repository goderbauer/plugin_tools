// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import 'common.dart';

const String _googleFormatterUrl =
    'https://github.com/google/google-java-format/releases/download/google-java-format-1.3/google-java-format-1.3-all-deps.jar';

class FormatCommand extends Command {
  FormatCommand(this.packagesDir) {
    argParser.addFlag('travis', hide: true);
    argParser.addOption('clang-format', defaultsTo: 'clang-format');
  }

  final Directory packagesDir;

  final name = 'format';
  final description = 'Formats the code of all packages.';

  Future run() async {
    String googleFormatterPath = await _getGogleFormatterPath();

    _formatDart();
    _formatJava(googleFormatterPath);
    _formatObjectiveC();

    if (argResults['travis']) {
      bool success = _printSummary();
      if (!success) {
        throw new ToolExit(1);
      }
    }
  }

  bool _printSummary() {
    ProcessResult modifiedFiles = Process.runSync(
        'git', ['ls-files', '--modified'],
        workingDirectory: packagesDir.path);

    print('\n\n');

    if (modifiedFiles.stdout.isEmpty) {
      print('All files formatted correctly.');
      return true;
    }

    ProcessResult diff = Process.runSync('git', ['diff', '--color'],
        workingDirectory: packagesDir.path);
    print(diff.stdout);

    print('These files are not formatted correctly (see diff above):');
    LineSplitter
        .split(modifiedFiles.stdout)
        .map((String line) => '  $line')
        .forEach(print);
    print('\nTo fix run "pub global activate flutter_plugin_tools && '
        'pub global run flutter_plugin_tools format".');

    return false;
  }

  void _formatObjectiveC() {
    print('Formatting all .m and .h files...');
    Iterable<String> hFiles = _getFilesWithExtension(packagesDir, '.h');
    Iterable<String> mFiles = _getFilesWithExtension(packagesDir, '.m');
    Process.runSync(argResults['clang-format'],
        ['-i', '--style=Google']..addAll(hFiles)..addAll(mFiles),
        workingDirectory: packagesDir.path);
  }

  void _formatJava(String googleFormaterPath) {
    print('Formatting all .java files...');
    Iterable<String> javaFiles = _getFilesWithExtension(packagesDir, '.java');
    Process.runSync(
        'java', ['-jar', googleFormaterPath, '--replace']..addAll(javaFiles),
        workingDirectory: packagesDir.path);
  }

  void _formatDart() {
    print('Formatting all .dart files...');
    Process.runSync('flutter', ['format'], workingDirectory: packagesDir.path);
  }

  Iterable<String> _getFilesWithExtension(Directory dir, String extension) =>
      dir
          .listSync(recursive: true)
          .where((FileSystemEntity entity) =>
              entity is File && p.extension(entity.path) == extension)
          .map((FileSystemEntity entity) => entity.path);

  Future<String> _getGogleFormatterPath() async {
    String javaFormatterPath = p.join(p.dirname(p.fromUri(Platform.script)),
        'google-java-format-1.3-all-deps.jar');
    File javaFormatterFile = new File(javaFormatterPath);

    if (!javaFormatterFile.existsSync()) {
      print('Downloading Google Java Format...');
      http.Response response = await http.get(_googleFormatterUrl);
      javaFormatterFile.writeAsBytesSync(response.bodyBytes);
    }

    return javaFormatterPath;
  }
}
