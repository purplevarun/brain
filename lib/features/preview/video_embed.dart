import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Inline video player for `![](clip.mp4)` embeds (media_kit, all platforms).
/// Uses [NoVideoControls] plus a tap-to-toggle overlay — media_kit's stock
/// controls depend on the legacy `package:flutter/material.dart`.
class VideoEmbed extends StatefulWidget {
  const VideoEmbed({super.key, required this.path, this.title});

  final String path;
  final String? title;

  @override
  State<VideoEmbed> createState() => _VideoEmbedState();
}

class _VideoEmbedState extends State<VideoEmbed> {
  late final Player _player;
  late final VideoController _controller;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _player.open(Media('file://${widget.path}'), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: GestureDetector(
          onTap: () => _player.playOrPause(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(controller: _controller, controls: NoVideoControls),
              if (!_playing)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(
                      Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
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
