// tsconnect build: check our own server for a newer TS원격 APK.
// The build number is baked in at build time (--dart-define=TS_BUILD=<number in the TS_BUILD file>).
import 'dart:async';
import 'dart:convert';

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/state_model.dart';

const int kTsBuild = int.fromEnvironment('TS_BUILD', defaultValue: 0);

/// "TS원격 b10 (RustDesk 1.5.3)" for the About screens.
String tsVersionText(String rustdeskVersion) =>
    '${kTsBuild > 0 ? 'TS원격 b$kTsBuild' : 'TS원격 (개발용)'} (RustDesk $rustdeskVersion)';
const String kTsBase = 'https://rd.tsconnect.kr/';
const String kTsVersionUrl = '${kTsBase}api/ts-app/version';
const String kTsWinVersionUrl = '${kTsBase}api/ts-app/version?platform=windows';

bool isTsUpdateUrl(String url) => url.startsWith(kTsBase);

/// Latest build on our server: (build, download url), or null if unreachable.
Future<(int, String)?> tsFetchLatest() async {
  try {
    final r = await http
        .get(Uri.parse(Platform.isWindows ? kTsWinVersionUrl : kTsVersionUrl))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    final build = j['build'];
    final url = j['url'];
    if (build is int && url is String && isTsUpdateUrl(url)) return (build, url);
  } catch (_) {}
  return null;
}

Future<void> tsCheckUpdate() async {
  // offline or server unreachable: try again next launch
  final latest = await tsFetchLatest();
  if (latest != null && latest.$1 > kTsBuild) {
    stateGlobal.updateUrl.value = latest.$2;
  }
}

/// "업데이트 확인" button for the About screens (next to the version).
class TsUpdateCheckButton extends StatefulWidget {
  const TsUpdateCheckButton({Key? key}) : super(key: key);
  @override
  State<TsUpdateCheckButton> createState() => _TsUpdateCheckButtonState();
}

class _TsUpdateCheckButtonState extends State<TsUpdateCheckButton> {
  bool _busy = false;
  String? _msg;
  String? _url; // set when a newer build exists

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _msg = null;
      _url = null;
    });
    final latest = await tsFetchLatest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (latest == null) {
        _msg = '서버에 연결할 수 없어요';
      } else if (latest.$1 > kTsBuild) {
        _msg = '새 버전 b${latest.$1}이 있어요';
        _url = latest.$2;
        stateGlobal.updateUrl.value = latest.$2;
      } else {
        _msg = '최신 버전이에요';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _check,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 16),
          label: const Text('업데이트 확인'),
        ),
        if (_msg != null)
          Text(_msg!,
              style: TextStyle(
                  fontSize: 12,
                  color: _url != null ? Colors.orange : muted)),
        if (_url != null)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(_url!)),
            child: const Text('내려받기'),
          ),
      ],
    );
  }
}
