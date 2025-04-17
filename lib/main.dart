// תיקון קריסה כשמתנגנים מספר צלילים: נוסיף המתנה לכל פעולת stop+dispose

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Board',
      theme: ThemeData(
        fontFamily: 'sans',
        scaffoldBackgroundColor: const Color(0xFFFCF5F8),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_SoundBoardScreenState> _soundBoardKey = GlobalKey();

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return SoundBoardScreen(key: _soundBoardKey);
      case 1:
        return const SoundManagerScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onItemTapped(int index) async {
    if (_selectedIndex == 0) {
      await _soundBoardKey.currentState?.stopAllSounds();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'לוח צלילים',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'רשימה',
          ),
        ],
      ),
    );
  }
}

class SoundBoardScreen extends StatefulWidget {
  const SoundBoardScreen({super.key});

  @override
  State<SoundBoardScreen> createState() => _SoundBoardScreenState();
}

class _SoundBoardScreenState extends State<SoundBoardScreen> {
  List<String> selectedFiles = [];
  final Map<String, AudioPlayer> _players = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedSounds();
  }

  Future<void> stopAllSounds() async {
    final futures = _players.values.map((player) async {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    });
    await Future.wait(futures);
    _players.clear();
  }

  @override
  void dispose() {
    stopAllSounds();
    super.dispose();
  }

  Future<void> _loadSelectedSounds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFiles = prefs.getStringList('selected_sounds') ?? [];
    });
  }

  void _onSoundPressed(String file) async {
    if (_players.containsKey(file)) {
      await _players[file]?.stop();
      await _players[file]?.dispose();
      setState(() {
        _players.remove(file);
      });
    } else {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/$file'));
      setState(() {
        _players[file] = player;
      });
      player.onPlayerComplete.listen((event) {
        setState(() {
          _players.remove(file);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('לוח הצלילים של שון ורון'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: selectedFiles.isEmpty
          ? const Center(child: Text('כאן תוצג רשימת הצלילים'))
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: selectedFiles.map((file) {
                final name = file.replaceAll('.wav', '').replaceAll('.mp3', '');
                final isPlaying = _players.containsKey(file);

                return GestureDetector(
                  onTap: () => _onSoundPressed(file),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isPlaying ? Colors.red[300] : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isPlaying
                          ? const Icon(Icons.pause, size: 30, color: Colors.white)
                          : Text(name, textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class SoundManagerScreen extends StatefulWidget {
  const SoundManagerScreen({super.key});

  @override
  State<SoundManagerScreen> createState() => _SoundManagerScreenState();
}

class _SoundManagerScreenState extends State<SoundManagerScreen> {
  List<String> allFiles = [];
  List<String> selectedFiles = [];
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<String>> soundTags = {};
  AudioPlayer? _singlePlayer;
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadSoundFiles();
    _loadSelectedSounds();
    _loadSoundTags();
    generateSoundMetadataJson().then(print);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _singlePlayer?.stop();
    _singlePlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadSoundFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final files = manifestMap.keys
        .where((path) => path.startsWith('assets/sounds/') &&
            (path.endsWith('.wav') || path.endsWith('.mp3')))
        .map((path) => path.split('/').last)
        .toList();

    setState(() {
      allFiles = files;
    });
  }

  Future<void> _loadSelectedSounds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFiles = prefs.getStringList('selected_sounds') ?? [];
    });
  }

  Future<void> _loadSoundTags() async {
    final jsonString = await rootBundle.loadString('assets/data/sound_metadata.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    setState(() {
      soundTags = jsonMap.map((key, value) => MapEntry(key, List<String>.from(value)));
    });
  }

  Future<String> generateSoundMetadataJson() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final files = manifestMap.keys
        .where((path) => path.startsWith('assets/sounds/') &&
            (path.endsWith('.wav') || path.endsWith('.mp3')))
        .map((path) => path.split('/').last)
        .toList();

    final metadata = { for (var file in files) file: [] };
    return const JsonEncoder.withIndent('  ').convert(metadata);
  }

  Future<void> _toggleSelection(String file) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (selectedFiles.contains(file)) {
        selectedFiles.remove(file);
      } else if (selectedFiles.length < 6) {
        selectedFiles.add(file);
      }
    });
    await prefs.setStringList('selected_sounds', selectedFiles);
  }

  void _onSoundPressed(String file) async {
    if (_currentlyPlaying == file) {
      await _singlePlayer?.stop();
      await _singlePlayer?.dispose();
      setState(() {
        _currentlyPlaying = null;
        _singlePlayer = null;
      });
    } else {
      await _singlePlayer?.stop();
      await _singlePlayer?.dispose();

      final player = AudioPlayer();
      await player.play(AssetSource('sounds/$file'));

      setState(() {
        _currentlyPlaying = file;
        _singlePlayer = player;
      });

      player.onPlayerComplete.listen((event) {
        setState(() {
          _currentlyPlaying = null;
          _singlePlayer = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = allFiles.where((file) {
      final name = file.toLowerCase();
      final tags = soundTags[file]?.join(' ').toLowerCase() ?? '';
      return name.contains(query.toLowerCase()) || tags.contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('!ניהול הצלילים'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'חיפוש לפי שם או תיוג',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: filteredFiles.isEmpty
                ? const Center(child: Text('לא נמצאו צלילים תואמים'))
                : ListView(
                    children: filteredFiles.map((file) {
                      final name = file.replaceAll('.wav', '').replaceAll('.mp3', '');
                      final isSelected = selectedFiles.contains(file);
                      final tags = soundTags[file] ?? [];
                      final isPlaying = _currentlyPlaying == file;

                      return ListTile(
                        leading: IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.volume_up),
                          onPressed: () => _onSoundPressed(file),
                        ),
                        title: Text(name, textAlign: TextAlign.right),
                        subtitle: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          children: tags.map((tag) => Chip(label: Text(tag))).toList(),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(file),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
