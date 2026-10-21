import 'package:flutter/material.dart';

import '../ui/interior.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _captured = false;
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => InteriorScope(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Quét QR chấm công')),
      body: MobileScanner(
        key: ValueKey(_attempt),
        fit: BoxFit.contain,
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chưa mở được camera. Kiểm tra quyền camera trong cài đặt. Bạn có thể quay lại để dán mã QR.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _attempt++),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        onDetect: (capture) {
          if (_captured || !mounted) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (barcode.format == BarcodeFormat.qrCode &&
                value != null &&
                value.isNotEmpty) {
              _captured = true;
              Navigator.of(context).pop(value);
              break;
            }
          }
        },
      ),
    ),
  );
}
