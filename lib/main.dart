import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/sound_tile.dart';
import 'package:flutter/foundation.dart';

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const SoundBoardScreen(),
      const SoundManagerScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
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
  late Future<List<String>> _selectedFilesFuture;

  Future<List<String>> _loadSelectedSounds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('selected_sounds') ?? [];
  }

  @override
  void initState() {
    super.initState();
    _selectedFilesFuture = _loadSelectedSounds();
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
      body: FutureBuilder<List<String>>(
        future: _selectedFilesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedFiles = snapshot.data!;
          if (selectedFiles.isEmpty) {
            return const Center(child: Text('כאן תוצג רשימת הצלילים'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: selectedFiles.length,
            itemBuilder: (context, index) {
              final fileName = selectedFiles[index];
              final displayName = fileName
                  .replaceAll('.wav', '')
                  .replaceAll('.mp3', '');

              return WaveSoundTileLight(
                fileName: fileName,
                displayName: displayName,
              );
            },
          );
        },
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
  late SharedPreferences _prefs;
  List<String> allFiles = [];
  List<String> selectedFiles = [];
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<String>> soundTags = {};
  AudioPlayer? _singlePlayer;
  String? _currentlyPlaying;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSoundFiles();
    await _loadSelectedSounds();
    await _loadSoundTags();
  }

  Future<void> _loadSoundFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final files = manifestMap.keys
        .where((path) =>
            path.startsWith('assets/sounds/') &&
            (path.endsWith('.wav') || path.endsWith('.mp3')))
        .map((path) => path.split('/').last)
        .toList();
    setState(() {
      allFiles = files;
    });
  }

  Future<void> _loadSelectedSounds() async {
    final list = _prefs.getStringList('selected_sounds') ?? [];
    if (!listEquals(selectedFiles, list)) {
      setState(() {
        selectedFiles = list;
      });
    }
  }

  Future<void> _loadSoundTags() async {
    final jsonString =
        await rootBundle.loadString('assets/data/sound_metadata.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    setState(() {
      soundTags =
          jsonMap.map((key, value) => MapEntry(key, List<String>.from(value)));
    });
  }

  Future<void> _toggleSelection(String file) async {
    if (selectedFiles.contains(file)) {
      selectedFiles.remove(file);
    } else if (selectedFiles.length < 6) {
      selectedFiles.add(file);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ניתן לבחור עד 6 צלילים בלבד')),
      );
      return;
    }
    setState(() {});
    await _prefs.setStringList('selected_sounds', selectedFiles);
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        query = value;
      });
    });
  }

  void _onSoundPressed(String file) async {
    if (_currentlyPlaying == file) {
      await _stopAndDisposeSinglePlayer();
    } else {
      await _stopAndDisposeSinglePlayer();
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/$file'));
      setState(() {
        _currentlyPlaying = file;
        _singlePlayer = player;
      });
      player.onPlayerComplete.listen((_) {
        setState(() {
          _currentlyPlaying = null;
          _singlePlayer = null;
        });
      });
    }
  }

  Future<void> _stopAndDisposeSinglePlayer() async {
    try {
      await _singlePlayer?.stop();
      await _singlePlayer?.release();
      await _singlePlayer?.dispose();
    } catch (_) {}
    _singlePlayer = null;
    _currentlyPlaying = null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stopAndDisposeSinglePlayer();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = allFiles.where((file) {
      final name = file.toLowerCase();
      final tags = soundTags[file]?.join(' ').toLowerCase() ?? '';
      return name.contains(query.toLowerCase()) ||
          tags.contains(query.toLowerCase());
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
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: filteredFiles.isEmpty
                ? const Center(child: Text('לא נמצאו צלילים תואמים'))
                : ListView.builder(
                    itemCount: filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = filteredFiles[index];
                      final name = file
                          .replaceAll('.wav', '')
                          .replaceAll('.mp3', '');
                      final isSelected = selectedFiles.contains(file);
                      final tags = soundTags[file] ?? [];
                      final isPlaying = _currentlyPlaying == file;

                      return ListTile(
                        leading: IconButton(
                          icon: Icon(
                              isPlaying ? Icons.pause : Icons.volume_up),
                          onPressed: () => _onSoundPressed(file),
                        ),
                        title: Text(name, textAlign: TextAlign.right),
                        subtitle: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          children:
                              tags.map((tag) => Chip(label: Text(tag))).toList(),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(file),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
