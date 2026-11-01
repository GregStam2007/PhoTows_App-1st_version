import 'phash_generator.dart';

class PhotoClusterer {
  final PHashGenerator phash = PHashGenerator();
  
  /// Επιστρέφει μια λίστα από ομάδες (κάθε ομάδα είναι μια λίστα με τα μονοπάτια των φωτογραφιών)
  List<List<String>> clusterPhotos(Map<String, String> hashes, double similarityThreshold) {
    List<List<String>> clusters = [];
    List<String> unassigned = hashes.keys.toList();

    while (unassigned.isNotEmpty) {
      String currentPhoto = unassigned.removeAt(0);
      List<String> currentCluster = [currentPhoto];
      String currentHash = hashes[currentPhoto]!;

      // Ψάχνουμε ποιες από τις υπόλοιπες μοιάζουν με αυτήν
      List<String> toRemove = [];
      for (String otherPhoto in unassigned) {
        String otherHash = hashes[otherPhoto]!;
        double sim = phash.calculateSimilarity(currentHash, otherHash);
        
        if (sim >= similarityThreshold) {
          currentCluster.add(otherPhoto); // Βρήκαμε διπλότυπο!
          toRemove.add(otherPhoto);
        }
      }

      // Τις βγάζουμε από την αναμονή γιατί μπήκαν ήδη στην ομάδα
      for (String matched in toRemove) {
        unassigned.remove(matched);
      }

      clusters.add(currentCluster);
    }

    return clusters;
  }
}

