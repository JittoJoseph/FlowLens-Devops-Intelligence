import 'package:flutter/foundation.dart';

@immutable
class Repository {
  final String name;
  final String fullName;
  final String description;
  final String owner;
  final String ownerAvatar;
  final bool isPrivate;
  final String defaultBranch;
  final int openPRs;
  final int totalPRs;
  final DateTime lastActivity;
  final List<String> languages;
  final int stars;
  final int forks;

  const Repository({
    required this.name,
    required this.fullName,
    required this.description,
    required this.owner,
    required this.ownerAvatar,
    required this.isPrivate,
    required this.defaultBranch,
    required this.openPRs,
    required this.totalPRs,
    required this.lastActivity,
    required this.languages,
    this.stars = 0,
    this.forks = 0,
  });

  Repository copyWith({
    String? name,
    String? fullName,
    String? description,
    String? owner,
    String? ownerAvatar,
    bool? isPrivate,
    String? defaultBranch,
    int? openPRs,
    int? totalPRs,
    DateTime? lastActivity,
    List<String>? languages,
    int? stars,
    int? forks,
  }) {
    return Repository(
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      isPrivate: isPrivate ?? this.isPrivate,
      defaultBranch: defaultBranch ?? this.defaultBranch,
      openPRs: openPRs ?? this.openPRs,
      totalPRs: totalPRs ?? this.totalPRs,
      lastActivity: lastActivity ?? this.lastActivity,
      languages: languages ?? this.languages,
      stars: stars ?? this.stars,
      forks: forks ?? this.forks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fullName': fullName,
      'description': description,
      'owner': owner,
      'ownerAvatar': ownerAvatar,
      'isPrivate': isPrivate,
      'defaultBranch': defaultBranch,
      'openPRs': openPRs,
      'totalPRs': totalPRs,
      'lastActivity': lastActivity.toIso8601String(),
      'languages': languages,
      'stars': stars,
      'forks': forks,
    };
  }

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      name: json['name'] as String,
      fullName: json['fullName'] as String,
      description: json['description'] as String,
      owner: json['owner'] as String,
      ownerAvatar: json['ownerAvatar'] as String,
      isPrivate: json['isPrivate'] as bool,
      defaultBranch: json['defaultBranch'] as String,
      openPRs: json['openPRs'] as int,
      totalPRs: json['totalPRs'] as int,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      languages: List<String>.from(json['languages'] as List),
      stars: json['stars'] as int? ?? 0,
      forks: json['forks'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Repository && other.fullName == fullName;
  }

  @override
  int get hashCode => fullName.hashCode;

  @override
  String toString() {
    return 'Repository(name: $name, owner: $owner, openPRs: $openPRs)';
  }
}
