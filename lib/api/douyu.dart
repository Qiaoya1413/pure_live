import 'dart:convert';
import 'package:hot_live/model/livearea.dart';
import 'package:hot_live/model/liveroom.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class DouyuApi {
  static Future<dynamic> _getJson(String url) async {
    var resp = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 12_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'
      },
    );
    return await jsonDecode(resp.body);
  }

  static Future<Map<String, Map<String, String>>> getRoomStreamLink(
      RoomInfo room) async {
    Map<String, Map<String, String>> links = {};

    String url =
        'https://playweb.douyucdn.cn/lapi/live/hlsH5Preview/${room.roomId}';

    try {
      String time = ((DateTime.now().millisecondsSinceEpoch) * 1000).toString();
      String sign = md5.convert(utf8.encode('${room.roomId}$time')).toString();
      Map<String, String> headers = {
        'rid': room.roomId,
        'time': time,
        'auth': sign
      };
      Map data = {
        'rid': room.roomId,
        'did': '10000000000000000000000000001501'
      };
      var resp = await http.post(Uri.parse(url), headers: headers, body: data);
      var body = json.decode(resp.body);
      if (body['error'] == 0) {
        String rtmpLive = body['data']['rtmp_live'];
        RegExpMatch? match =
            RegExp(r'(\d{1,8}[0-9a-zA-Z]+)_?\d{0,4}(/playlist|.m3u8)')
                .firstMatch(rtmpLive);
        String? key = match?.group(1);

        // add stream links
        List<String> cdns = ['hw', 'ws', 'akm'];
        links['原画'] = {};
        links['流畅'] = {};
        for (String cdn in cdns) {
          links['原画']![cdn] =
              'https://$cdn-tct.douyucdn.cn/live/$key.flv?uuid=';
          links['流畅']![cdn] =
              'https://$cdn-tct.douyucdn.cn/live/${key}_900.flv?uuid=';
        }
      }
    } catch (e) {
      return links;
    }
    return links;
  }

  static Future<RoomInfo> getRoomInfo(RoomInfo room) async {
    try {
      dynamic body = await _getJson(
          'https://open.douyucdn.cn/api/RoomApi/room/${room.roomId}');
      if (body['error'] == 0) {
        Map roomInfo = body['data'];
        dynamic liveStatus = roomInfo['room_status'];
        room.nick = roomInfo['owner_name'];
        room.title = roomInfo['room_name'];
        room.avatar = roomInfo['avatar'];
        room.cover = roomInfo['room_thumb'];
        room.liveStatus =
            liveStatus == '1' ? LiveStatus.live : LiveStatus.offline;
      }
    } catch (e) {
      return room;
    }
    return room;
  }

  static Future<List<RoomInfo>> getRecommend(int page, int size) async {
    List<RoomInfo> list = [];

    try {
      int start =
          size * (page - 1) ~/ 8 + ((size * (page - 1) % 8 == 0) ? 0 : 1);
      start = (start == 0) ? 1 : start;
      int end = size * (page) ~/ 8 + ((size * (page) % 8 == 0) ? 0 : 1);

      for (int i = start; i <= end; i++) {
        String url = "https://m.douyu.com/api/room/list?page=$i&type=";
        dynamic response = await _getJson(url);
        dynamic result = response["data"];
        if (response["code"] == 0) {
          List<dynamic> roomInfoList = result["list"];
          for (var roomInfo in roomInfoList) {
            RoomInfo room = RoomInfo(roomInfo["rid"].toString());
            room.platform = 'douyu';
            room.nick = roomInfo["nickname"];
            room.title = roomInfo["roomName"];
            room.cover = roomInfo["roomSrc"];
            room.avatar = roomInfo["avatar"];
            room.liveStatus = LiveStatus.live;
            list.add(room);
          }
        }
      }
    } catch (e) {
      return list;
    }
    return list;
  }

  static Future<List<List<AreaInfo>>> getAreaList() async {
    List<List<AreaInfo>> areaList = [];

    String url = "https://m.douyu.com/api/cate/list";

    try {
      dynamic response = await _getJson(url);
      Map<String, String> cate1Map = {};
      Map<String, List<AreaInfo>> cate2Map = {};
      if (response["code"] == 0) {
        List<dynamic> cate1InfoList = response["data"]["cate1Info"];
        for (var element in cate1InfoList) {
          String cate1Name = element["cate1Name"];
          String cate1Id = element["cate1Id"].toString();
          cate1Map[cate1Id] = cate1Name;
          cate2Map[cate1Id] = [];
        }

        List<dynamic> areaInfoList = response["data"]["cate2Info"];
        for (var areaInfo in areaInfoList) {
          final typeId = areaInfo["cate1Id"].toString();
          if ("21" == typeId || !cate1Map.containsKey(typeId)) {
            continue;
          }

          AreaInfo area = AreaInfo();
          area.areaType = typeId;
          area.typeName = cate1Map[typeId]!;

          area.platform = "douyu";
          area.areaId = areaInfo["cate2Id"].toString();
          area.areaName = areaInfo["cate2Name"];
          area.areaPic = areaInfo["pic"];
          area.shortName = areaInfo["shortName"];

          cate2Map[typeId]?.add(area);
        }
      }

      cate2Map.forEach((key, value) {
        if (value.isNotEmpty) areaList.add(value);
      });
    } catch (e) {
      return areaList;
    }
    return areaList;
  }

  static Future<List<RoomInfo>> getAreaRooms(
      AreaInfo area, int page, int size) async {
    List<RoomInfo> list = [];

    try {
      int start = size * (page - 1) ~/ 8 + 1;
      start = (start == 0) ? 1 : start;
      int end = size * page ~/ 8 + ((size * (page) % 8 == 0) ? 0 : 1);

      for (int i = start; i <= end; i++) {
        String url =
            "https://m.douyu.com/api/room/list?page=$i&type=${area.shortName}";
        dynamic response = await _getJson(url);
        dynamic result = response["data"];
        if (response["code"] == 0) {
          List<dynamic> roomInfoList = result["list"];
          for (var roomInfo in roomInfoList) {
            RoomInfo room = RoomInfo(roomInfo["rid"].toString());
            room.platform = 'douyu';
            room.nick = roomInfo["nickname"];
            room.title = roomInfo["roomName"];
            room.cover = roomInfo["roomSrc"];
            room.avatar = roomInfo["avatar"];
            room.liveStatus = LiveStatus.live;
            list.add(room);
          }
        }
      }
    } catch (e) {
      return list;
    }
    return list;
  }

  static Future<List<RoomInfo>> search(String keyWords, bool isLive) async {
    List<RoomInfo> list = [];
    String url = "https://www.douyu.com/japi/search/api/searchAnchor?kw=" +
        const Utf8Encoder().convert(keyWords).toString() +
        "&page=1&pageSize=5&filterType=${isLive ? 1 : 0}";

    try {
      dynamic response = await _getJson(url);
      if (response["error"] == 0) {
        List<dynamic> ownerList = response["data"]["relateAnchor"];
        for (var ownerInfo in ownerList) {
          RoomInfo owner = RoomInfo(ownerInfo['rid'].toString());
          owner.platform = "douyu";
          owner.nick = ownerInfo["nickName"];
          owner.areaName = ownerInfo["cateName"];
          owner.avatar = ownerInfo["avatar"];
          owner.liveStatus =
              ownerInfo["isLive"] == 1 ? LiveStatus.live : LiveStatus.offline;
          list.add(owner);
        }
      }
    } catch (e) {
      return list;
    }
    return list;
  }
}
