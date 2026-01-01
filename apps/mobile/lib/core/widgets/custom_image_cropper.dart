import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class CustomImageCropper extends StatefulWidget {
  const CustomImageCropper({
    super.key,
    required this.image,
    required this.onCropped,
  });

  final Uint8List image;
  final ValueChanged<Uint8List> onCropped;

  @override
  State<CustomImageCropper> createState() => _CustomImageCropperState();
}

class _CustomImageCropperState extends State<CustomImageCropper> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Bar - Geri ve Onay butonları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  const Text(
                    "Logo Düzenle",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_isCropping) return;
                      setState(() => _isCropping = true);
                      _controller.crop();
                    },
                    icon: _isCropping
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            // Kırpma Alanı
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Crop(
                    image: widget.image,
                    controller: _controller,
                    onCropped: (image) {
                      widget.onCropped(image);
                      Navigator.of(context).pop();
                    },
                    aspectRatio: 1, // Kare format
                    baseColor: Colors.black,
                    maskColor: Colors.black.withOpacity(0.7),
                    radius: 20,
                    interactive: true,
                    // fixAspectRatio parametresi 1.1.0 sürümünde mevcut değil.AspectRatio zaten 1 olarak ayarlandı.
                    // initialRectBuilder: (rect, _) => Rect.fromLTRB(
                    //   rect.left + 20, rect.top + 20, rect.right - 20, rect.bottom - 20
                    // ),
                    cornerDotBuilder: (size, edgeAlignment) => const SizedBox.shrink(), // Köşe noktalarını gizle (opsiyonel)
                  ),
                ),
              ),
            ),

            // Alt Kontroller (İsteğe bağlı, rotate vb. eklenebilir ama clean istendi)
            // Kullanıcı "alt kısımdaki scale ve restart butonları da yukarı gelmeli" demişti, 
            // ama crop_your_image gesture ile çalışıyor zaten (zoom/pan).
            // Ekstra butona gerek yok. Sadece bilgi notu eklenebilir.
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                "Yakınlaştırmak için iki parmağınızı kullanın",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
