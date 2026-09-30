/// Web implementations of the library's two seams — see
/// [MemorySessionIndexStore] for why the browser index is not persisted.
library;

import 'session_file_system.dart';
import 'session_index_store.dart';

SessionIndexStore openPlatformSessionIndexStore() => MemorySessionIndexStore();

SessionFileSystem platformSessionFileSystem() => const NoSessionFileSystem();
