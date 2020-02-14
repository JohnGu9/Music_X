import 'package:flutter/material.dart';

class BorderTextButton extends StatelessWidget {
  const BorderTextButton(
      {Key key,
      this.text,
      this.onTap,
      this.color,
      this.paddingColor,
      this.textColor,
      this.fontSize,
      this.icon,
      this.customIcon,
      this.elevation = 0.0})
      : super(key: key);
  final String text;
  final Function() onTap;
  final Color color;
  final Color paddingColor;
  final Color textColor;
  final double elevation;
  final double fontSize;
  final Widget customIcon;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final _color = color ?? Theme.of(context).textTheme.headline6.color;
    final shape = StadiumBorder(
        side: BorderSide(
            color: paddingColor == null ? _color : Colors.transparent));
    final content = <Widget>[
      Text(text,
          style: TextStyle(
              fontSize: fontSize ?? Theme.of(context).textTheme.headline6.fontSize,
              fontFamily: Theme.of(context).textTheme.headline6.fontFamily,
              fontWeight: FontWeight.w500,
              color: textColor ?? _color)),
    ];
    if (text.isNotEmpty) {
      if (customIcon != null)
        content..add(const VerticalDivider(width: 5))..add(customIcon);
      else if (icon != null)
        content
          ..add(const VerticalDivider(width: 5))
          ..add(Icon(
            icon,
            color: textColor ?? _color,
          ));
    } else {
      if (customIcon != null)
        content..add(customIcon);
      else if (icon != null)
        content
          ..add(Icon(
            icon,
            color: textColor ?? _color,
          ));
    }
    return Material(
      shape: shape,
      animationDuration: Duration.zero,
      color: paddingColor ?? Colors.transparent,
      elevation: elevation,
      child: InkWell(
        enableFeedback: true,
        splashColor: _color,
        onTap: onTap ?? () {},
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: content,
          ),
        ),
      ),
    );
  }
}
