import 'package:flutter/material.dart';

import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';

class SmallYTActionButton extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? iconWidget;
  final Widget? smallIconWidget;
  final Widget? titleWidget;
  final double? width;

  const SmallYTActionButton({
    super.key,
    required this.title,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.iconWidget,
    this.smallIconWidget,
    this.titleWidget,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: NamidaInkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        enableSecondaryTap: true,
        borderRadius: 12.0,
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: iconWidget ??
                  smallIconWidget ??
                  Icon(
                    icon,
                    size: 25.0,
                  ),
            ),
            SizedBox(height: 6.0),
            NamidaDummyContainer(
              width: 24.0,
              height: 8.0,
              borderRadius: 4.0,
              shimmerEnabled: title == null,
              child: ShimmerWrapper(
                shimmerEnabled: title == null,
                fadeDurationMS: titleWidget == null ? 600 : 100,
                child: titleWidget ??
                    Text(
                      title ?? '',
                      style: context.textTheme.displaySmall,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
