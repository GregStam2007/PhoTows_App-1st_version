import 'dart:io';
import 'phash_generator.dart';
import 'photo_scorer.dart';
import 'clusterer.dart';

// ΝΕΕΣ ΔΟΜΕΣ ΔΕΔΟΜΕΝΩΝ
class PhotoGroup {
  final String bestPhoto;
  final List<String> duplicates; // Αυτές που θα διαγραφούν
  final List<String> suggested;  // Οι προτεινόμενες (κοντινές)

  PhotoGroup({required this.bestPhoto, required this.duplicates, required this.suggested});
}

class PipelineResult {
  final List<PhotoGroup> groups;
  final List<String> safePhotos;

  PipelineResult({required this.groups, required this.safePhotos});
}

class PhotoPipeline {
  final PHashGenerator embedder = PHashGenerator();
  final PhotoScorer scorer = PhotoScorer();
  final PhotoClusterer clusterer = PhotoClusterer();

  double getThresholdFromUI(String userChoice) {
    switch (userChoice) {
      case 'Very Loose': return 0.65;
      case 'Loose': return 0.75;
      case 'Strict': return 0.85;
      case 'Very Strict': return 0.92;
      default: return 0.85;
    }
  }

  Future<PipelineResult> runPipeline(String userChoice, String testDirectoryPath) async {
    double strictThreshold = getThresholdFromUI(userChoice);
    // Χαλαρό όριο για τις προτεινόμενες (15% κάτω από το αυστηρό)
    double softThreshold = strictThreshold - 0.15; 
    if (softThreshold < 0) softThreshold = 0;

    Directory inputDirectory = Directory(testDirectoryPath);
    if (!inputDirectory.existsSync()) return PipelineResult(groups: [], safePhotos: []);

    List<FileSystemEntity> files = inputDirectory.listSync().where((item) {
      return item.path.toLowerCase().endsWith('.jpg') || item.path.toLowerCase().endsWith('.png');
    }).toList();

    if (files.isEmpty) return PipelineResult(groups: [], safePhotos: []);

    Map<String, String> hashes = {};
    for (var file in files) {
      String? hash = embedder.getHash(file.path);
      if (hash != null) hashes[file.path] = hash;
    }
    
    // Αρχική ομαδοποίηση
    List<List<String>> allClusters = clusterer.clusterPhotos(hashes, strictThreshold);
    
    List<List<String>> multiClusters = [];
    List<String> singletons = []; // Αυτές που έμειναν μόνες τους

    for (var cluster in allClusters) {
      if (cluster.length > 1) {
        multiClusters.add(cluster);
      } else {
        singletons.add(cluster[0]);
      }
    }

    // Διαχωρισμός Καλύτερης και Διπλότυπων για κάθε ομάδα
    List<PhotoGroup> groups = [];
    for (var cluster in multiClusters) {
      String bestPhoto = cluster[0];
      double bestScore = -1;
      
      for (String photoPath in cluster) {
        double score = scorer.getSharpnessScore(photoPath);
        if (score > bestScore) {
          bestScore = score;
          bestPhoto = photoPath;
        }
      }
      
      List<String> duplicates = List.from(cluster)..remove(bestPhoto);
      groups.add(PhotoGroup(bestPhoto: bestPhoto, duplicates: duplicates, suggested: []));
    }

    // Έλεγχος των "Μοναχικών" για Προτεινόμενα Διπλότυπα
    List<String> finalSafePhotos = [];
    
    for (String singlePath in singletons) {
      String singleHash = hashes[singlePath]!;
      double maxSim = -1.0;
      PhotoGroup? closestGroup;

      // Βρίσκουμε την πιο κοντινή ομάδα
      for (var group in groups) {
        String groupHash = hashes[group.bestPhoto]!;
        double sim = embedder.calculateSimilarity(singleHash, groupHash);
        if (sim > maxSim) {
          maxSim = sim;
          closestGroup = group;
        }
      }

      // Αν περνάει το χαλαρό όριο, μπαίνει στα προτεινόμενα της ομάδας
      if (closestGroup != null && maxSim >= softThreshold) {
        closestGroup.suggested.add(singlePath);
      } else {
        finalSafePhotos.add(singlePath); // Αλλιώς είναι 100% ασφαλής
      }
    }

    return PipelineResult(groups: groups, safePhotos: finalSafePhotos);
  }
}