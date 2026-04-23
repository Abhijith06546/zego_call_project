import 'package:zego_express_engine/zego_express_engine.dart';
import '../constants.dart';

class ZegoService {
  static ZegoService? _instance;
  static ZegoService get instance => _instance ??= ZegoService._();
  ZegoService._();

  bool _engineCreated = false;

  Future<void> initEngine() async {
    if (_engineCreated) return;

    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        ZegoConstants.appId,
        ZegoScenario.StandardVoiceCall,
        appSign: ZegoConstants.appSign,
      ),
    );

    _engineCreated = true;
    _registerCallbacks();
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
      // Room connection state changes
    };
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    required String streamId,
  }) async {
    final user = ZegoUser(userId, userName);
    final config = ZegoRoomConfig.defaultConfig()..isUserStatusNotify = true;

    await ZegoExpressEngine.instance.loginRoom(roomId, user, config: config);
    await ZegoExpressEngine.instance.muteMicrophone(false);
    await ZegoExpressEngine.instance.startPublishingStream(streamId);
  }

  Future<void> leaveRoom(String roomId, String streamId) async {
    await ZegoExpressEngine.instance.stopPublishingStream();
    await ZegoExpressEngine.instance.logoutRoom(roomId);
  }

  Future<void> toggleMic(bool muted) async {
    await ZegoExpressEngine.instance.muteMicrophone(muted);
  }

  Future<void> destroy() async {
    if (_engineCreated) {
      await ZegoExpressEngine.destroyEngine();
      _engineCreated = false;
    }
  }
}
