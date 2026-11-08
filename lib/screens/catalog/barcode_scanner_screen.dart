import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/fit_theme.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../../database/catalog_exception.dart';
import '../../database/catalog_repository.dart';
import '../../models/food.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.userId,
    required this.repository,
  });

  final String userId;
  final CatalogRepository repository;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _lookingUp = false;
  bool _closed = false;
  String? _message;
  final _barcodeInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  @override
  void dispose() {
    _closed = true;
    _barcodeInput.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_lookingUp || _closed) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        value = rawValue;
        break;
      }
    }
    if (value == null) return;

    await _lookup(value);
  }

  Future<void> _lookup(String value) async {
    if (_lookingUp || _closed) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _message = 'Recherche du produit…';
    });

    try {
      try {
        await _controller.stop();
      } catch (_) {
        /* Manual lookup also works without camera. */
      }
      final food = await widget.repository.findByBarcode(
        value,
        userId: widget.userId,
      );
      if (!mounted || _closed) return;
      if (food == null) {
        setState(() {
          _lookingUp = false;
          _message = 'Produit introuvable. Vous pouvez l’ajouter au catalogue.';
        });
        await _controller.start().catchError((Object _) {});
        return;
      }
      Navigator.of(context).pop<Food>(food);
    } on CatalogException catch (error) {
      _showLookupError(error.message);
    } on Exception {
      _showLookupError(
        'Le scan a échoué. Réessayez ou saisissez le produit manuellement.',
      );
    }
  }

  void _showLookupError(String message) {
    if (!mounted || _closed) return;
    setState(() {
      _lookingUp = false;
      _message = message;
    });
    _controller.start().catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Code-barres'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: 'Activer ou désactiver le flash',
            onPressed: _lookingUp ? null : _controller.toggleTorch,
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Changer de caméra',
            onPressed: _lookingUp ? null : _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.78,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: FitTheme.lime, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: FitTheme.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lookingUp) const LinearProgressIndicator(),
                  Text(
                    _message ?? 'Cadrez le code-barres de l’emballage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ou saisissez les chiffres sous le code-barres.',
                    style: TextStyle(color: FitTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeInput,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onSubmitted: _lookingUp ? null : _lookup,
                          decoration: const InputDecoration(
                            hintText: 'Ex. 3017620422003',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: _lookingUp
                            ? null
                            : () => _lookup(_barcodeInput.text),
                        tooltip: 'Rechercher le produit',
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'La caméra n’est pas disponible. Vérifiez son autorisation dans les réglages.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.errorCode.name,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
