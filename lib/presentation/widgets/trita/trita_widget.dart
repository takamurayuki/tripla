import 'package:flutter/material.dart';

import 'trita_state.dart';

/// トリ太くん表示ウィジェット (PNG 版)。
///
/// `assets/trita/body/*.png` を使った PNG 実装。Rive ファイル
/// `assets/rive/trita.riv` が配置されたら、本ウィジェットの実装を
/// `RiveAnimation.asset` ベースに置き換える(呼び出し側 API は不変)。
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
  late final AnimationController _bobController;
  late final Animation<double> _bobAnimation;

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
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

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
    final body = _bodyAssetByState[widget.state]!;
    final face = _faceOverlayByState[widget.state];

    return AnimatedBuilder(
      animation: _bobAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bobAnimation.value),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(body, fit: BoxFit.contain),
            if (face != null)
              Positioned(
                top: widget.size * 0.08,
                child: Image.asset(face, width: widget.size * 0.35),
              ),
          ],
        ),
      ),
    );
  }
}
