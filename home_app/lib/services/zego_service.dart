import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:zego_express_engine/zego_express_engine.dart';
import '../constants.dart';
import '../utils/zego_token_helper.dart';

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
          appSign: kIsWeb ? null : ZegoConstants.appSign,
        ),
      );
      _engineCreated = true;
      _registerCallbacks();
      debugPrint('[ZegoService] Engine initialized');
    } catch (e, stack) {
      debugPrint('[ZegoService] initEngine failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  void _registerCallbacks() {
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, streamList, extendedData) {
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final stream in streamList) {
          ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
        }
      }
    };

    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      if (errorCode != 0) {
        debugPrint('[ZegoService] Room state error — room: $roomID, state: $state, code: $errorCode');
      }
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
        config.token = ZegoTokenHelper.generateToken04(
          appId: ZegoConstants.appId,
          userId: userId,
          appSign: ZegoConstants.appSign,
        );
      }

      await ZegoExpressEngine.instance.loginRoom(roomId, user, config: config);
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await ZegoExpressEngine.instance.startPublishingStream(streamId);
      debugPrint('[ZegoService] Joined room: $roomId as $userId');
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
