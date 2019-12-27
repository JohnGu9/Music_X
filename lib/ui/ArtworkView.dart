import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:musicx/ui/DelayBuilder.dart';

const _duration = Duration(milliseconds: 500);

class ArtworkListView extends StatelessWidget {
  const ArtworkListView({Key key, @required this.artwork})
      : assert(artwork != null),
        super(key: key);
  final ValueListenable<ImageProvider> artwork;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        elevation: 6.0,
        shape: const CircleBorder(),
        color: Theme.of(context).primaryColor,
        clipBehavior: Clip.hardEdge,
        child: DelayValueListenableBuilder(
          listenable: artwork,
          builder: _builder,
        ),
      ),
    );
  }

  static Widget _builder(BuildContext context, ImageProvider value, Widget child) {
    return AnimatedSwitcher(
      duration: _duration,
      child: value == null
          ? const SizedBox()
          : Image(image: value, fit: BoxFit.cover),
    );
  }
}
