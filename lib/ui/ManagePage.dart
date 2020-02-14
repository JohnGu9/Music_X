import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/ui.dart';
import 'package:music/ui/AlbumInfoPage.dart';
import 'package:music/unit.dart';

import 'AddListDialog.dart';

class ManagePage extends StatelessWidget {
  static push(BuildContext context) {
    return GeneralPageRoute.push(context, _builder,
        transitionBuilder: _transitionBuilder,
        gestureHitTestBehavior: HitTestBehavior.opaque);
  }

  static Widget _builder(BuildContext context) {
    return null;
  }

  static Widget _transitionBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return ManagePage(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
    );
  }

  ManagePage({Key key, this.animation, this.secondaryAnimation})
      : _position = Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
            .animate(animation),
        _subPosition = Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
            .animate(CurvedAnimation(
                parent: animation, curve: const Interval(0.5, 1.0))),
        super(key: key);
  final Animation animation;
  final Animation secondaryAnimation;
  final Animation<Offset> _position;
  final Animation<Offset> _subPosition;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SecondaryTransition(
      listenable: secondaryAnimation,
      child: SlideTransition(
        position: _position,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Material(
            shape: shape,
            color: Theme.of(context).primaryColor,
            clipBehavior: Clip.hardEdge,
            child: DefaultTabController(
              length: 3,
              initialIndex: 0,
              child: NestedScrollView(
                physics: const ClampingScrollPhysics(),
                headerSliverBuilder: _headerSliverBuilder,
                body: SlideTransition(position: _subPosition, child: _Body()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _headerSliverBuilder(
      BuildContext context, bool innerBoxIsScrolled) {
    return [
      SliverOverlapAbsorber(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        sliver: SliverAppBar(
          pinned: true,
          elevation: 0.0,
          title: const Text('More'),
          backgroundColor: Theme.of(context).backgroundColor,
          expandedHeight: 200,
          flexibleSpace: GeneralNavigator.of(context).gestureBuilder(
              context: context, child: const FlexibleSpaceBar()),
          bottom: const _Bottom(),
        ),
      ),
    ];
  }
}

class _Bottom extends StatelessWidget implements PreferredSizeWidget {
  const _Bottom({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const TabBar(
      tabs: <Tab>[
        Tab(icon: Icon(Icons.favorite)),
        Tab(icon: Icon(Icons.library_music)),
        Tab(icon: Icon(Icons.album)),
      ],
    );
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize => Size(double.infinity, 30);
}

class _Body extends StatelessWidget {
  const _Body({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const TabBarView(
      children: const [
        _Favorite(),
        _Library(),
        _Album(),
      ],
    );
  }
}

class _Favorite extends StatelessWidget {
  const _Favorite({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final ScrollController scrollController =
        PrimaryScrollController.of(context);
    return CustomScrollView(
      physics: Constants.physics,
      slivers: <Widget>[
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverToBoxAdapter(
          child: _ListView(
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

const textStyle = TextStyle(color: Colors.white);

class _ListView extends StatelessWidget {
  const _ListView({Key key, this.scrollController}) : super(key: key);
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return DelayValueListenableBuilder(
        listenable: FavoriteListManager(), builder: _builder);
  }

  Widget _builder(BuildContext context, List<String> value, Widget child) {
    final fm = FavoriteListManager();
    if (fm.state == ManagerState.updating)
      return const Padding(
        padding: const EdgeInsets.all(30.0),
        child: CircularProgressIndicator(),
      );
    if (fm.isEmpty)
      return Card(
        margin: const EdgeInsets.all(30),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text(
            'If you like some songs,\nmark it as \'Favorite\' and can access them in this.',
            style: Theme.of(context).textTheme.headline6,
          ),
        ),
      );
    return RawReorderableListView(
      scrollController: scrollController,
      onReorder: fm.reorder,
      children: FavoriteItemMapList(parent: fm),
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: FadeTransition(
          opacity: const AlwaysStoppedAnimation(0.7),
          child: ListTile(
            title: const Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: const Text(
                'Favortie',
                style: textStyle,
              ),
            ),
            trailing: Text(
              '${value.length}  Songs',
              style: textStyle,
            ),
          ),
        ),
      ),
      end: const SizedBox(height: PanelHeight),
    );
  }
}

class _Library extends StatelessWidget {
  const _Library({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DelayValueListenableBuilder(
        listenable: CoreListManager(),
        builder: _builder,
      ),
    );
  }

  Widget _builder(
      final BuildContext context, final List<String> value, Widget _) {
    const crossAxisCount = 2;
    final cm = CoreListManager();

    _addCustomListManager() {
      return showCupertinoDialog(context: context, builder: addListDialog);
    }

    Widget _childBuilder(final BuildContext context, final int index) {
      if (cm.length <= index) return null;
      return AnimationConfiguration.staggeredGrid(
        position: index,
        duration: const Duration(milliseconds: 375),
        columnCount: crossAxisCount,
        child: ScaleAnimation(
          child: CustomListItemView(
            listManager: cm.listManagers[index],
          ),
        ),
      );
    }

    Widget child;
    if (cm.state == ManagerState.updating)
      child = const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    else
      child = SliverGrid(
        delegate:
            SliverChildBuilderDelegate(_childBuilder, childCount: cm.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
      );

    Widget _limiterWrap({@required Widget child}) {
      if (value.isEmpty) return child;
      return AnimationLimiter(
        child: child,
      );
    }

    return _limiterWrap(
      child: CustomScrollView(
        physics: Constants.physics,
        slivers: <Widget>[
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FadeTransition(
                opacity: const AlwaysStoppedAnimation(0.7),
                child: ListTile(
                  title: Text(
                    '${value.length}  Playlists',
                    style: textStyle,
                  ),
                  trailing: FlatButton(
                    onPressed: _addCustomListManager,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                        const VerticalDivider(
                            width: 5, color: Colors.transparent),
                        Text(
                          'Add Playlist',
                          style: textStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
          SliverBottomPadding,
        ],
      ),
    );
  }
}

class _Album extends StatelessWidget {
  const _Album({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DelayValueListenableBuilder(
        listenable: AlbumManager(),
        builder: _builder,
      ),
    );
  }

  static Widget _builder(
      BuildContext context, List<AlbumInfoProvider> value, Widget child) {
    const crossAxisCount = 2;

    Widget _childBuilder(BuildContext context, int index) {
      final albumInfo = value[index];
      return AnimationConfiguration.staggeredGrid(
        position: index,
        duration: const Duration(milliseconds: 375),
        columnCount: crossAxisCount,
        child: ScaleAnimation(
          child: AlbumItemView(
            albumInfo: albumInfo,
          ),
        ),
      );
    }

    Widget _limiterWrap({final Widget child}) {
      if (value.isEmpty) return child;
      return AnimationLimiter(
        child: child,
      );
    }

    return CustomScrollView(
      physics: Constants.physics,
      slivers: <Widget>[
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: FadeTransition(
              opacity: const AlwaysStoppedAnimation(0.7),
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '${value.length}  Albums',
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
        _limiterWrap(
          child: SliverGrid(
            delegate: SliverChildBuilderDelegate(_childBuilder,
                childCount: value.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
          ),
        ),
        SliverBottomPadding,
      ],
    );
  }
}

class CustomListItemView extends StatelessWidget {
  const CustomListItemView({Key key, this.listManager}) : super(key: key);
  final ListManager listManager;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      elevation: 6.0,
      shape: shape,
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: () {},
        child: const Icon(Icons.album),
      ),
    );
  }
}

class AlbumItemView extends StatelessWidget {
  const AlbumItemView({Key key, this.albumInfo}) : super(key: key);
  final AlbumInfoProvider albumInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      elevation: 6.0,
      shape: shape,
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).backgroundColor,
      child: Stack(
        children: <Widget>[
          DelayValueListenableBuilder(
            listenable: albumInfo.artwork,
            builder: _imageBuilder,
          ),
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: const [Colors.transparent, Colors.black54],
                    stops: [0.5, 0.9],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  albumInfo.title,
                  style: TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                return AlbumInfoPage.push(context, albumInfo);
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _imageBuilder(
      BuildContext context, ImageProvider value, Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      layoutBuilder: Constants.expandedLayoutBuilder,
      child: value == null
          ? FittedBox(
              fit: BoxFit.contain,
              child: ScaleTransition(
                scale: const AlwaysStoppedAnimation(0.5),
                child: Icon(
                  Icons.music_note,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            )
          : Image(
              key: ValueKey(value),
              image: value,
              fit: BoxFit.cover,
            ),
    );
  }
}
