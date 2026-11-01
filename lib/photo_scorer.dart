import 'dart:io';

class PhotoScorer {
  /// Επιστρέφει ένα σκορ καθαρότητας. Υψηλότερο σκορ = πιο καθαρή εικόνα.
  double getSharpnessScore(String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return 0.0;

      // TODO: Εδώ θα προσθέσουμε τον μαθηματικό υπολογισμό της αντίθεσης των pixels 
      // (Laplacian variance) σε Dart στο επόμενο βήμα.
      // Προς το παρόν, επιστρέφουμε το μέγεθος του αρχείου ως προσωρινό κριτήριο 
      // (συχνά οι πιο καθαρές φωτογραφίες έχουν περισσότερα δεδομένα/μεγαλύτερο μέγεθος).
      return file.lengthSync().toDouble();
      
    } catch (e) {
      print("Σφάλμα κατά τη βαθμολόγηση της $imagePath: $e");
      return 0.0;
    }
  }
}

