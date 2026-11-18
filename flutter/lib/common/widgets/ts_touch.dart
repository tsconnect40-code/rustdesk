// TS원격: phone -> PC touch control (benchmarked against Artemis/Moonlight).
//
// - two-finger drag = smooth scroll with fling, pinch = zoom
// - pointer acceleration + speed setting for one-finger cursor moves
// - three-finger tap = keyboard, swipes = Alt+Tab / Win+Tab / Win+D
// - haptics, Android edge guard, shortcut bar, palm rejection
import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const kTsTouchSpeedKey = 'ts-touch-speed';
const kTsPalmRejectKey = 'ts-palm-reject';
const kTsTouchSpeedMin = 50;
const kTsTouchSpeedMax = 250;

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class TsTouch {
  static int speed = 100;
  static bool palmReject = false;
  static bool _loaded = false;

  /// Set by the mobile remote page; toggles the soft keyboard.
  static VoidCallback? toggleKeyboard;

  static void load() {
    if (_loaded) return;
    _loaded = true;
    final s = int.tryParse(bind.mainGetLocalOption(key: kTsTouchSpeedKey));
    if (s != null && s >= kTsTouchSpeedMin && s <= kTsTouchSpeedMax) {
      speed = s;
    }
    final p = bind.mainGetLocalOption(key: kTsPalmRejectKey);
    if (p == 'Y') {
      palmReject = true;
    } else if (p == 'N') {
      palmReject = false;
    } else {
      // Default: on for tablets, off for phones.
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final size = view.physicalSize / view.devicePixelRatio;
        palmReject = size.shortestSide >= 600;
      } catch (_) {
        palmReject = false;
      }
    }
  }

  static void setSpeed(int v) {
    speed = v.clamp(kTsTouchSpeedMin, kTsTouchSpeedMax);
    bind.mainSetLocalOption(key: kTsTouchSpeedKey, value: speed.toString());
  }

  static void setPalmReject(bool v) {
    palmReject = v;
    bind.mainSetLocalOption(key: kTsPalmRejectKey, value: v ? 'Y' : 'N');
  }

  static double get gain => speed / 100.0;

  /// A large contact ellipse is most likely a palm or the side of a hand.
  static bool isPalm(PointerDownEvent e) {
    if (!isMobile || !palmReject) return false;
    if (e.kind != PointerDeviceKind.touch) return false;
    final r = e.radiusMajor;
    return r > 0 && r > 60;
  }

  static void haptic() {
    HapticFeedback.mediumImpact();
  }

  static void lightHaptic() {
    HapticFeedback.selectionClick();
  }

  /// Press [key] once with the given modifiers, restoring the toolbar's
  /// modifier state afterwards.
  static void combo(InputModel m, String key,
      {bool ctrl = false, bool alt = false, bool shift = false, bool win = false}) {
    final o = [m.ctrl, m.alt, m.shift, m.command];
    m.ctrl = ctrl;
    m.alt = alt;
    m.shift = shift;
    m.command = win;
    try {
      m.inputKey(key);
    } finally {
      m.ctrl = o[0];
      m.alt = o[1];
      m.shift = o[2];
      m.command = o[3];
    }
  }
}

/// One-finger cursor acceleration: slow = precise, fast = far.
class TsPointerAccel {
  final Stopwatch _sw = Stopwatch();
  double _v = 0;

  void reset() {
    _sw
      ..reset()
      ..start();
    _v = 0;
  }

  Offset apply(Offset d) {
    if (!_sw.isRunning) reset();
    final ms = (_sw.elapsedMicroseconds / 1000.0).clamp(4.0, 50.0);
    _sw
      ..reset()
      ..start();
    final inst = d.distance / ms; // logical px per ms
    _v = _v == 0 ? inst : _v * 0.6 + inst * 0.4;
    double g;
    if (_v <= 0.2) {
      g = 0.75;
    } else if (_v >= 1.6) {
      g = 2.4;
    } else {
      g = 0.75 + (_v - 0.2) / 1.4 * 1.65;
    }
    return d * (g * TsTouch.gain);
  }
}

/// Two-finger scroll sent as high-resolution wheel units ("trackpad" type,
/// which the Windows host injects without the 120x notch multiplier).
class TsScroller {
  final FFI ffi;
  TsScroller(this.ffi);

  Offset _rem = Offset.zero;
  Timer? _fling;
  int _axis = 0; // 0 undecided, 1 vertical, 2 horizontal, 3 free
  Offset _axisAccum = Offset.zero;

  void stopFling() {
    _fling?.cancel();
    _fling = null;
  }

  void begin() {
    stopFling();
    _rem = Offset.zero;
    _axis = 0;
    _axisAccum = Offset.zero;
  }

  double get _factor {
    final p = ffi.ffiModel.pi.platform;
    if (p == kPeerPlatformWindows) return 2.5;
    if (p == kPeerPlatformLinux) return 0.06;
    return 1.0;
  }

  Offset _lock(Offset d) {
    if (_axis == 0) {
      _axisAccum += d;
      final ax = _axisAccum.dx.abs(), ay = _axisAccum.dy.abs();
      if (ax + ay < 6) return d;
      if (ay >= ax * 1.5) {
        _axis = 1;
      } else if (ax >= ay * 1.5) {
        _axis = 2;
      } else {
        _axis = 3;
      }
    }
    if (_axis == 1) return Offset(0, d.dy);
    if (_axis == 2) return Offset(d.dx, 0);
    return d;
  }

  void update(Offset fingerDelta) {
    _send(_lock(fingerDelta));
  }

  void end(Velocity v) {
    var vel = _lock(v.pixelsPerSecond);
    if (vel.distance < 350) return;
    if (vel.distance > 6000) vel = vel / vel.distance * 6000;
    var step = vel * 0.016;
    stopFling();
    _fling = Timer.periodic(const Duration(milliseconds: 16), (t) {
      step *= 0.92;
      if (step.distance < 0.6) {
        stopFling();
        return;
      }
      _send(step);
    });
  }

  void _send(Offset d) {
    if (ffi.inputModel.isViewCamera || ffi.ffiModel.viewOnly) return;
    _rem += d * _factor;
    final x = _rem.dx.truncate();
    final y = _rem.dy.truncate();
    _rem -= Offset(x.toDouble(), y.toDouble());
    if (x == 0 && y == 0) return;
    bind.sessionSendMouse(
        sessionId: ffi.sessionId,
        msg: '{"type": "trackpad", "x": "$x", "y": "$y"}');
  }
}

enum TsThreeAction { tap, left, right, up, down }

/// Passive multi-finger tracker (does not take part in the gesture arena).
class TsThreeFinger {
  final Map<int, Offset> _start = {};
  final Map<int, Offset> _pos = {};
  int _maxCount = 0;
  int _t0 = 0;
  bool _fired = false;
  double _maxMove = 0;

  /// Last time 3+ fingers were involved; used to suppress clicks.
  int lastMultiMs = 0;
  void Function(TsThreeAction a)? onAction;

  int get activeCount => _start.length;

  // Two fingers held still briefly -> canvas move mode (armed).
  bool twoHoldArmed = false;
  Timer? _twoTimer;
  final Map<int, Offset> _twoBase = {};

  void _twoReset() {
    _twoTimer?.cancel();
    _twoTimer = null;
    _twoBase.clear();
  }
  bool get recentlyMulti => _nowMs() - lastMultiMs < 450;

  void down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch || TsTouch.isPalm(e)) return;
    if (_start.isEmpty) {
      _maxCount = 0;
      _t0 = _nowMs();
      _fired = false;
      _maxMove = 0;
    }
    _start[e.pointer] = e.position;
    _pos[e.pointer] = e.position;
    _maxCount = max(_maxCount, _start.length);
    if (_start.length >= 3) lastMultiMs = _nowMs();
    _twoReset();
    if (_start.length == 2 && !twoHoldArmed) {
      _twoBase.addAll(_pos);
      _twoTimer = Timer(const Duration(milliseconds: 300), () {
        _twoTimer = null;
        if (_start.length == 2) {
          twoHoldArmed = true;
          TsTouch.haptic();
        }
      });
    } else if (_start.length >= 3) {
      twoHoldArmed = false;
    }
  }

  Offset _avgDelta() {
    var sum = Offset.zero;
    for (final k in _start.keys) {
      sum += (_pos[k] ?? _start[k]!) - _start[k]!;
    }
    return _start.isEmpty ? Offset.zero : sum / _start.length.toDouble();
  }

  void move(PointerMoveEvent e) {
    final s = _start[e.pointer];
    if (s == null) return;
    _pos[e.pointer] = e.position;
    _maxMove = max(_maxMove, (e.position - s).distance);
    final b = _twoBase[e.pointer];
    if (_twoTimer != null && b != null && (e.position - b).distance > 12) {
      _twoReset();
    }
    if (_start.length >= 3) lastMultiMs = _nowMs();
    if (_maxCount == 3 && _start.length == 3 && !_fired) {
      final d = _avgDelta();
      if (d.distance > 70) {
        _fired = true;
        lastMultiMs = _nowMs();
        if (d.dx.abs() > d.dy.abs()) {
          onAction?.call(d.dx > 0 ? TsThreeAction.right : TsThreeAction.left);
        } else {
          onAction?.call(d.dy < 0 ? TsThreeAction.up : TsThreeAction.down);
        }
      }
    }
  }

  void up(PointerEvent e, {bool cancel = false}) {
    if (!_start.containsKey(e.pointer)) return;
    _start.remove(e.pointer);
    _pos.remove(e.pointer);
    _twoReset();
    if (_start.isNotEmpty) return;
    twoHoldArmed = false;
    if (_maxCount >= 3) lastMultiMs = _nowMs();
    if (!cancel &&
        _maxCount == 3 &&
        !_fired &&
        _nowMs() - _t0 < 400 &&
        _maxMove < 25) {
      onAction?.call(TsThreeAction.tap);
    }
  }

  void cancelAll() {
    _start.clear();
    _pos.clear();
    _twoReset();
    twoHoldArmed = false;
  }
}

void tsRunThreeAction(FFI ffi, TsThreeAction a) {
  if (ffi.ffiModel.viewOnly || !ffi.ffiModel.keyboard) return;
  if (ffi.ffiModel.isPeerAndroid) {
    if (a == TsThreeAction.tap) {
      TsTouch.lightHaptic();
      TsTouch.toggleKeyboard?.call();
    }
    return;
  }
  final m = ffi.inputModel;
  TsTouch.lightHaptic();
  switch (a) {
    case TsThreeAction.tap:
      TsTouch.toggleKeyboard?.call();
      break;
    case TsThreeAction.right:
      TsTouch.combo(m, 'VK_TAB', alt: true);
      break;
    case TsThreeAction.left:
      TsTouch.combo(m, 'VK_TAB', alt: true, shift: true);
      break;
    case TsThreeAction.up:
      TsTouch.combo(m, 'VK_TAB', win: true);
      break;
    case TsThreeAction.down:
      TsTouch.combo(m, 'd', win: true);
      break;
  }
}

// Palm-aware versions of Flutter's recognizers.
class TsTapGestureRecognizer extends TapGestureRecognizer {
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !TsTouch.isPalm(event) && super.isPointerAllowed(event);
}

class TsDoubleTapGestureRecognizer extends DoubleTapGestureRecognizer {
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !TsTouch.isPalm(event) && super.isPointerAllowed(event);
}

class TsLongPressGestureRecognizer extends LongPressGestureRecognizer {
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !TsTouch.isPalm(event) && super.isPointerAllowed(event);
}

class _TsKey {
  final String label;
  final String key;
  final bool ctrl, alt, shift, win;
  const _TsKey(this.label, this.key,
      {this.ctrl = false, this.alt = false, this.shift = false, this.win = false});
}

const _tsKeys = <_TsKey>[
  _TsKey('복사', 'c', ctrl: true),
  _TsKey('붙여넣기', 'v', ctrl: true),
  _TsKey('잘라내기', 'x', ctrl: true),
  _TsKey('실행 취소', 'z', ctrl: true),
  _TsKey('전체 선택', 'a', ctrl: true),
  _TsKey('저장', 's', ctrl: true),
  _TsKey('찾기', 'f', ctrl: true),
  _TsKey('창 전환', 'VK_TAB', alt: true),
  _TsKey('바탕화면', 'd', win: true),
  _TsKey('시작', 'Meta'),
  _TsKey('Esc', 'VK_ESCAPE'),
  _TsKey('Enter', 'VK_RETURN'),
  _TsKey('Del', 'VK_DELETE'),
  _TsKey('새로고침', 'VK_F5'),
  _TsKey('작업 관리자', 'VK_ESCAPE', ctrl: true, shift: true),
  _TsKey('창 닫기', 'VK_F4', alt: true),
];

/// Horizontal strip of common PC shortcuts for the mobile remote page.
class TsShortcutBar extends StatelessWidget {
  final InputModel inputModel;
  const TsShortcutBar({Key? key, required this.inputModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.92),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: _tsKeys
              .map((k) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: MyTheme.accent,
                      ),
                      onPressed: () {
                        TsTouch.lightHaptic();
                        TsTouch.combo(inputModel, k.key,
                            ctrl: k.ctrl, alt: k.alt, shift: k.shift, win: k.win);
                      },
                      child: Text(k.label, style: const TextStyle(fontSize: 13)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
