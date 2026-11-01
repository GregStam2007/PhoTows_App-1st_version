import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'pipeline.dart'; 

void main() {
  runApp(const PhoTowsApp());
}

class PhoTowsApp extends StatelessWidget {
  const PhoTowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhoTows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PhoTowsHomePage(),
    );
  }
}

class PhoTowsHomePage extends StatefulWidget {
  const PhoTowsHomePage({super.key});

  @override
  State<PhoTowsHomePage> createState() => _PhoTowsHomePageState();
}

class _PhoTowsHomePageState extends State<PhoTowsHomePage> {
  String _statusText = "Πάτα το + για να επιλέξεις\nφωτογραφίες από τη συλλογή σου!";
  bool _isProcessing = false;
  String _selectedStrictness = 'Strict'; 

  List<File> _currentPhotos = [];
  Map<String, AssetEntity> _photoEntities = {}; 

  Future<void> _pickPhotos() async {
    final List<AssetEntity>? pickedAssets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 50, 
        requestType: RequestType.image,
      ),
    );

    if (pickedAssets != null && pickedAssets.isNotEmpty) {
      setState(() {
        _isProcessing = true;
        _statusText = "Φόρτωση επιλεγμένων φωτογραφιών...";
      });

      List<File> files = [];
      Map<String, AssetEntity> entitiesMap = {};

      for (var asset in pickedAssets) {
        final file = await asset.file;
        if (file != null) {
          files.add(file);
          entitiesMap[file.path] = asset;
        }
      }

      setState(() {
        _currentPhotos = files;
        _photoEntities = entitiesMap;
        _statusText = "Επιλέχθηκαν ${_currentPhotos.length} φωτογραφίες!";
        _isProcessing = false;
      });
    }
  }

  Future<void> _startProcessing() async {
    if (_currentPhotos.isEmpty) {
      setState(() => _statusText = "Διάλεξε πρώτα μερικές φωτογραφίες!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = "Η ανάλυση ξεκίνησε... Παρακαλώ περίμενε.";
    });

    try {
      final dir = Directory.systemTemp.createTempSync();
      for (var file in _currentPhotos) {
        file.copySync('${dir.path}/${file.uri.pathSegments.last}');
      }
      
      final pipeline = PhotoPipeline();
      // Παίρνουμε το νέο σύνθετο αποτέλεσμα
      PipelineResult result = await pipeline.runPipeline(_selectedStrictness, dir.path);
      
      // Φτιάχνουμε λίστα με τις αρχικές προεπιλεγμένες διαγραφές (τα σίγουρα διπλότυπα)
      List<String> initialDeletions = [];
      for (var group in result.groups) {
        for (var tempPath in group.duplicates) {
          String fileName = tempPath.split('/').last;
          String realPath = _currentPhotos.firstWhere((f) => f.path.endsWith(fileName)).path;
          initialDeletions.add(realPath);
        }
      }

      setState(() => _isProcessing = false);

      final finalSelection = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            allPhotos: _currentPhotos,
            pipelineResult: result,
            initialDeletions: initialDeletions,
          ),
        ),
      );

      if (finalSelection != null && finalSelection.isNotEmpty) {
        List<String> idsToDelete = [];
        for (String path in finalSelection) {
          if (_photoEntities.containsKey(path)) {
            idsToDelete.add(_photoEntities[path]!.id);
          }
        }

        final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

        setState(() {
          _currentPhotos.removeWhere((file) => finalSelection.contains(file.path));
          _statusText = "Ολοκληρώθηκε!\nΔιαγράφηκαν οριστικά ${result.length} φωτογραφίες 🗑️";
        });
      } else {
        setState(() => _statusText = "Η εκκαθάριση ακυρώθηκε.");
      }
    } catch (e) {
      setState(() {
        _statusText = "Υπήρξε κάποιο σφάλμα.";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhoTows (Edge AI)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Αυστηρότητα: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _selectedStrictness,
                      items: <String>['Very Loose', 'Loose', 'Strict', 'Very Strict']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: _isProcessing ? null : (String? newValue) {
                        setState(() {
                          _selectedStrictness = newValue!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                if (_isProcessing) const LinearProgressIndicator(),
              ],
            ),
          ),
          Expanded(
            child: _currentPhotos.isEmpty
                ? const Center(child: Icon(Icons.photo_library, size: 100, color: Colors.black12))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                    ),
                    itemCount: _currentPhotos.length,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_currentPhotos[index], fit: BoxFit.cover, cacheWidth: 200),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isProcessing ? null : _pickPhotos,
            tooltip: 'Επιλογή Φωτογραφιών',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _isProcessing ? null : _startProcessing,
            tooltip: 'Έναρξη Εκκαθάρισης',
            child: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ΝΕΑ ΟΘΟΝΗ ΟΜΑΔΟΠΟΙΗΜΕΝΟΥ ΕΛΕΓΧΟΥ
// ==========================================
class ReviewScreen extends StatefulWidget {
  final List<File> allPhotos;
  final PipelineResult pipelineResult;
  final List<String> initialDeletions;

  const ReviewScreen({super.key, required this.allPhotos, required this.pipelineResult, required this.initialDeletions});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Set<String> _selectedForDeletion;

  @override
  void initState() {
    super.initState();
    _selectedForDeletion = Set<String>.from(widget.initialDeletions);
  }

  // Helper για να βρίσκουμε το πραγματικό File από το προσωρινό όνομα
  File _getRealFile(String tempPath) {
    String fileName = tempPath.split('/').last;
    return widget.allPhotos.firstWhere((f) => f.path.endsWith(fileName));
  }

  // Η νέα, πιο κομψή κάρτα φωτογραφίας
  Widget _buildPhotoCard(File file) {
    final isSelected = _selectedForDeletion.contains(file.path);

    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? _selectedForDeletion.remove(file.path) : _selectedForDeletion.add(file.path);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transformAlignment: Alignment.center,
        // Αν είναι επιλεγμένη, την μικραίνει λιγάκι
        transform: Matrix4.identity()..scale(isSelected ? 0.88 : 1.0), 
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file, fit: BoxFit.cover, cacheWidth: 200),
            ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), // Κομψό σκούρο φίλτρο αντί για κόκκινο
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent, width: 3), // Κόκκινο περίγραμμα
                ),
                child: const Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.delete, color: Colors.white, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> tempPaths) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: tempPaths.length,
      itemBuilder: (context, index) {
        return _buildPhotoCard(_getRealFile(tempPaths[index]));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Έλεγχος Ομάδων'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // 1. Εμφάνιση των Ομάδων με τα προτεινόμενά τους
          for (int i = 0; i < widget.pipelineResult.groups.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
              child: Text(
                'Ομάδα ${i + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            _buildGrid([
              widget.pipelineResult.groups[i].bestPhoto,
              ...widget.pipelineResult.groups[i].duplicates
            ]),
            
            // Αν υπάρχουν προτεινόμενα, τα βάζουμε ακριβώς από κάτω!
            if (widget.pipelineResult.groups[i].suggested.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
                child: Text(
                  '↳ Προτεινόμενες (Παρόμοιες)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
              _buildGrid(widget.pipelineResult.groups[i].suggested),
            ],
            const Divider(thickness: 2),
          ],

          // 2. Οι εντελώς Ασφαλείς Φωτογραφίες στο τέλος
          if (widget.pipelineResult.safePhotos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 16, bottom: 8),
              child: Text(
                'Ασφαλείς / Χωρίς Διπλότυπο',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            _buildGrid(widget.pipelineResult.safePhotos),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, _selectedForDeletion.toList());
        },
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: Text('Διαγραφή ${_selectedForDeletion.length}'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}