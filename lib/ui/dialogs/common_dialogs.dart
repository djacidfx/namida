import 'package:flutter/material.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class NamidaDialogs {
  static NamidaDialogs get inst => _instance;
  static final NamidaDialogs _instance = NamidaDialogs._internal();
  NamidaDialogs._internal();

  Future<void> showTrackDialog(
    Track track, {
    Widget? leading,
    String? playlistName,
    TrackWithDate? trackWithDate,
    int? index,
    bool comingFromQueue = false,
    bool isFromPlayerQueue = false,
    Exception? errorPlayingTrack,
    required QueueSource source,
    String? heroTag,
  }) async {
    final trExt = track.toTrackExt();
    await showGeneralPopupDialog(
      [track],
      trExt.originalArtist,
      trExt.title.overflow,
      source,
      thirdLineText: trExt.album.overflow,
      forceSquared: settings.forceSquaredTrackThumbnail.value,
      tracksWithDates: trackWithDate == null ? [] : [trackWithDate],
      playlistName: playlistName,
      index: index,
      comingFromQueue: comingFromQueue,
      isFromPlayerQueue: isFromPlayerQueue,
      errorPlayingTrack: errorPlayingTrack,
      heroTag: heroTag,
    );
  }

  Future<void> showAlbumDialog(String albumIdentifier) async {
    final tracks = albumIdentifier.getAlbumTracks();
    final artists = tracks.mappedUniquedList((e) => e.artistsList);
    await showGeneralPopupDialog(
      tracks,
      tracks.album.overflow,
      "${tracks.displayTrackKeyword} & ${artists.length.displayArtistKeyword}",
      QueueSource.album,
      thirdLineText: artists.join(', ').overflow,
      forceSquared: Dimensions.inst.shouldAlbumBeSquared(rootContext),
      forceSingleArtwork: true,
      heroTag: 'album_$albumIdentifier',
      albumToAddFrom: (tracks.album, albumIdentifier),
      networkArtworkInfo: NetworkArtworkInfo.album(albumIdentifier, artists.firstOrNull),
    );
  }

  Future<void> showArtistDialog(String name, MediaType type) async {
    final tracks = name.getArtistTracksFor(type);
    final albums = tracks.mappedUniqued((e) => e.album);
    await showGeneralPopupDialog(
      tracks,
      name.overflow,
      "${tracks.displayTrackKeyword} & ${albums.length.displayAlbumKeyword}",
      QueueSource.artist,
      thirdLineText: albums.take(5).join(', ').overflow,
      forceSquared: true,
      forceSingleArtwork: true,
      heroTag: 'artist_$name',
      isCircle: true,
      artistToAddFrom: name,
      networkArtworkInfo: NetworkArtworkInfo.artist(name),
    );
  }

  Future<void> showGenreDialog(String name) async {
    final tracks = name.getGenresTracks();
    await showGeneralPopupDialog(
      tracks,
      name,
      [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
      QueueSource.genre,
      extractColor: false,
      heroTag: 'genre_$name',
      forceSquared: true,
    );
  }

  /// Supports all playlists, (History, Most Played, Favourites & others).
  Future<void> showPlaylistDialog(String playlistName) async {
    if (playlistName == k_PLAYLIST_NAME_HISTORY) {
      final twds = HistoryController.inst.historyTracks.toList();
      final trs = twds.toTracks();
      await showGeneralPopupDialog(
        trs,
        k_PLAYLIST_NAME_HISTORY.translatePlaylistName(),
        trs.length.displayTrackKeyword,
        QueueSource.history,
        thirdLineText: HistoryController.inst.newestTrack?.dateAdded.dateAndClockFormattedOriginal ?? '',
        playlistName: k_PLAYLIST_NAME_HISTORY,
        tracksWithDates: twds,
        extractColor: false,
        heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
        forceSquared: true,
        comingFromPlaylistMenu: true,
      );
      return;
    }
    if (playlistName == k_PLAYLIST_NAME_MOST_PLAYED) {
      final trs = HistoryController.inst.currentMostPlayedTracks.toList();
      final firstTrack = trs.firstOrNull;
      String thirdLineText = ''; // top track count + info
      if (firstTrack != null) {
        final currentListenCount = HistoryController.inst.currentTopTracksMapListens[firstTrack]?.length ?? 0;
        thirdLineText = "↑ ${currentListenCount.formatDecimal()} • ${firstTrack.title}";
      }
      await showGeneralPopupDialog(
        trs,
        k_PLAYLIST_NAME_MOST_PLAYED.translatePlaylistName(),
        trs.length.displayTrackKeyword,
        QueueSource.mostPlayed,
        thirdLineText: thirdLineText,
        playlistName: k_PLAYLIST_NAME_MOST_PLAYED,
        extractColor: false,
        heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
        forceSquared: true,
        comingFromPlaylistMenu: true,
      );
      return;
    }

    final playlist = PlaylistController.inst.getPlaylist(playlistName);
    if (playlist == null) return;
    // -- Delete Empty Playlists --
    if (playlist.tracks.isEmpty) {
      showDeletePlaylistDialog(playlist);
    } else {
      final trackss = playlist.tracks.toTracks();
      await showGeneralPopupDialog(
        trackss,
        playlist.name.translatePlaylistName(),
        [trackss.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' • '),
        playlist.toQueueSource(),
        thirdLineText: playlist.moods.join(', ').overflow,
        playlistName: playlist.name,
        tracksWithDates: playlist.tracks,
        extractColor: false,
        heroTag: 'playlist_${playlist.name}',
        forceSquared: true,
        comingFromPlaylistMenu: true,
      );
    }
  }

  void showDeletePlaylistDialog(LocalPlaylist playlist) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.WARNING,
        bodyText: '${lang.DELETE_PLAYLIST}: "${playlist.name}"?',
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () {
              PlaylistController.inst.removePlaylist(playlist);
              NamidaNavigator.inst.closeDialog();
            },
          )
        ],
      ),
    );
  }

  Future<void> showQueueDialog(int date) async {
    final queue = date.getQueue()!;
    await showGeneralPopupDialog(
      queue.tracks,
      queue.date.dateFormatted,
      queue.date.clockFormatted,
      QueueSource.queuePage,
      thirdLineText: [
        queue.tracks.displayTrackKeyword,
        queue.tracks.totalDurationFormatted,
      ].join(' - '),
      extractColor: false,
      queue: queue,
      forceSquared: true,
      heroTag: 'queue_${queue.date}',
    );
  }

  Future<void> showFolderDialog({
    required Folder folder,
    required FoldersController controller,
    required bool isTracksRecursive,
    required List<Track> tracks,
  }) async {
    if (isTracksRecursive) VibratorController.medium();
    await showGeneralPopupDialog(
      tracks,
      folder.folderName,
      [
        tracks.displayTrackKeyword,
        tracks.totalDurationFormatted,
      ].join(' • '),
      folder is VideoFolder ? QueueSource.folderVideos : QueueSource.folder,
      thirdLineText: tracks.totalSizeFormatted,
      trailingIcon: isTracksRecursive ? Broken.cards : Broken.card,
    );
  }
}
