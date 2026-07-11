abstract class ValuedEnum {
  int get value;
}

enum CmdType implements ValuedEnum {
  system(2),
  notification(7),
  health(8),
  calendar(12),
  schedule(17),
  thirdPartyApp(20),
  dataUpload(22);

  @override
  final int value;
  const CmdType(this.value);
}

enum SystemSubtype implements ValuedEnum {
  battery(1),
  deviceInfo(2),
  clockSync(3),
  dnd(11),
  deviceState(78);

  @override
  final int value;
  const SystemSubtype(this.value);
}

enum NotificationSubtype implements ValuedEnum {
  push(0),
  dismiss(1),
  repliesQuery(9),
  repliesDelete(11),
  replies(12),
  replySend(13),
  iconRequest(15),
  iconQuery(16);

  @override
  final int value;
  const NotificationSubtype(this.value);
}

enum HealthSubtype implements ValuedEnum {
  userInfo(0),
  fetchData(1);

  @override
  final int value;
  const HealthSubtype(this.value);
}

enum CalendarSubtype implements ValuedEnum {
  setCalendar(1);

  @override
  final int value;
  const CalendarSubtype(this.value);
}

enum ScheduleSubtype implements ValuedEnum {
  getAlarms(0),
  createAlarm(1),
  editAlarm(2),
  deleteAlarm(4);

  @override
  final int value;
  const ScheduleSubtype(this.value);
}

enum ThirdPartyAppSubtype implements ValuedEnum {
  rpkList(0),
  rpkInstall(1),
  rpkInstalled(2),
  rpkDelete(3),
  launchApp(4),
  requestPhoneAppStatus(6),
  responsePhoneAppStatus(7),
  sendPhoneMessage(8),
  sendWearMessage(9);

  @override
  final int value;
  const ThirdPartyAppSubtype(this.value);
}

enum DataUploadSubtype implements ValuedEnum {
  uploadStart(0);

  @override
  final int value;
  const DataUploadSubtype(this.value);
}
