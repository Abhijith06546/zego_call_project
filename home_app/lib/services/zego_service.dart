import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants.dart';

class ZegoService {
  static ZegoService? _instance;
  static ZegoService get instance => _instance ??= ZegoService._();
  ZegoService._();

  bool _engineCreated = false;

  Future<void> initEngine() async {
    if (_engineCreated) return;
    try {
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          ZegoConstants.appId,
          ZegoScenario.StandardVoiceCall,
          // Web SDK does not support AppSign mode; token is provided per-room login.
          appSign: kIsWeb ? null : ZegoConstants.appSign,
        ),
      );
      _engineCreated = true;
      _registerCallbacks();
      debugPrint('[ZegoService] Engine initialized (web=$kIsWeb)');
    } catch (e, stack) {
      debugPrint('[ZegoService] initEngine failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  void _registerCallbacks() {
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, streamList, extendedData) {
      final ids = streamList.map((s) => s.streamID).toList();
      debugPrint('[ZegoService] onRoomStreamUpdate — room: $roomID, type: $updateType, streams: $ids');
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          debugPrint('[ZegoService] startPlayingStream: ${stream.streamID}');
          ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final stream in streamList) {
          debugPrint('[ZegoService] stopPlayingStream: ${stream.streamID}');
          ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
        }
      }
    };

    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      debugPrint('[ZegoService] onRoomStateUpdate — room: $roomID, state: $state, code: $errorCode');
    };

    ZegoExpressEngine.onPublisherStateUpdate =
        (streamID, state, errorCode, extendedData) {
      debugPrint('[ZegoService] onPublisherStateUpdate — stream: $streamID, state: $state, code: $errorCode');
    };

    ZegoExpressEngine.onPlayerStateUpdate =
        (streamID, state, errorCode, extendedData) {
      debugPrint('[ZegoService] onPlayerStateUpdate — stream: $streamID, state: $state, code: $errorCode');
    };
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    required String streamId,
  }) async {
    try {
      final user = ZegoUser(userId, userName);
      final config = ZegoRoomConfig.defaultConfig()..isUserStatusNotify = true;

      if (kIsWeb) {
        debugPrint('[ZegoService] Fetching token from Cloud Function...');
        final callable = FirebaseFunctions.instance.httpsCallable('getZegoToken');
        final result = await callable.call({'userId': userId, 'roomId': roomId});
        config.token = result.data['token'] as String;
        debugPrint('[ZegoService] Token received (length=${config.token.length})');
      }

      debugPrint('[ZegoService] loginRoom — roomId: $roomId, userId: $userId, streamId: $streamId');
      final loginResult = await ZegoExpressEngine.instance.loginRoom(roomId, user, config: config);
      debugPrint('[ZegoService] loginRoom result: $loginResult');

      debugPrint('[ZegoService] startPublishingStream: $streamId');
      await ZegoExpressEngine.instance.startPublishingStream(streamId);

      await ZegoExpressEngine.instance.muteMicrophone(false);
      debugPrint('[ZegoService] mic unmuted');
    } catch (e, stack) {
      debugPrint('[ZegoService] joinRoom failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId, String streamId) async {
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
      await ZegoExpressEngine.instance.logoutRoom(roomId);
      debugPrint('[ZegoService] Left room: $roomId');
    } catch (e, stack) {
      debugPrint('[ZegoService] leaveRoom failed: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> toggleMic(bool muted) async {
    try {
      await ZegoExpressEngine.instance.muteMicrophone(muted);
    } catch (e, stack) {
      debugPrint('[ZegoService] toggleMic failed: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> destroy() async {
    if (_engineCreated) {
      try {
        await ZegoExpressEngine.destroyEngine();
        _engineCreated = false;
        debugPrint('[ZegoService] Engine destroyed');
      } catch (e, stack) {
        debugPrint('[ZegoService] destroy failed: $e');
        debugPrint(stack.toString());
      }
    }
  }
}
