// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class BuildCommand extends Command {
  BuildCommand(this.packagesDir) {
    argParser.addFlag('ipa', defaultsTo: Platform.isMacOS);
    argParser.addFlag('apk');
  }

  final Directory packagesDir;

  final name = 'build';
  final description = 'Builds all example apps.';

  Future run() async {
    List<String> failingPackages = <String>[];
    for (Directory example in _getExamplePackages(packagesDir)) {
      String packageName = p.relative(example.path, from: packagesDir.path);

      if (argResults['ipa']) {
        print('\nBUILDING IPA for $packageName');
        int exitCode = await runAndStream(
            'flutter', ['build', 'ios', '--no-codesign'], example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (ipa)');
        }
      }

      if (argResults['apk']) {
        print('\nBUILDING APK for $packageName');
        int exitCode = await runAndStream('flutter', ['build', 'apk'], example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (apk)');
        }
      }
    }

    print('\n\n');

    if (failingPackages.isNotEmpty) {
      print('The following build are failing (see above for details):');
      failingPackages.forEach((String package) {
        print(' * $package');
      });
      throw new ToolExit(1);
    }

    print('All builds successful!');
  }

  Iterable<Directory> _getExamplePackages(Directory dir) => dir
      .listSync(recursive: true)
      .where((FileSystemEntity entity) =>
          entity is Directory && p.basename(entity.path) == 'example')
      .where((Directory dir) => dir.listSync().any((FileSystemEntity entity) =>
          entity is File && p.basename(entity.path) == 'pubspec.yaml'));
}
