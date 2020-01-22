import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music/ui.dart';
import 'package:music/unit.dart';

class SettingPage {
  static push(BuildContext context) {
    return GeneralPageRoute.push(context, _builder,
        transitionBuilder: _transitionBuilder,
        gestureHitTestBehavior: HitTestBehavior.opaque);
  }

  static Widget _transitionBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return RepaintBoundary(
      child: SecondaryTransition(
        listenable: secondaryAnimation,
        child: RepaintBoundary(
          child: _SettingPage(
            animation: animation,
          ),
        ),
      ),
    );
  }

  static Widget _builder(BuildContext context) {
    return null;
  }
}

class _SettingPage extends AnimatedWidget {
  static final Tween _layoutOffset =
      Tween(begin: const Offset(0, 1), end: const Offset(0, 0));
  static final ColorTween _colorTween =
      ColorTween(begin: Colors.transparent, end: Colors.black12);

  _SettingPage({Key key, this.animation})
      : super(key: key, listenable: animation);
  final Animation animation;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      color: _colorTween.evaluate(animation),
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: FractionalTranslation(
        translation: _layoutOffset.evaluate(animation),
        child: Material(
          shape: shape,
          elevation: 6.0,
          clipBehavior: Clip.hardEdge,
          color: Theme.of(context).primaryColor,
          child: CustomScrollView(
            physics: Constants.physics,
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 200,
                backgroundColor: Colors.transparent,
                flexibleSpace: GeneralNavigator.of(context).gestureBuilder(
                  context: context,
                  child: FlexibleSpaceBar(
                    title: Text(
                      'Setting',
                      style: Theme.of(context).textTheme.title,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FractionalTranslation(
                    translation: _layoutOffset.evaluate(animation),
                    child: const _List()),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                    height:
                        MediaQuery.of(context).size.height * Panel.startValue +
                            8.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      shape: shape,
      elevation: 6.0,
      color: Theme.of(context).backgroundColor,
      child: Padding(
        padding: PageSidePadding,
        child: Column(
          children: const <Widget>[
            const _Preference(),
          ],
        ),
      ),
    );
  }
}

class _Preference extends StatelessWidget {
  const _Preference({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.palette),
          title: Text(
            'Preference',
            style: Theme.of(context).textTheme.title,
          ),
        ),
        for (final theme in Themes.values) _builder(context, theme),
      ],
    );
  }

  static Widget _builder(BuildContext context, Themes theme) {
    return Card(
      color: themes[theme].primaryColor,
      child: ListTile(
        title: Text(ThemeHeritage.toName(theme: theme)),
        onTap: () {
          return ThemeHeritage.of(context).changeTheme(theme: theme);
        },
      ),
    );
  }
}
