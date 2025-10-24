import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:just_audio/just_audio.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

Future<void> showTrackInfoDialog(
  Track track,
  bool enableBlur, {
  NetworkArtworkInfo? networkArtworkInfo,
  bool comingFromQueue = false,
  int? index,
  Color? colorScheme,
  required QueueSource queueSource,
  required String? heroTag,
}) async {
  final trackExt = track.toTrackExtOrNull();

  final totalListens = HistoryController.inst.topTracksMapListens.value[track] ?? [];
  final firstListenTrack = totalListens.firstOrNull;

  final color = Colors.transparent.obso;

  void onColorsObtained(Color newColor) {
    color.value = newColor;
  }

  onColorsObtained(colorScheme ?? CurrentColor.inst.color);

  if (colorScheme == null) {
    final colorSync = CurrentColor.inst.getTrackDelightnedColorSync(track, networkArtworkInfo);
    if (colorSync != null) {
      onColorsObtained(colorSync);
    } else {
      CurrentColor.inst
          .getTrackDelightnedColor(track, networkArtworkInfo, useIsolate: true)
          .executeWithMinDelay(
            delayMS: NamidaNavigator.kDefaultDialogDurationMS,
          )
          .then(onColorsObtained);
    }
  }

  bool shouldShowTheField(bool isUnknown) => !isUnknown || (settings.showUnknownFieldsInTrackInfoDialog.value && isUnknown);

  void showPreviewTrackDialog() async {
    final wasPlaying = Player.inst.playWhenReady.value;
    if (wasPlaying) {
      Player.inst.pause();
    }

    final ap = AudioPlayer();
    await ap.setSource(track.toAudioSource(0, 0, null));
    ap.play();

    NamidaNavigator.inst.navigateDialog(
      durationInMs: 400,
      onDismissing: () {
        ap.stop();
        if (wasPlaying) {
          Player.inst.play();
        }
      },
      dialog: ObxO(
        rx: color,
        builder: (context, dialogColor) {
          final theme = AppThemes.inst.getAppTheme(dialogColor, null, true);
          return AnimatedThemeOrTheme(
            data: theme,
            child: CustomBlurryDialog(
              theme: theme,
              horizontalInset: 24.0,
              verticalInset: 24.0,
              title: lang.PREVIEW,
              normalTitleStyle: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder(
                    initialData: ap.position,
                    stream: ap.positionStream,
                    builder: (context, snapshot) {
                      final dur = snapshot.data ?? Duration.zero;
                      return Text(dur.inSeconds.secondsLabel);
                    },
                  ),
                  StreamBuilder(
                    initialData: ap.position,
                    stream: ap.positionStream,
                    builder: (context, snapshot) {
                      final dur = snapshot.data ?? Duration.zero;
                      return Slider.adaptive(
                        value: dur.inMilliseconds.toDouble(),
                        min: 0,
                        max: ap.duration?.inMilliseconds.toDouble() ?? 0,
                        onChanged: (value) => ap.seek(Duration(milliseconds: value.toInt())),
                      );
                    },
                  ),
                  Text(((ap.duration?.inSeconds ?? 0).secondsLabel)),
                  StreamBuilder(
                    initialData: ap.playing,
                    stream: ap.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return NamidaIconButton(
                        icon: isPlaying ? Broken.pause : Broken.play,
                        onPressed: ap.playing ? ap.pause : ap.play,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String releasedFromNow = '';
  final parsed = trackExt == null ? null : DateTime.tryParse(trackExt.year.toString());
  if (parsed != null) {
    releasedFromNow = TimeAgoController.dateFromNow(parsed);
  }

  final trackPathDetailTilesSection = <TrackInfoListTile>[
    if (shouldShowTheField(track.filenameWOExt == ''))
      TrackInfoListTile(
        title: lang.FILE_NAME,
        value: track.filenameWOExt,
        icon: Broken.quote_up_circle,
      ),
    if (shouldShowTheField(track.folderName == ''))
      TrackInfoListTile(
        title: lang.FOLDER,
        value: track.folderName,
        icon: Broken.folder,
      ),
    if (shouldShowTheField(track.path == ''))
      TrackInfoListTile(
        title: lang.PATH,
        value: track.path,
        icon: Broken.location,
      ),
  ];
  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
    },
    lighterDialogColor: false,
    dialog: ObxO(
      rx: color,
      builder: (context, dialogColor) {
        final theme = AppThemes.inst.getAppTheme(dialogColor, null, true);
        return AnimatedThemeOrTheme(
          data: theme,
          child: CustomBlurryDialog(
            theme: theme,
            horizontalInset: 32.0,
            verticalInset: 86.0,
            normalTitleStyle: true,
            title: lang.TRACK_INFO,
            trailingWidgets: [
              ObxO(
                rx: settings.showUnknownFieldsInTrackInfoDialog,
                builder: (context, showUnknownFieldsInTrackInfoDialog) => NamidaIconButton(
                  tooltip: () => lang.SHOW_HIDE_UNKNOWN_FIELDS,
                  icon: showUnknownFieldsInTrackInfoDialog ? Broken.eye : Broken.eye_slash,
                  iconColor: theme.colorScheme.primary,
                  onPressed: () => settings.save(showUnknownFieldsInTrackInfoDialog: !settings.showUnknownFieldsInTrackInfoDialog.value),
                ),
              ),
              NamidaLocalLikeButton(
                track: track,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              NamidaIconButton(
                tooltip: () => lang.PREVIEW,
                icon: Broken.play,
                iconColor: theme.colorScheme.primary,
                onPressed: showPreviewTrackDialog,
              ),
            ],
            icon: Broken.info_circle,
            child: LayoutWidthProvider(
              builder: (context, maxWidth) {
                final artwork = NamidaHero(
                  tag: heroTag,
                  child: NetworkArtwork.orLocal(
                    key: Key(track.pathToImage),
                    fadeMilliSeconds: 0,
                    track: track,
                    path: track.pathToImage,
                    info: networkArtworkInfo,
                    thumbnailSize: maxWidth * 0.5,
                    forceSquared: settings.forceSquaredTrackThumbnail.value,
                    compressed: false,
                  ),
                );
                return SizedBox(
                  height: namida.height * 0.7,
                  width: maxWidth,
                  child: ObxO(
                    rx: settings.showUnknownFieldsInTrackInfoDialog,
                    builder: (context, _) => CustomScrollView(
                      slivers: [
                        SuperSliverList(
                          delegate: SliverChildListDelegate(
                            [
                              const SizedBox(height: 12.0),
                              NamidaInkWell(
                                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                                onTap: () => showTrackListensDialog(track, datesOfListen: totalListens, colorScheme: color.value),
                                borderRadius: 12.0,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 2.0),
                                    NamidaArtworkExpandableToFullscreen(
                                      artwork: artwork,
                                      heroTag: heroTag,
                                      imageFile: () => File(networkArtworkInfo?.toArtworkLocation().path ?? track.pathToImage),
                                      onSave: (_) => EditDeleteController.inst.saveTrackArtworkToStorage(track),
                                      themeColor: () => color.value,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Broken.hashtag_1,
                                                size: 18.0,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Expanded(
                                                child: Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      '${lang.TOTAL_LISTENS}: ',
                                                      style: theme.textTheme.displaySmall,
                                                    ),
                                                    Text(
                                                      '${totalListens.length}',
                                                      style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8.0),
                                          Row(
                                            children: [
                                              const Icon(
                                                Broken.cake,
                                                size: 18.0,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Expanded(
                                                child: Text(
                                                  firstListenTrack?.dateAndClockFormattedOriginal ?? lang.MAKE_YOUR_FIRST_LISTEN,
                                                  style: theme.textTheme.displaySmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              if (trackExt == null)
                                ...trackPathDetailTilesSection
                              else ...<Widget>[
                                if (shouldShowTheField(trackExt.hasUnknownTitle))
                                  TrackInfoListTile(
                                    title: lang.TITLE,
                                    value: trackExt.title,
                                    icon: Broken.text,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownArtist))
                                  TrackInfoListTile(
                                    title: Indexer.splitArtist(
                                              title: trackExt.title,
                                              originalArtist: trackExt.originalArtist,
                                              config: ArtistsSplitConfig.settings(addFeatArtist: false),
                                            ).length ==
                                            1
                                        ? lang.ARTIST
                                        : lang.ARTISTS,
                                    value: trackExt.hasUnknownArtist ? UnknownTags.ARTIST : trackExt.originalArtist,
                                    icon: Broken.microphone,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownAlbum))
                                  TrackInfoListTile(
                                    title: lang.ALBUM,
                                    value: trackExt.hasUnknownAlbum ? UnknownTags.ALBUM : trackExt.album,
                                    icon: Broken.music_dashboard,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownAlbumArtist))
                                  TrackInfoListTile(
                                    title: lang.ALBUM_ARTIST,
                                    value: trackExt.hasUnknownAlbumArtist ? UnknownTags.ALBUMARTIST : trackExt.albumArtist,
                                    icon: Broken.user,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownGenre))
                                  TrackInfoListTile(
                                    title: trackExt.genresList.length == 1 ? lang.GENRE : lang.GENRES,
                                    value: trackExt.hasUnknownGenre ? UnknownTags.GENRE : trackExt.genresList.join(', '),
                                    icon: trackExt.genresList.length == 1 ? Broken.emoji_happy : Broken.smileys,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownMood))
                                  TrackInfoListTile(
                                    title: trackExt.moodList.length == 1 ? lang.MOOD : lang.MOODS,
                                    value: trackExt.hasUnknownMood ? UnknownTags.MOOD : trackExt.moodList.join(', '),
                                    icon: Broken.happyemoji,
                                  ),

                                if (shouldShowTheField(trackExt.hasUnknownComposer))
                                  TrackInfoListTile(
                                    title: lang.COMPOSER,
                                    value: trackExt.hasUnknownComposer ? UnknownTags.COMPOSER : trackExt.composer,
                                    icon: Broken.profile_2user,
                                  ),

                                if (shouldShowTheField(trackExt.durationMS == 0))
                                  TrackInfoListTile(
                                    title: lang.DURATION,
                                    value: trackExt.durationMS.milliSecondsLabel,
                                    icon: Broken.clock,
                                  ),

                                if (shouldShowTheField(trackExt.year == 0))
                                  TrackInfoListTile(
                                    title: lang.YEAR,
                                    value: trackExt.year == 0 ? '?' : '${trackExt.year} (${trackExt.year.yearFormatted}${releasedFromNow == '' ? '' : ' | $releasedFromNow'})',
                                    icon: Broken.calendar,
                                  ),

                                if (shouldShowTheField(trackExt.dateModified == 0))
                                  TrackInfoListTile(
                                    title: lang.DATE_MODIFIED,
                                    value: trackExt.dateModified.dateAndClockFormattedOriginal,
                                    icon: Broken.calendar_1,
                                  ),

                                ///
                                if (shouldShowTheField(trackExt.discNo == 0))
                                  TrackInfoListTile(
                                    title: lang.DISC_NUMBER,
                                    value: trackExt.discNo.toString(),
                                    icon: Broken.hashtag,
                                  ),

                                if (shouldShowTheField(trackExt.trackNo == 0))
                                  TrackInfoListTile(
                                    title: lang.TRACK_NUMBER,
                                    value: trackExt.trackNo.toString(),
                                    icon: Broken.hashtag,
                                  ),

                                ...trackPathDetailTilesSection,

                                TrackInfoListTile(
                                  title: lang.FORMAT,
                                  value: [
                                    track.audioInfoFormattedCompact,
                                    '${trackExt.extension} - ${trackExt.size.fileSizeFormatted}',
                                    track.gainDataFormatted,
                                  ].joinText(separator: '\n'),
                                  icon: Broken.voice_cricle,
                                ),

                                if (shouldShowTheField(trackExt.lyrics == ''))
                                  TrackInfoListTile(
                                    title: lang.LYRICS,
                                    value: trackExt.lyrics,
                                    icon: trackExt.lyrics.isEmpty ? Broken.note_remove : Broken.message_text,
                                  ),

                                if (shouldShowTheField(trackExt.comment == ''))
                                  TrackInfoListTile(
                                    title: lang.COMMENT,
                                    value: trackExt.comment,
                                    icon: Broken.message_text_1,
                                    isComment: true,
                                  ),
                                if (shouldShowTheField(trackExt.description == ''))
                                  TrackInfoListTile(
                                    title: lang.DESCRIPTION,
                                    value: trackExt.description,
                                    icon: Broken.note_text,
                                    isComment: true,
                                  ),
                                if (shouldShowTheField(trackExt.synopsis == ''))
                                  TrackInfoListTile(
                                    title: lang.SYNOPSIS,
                                    value: trackExt.synopsis,
                                    icon: Broken.text,
                                    isComment: true,
                                  ),
                                const SizedBox(height: 12.0),
                              ],
                            ].addSeparators(separator: NamidaContainerDivider(color: color.value), skipFirst: 3).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

class TrackInfoListTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isComment;
  final Widget? child;

  const TrackInfoListTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isComment = false,
    this.child,
  });

  void _copyField(BuildContext context) {
    if (value == '' || value == '?') return;

    Clipboard.setData(ClipboardData(text: value));
    snackyy(
      title: 'Copied $title',
      message: value,
      leftBarIndicatorColor: context.theme.colorScheme.primary,
      altDesign: true,
      top: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const iconSize = 17.0;
    const textToIconPaddingCorrector = EdgeInsets.only(top: 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: NamidaInkWell(
        borderRadius: 16.0,
        onTap: () => _copyField(context),
        onLongPress: () => _copyField(context),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Wrap(
          runSpacing: 6.0,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: context.theme.colorScheme.onSurface.withAlpha(220),
            ),
            const SizedBox(width: 6.0),
            Padding(
              padding: textToIconPaddingCorrector,
              child: Text(
                '$title:',
                style: context.theme.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.onSurface.withAlpha(220)),
              ),
            ),
            const SizedBox(width: 4.0),
            Padding(
              padding: textToIconPaddingCorrector,
              child: child ??
                  (isComment
                      ? NamidaSelectableAutoLinkText(text: value == '' ? '?' : value)
                      : Text(
                          value == '' ? '?' : value,
                          style: context.theme.textTheme.displayMedium?.copyWith(
                            color: Color.alphaBlend(context.theme.colorScheme.primary.withAlpha(140), context.textTheme.displayMedium!.color!),
                            fontSize: 13.5,
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
