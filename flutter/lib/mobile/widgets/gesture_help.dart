import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:flutter_hbb/common/widgets/ts_touch.dart';

class GestureIcons {
  static const String _family = 'gestureicons';

  GestureIcons._();

  static const IconData iconMouse = IconData(0xe65c, fontFamily: _family);
  static const IconData iconTabletTouch = IconData(0xe9ce, fontFamily: _family);
  static const IconData iconGestureFDrag =
      IconData(0xe686, fontFamily: _family);
  static const IconData iconMobileTouch = IconData(0xe9cd, fontFamily: _family);
  static const IconData iconGesturePress =
      IconData(0xe66c, fontFamily: _family);
  static const IconData iconGestureTap = IconData(0xe66f, fontFamily: _family);
  static const IconData iconGesturePinch =
      IconData(0xe66a, fontFamily: _family);
  static const IconData iconGesturePressHold =
      IconData(0xe66b, fontFamily: _family);
  static const IconData iconGestureFDragUpDown_ =
      IconData(0xe685, fontFamily: _family);
  static const IconData iconGestureFTap_ =
      IconData(0xe68e, fontFamily: _family);
  static const IconData iconGestureFSwipeRight =
      IconData(0xe68f, fontFamily: _family);
  static const IconData iconGestureFdoubleTap =
      IconData(0xe691, fontFamily: _family);
  static const IconData iconGestureFThreeFingers =
      IconData(0xe687, fontFamily: _family);
}

typedef OnTouchModeChange = void Function(bool);

class GestureHelp extends StatefulWidget {
  GestureHelp(
      {Key? key,
      required this.touchMode,
      required this.onTouchModeChange,
      required this.virtualMouseMode,
      this.inputModel})
      : super(key: key);
  final bool touchMode;
  final OnTouchModeChange onTouchModeChange;
  final VirtualMouseMode virtualMouseMode;
  final InputModel? inputModel;

  @override
  State<StatefulWidget> createState() =>
      _GestureHelpState(touchMode, virtualMouseMode);
}

class _GestureHelpState extends State<GestureHelp> {
  late int _selectedIndex;
  late bool _touchMode;
  final VirtualMouseMode _virtualMouseMode;

  _GestureHelpState(bool touchMode, VirtualMouseMode virtualMouseMode)
      : _virtualMouseMode = virtualMouseMode {
    _touchMode = touchMode;
    _selectedIndex = _touchMode ? 1 : 0;
  }

  /// Helper to exit relative mouse mode when certain conditions are met.
  /// This reduces code duplication across multiple UI callbacks.
  void _exitRelativeMouseModeIf(bool condition) {
    if (condition) {
      widget.inputModel?.setRelativeMouseMode(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final space = 12.0;
    var width = size.width - 2 * space;
    final minWidth = 90;
    if (size.width > minWidth + 2 * space) {
      final n = (size.width / (minWidth + 2 * space)).floor();
      width = size.width / n - 2 * space;
    }
    return Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToggleSwitch(
                        initialLabelIndex: _selectedIndex,
                        activeFgColor: Colors.white,
                        inactiveFgColor: Colors.white60,
                        activeBgColor: [MyTheme.accent],
                        inactiveBgColor: Theme.of(context).hintColor,
                        totalSwitches: 2,
                        minWidth: 150,
                        fontSize: 15,
                        iconSize: 18,
                        labels: [
                          translate("Mouse mode"),
                          translate("Touch mode")
                        ],
                        icons: [Icons.mouse, Icons.touch_app],
                        onToggle: (index) {
                          setState(() {
                            if (_selectedIndex != index) {
                              _selectedIndex = index ?? 0;
                              _touchMode = index == 0 ? false : true;
                              widget.onTouchModeChange(_touchMode);
                              // Exit relative mouse mode when switching to touch mode
                              _exitRelativeMouseModeIf(_touchMode);
                            }
                          });
                        },
                      ),
                      Transform.translate(
                        offset: const Offset(-10.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _virtualMouseMode.showVirtualMouse,
                              onChanged: (value) async {
                                if (value == null) return;
                                await _virtualMouseMode.toggleVirtualMouse();
                                // Exit relative mouse mode when virtual mouse is hidden
                                _exitRelativeMouseModeIf(
                                    !_virtualMouseMode.showVirtualMouse);
                                setState(() {});
                              },
                            ),
                            InkWell(
                              onTap: () async {
                                await _virtualMouseMode.toggleVirtualMouse();
                                // Exit relative mouse mode when virtual mouse is hidden
                                _exitRelativeMouseModeIf(
                                    !_virtualMouseMode.showVirtualMouse);
                                setState(() {});
                              },
                              child: Text(translate('Show virtual mouse')),
                            ),
                          ],
                        ),
                      ),
                      if (_touchMode && _virtualMouseMode.showVirtualMouse)
                        Padding(
                          // Indent "Virtual mouse size"
                          padding: const EdgeInsets.only(left: 24.0),
                          child: SizedBox(
                            width: 260,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 0.0, bottom: 0),
                                  child: Text(translate('Virtual mouse size')),
                                ),
                                Transform.translate(
                                  offset: Offset(-0.0, -6.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 0.0),
                                        child: Text(translate('Small')),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: _virtualMouseMode
                                              .virtualMouseScale,
                                          min: 0.8,
                                          max: 1.8,
                                          divisions: 10,
                                          onChanged: (value) {
                                            _virtualMouseMode
                                                .setVirtualMouseScale(value);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 16.0),
                                        child: Text(translate('Large')),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_touchMode && _virtualMouseMode.showVirtualMouse)
                        Transform.translate(
                          offset: const Offset(-10.0, -12.0),
                          child: Padding(
                              // Indent "Show virtual joystick"
                              padding: const EdgeInsets.only(left: 24.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value:
                                        _virtualMouseMode.showVirtualJoystick,
                                    onChanged: (value) async {
                                      if (value == null) return;
                                      await _virtualMouseMode
                                          .toggleVirtualJoystick();
                                      // Exit relative mouse mode when joystick is hidden
                                      _exitRelativeMouseModeIf(
                                          !_virtualMouseMode
                                              .showVirtualJoystick);
                                      setState(() {});
                                    },
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await _virtualMouseMode
                                          .toggleVirtualJoystick();
                                      // Exit relative mouse mode when joystick is hidden
                                      _exitRelativeMouseModeIf(
                                          !_virtualMouseMode
                                              .showVirtualJoystick);
                                      setState(() {});
                                    },
                                    child: Text(
                                        translate("Show virtual joystick")),
                                  ),
                                ],
                              )),
                        ),
                      // Relative mouse mode option - only visible when joystick is shown
                      if (!_touchMode &&
                          _virtualMouseMode.showVirtualMouse &&
                          _virtualMouseMode.showVirtualJoystick &&
                          widget.inputModel != null)
                        Obx(() => Transform.translate(
                              offset: const Offset(-10.0, -24.0),
                              child: Padding(
                                  // Indent further for 'Relative mouse mode'
                                  padding: const EdgeInsets.only(left: 48.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: widget.inputModel!
                                            .relativeMouseMode.value,
                                        onChanged: (value) {
                                          if (value == null) return;
                                          widget.inputModel!
                                              .setRelativeMouseMode(value);
                                        },
                                      ),
                                      InkWell(
                                        onTap: () {
                                          widget.inputModel!
                                              .toggleRelativeMouseMode();
                                        },
                                        child: Text(
                                            translate('Relative mouse mode')),
                                      ),
                                    ],
                                  )),
                            )),
                      _tsSettings(context),
                    ],
                  ),
                ),
                Container(
                    child: Wrap(
                  spacing: space,
                  runSpacing: 2 * space,
                  children: _touchMode
                      ? [
                          GestureInfo(width, GestureIcons.iconMobileTouch,
                              '한 손가락 탭', '왼쪽 클릭'),
                          GestureInfo(width, GestureIcons.iconGesturePressHold,
                              '길게 누르기', '오른쪽 클릭'),
                          GestureInfo(width, GestureIcons.iconGestureFSwipeRight,
                              '한 손가락 이동', '드래그'),
                          ..._tsCommonCards(width),
                        ]
                      : [
                          GestureInfo(width, GestureIcons.iconMobileTouch,
                              '한 손가락 탭', '왼쪽 클릭'),
                          GestureInfo(width, GestureIcons.iconGesturePressHold,
                              '길게 누르기 · 두 손가락 탭', '오른쪽 클릭'),
                          GestureInfo(width, GestureIcons.iconGestureFdoubleTap,
                              '두 번 탭 후 끌기', '드래그'),
                          ..._tsCommonCards(width),
                        ],
                )),
              ],
            )));
  }

  List<Widget> _tsCommonCards(double width) => [
        GestureInfo(width, GestureIcons.iconGestureFDragUpDown_,
            '두 손가락 위아래 · 좌우', '스크롤'),
        GestureInfo(
            width, GestureIcons.iconGesturePinch, '벌리기 · 모으기', '화면 확대'),
        GestureInfo(width, GestureIcons.iconGesturePressHold,
            '두 손가락 대고 잠깐 멈춘 뒤 끌기', '화면 이동'),
        GestureInfo(width, GestureIcons.iconGestureFTap_, '세 손가락 탭',
            '키보드 열기/닫기'),
        GestureInfo(width, GestureIcons.iconGestureFThreeFingers,
            '세 손가락 좌우', '창 전환 (Alt+Tab)'),
        GestureInfo(width, GestureIcons.iconGestureFThreeFingers,
            '세 손가락 위로', '작업 보기 (Win+Tab)'),
        GestureInfo(width, GestureIcons.iconGestureFThreeFingers,
            '세 손가락 아래로', '바탕화면 (Win+D)'),
      ];

  Widget _tsSettings(BuildContext context) {
    TsTouch.load();
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_touchMode)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('마우스 속도 ${TsTouch.speed}%'),
            ),
          if (!_touchMode)
            Row(children: [
              const Text('느리게'),
              Expanded(
                child: Slider(
                  value: TsTouch.speed.toDouble(),
                  min: kTsTouchSpeedMin.toDouble(),
                  max: kTsTouchSpeedMax.toDouble(),
                  divisions: (kTsTouchSpeedMax - kTsTouchSpeedMin) ~/ 10,
                  onChanged: (v) => setState(() => TsTouch.setSpeed(v.round())),
                ),
              ),
              const Text('빠르게'),
            ]),
          Transform.translate(
            offset: const Offset(-10.0, 0.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: TsTouch.palmReject,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => TsTouch.setPalmReject(v));
                  },
                ),
                InkWell(
                  onTap: () =>
                      setState(() => TsTouch.setPalmReject(!TsTouch.palmReject)),
                  child: const Text('손바닥 닿음 무시 (태블릿)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GestureInfo extends StatelessWidget {
  const GestureInfo(this.width, this.icon, this.fromText, this.toText,
      {Key? key})
      : super(key: key);

  final String fromText;
  final String toText;
  final IconData icon;
  final double width;

  final iconSize = 35.0;
  final iconColor = MyTheme.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: width,
        child: Column(
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            SizedBox(height: 6),
            Text(fromText,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 9, color: Theme.of(context).hintColor)),
            SizedBox(height: 3),
            Text(toText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color))
          ],
        ));
  }
}
