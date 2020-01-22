import 'package:flutter/material.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/controller/MediaPlayerController.dart';

class FavoriteButtonIcon extends StatelessWidget {
  const FavoriteButtonIcon({Key key, this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return ValueListenableBuilder(
      builder: _builder,
      valueListenable: FavoriteListManager(),
    );
  }

  Icon get displayIcon {
    return FavoriteListManager().songInfos.contains(songInfo)
        ? const Icon(
            Icons.favorite,
            key: ValueKey(true),
            color: Colors.white,
          )
        : const Icon(
            Icons.favorite_border,
            key: ValueKey(false),
            color: Colors.white,
          );
  }

  bool get waitingState {
    return FavoriteListManager().state == ManagerState.updating ||
        FavoriteListManager().state == ManagerState.idle;
  }

  Widget _builder(final BuildContext context, final _, final Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: displayIcon,
    );
  }
}

class AutoFavoriteButtonIcon extends StatefulWidget {
  const AutoFavoriteButtonIcon({Key key}) : super(key: key);

  @override
  _AutoFavoriteButtonIconState createState() => _AutoFavoriteButtonIconState();
}

class _AutoFavoriteButtonIconState extends State<AutoFavoriteButtonIcon> {
  _onChanged() {
    return setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    MediaPlayerController().current.addListener(_onChanged);
    FavoriteListManager().addListener(_onChanged);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    MediaPlayerController().current.removeListener(_onChanged);
    FavoriteListManager().removeListener(_onChanged);
    super.dispose();
  }

  bool get contains {
    return FavoriteListManager()
        .songInfos
        .contains(MediaPlayerController().current.value);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: contains
            ? const Icon(
                Icons.favorite,
                key: ValueKey(true),
              )
            : const Icon(
                Icons.favorite_border,
                key: ValueKey(false),
              ),
      ),
    );
  }
}
