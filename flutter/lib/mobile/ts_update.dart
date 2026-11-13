// tsconnect build: check our own server for a newer TS원격 APK.
// The build number is baked in at build time (--dart-define=TS_BUILD=<run number>).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/state_model.dart';

const int kTsBuild = int.fromEnvironment('TS_BUILD', defaultValue: 0);
const String kTsBase = 'https://rd.tsconnect.kr/';
const String kTsVersionUrl = '${kTsBase}api/ts-app/version';

bool isTsUpdateUrl(String url) => url.startsWith(kTsBase);

Future<void> tsCheckUpdate() async {
  try {
    final r = await http
        .get(Uri.parse(kTsVersionUrl))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return;
    final j = jsonDecode(r.body);
    final build = j['build'];
    final url = j['url'];
    if (build is int && url is String && build > kTsBuild && isTsUpdateUrl(url)) {
      stateGlobal.updateUrl.value = url;
    }
  } catch (_) {
    // offline or server unreachable: try again next launch
  }
}
