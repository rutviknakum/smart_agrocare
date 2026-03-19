import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 0)
class ScanRecord extends HiveObject {
  @HiveField(0)
  String imagePath;

  @HiveField(1)
  String? predictedDisease;

  @HiveField(2)
  double? confidence;

  @HiveField(3)
  String? crop;

  @HiveField(4)
  DateTime createdAt;

  ScanRecord({
    required this.imagePath,
    this.predictedDisease,
    this.confidence,
    this.crop,
    DateTime? createdAt, // ← OPTIONAL
  }) : createdAt = createdAt ?? DateTime.now(); // ← AUTO GENERATE
}
