import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/ui/GeneralPageRoute.dart';
import 'package:music/ui/Panel.dart';
import 'package:music/unit.dart';
import 'package:music/unit/Streams.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  Native.init();
  runApp(const FlutterActivity());
}

class FlutterActivity extends StatefulWidget {
  const FlutterActivity({Key key}) : super(key: key);

  @override
  _FlutterActivityState createState() => _FlutterActivityState();
}

class _FlutterActivityState extends State<FlutterActivity>
    with TickerProviderStateMixin {
  static Widget _heritageBuilder(BuildContext context, ThemeData value) {
    if (value == themes[Themes.Black] || value == themes[Themes.White])
      return MaterialApp(
        title: 'Flutter Demo',
        theme: value,
        debugShowCheckedModeBanner: false,
        home: const InitializationPage(),
      );
    return MaterialApp(
      title: 'Flutter Demo',
      theme: value,
      darkTheme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const InitializationPage(),
    );
  }

  AnimationController controller0;
  AnimationController controller1;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    controller0 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    controller1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    MediaPlayerController(
        animationController: controller0, progressController: controller1);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller0.dispose();
    controller1.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: _onNotification,
      child: ThemeHeritage(
        heritageBuilder: _heritageBuilder,
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
    Panel.startValue = PanelHeight / MediaQuery.of(context).size.height;
    final entry = OverlayEntry(builder: _panelBuilder);
    Overlay.of(context).insert(entry);
    GeneralPageRoute.pushReplacement(
      context,
      _builder,
      transitionBuilder: _transitionBuilder,
      transitionDuration: const Duration(seconds: 1),
    );
  }

  static Widget _panelBuilder(BuildContext context) {
    return const RepaintBoundary(child: Panel());
  }

  static Widget _transitionBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return const MainPage();
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
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}
