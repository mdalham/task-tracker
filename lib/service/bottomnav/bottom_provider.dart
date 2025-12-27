import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  int _index = 0;
  int? _timelineTabIndex;
  bool _shouldChangeTimelineTab = false;

  int get index => _index;
  int? get timelineTabIndex => _timelineTabIndex;
  bool get shouldChangeTimelineTab => _shouldChangeTimelineTab;

  void changeTab(int newIndex, {int? timelineTab}) {
    _index = newIndex;

    if (timelineTab != null) {
      _timelineTabIndex = timelineTab;
      _shouldChangeTimelineTab = true;
    }

    notifyListeners();
  }

  void resetTimelineTab() {
    _shouldChangeTimelineTab = false;
    _timelineTabIndex = null;
  }

  void acknowledgeTimelineChange() {
    _shouldChangeTimelineTab = false;
  }
}