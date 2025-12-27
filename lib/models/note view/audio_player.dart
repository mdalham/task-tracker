import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';

import '../../widget/custom_container.dart';

class AudioPlayer extends StatefulWidget {
  final File file;

  const AudioPlayer({super.key, required this.file,});

  @override
  State<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool isPlaying = false;
  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 100));
    setState(() => _isPlayerInitialized = true);
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<void> togglePlay() async {
    if (!_isPlayerInitialized) return;

    if (isPlaying) {
      await _player.pausePlayer();
      setState(() => isPlaying = false);
    } else {
      // If already playing something else, stop first
      if (_player.isPlaying) await _player.stopPlayer();

      await _player.startPlayer(
        fromURI: widget.file.path,
        codec: Codec.aacADTS, // important for .aac files
        whenFinished: () {
          setState(() => isPlaying = false);
        },
      );
      setState(() => isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4 ),
      child: CustomContainer(
        color: colorScheme.primaryContainer,
        outlineColor: colorScheme.outline,
        circularRadius: 18,
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.audiotrack, color: Colors.deepPurple),
          title: Text(widget.file.path.split('/').last,style: textTheme.bodyLarge,),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: isPlaying
                    ? Icon(Icons.pause, color: colorScheme.onSurface)
                    : Icon(Icons.play_arrow, color: colorScheme.onSurface),
                onPressed: togglePlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
