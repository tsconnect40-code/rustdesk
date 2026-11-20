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

/// Black out the remote PC's screen whenever this PC controls it.
const kTsAutoPrivacy = 'ts-auto-privacy';

/// Keep the account logged in after the program exits.
/// Off (default): logged out when TS원격 closes.
const kTsAutoLogin = 'ts-auto-login';

/// Last account name, to prefill the login box after a logout.
const kTsLastUser = 'ts-last-user';

bool tsLocalFlag(String key) => bind.mainGetLocalOption(key: key) == 'Y';
Future<void> tsSetLocalFlag(String key, bool v) =>
    bind.mainSetLocalOption(key: key, value: v ? 'Y' : 'N');
