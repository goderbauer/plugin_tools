// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class TestCommand extends Command {
  TestCommand(this.packagesDir);

  final Directory packagesDir;

  final name = 'test';
  final description = 'Runs the tests for all packages.';

  Future run() async {
    List<String> failingPackages = <String>[];
    for (Directory packageDir in _listAllPackages(packagesDir)) {
      String packageName = p.relative(packageDir.path, from: packagesDir.path);
      if (!new Directory(p.join(packageDir.path, 'test')).existsSync()) {
        print('\nSKIPPING $packageName - no test subdirectory');
        continue;
      }

      print('\nRUNNING $packageName tests...');
      int exitCode =
          await runAndStream('flutter', ['test', '--color'], packageDir);
      if (exitCode != 0) {
        failingPackages.add(packageName);
      }
    }

    print('\n\n');
    if (failingPackages.isNotEmpty) {
      print('Tests for the following packages are failing (see above):');
      failingPackages.forEach((String package) {
        print(' * $package');
      });
      throw new ToolExit(1);
    }

    print('All tests are passing!');
  }

  Iterable<Directory> _listAllPackages(Directory root) => root
      .listSync(recursive: true)
      .where((FileSystemEntity entity) =>
          entity is File && p.basename(entity.path) == 'pubspec.yaml')
      .map((FileSystemEntity entity) => entity.parent);
}
