import 'package:hive/hive.dart';

part 'option.g.dart';

@HiveType(typeId: 6)
class Option {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String text;

  Option({required this.id, required this.text});
}
