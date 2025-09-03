import 'package:flutter/foundation.dart';

@immutable
class Repository {
  final String? id; // UUID from API
  final String name;
  final String fullName;
  final String description;
  final String owner;
  final String ownerAvatar;
  final bool isPrivate;
  final String defaultBranch;
  final int openPRs;
  final int totalPRs;
  final int mergedPRs;
  final int closedPRs;
  final int draftPRs;
  final DateTime lastActivity;
  final List<String> languages;
  final int stars;
  final int forks;
  final String? htmlUrl; // GitHub URL

  const Repository({
    this.id,
    required this.name,
    required this.fullName,
    required this.description,
    required this.owner,
    required this.ownerAvatar,
    required this.isPrivate,
    required this.defaultBranch,
    required this.openPRs,
    required this.totalPRs,
    this.mergedPRs = 0,
    this.closedPRs = 0,
    this.draftPRs = 0,
    required this.lastActivity,
    required this.languages,
    this.stars = 0,
    this.forks = 0,
    this.htmlUrl,
  });

  Repository copyWith({
    String? id,
    String? name,
    String? fullName,
    String? description,
    String? owner,
    String? ownerAvatar,
    bool? isPrivate,
    String? defaultBranch,
    int? openPRs,
    int? totalPRs,
    int? mergedPRs,
    int? closedPRs,
    int? draftPRs,
    DateTime? lastActivity,
    List<String>? languages,
    int? stars,
    int? forks,
    String? htmlUrl,
  }) {
    return Repository(
      id: id ?? this.id,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      isPrivate: isPrivate ?? this.isPrivate,
      defaultBranch: defaultBranch ?? this.defaultBranch,
      openPRs: openPRs ?? this.openPRs,
      totalPRs: totalPRs ?? this.totalPRs,
      mergedPRs: mergedPRs ?? this.mergedPRs,
      closedPRs: closedPRs ?? this.closedPRs,
      draftPRs: draftPRs ?? this.draftPRs,
      lastActivity: lastActivity ?? this.lastActivity,
      languages: languages ?? this.languages,
      stars: stars ?? this.stars,
      forks: forks ?? this.forks,
      htmlUrl: htmlUrl ?? this.htmlUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fullName': fullName,
      'description': description,
      'owner': owner,
      'ownerAvatar': ownerAvatar,
      'isPrivate': isPrivate,
      'defaultBranch': defaultBranch,
      'openPRs': openPRs,
      'totalPRs': totalPRs,
      'mergedPRs': mergedPRs,
      'closedPRs': closedPRs,
      'draftPRs': draftPRs,
      'lastActivity': lastActivity.toIso8601String(),
      'languages': languages,
      'stars': stars,
      'forks': forks,
      'htmlUrl': htmlUrl,
    };
  }

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      id: json['id'] as String?,
      name: json['name'] as String,
      fullName: json['fullName'] as String,
      description: json['description'] as String,
      owner: json['owner'] as String,
      ownerAvatar: json['ownerAvatar'] as String,
      isPrivate: json['isPrivate'] as bool,
      defaultBranch: json['defaultBranch'] as String,
      openPRs: json['openPRs'] as int,
      totalPRs: json['totalPRs'] as int,
      mergedPRs: json['mergedPRs'] as int? ?? 0,
      closedPRs: json['closedPRs'] as int? ?? 0,
      draftPRs: json['draftPRs'] as int? ?? 0,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      languages: List<String>.from(json['languages'] as List),
      stars: json['stars'] as int? ?? 0,
      forks: json['forks'] as int? ?? 0,
      htmlUrl: json['htmlUrl'] as String?,
    );
  }

  // Factory constructor for API response format
  factory Repository.fromApiJson(Map<String, dynamic> json) {
    return Repository(
      id: json['id'] as String?,
      name: json['name'] as String,
      fullName: json['full_name'] as String,
      description: json['description'] as String? ?? '',
      owner: json['owner'] as String,
      ownerAvatar:
          'https://github.com/${json['owner']}.png', // GitHub avatar URL pattern
      isPrivate: json['is_private'] as bool,
      defaultBranch: json['default_branch'] as String,
      openPRs: json['open_prs'] as int,
      totalPRs: json['total_prs'] as int,
      mergedPRs: json['merged_prs'] as int? ?? 0,
      closedPRs: json['closed_prs'] as int? ?? 0,
      draftPRs: json['draft_prs'] as int? ?? 0,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      languages: [
        json['language'] as String? ?? 'Unknown',
      ], // API provides single language
      stars: json['stars'] as int? ?? 0,
      forks: json['forks'] as int? ?? 0,
      htmlUrl: json['html_url'] as String?,
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
    return 'Repository(name: $name, owner: $owner, openPRs: $openPRs, mergedPRs: $mergedPRs, closedPRs: $closedPRs)';
  }
}
