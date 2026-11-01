import 'dart:io';
import 'package:image/image.dart' as img;

class PHashGenerator {
  /// Παίρνει το μονοπάτι μιας εικόνας και επιστρέφει το pHash (string από 0 και 1)
  String? getHash(String imagePath) { 
    try {
      // 1. Διαβάζουμε την εικόνα από το κινητό
      final bytes = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 2. Σμίκρυνση σε 8x8 (όπως απαιτεί ο κλασικός αλγόριθμος)
      final resized = img.copyResize(image, width: 8, height: 8);

      // 3. Μετατροπή σε ασπρόμαυρο (Grayscale)
      final grayscale = img.grayscale(resized);

      // 4. Υπολογισμός του μέσου όρου φωτεινότητας
      int totalLuminance = 0;
      List<int> pixelValues = [];
      
      for (var pixel in grayscale) {
        // Παίρνουμε την τιμή του γκρι (0-255)
        int lum = pixel.luminance.toInt();
        pixelValues.add(lum);
        totalLuminance += lum;
      }
      
      int averageLuminance = totalLuminance ~/ 64; // 8x8 = 64 pixels

      // 5. Δημιουργία του Hash (1 αν είναι πάνω από τον μέσο όρο, 0 αν είναι κάτω)
      String hash = "";
      for (int lum in pixelValues) {
        hash += (lum >= averageLuminance) ? "1" : "0";
      }

      return hash;
    } catch (e) {
      print("Σφάλμα κατά τη δημιουργία pHash για $imagePath: $e");
      return null;
    }
  }

  /// Υπολογίζει την ομοιότητα (0.0 έως 1.0) μεταξύ δύο hashes
  double calculateSimilarity(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 0.0;
    int identicalBits = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] == hash2[i]) identicalBits++;
    }
    return identicalBits / hash1.length;
  }
}

