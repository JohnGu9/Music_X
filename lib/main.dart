import 'package:flutter/material.dart';
import 'package:musicx/ui.dart';
import 'package:musicx/ui/GeneralPageRoute.dart';
import 'package:musicx/ui/Panel.dart';
import 'package:musicx/unit/Streams.dart';

void main() => runApp(const FlutterActivity());

class FlutterActivity extends StatelessWidget {
  const FlutterActivity({Key key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: _onNotification,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        debugShowCheckedModeBanner: false,
        home: const InitializationPage(),
      ),
    );
  }

  bool _onNotification(Notification notification) {
    final AnimationStream stream = AnimationStream();
    switch (notification.runtimeType) {
      case ScrollStartNotification:
        stream.addAnimation(hashCode);
        break;
      case ScrollEndNotification:
        stream.removeAnimation(hashCode);
        break;
      case OverscrollNotification:
        stream.removeAnimation(hashCode);
        break;
    }
    return true;
  }
}

class InitializationPage extends StatefulWidget {
  /// This widget is for initialization
  ///  do any prepare jobs in this widget
  const InitializationPage({Key key}) : super(key: key);

  @override
  _InitializationPageState createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage> {
  _pushRoute() async {
    final entry = OverlayEntry(builder: _panelBuilder);
    Overlay.of(context).insert(entry);
    await AnimationStream().idle();

    GeneralPageRoute.pushReplacement(
      context,
      _builder,
      transitionBuilder: _transitionBuilder,
      transitionDuration: const Duration(seconds: 1),
    );
  }

  static Widget _panelBuilder(BuildContext context) {
    return const Panel();
  }

  static Widget _transitionBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      Widget gesture) {
    return MainPage(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
    );
  }

  static Widget _builder(BuildContext context) {
    return null;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future(_pushRoute);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const Scaffold(
      backgroundColor: Colors.white,
    );
  }
}
