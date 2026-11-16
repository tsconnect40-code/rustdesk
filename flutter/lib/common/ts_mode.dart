// tsconnect build: receive-only install mode.
//
// A PC installed as "receive only" keeps its settings locked until an
// account (given out by the admin) is logged in on it.
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const kTsReceiveOnly = 'ts-receive-only';

bool get tsReceiveOnly => bind.mainGetOptionSync(key: kTsReceiveOnly) == 'Y';

/// Settings are locked on a receive-only PC while nobody is logged in.
bool get tsLocked => tsReceiveOnly && !gFFI.userModel.isLogin;
