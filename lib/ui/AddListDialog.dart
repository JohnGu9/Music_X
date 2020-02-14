import 'package:flutter/material.dart';
import 'package:music/controller/CustomListManager.dart';

Widget addListDialog(final BuildContext context) {
  return const AddListDialog();
}

class AddListDialog extends StatelessWidget {
  const AddListDialog({Key key}) : super(key: key);
  static final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AlertDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
      title: Text('Add new List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              icon: const Icon(Icons.library_music),
              labelText: 'Name',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        FlatButton(
            onPressed: () {
              final res = CoreListManager().tryToAdd(_controller.text);
              print(res);
              _controller.clear();
              return Navigator.of(context).pop();
            },
            child: const Text('Add')),
        FlatButton(
            onPressed: () {
              return Navigator.of(context).pop();
            },
            child: const Text('Cancel')),
      ],
    );
  }
}
