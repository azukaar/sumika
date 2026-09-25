import 'package:flutter/foundation.dart';

class AppMode {
  // Web only: open with ?no-config to hide the settings gear and the
  // edit/forget actions, e.g. for a wall-mounted panel.
  static final bool noConfig =
      kIsWeb && Uri.base.queryParameters.containsKey('no-config');
}
