// What `sebring_race_laps0_3.duckdb` says about its course (comparison
// proposal §4), as `CourseRepository` reads it from the whole file:
// `integration_test/compare_test.dart` asserts these against the file.
//
// Dart, for the tests that cannot open a `.duckdb` file: with these, the two
// 5 Hz fixture laps re-anchor on the game's splits exactly as they do in the
// app (D1).
library;

import 'package:pace_reader/data/models/models.dart';

const sebringCourse = CourseFacts(
  wrapLength: 3083.313,
  wrapCount: 3,
  sector1Station: 1029.435,
  sector2Station: 1572.549,
);
