import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music/controller/CustomImageProvider.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/ui/DelayBuilder.dart';

const _duration = Duration(milliseconds: 500);

class ArtworkView extends StatelessWidget {
  const ArtworkView(
      {final Key key, this.artwork, @required this.shape, this.color})
      : super(key: key);
  final CustomImageProvider artwork;
  final ShapeBorder shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final _color = color ?? Theme.of(context).primaryColor;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        elevation: 6.0,
        shape: shape,
        color: _color,
        clipBehavior: Clip.hardEdge,
        child: RepaintBoundary(
          child: DelayValueListenableBuilder(
            listenable: artwork,
            builder: _builder,
          ),
        ),
      ),
    );
  }

  static final Matrix4 _transform = Matrix4.identity()..scale(0.4, 0.4, 1.0);

  static Widget _builder(
      BuildContext context, ImageProvider value, Widget child) {
    return AnimatedSwitcher(
      layoutBuilder: _defaultLayoutBuilder,
      duration: _duration,
      child: value == null
          ? InkWell(
              onTap: _onTap,
              child: Transform(
                transform: _transform,
                alignment: Alignment.center,
                child: FittedBox(
                    fit: BoxFit.cover, child: Icon(Icons.track_changes)),
              ),
            )
          : Image(
              key: ValueKey(value),
              image: value,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
    );
  }
}

_onTap() {}

Widget _defaultLayoutBuilder(
    Widget currentChild, List<Widget> previousChildren) {
  return Stack(
    fit: StackFit.expand,
    children:
        currentChild == null ? previousChildren : List.from(previousChildren)
          ..add(currentChild),
    alignment: Alignment.center,
  );
}

class ArtworkListView extends ArtworkView {
  const ArtworkListView(
      {final Key key,
      final CustomImageProvider artwork,
      final ShapeBorder shape = const CircleBorder()})
      : super(key: key, artwork: artwork, shape: shape);
}

class AutoPanelArtworkView extends StatelessWidget {
  const AutoPanelArtworkView(
      {Key key,
      this.shape = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)))})
      : super(key: key);
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ValueListenableBuilder(
        builder: _builder,
        valueListenable: MediaPlayerController().current,
      ),
    );
  }

  Widget _builder(BuildContext context, SongInfoProvider value, Widget child) {
    if (value == null)
      return ArtworkView(
        shape: shape,
      );
    return ArtworkView(
      shape: shape,
      artwork: value.artwork,
    );
  }
}

class SongInfoArtworkView extends ArtworkView {
  const SongInfoArtworkView(
      {Key key,
      final CustomImageProvider artwork,
      final ShapeBorder shape =
          const RoundedRectangleBorder(borderRadius: borderRadius),
      final Color color})
      : super(key: key, artwork: artwork, shape: shape, color: color);
}

class AlbumArtworkView extends ArtworkView {
  const AlbumArtworkView(
      {Key key,
      final CustomImageProvider artwork,
      final ShapeBorder shape =
          const RoundedRectangleBorder(borderRadius: borderRadius)})
      : super(key: key, artwork: artwork, shape: shape);
}

class ArtistArtworkView extends ArtworkView {
  const ArtistArtworkView(
      {Key key,
      final CustomImageProvider artwork,
      final ShapeBorder shape =
          const RoundedRectangleBorder(borderRadius: borderRadius)})
      : super(key: key, artwork: artwork, shape: shape);
}
