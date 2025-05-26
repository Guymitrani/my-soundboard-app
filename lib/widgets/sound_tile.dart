import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WaveSoundTileLight extends StatefulWidget {
  final String fileName;
  final String displayName;

  const WaveSoundTileLight({
    super.key,
    required this.fileName,
    required this.displayName,
  });

  @override
  State<WaveSoundTileLight> createState() => _WaveSoundTileLightState();
}

class _WaveSoundTileLightState extends State<WaveSoundTileLight>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _animationController;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _animationController = AnimationController(vsync: this);
    _player.onPlayerComplete.listen((event) => _reset());
  }

  void _reset() {
    _animationController.stop();
    _animationController.reset();
    setState(() => isPlaying = false);
  }

  Future<void> _onTap() async {
    if (isPlaying) {
      await _player.stop();
      _reset();
    } else {
      await _player.stop();
      _animationController.stop();

      await _player.setSource(AssetSource('sounds/${widget.fileName}'));
      final duration = await _player.getDuration();

      if (duration != null) {
        _animationController.duration = duration;
        await _player.resume();
        _animationController.forward(from: 0.0);
        setState(() => isPlaying = true);
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = widget.fileName
        .replaceAll('.mp3', '')
        .replaceAll('.wav', '');

    return GestureDetector(
      onTap: _onTap,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Waveform background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.8, // 0 = שקוף לגמרי, 1 = אטום לגמרי
                  child: SvgPicture.asset(
                    'assets/images/$imageFile.svg',
                    fit: BoxFit.cover,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ),

              // Lightweight progress layer
              AnimatedBuilder(
                animation: _animationController,
                builder: (_, __) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _animationController.value,
                      child: ShaderMask(
                        blendMode: BlendMode.colorDodge,
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: [
                              Color.fromARGB(100, 255, 0, 106),
                              Color.fromARGB(100, 255, 0, 0),
                            ],
                          ).createShader(bounds);
                        },
                        child: Container(
                          color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.8) // בסיס לתצוגת הצבעים
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Text label on top
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      shadows: [Shadow(blurRadius: 10, color: Colors.white)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
