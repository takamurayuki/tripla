import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'trita_state.dart';

/// トリ太くん表示ウィジェット。
///
/// 現在は `assets/trita/body/*.png` を用いた PNG fallback で実装している。
/// `assets/rive/trita.riv` が配置されたら、本ウィジェットの内部実装のみを
/// `RiveAnimation.asset` 版に差し替える (呼び出し側 API は不変)。
///
/// 要件定義書 §8.4 / §9.1 / §9.2 参照。
class TritaWidget extends StatefulWidget {
  const TritaWidget({
    super.key,
    this.state = TritaState.idle,
    this.size = 200,
  });

  final TritaState state;
  final double size;

  @override
  State<TritaWidget> createState() => _TritaWidgetState();
}

class _TritaWidgetState extends State<TritaWidget>
    with SingleTickerProviderStateMixin {
  static const _riveAssetPath = 'assets/rive/trita.riv';

  late final AnimationController _bobController;
  late final Animation<double> _bobAnimation;

  Future<bool>? _riveAvailable;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bobAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _bobController, curve: Curves.easeInOut),
    );
    _riveAvailable = _checkRiveAsset();
  }

  Future<bool> _checkRiveAsset() async {
    try {
      await rootBundle.load(_riveAssetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _riveAvailable,
      builder: (context, snapshot) {
        // .riv が配置されたら差し替える。現状は常に PNG fallback。
        final hasRive = snapshot.data ?? false;
        if (hasRive) {
          return _TritaPngView(
            state: widget.state,
            size: widget.size,
            bobAnimation: _bobAnimation,
          );
        }
        return _TritaPngView(
          state: widget.state,
          size: widget.size,
          bobAnimation: _bobAnimation,
        );
      },
    );
  }
}

class _TritaPngView extends StatelessWidget {
  const _TritaPngView({
    required this.state,
    required this.size,
    required this.bobAnimation,
  });

  final TritaState state;
  final double size;
  final Animation<double> bobAnimation;

  static const _bodyAssetByState = <TritaState, String>{
    TritaState.idle: 'assets/trita/body/stand_hold_camera.png',
    TritaState.banzai: 'assets/trita/body/banzai.png',
    TritaState.holdCamera: 'assets/trita/body/stand_hold_camera.png',
    TritaState.mapOpen: 'assets/trita/body/map_open.png',
    TritaState.thinking: 'assets/trita/body/thinking.png',
    TritaState.heartEyes: 'assets/trita/body/stand_hold_camera.png',
    TritaState.cameraShooting: 'assets/trita/body/camera_shooting.png',
    TritaState.jump: 'assets/trita/body/jump.png',
    TritaState.run: 'assets/trita/body/walk.png',
  };

  static const _faceOverlayByState = <TritaState, String?>{
    TritaState.heartEyes: 'assets/trita/face/heart_eyes.png',
  };

  @override
  Widget build(BuildContext context) {
    final body = _bodyAssetByState[state]!;
    final face = _faceOverlayByState[state];

    return AnimatedBuilder(
      animation: bobAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, bobAnimation.value),
          child: child,
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(body, fit: BoxFit.contain),
            if (face != null)
              Positioned(
                top: size * 0.08,
                child: Image.asset(face, width: size * 0.35),
              ),
          ],
        ),
      ),
    );
  }
}
