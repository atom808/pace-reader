/// A minimal reader for the one zip Pace Reader opens: Le Mans Ultimate's
/// `Bin\UI.zip`.
///
/// The file is 1.2 GB and Pace Reader wants about sixty small entries from
/// it, so nothing here reads it whole: [ZipReader.open] reads only the central
/// directory at the end, and [ZipReader.read] seeks to one entry and inflates
/// that. No dependency: `dart:io` already inflates raw deflate streams.
///
/// The game's zip uses backslash separators; [ZipReader.names] reports them as
/// `/`. Zip64 archives and encrypted entries are not supported and read as
/// absent.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ZipEntry {
  const ZipEntry({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.size,
    required this.headerOffset,
  });

  /// `/`-separated, whatever the archive used.
  final String name;
  final int method;
  final int compressedSize;
  final int size;
  final int headerOffset;
}

class ZipReader {
  ZipReader._(this._file, this.entries);

  final RandomAccessFile _file;
  final Map<String, ZipEntry> entries;

  static const _endSignature = 0x06054b50;
  static const _centralSignature = 0x02014b50;
  static const _localSignature = 0x04034b50;

  /// Opens [path], or null when it is not a readable, non-zip64 archive.
  static Future<ZipReader?> open(String path) async {
    RandomAccessFile? file;
    try {
      file = await File(path).open();
      final length = await file.length();
      final tailLength = length < 66000 ? length : 66000;
      await file.setPosition(length - tailLength);
      final tail = ByteData.sublistView(await file.read(tailLength));

      var end = -1;
      for (var i = tailLength - 22; i >= 0; i--) {
        if (tail.getUint32(i, Endian.little) == _endSignature) {
          end = i;
          break;
        }
      }
      if (end < 0) {
        await file.close();
        return null;
      }
      final count = tail.getUint16(end + 10, Endian.little);
      final directorySize = tail.getUint32(end + 12, Endian.little);
      final directoryOffset = tail.getUint32(end + 16, Endian.little);
      if (directoryOffset == 0xFFFFFFFF || directorySize == 0xFFFFFFFF) {
        await file.close();
        return null;
      }

      await file.setPosition(directoryOffset);
      final directory = await file.read(directorySize);
      final view = ByteData.sublistView(directory);
      final entries = <String, ZipEntry>{};
      var at = 0;
      for (var i = 0; i < count && at + 46 <= directory.length; i++) {
        if (view.getUint32(at, Endian.little) != _centralSignature) break;
        final flags = view.getUint16(at + 8, Endian.little);
        final method = view.getUint16(at + 10, Endian.little);
        final compressed = view.getUint32(at + 20, Endian.little);
        final size = view.getUint32(at + 24, Endian.little);
        final nameLength = view.getUint16(at + 28, Endian.little);
        final extraLength = view.getUint16(at + 30, Endian.little);
        final commentLength = view.getUint16(at + 32, Endian.little);
        final offset = view.getUint32(at + 42, Endian.little);
        final raw = directory.sublist(at + 46, at + 46 + nameLength);
        final name = utf8.decode(raw, allowMalformed: true).replaceAll('\\', '/');
        at += 46 + nameLength + extraLength + commentLength;
        // Encrypted entries and zip64 sentinels read as absent.
        if (flags & 1 != 0 || offset == 0xFFFFFFFF || size == 0xFFFFFFFF) {
          continue;
        }
        entries[name] = ZipEntry(
          name: name,
          method: method,
          compressedSize: compressed,
          size: size,
          headerOffset: offset,
        );
      }
      return ZipReader._(file, entries);
    } on Object {
      await file?.close();
      return null;
    }
  }

  Iterable<String> get names => entries.keys;

  /// The entry's bytes, or null when it is missing or cannot be inflated.
  Future<Uint8List?> read(String name) async {
    final entry = entries[name];
    if (entry == null) return null;
    try {
      await _file.setPosition(entry.headerOffset);
      final header = ByteData.sublistView(await _file.read(30));
      if (header.getUint32(0, Endian.little) != _localSignature) return null;
      final skip = header.getUint16(26, Endian.little) +
          header.getUint16(28, Endian.little);
      await _file.setPosition(entry.headerOffset + 30 + skip);
      final data = await _file.read(entry.compressedSize);
      return switch (entry.method) {
        0 => data,
        8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(data)),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  Future<void> close() => _file.close();
}
