import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'file_saver.dart';

Future<void> saveFile(String data, String fileName) async {
  // CRITICAL PRINT 1: Confirms this specific file (the web implementation) is being executed.
  print('PLATFORM CHECK: Running WEB file save logic.');
  print('File Name: $fileName, Data Size: ${data.length} chars'); // Check data size

  try {
    // 1. Create a Blob from the data (assuming text/csv)
    final bytes = Uint8List.fromList(data.codeUnits);

    // CRITICAL PRINT 2: Check if Blob creation succeeded.
    print('Web: Converted data to bytes.');

    final blob = html.Blob([bytes]);

    // 2. Create an anchor element and trigger download
    final url = html.Url.createObjectUrlFromBlob(blob);

    // CRITICAL PRINT 3: Check if the download trigger is attempted.
    print('Web: Created temporary object URL and attempting download click.');

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click(); // Trigger the download

    // 3. Clean up the URL
    html.Url.revokeObjectUrl(url);

    print('Web: Download action initiated and URL revoked.');

  } catch (e) {
    // CRITICAL PRINT 4: If any part of the web logic fails, this catches it.
    print('!!! WEB EXPORT FAILED DURING DOWNLOAD PROCESS: $e');
    throw Exception('Web download failed: $e');
  }
}