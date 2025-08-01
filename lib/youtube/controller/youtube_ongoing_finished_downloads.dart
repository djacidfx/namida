import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class YTOnGoingFinishedDownloads {
  static final YTOnGoingFinishedDownloads inst = YTOnGoingFinishedDownloads._internal();
  YTOnGoingFinishedDownloads._internal();

  final youtubeDownloadTasksTempList = <(DownloadTaskGroupName, YoutubeItemDownloadConfig)>[].obs;
  final isOnGoingSelected = Rxn<bool>();

  void refreshList() => updateTempList(isOnGoingSelected.value);

  void updateTempList(bool? forIsGoing) {
    youtubeDownloadTasksTempList.clear();
    if (forIsGoing == null) return;

    void addToListy({required bool Function(bool fileExists, bool isDownloadingOrFetching) filter}) {
      YoutubeController.inst.youtubeDownloadTasksMap.keys.toList().reverseLoop((key) {
        final smallList = YoutubeController.inst.youtubeDownloadTasksMap[key]?.values.toList();
        // -- reverseLoop to insert newer first.
        smallList?.reverseLoop((v) {
          final fileExist = YoutubeController.inst.downloadedFilesMap[key]?[v.filename] != null;
          final isDownloadingOrFetching = (YoutubeController.inst.isDownloading[v.id]?[v.filename] ?? false) || (YoutubeController.inst.isFetchingData[v.id]?[v.filename] ?? false);
          if (filter(fileExist, isDownloadingOrFetching)) youtubeDownloadTasksTempList.value.add((key, v));
        });
      });
    }

    if (forIsGoing) {
      addToListy(filter: (fileExists, isDownloadingOrFetching) => !fileExists || isDownloadingOrFetching);
    } else {
      addToListy(filter: (fileExists, isDownloadingOrFetching) => fileExists && !isDownloadingOrFetching);
    }

    final dateNow = DateTime.now();
    youtubeDownloadTasksTempList.value.sortByReverseAlt((e) => e.$2.addedAt ?? e.$2.fileDate ?? dateNow, (e) => -(e.$2.originalIndex ?? 0));

    youtubeDownloadTasksTempList.refresh();
  }
}
