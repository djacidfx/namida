import 'package:flutter/material.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class SeekReadyDimensions {
  static const barHeight = 32.0;
  static const circleWidth = 20.0;
  static const halfCircle = circleWidth / 2;
  static const progressBarHeight = 2;
  static const progressBarHeightFullscreen = 3;
  static const seekTextWidth = 42.0;
  static const seekTextExtraMargin = 8.0;
}

class SeekReadyWidget extends StatefulWidget {
  final bool isLocal;
  final bool isFullscreen;
  final bool showPositionCircle;
  final bool Function()? canDrag;
  final void Function(bool isDragging)? onDraggingChange;

  const SeekReadyWidget({
    super.key,
    this.isLocal = false,
    this.isFullscreen = false,
    this.showPositionCircle = false,
    this.canDrag,
    this.onDraggingChange,
  });

  @override
  State<SeekReadyWidget> createState() => _SeekReadyWidgetState();
}

class _SeekReadyWidgetState extends State<SeekReadyWidget> with SingleTickerProviderStateMixin {
  /// the percentage of the seek bar that causes a seek near the left edge to trigger a magnet effect to 0.
  late final _defaultSeekLeftMagnet = widget.isFullscreen ? 0.01 : 0.05;
  final _seekPercentage = 0.0.obs;

  late AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    _seekPercentage.close();
    super.dispose();
  }

  void toggleBarAnimation({required bool show}) => _animation.animateTo(show ? 1 : 0);

  bool _getSeekActionEnable({required YTSeekActionMode mode}) {
    switch (mode) {
      case YTSeekActionMode.none:
        return false;
      case YTSeekActionMode.expandedMiniplayer:
        return _isMiniplayerExpanded;
      case YTSeekActionMode.minimizedMiniplayer:
        return !_isMiniplayerExpanded;
      default:
        return true;
    }
  }

  void _onSeekDragUpdate(double deltax, double maxWidth) {
    final percentageSwiped = (deltax / maxWidth).clampDouble(0.0, 1.0);
    _seekPercentage.value = percentageSwiped;
  }

  Duration get _currentDurationR => Player.inst.getCurrentVideoDurationR;

  void _onSeekEnd() async {
    widget.onDraggingChange?.call(false);
    final newSeek = _seekPercentage.value * (Player.inst.getCurrentVideoDuration.inMilliseconds);
    await Player.inst.seek(Duration(milliseconds: newSeek.round()));
  }

  void _onDragStart(double deltax, double maxWidth, {bool fromTap = false}) {
    widget.onDraggingChange?.call(true);
    _isPointerDown = true;

    if (fromTap) {
      // display stuff only if still touching.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isPointerDown && _animation.value == 0) {
          _animation.animateTo(1, duration: const Duration(milliseconds: 150));
        }
      });
    } else {
      _animation.animateTo(1);
    }

    _onSeekDragUpdate(deltax, maxWidth);
  }

  void _onDragFinish() {
    widget.onDraggingChange?.call(false);

    if (_seekPercentage.value <= _defaultSeekLeftMagnet) {
      // left magnet
      _seekPercentage.value = 0;
      VibratorController.veryhigh();
    }

    _isPointerDown = false;
    _animation.animateTo(0);
    if (_dragUpToCancel < _dragUpToCancelMax) _onSeekEnd();
    _dragUpToCancel = 0.0;
  }

  bool _isPointerDown = false;

  bool get _isMiniplayerExpanded => MiniPlayerController.inst.animation.value >= 0.95;

  bool get _tapToSeek => widget.isFullscreen ? true : _getSeekActionEnable(mode: settings.youtube.tapToSeek.value);
  bool get _userDragToSeek => widget.isFullscreen ? true : _getSeekActionEnable(mode: settings.youtube.dragToSeek.value);

  bool _dragToSeek = true;
  String _currentSeekStuckWord = '';
  double _dragUpToCancel = 0.0;
  late final _dragUpToCancelMax = widget.isFullscreen ? 8 : 5;

  late bool _canDragToSeekLatest = _userDragToSeek; // used for dragging update.
  bool get _canDragToSeek {
    final can = _userDragToSeek && _dragToSeek && (widget.canDrag == null ? true : widget.canDrag!());
    _canDragToSeekLatest = can;
    return can;
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = widget.isFullscreen;
    final clampCircleEdges = !widget.isFullscreen;
    const barHeight = SeekReadyDimensions.barHeight;
    const circleWidth = SeekReadyDimensions.circleWidth;
    const halfCircle = SeekReadyDimensions.halfCircle;
    final progressBarHeight = fullscreen ? SeekReadyDimensions.progressBarHeightFullscreen : SeekReadyDimensions.progressBarHeight;
    const progressBarHeightExtraHeight = 2.0;
    const seekTextWidth = SeekReadyDimensions.seekTextWidth;
    const seekTextExtraMargin = SeekReadyDimensions.seekTextExtraMargin;

    final progressColor = CurrentColor.inst.miniplayerColor.withValues(alpha: 0.8);
    final miniplayerBGColor = fullscreen ? Colors.grey : Color.alphaBlend(context.theme.secondaryHeaderColor.withValues(alpha: 0.25), context.theme.scaffoldBackgroundColor);
    final bufferColor =
        fullscreen ? miniplayerBGColor.invert() : Color.alphaBlend(progressColor.withValues(alpha: 0.25), miniplayerBGColor.invert().withValues(alpha: 0.5)).withValues(alpha: 0.5);

    final circleWidget = AnimatedBuilder(
      animation: _animation,
      child: Container(
        alignment: Alignment.center,
        height: circleWidth,
        width: circleWidth,
        decoration: BoxDecoration(
          color: CurrentColor.inst.miniplayerColor.withValues(alpha: 1.0),
          borderRadius: const BorderRadius.all(Radius.circular(64.0)),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color.fromARGB(220, 40, 40, 40),
            shape: BoxShape.circle,
          ),
          width: halfCircle,
          height: halfCircle,
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
    );

    return LayoutBuilder(
      builder: (context, c) {
        final maxWidth = c.maxWidth;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // -- hittest
            Padding(
              padding: const EdgeInsets.only(
                top: barHeight / 2,
              ),
              child: Listener(
                onPointerDown: (_) => _canDragToSeek, // refresh `_canDragToSeekLatest`
                onPointerMove: (event) {
                  if (!_canDragToSeekLatest) return;
                  if (!_isMiniplayerExpanded) return;
                  if (_dragUpToCancel > _dragUpToCancelMax) {
                    _canDragToSeekLatest = false;
                    setState(() {
                      _currentSeekStuckWord = const <String>[" --:-- ", " kuru ", "umm..", "🫵😂", "🫵😹"].random;
                      _dragToSeek = false;
                    });
                    VibratorController.veryhigh();
                  } else {
                    _currentSeekStuckWord = '';
                    _dragToSeek = true;
                    _dragUpToCancel -= event.delta.dy * 0.1;
                  }
                },
                onPointerUp: (_) {
                  _dragToSeek = true;
                  _canDragToSeekLatest = true;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanDown: (event) {
                    if (!_canDragToSeek) return;
                    if (_tapToSeek) _onDragStart(event.localPosition.dx, c.maxWidth, fromTap: true);
                  },
                  onPanEnd: (_) {
                    if (_tapToSeek) _onDragFinish();
                  },
                  onHorizontalDragStart: (details) {
                    if (!_canDragToSeek) return;
                    _onDragStart(details.localPosition.dx, c.maxWidth);
                  },
                  onHorizontalDragUpdate: (event) {
                    if (!_canDragToSeekLatest) return;
                    _onSeekDragUpdate(event.localPosition.dx, c.maxWidth);
                  },
                  onHorizontalDragEnd: (_) {
                    _onDragFinish();
                  },
                  onHorizontalDragCancel: () {
                    _isPointerDown = false;
                    _animation.animateTo(0);
                    widget.onDraggingChange?.call(false);
                  },
                  onTapDown: (details) {
                    if (!_canDragToSeek) return;
                    if (_tapToSeek) _onDragStart(details.localPosition.dx, c.maxWidth, fromTap: true);
                  },
                  onTapUp: (_) {
                    if (_tapToSeek) _onDragFinish();
                  },
                  child: SizedBox(
                    height: barHeight,
                    width: maxWidth,
                    child: const ColoredBox(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

            // -- current seek
            Obx(
              (context) {
                final nowPlayingPosition = Player.inst.nowPlayingPositionR;
                final itemDurMS = _currentDurationR.inMilliseconds;
                final seek = (_seekPercentage.valueR * itemDurMS).round();

                String finalText;
                if (_currentSeekStuckWord != '') {
                  finalText = _currentSeekStuckWord;
                } else if (settings.player.displayActualPositionWhenSeeking.value) {
                  int seekClamped = seek;
                  seekClamped = seekClamped.withMinimum(0);
                  seekClamped = seekClamped.withMaximum(itemDurMS);
                  finalText = " ${seekClamped.milliSecondsLabel} ";
                } else {
                  final diffInMs = seek - nowPlayingPosition;
                  final plusOrMinus = diffInMs < 0 ? '' : '+';
                  final seekText = diffInMs.milliSecondsLabel;
                  finalText = " $plusOrMinus$seekText ";
                }

                return Transform.translate(
                  offset: Offset((maxWidth * _seekPercentage.valueR - seekTextWidth * 0.5).clampDouble(seekTextExtraMargin, maxWidth - seekTextWidth - seekTextExtraMargin), -12.0),
                  child: AnimatedBuilder(
                    animation: _animation,
                    child: Container(
                      width: seekTextWidth,
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                        color: context.theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                      ),
                      child: FittedBox(
                        child: Text(
                          finalText,
                          style: context.textTheme.displaySmall,
                        ),
                      ),
                    ),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _animation.value,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 2), end: const Offset(0, 0.0)).animate(_animation),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            // -- progress bar
            Positioned(
              bottom: barHeight / 2 - (progressBarHeight / 2),
              child: AnimatedBuilder(
                animation: _animation,
                child: Obx((context) {
                  final durMS = Player.inst.getCurrentVideoDurationR.inMilliseconds;
                  final currentPositionMS = Player.inst.nowPlayingPositionR;
                  final buffered = Player.inst.buffered.valueR;
                  final videoCached = Player.inst.currentCachedVideo.valueR != null;
                  final audioCached = widget.isLocal || Player.inst.currentCachedAudio.valueR != null;
                  return SizedBox(
                    width: maxWidth,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (fullscreen || videoCached || audioCached)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: bufferColor.withValues(alpha: fullscreen ? 0.3 : 0.1),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(6.0),
                                ),
                              ),
                              child: SizedBox(width: maxWidth),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bufferColor.withValues(alpha: fullscreen ? 0.8 : 0.2),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6.0),
                              ),
                            ),
                            child: SizedBox(
                              width: maxWidth *
                                  ((videoCached && audioCached) || (audioCached && settings.youtube.isAudioOnlyMode.valueR)
                                      ? 1.0
                                      : buffered > Duration.zero && durMS > 0
                                          ? buffered.inMilliseconds / durMS
                                          : 0.0),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: progressColor,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6.0),
                              ),
                            ),
                            child: SizedBox(
                              width: durMS == 0 ? 0 : (maxWidth * (currentPositionMS / durMS)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                builder: (context, child) {
                  return SizedBox(
                    height: progressBarHeight + progressBarHeightExtraHeight * _animation.value,
                    child: child!,
                  );
                },
              ),
            ),

            if (widget.showPositionCircle)
              AnimatedBuilder(
                animation: _animation,
                child: Obx(
                  (context) {
                    final durMS = Player.inst.getCurrentVideoDurationR.inMilliseconds;
                    final currentPositionMS = Player.inst.nowPlayingPositionR;
                    final pos = durMS == 0 ? 0.0 : (maxWidth * (currentPositionMS / durMS));
                    final clampedEdge = clampCircleEdges ? halfCircle / 2 : 0.0;
                    return Transform.translate(
                      offset: Offset(-halfCircle / 2 + pos.clampDouble(clampedEdge, maxWidth - clampedEdge), (barHeight / 4)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CurrentColor.inst.miniplayerColor.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(6.0),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                builder: (context, child) {
                  const multiplier = 1.5;
                  final extras = _animation.value * progressBarHeightExtraHeight;
                  final finalSize = halfCircle + extras * multiplier;
                  return Transform.translate(
                    offset: Offset(0, -extras / multiplier),
                    child: SizedBox(
                      height: finalSize,
                      width: finalSize,
                      child: child,
                    ),
                  );
                },
              ),

            // -- circle
            Obx(
              (context) {
                final clampedEdge = clampCircleEdges ? circleWidth / 2 : 0.0;
                final seekP = _seekPercentage.valueR;
                return Transform.translate(
                  offset: Offset(-halfCircle + (maxWidth * seekP).clampDouble(clampedEdge, maxWidth - clampedEdge), barHeight / 4),
                  child: circleWidget,
                );
              },
            ),
          ],
        );
      },
    );
  }
}
