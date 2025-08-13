import '../types.dart';

bool hasOption(Device device, String prop) {
  return device.definition.options?.any((element) => element.name == prop) ?? false;
}