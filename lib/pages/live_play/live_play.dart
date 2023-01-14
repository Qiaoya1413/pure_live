import 'package:flutter/material.dart';
import 'package:hot_live/api/danmaku/danmaku_stream.dart';
import 'package:hot_live/api/liveapi.dart';
import 'package:hot_live/model/liveroom.dart';
import 'package:hot_live/provider/favorite_provider.dart';
import 'package:hot_live/pages/live_play/danmaku_listview.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import 'danmaku_chewie_controller.dart';

class LivePlayPage extends StatefulWidget {
  const LivePlayPage({Key? key, required this.room}) : super(key: key);

  final RoomInfo room;

  @override
  State<LivePlayPage> createState() => _LivePlayPageState();
}

class _LivePlayPageState extends State<LivePlayPage> {
  VideoPlayerController? videoController;
  ChewieController? chewieController;
  DanmakuStream? danmakuStream;

  bool _hasError = false;
  Map<String, Map<String, String>> streamList = {};

  late FavoriteProvider favoriteProvider =
      Provider.of<FavoriteProvider>(context);

  @override
  void initState() {
    super.initState();
    initLive();
  }

  @override
  void dispose() {
    super.dispose();
    ScreenBrightness().resetScreenBrightness();
    videoController?.pause();
    chewieController?.dispose();
    videoController?.dispose();
    danmakuStream?.dispose();
  }

  void initLive() async {
    streamList = await LiveApi.getRoomStreamLink(widget.room);
    if (streamList.isNotEmpty) {
      // 设置弹幕监控流
      danmakuStream = DanmakuStream(room: widget.room);
      // 设置直播视频流
      _changeLiveStream(
        streamList.values.toList().first.values.toList().first,
      );
    } else {
      _hasError = true;
    }
    setState(() {});
  }

  void _changeLiveStream(String url, {bool swap = false}) {
    if (swap) videoController?.dispose();
    videoController = VideoPlayerController.network(url)
      ..initialize().then(
        (_) {
          if (swap) chewieController?.dispose();
          chewieController = ChewieController(
            videoPlayerController: videoController!,
            customControls:
                DanmakuChewieController(danmakuStream: danmakuStream!),
            autoPlay: true,
            isLive: true,
          );
          setState(() {});
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final resolutionBtns = [];
    streamList.forEach((resolution, cdns) {
      final btn = PopupMenuButton(
        iconSize: 24,
        icon: Text(
          resolution.substring(resolution.length - 2, resolution.length),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        onSelected: (String link) => _changeLiveStream(link, swap: true),
        itemBuilder: (context) {
          final menuList = <PopupMenuItem<String>>[];
          cdns.forEach((cdn, url) {
            final menuItem = PopupMenuItem<String>(
              child: Text(cdn, style: const TextStyle(fontSize: 14.0)),
              value: url,
            );
            menuList.add(menuItem);
          });
          return menuList;
        },
      );
      resolutionBtns.add(btn);
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            Wakelock.disable();
          },
        ),
        title: Text(widget.room.title),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: (videoController?.value.isInitialized ?? false)
                  ? Container(
                      child: Chewie(controller: chewieController!),
                      color: Colors.black,
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: _hasError
                            ? const Icon(Icons.error_rounded, size: 32)
                            : const CircularProgressIndicator(),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Row(
                children: [
                  const Icon(Icons.video_library_rounded, size: 20),
                  const Spacer(),
                  const IconButton(onPressed: null, icon: Text('')),
                  ...resolutionBtns,
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: danmakuStream != null
                  ? DanmakuListView(
                      room: widget.room,
                      danmakuStream: danmakuStream!,
                    )
                  : Container(),
            ),
            OwnerListTile(
              room: widget.room,
              favoriteProvider: favoriteProvider,
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerListTile extends StatelessWidget {
  const OwnerListTile({
    Key? key,
    required this.room,
    required this.favoriteProvider,
  }) : super(key: key);

  final RoomInfo room;
  final FavoriteProvider favoriteProvider;

  @override
  Widget build(BuildContext context) {
    final followedStyle = Theme.of(context)
        .textTheme
        .button
        ?.copyWith(color: Theme.of(context).errorColor);

    return ListTile(
      leading: CircleAvatar(
        foregroundImage: (room.avatar == '') ? null : NetworkImage(room.avatar),
        radius: 18,
        backgroundColor: Theme.of(context).disabledColor,
      ),
      title: Text(
        room.nick,
        maxLines: 1,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: favoriteProvider.isFavorite(room.roomId)
          ? ElevatedButton(
              onPressed: () => favoriteProvider.removeRoom(room),
              child: Text('Followed', style: followedStyle),
            )
          : ElevatedButton(
              onPressed: () => favoriteProvider.addRoom(room),
              child: const Text('Follow'),
            ),
    );
  }
}
