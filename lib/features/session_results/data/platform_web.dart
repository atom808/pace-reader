/// Web: no folders to read, so nothing to index.
library;

import 'results_file_system.dart';
import 'results_index_store.dart';

ResultsIndexStore openPlatformResultsIndexStore() => MemoryResultsIndexStore();

ResultsFileSystem platformResultsFileSystem() => const NoResultsFileSystem();
