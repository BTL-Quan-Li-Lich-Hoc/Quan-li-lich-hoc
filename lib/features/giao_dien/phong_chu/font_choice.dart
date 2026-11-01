import 'package:flutter/foundation.dart';

enum AppFontKind { system, builtIn, imported }

@immutable
final class AppFontChoice {
  const new({
    required this.id,
    required this.label,
    required this.kind,
    this.family,
    this.path,
    this.fileName,
  });

  factory fromJson(Map<String, Object?> json) {
    final kindName = json['kind'] as String?;
    final kind = AppFontKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => AppFontKind.system,
    );
    return AppFontChoice(
      id: json['id'] as String? ?? 'system',
      label: json['label'] as String? ?? 'Mặc định hệ thống',
      kind: kind,
      family: json['family'] as String?,
      path: json['path'] as String?,
      fileName: json['fileName'] as String?,
    );
  }

  static const system = AppFontChoice(
    id: 'system',
    label: 'Mặc định hệ thống',
    kind: AppFontKind.system,
  );

  static const builtIns = <AppFontChoice>[
    system,
    AppFontChoice(
      id: 'minecraft',
      label: 'Minecraft',
      kind: AppFontKind.builtIn,
      family: 'MinecraftCustom',
    ),
    AppFontChoice(
      id: 'serif',
      label: 'Serif',
      kind: AppFontKind.builtIn,
      family: 'serif',
    ),
    AppFontChoice(
      id: 'monospace',
      label: 'Monospace',
      kind: AppFontKind.builtIn,
      family: 'monospace',
    ),
  ];

  final String id;
  final String label;
  final AppFontKind kind;
  final String? family;
  final String? path;
  final String? fileName;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'kind': kind.name,
    'family': family,
    'path': path,
    'fileName': fileName,
  };
}
