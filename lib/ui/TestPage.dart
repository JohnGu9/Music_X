import 'package:flutter/material.dart';
import 'package:music/component.dart';
import 'package:music/unit.dart';

class TestPage extends StatelessWidget {
  const TestPage({Key key, this.animation, this.secondaryAnimation}) : super(key: key);
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return WillPopScope(
      onWillPop: _onWillPop,
      child:const _TestPageContent(),
    );
  }

  static Future<bool> _onWillPop() async {
    return false;
  }
}

class _TestPageContent extends StatelessWidget {
  const _TestPageContent({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final ScrollController _scrollController = ScrollController();
    return CustomScrollView(
      physics: Constants.physics,
      controller: _scrollController,
      slivers: <Widget>[
        SliverAppBar(
          automaticallyImplyLeading: false,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.all(30.0),
            title: Text('Music X'),
          ),
        ),
        _CustomListView(
          scrollController: _scrollController,
        )
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          const VerticalDivider(width: 20),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'PLAY',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.play_arrow,
          ),
          const VerticalDivider(width: 10),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'SHUFFLE',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.shuffle,
          ),
        ],
      ),
    );
  }
}

class _CustomListView extends StatelessWidget {
  const _CustomListView({Key key, @required this.scrollController})
      : super(key: key);
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SliverToBoxAdapter(
      child: Material(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Constants.radius, bottomLeft: Constants.radius)),
        clipBehavior: Clip.hardEdge,
        child: RawReorderableListView(
          scrollController: scrollController,
          header: const _ListHeader(),
          onReorder: (int oldIndex, int newIndex) {},
          children: List.generate(20, (int i) {
            return _itemBuilder(i);
          }),
        ),
      ),
    );
  }

  static Widget _itemBuilder(int i) {
    return ListTile(
      key: ValueKey(i),
      title: Text('$i'),
    );
  }
}
