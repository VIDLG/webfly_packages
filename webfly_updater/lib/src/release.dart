// ---------------------------------------------------------------------------
// Release Response (Generic)
// ---------------------------------------------------------------------------

/// Generic release metadata abstraction.
/// Allows different release sources (GitHub, GitLab, self-hosted, etc.)
class ReleaseMetadata {
  /// Version/tag name (e.g., 'v1.0.0').
  final String version;

  /// Release notes/description.
  final String? releaseNotes;

  /// List of downloadable assets.
  final List<ReleaseAsset> assets;

  const ReleaseMetadata({
    required this.version,
    this.releaseNotes,
    this.assets = const [],
  });

  /// Find an asset by file extension.
  ReleaseAsset? findAssetByExt(String ext) {
    for (final asset in assets) {
      if (asset.name.endsWith(ext)) {
        return asset;
      }
    }
    return null;
  }
}

/// Generic release asset abstraction.
class ReleaseAsset {
  /// Asset file name.
  final String name;

  /// Direct download URL.
  final String downloadUrl;

  const ReleaseAsset({required this.name, required this.downloadUrl});
}

// ---------------------------------------------------------------------------
// GitHub Release Response
// ---------------------------------------------------------------------------

/// GitHub API release response.
class GitHubReleaseResponse extends ReleaseMetadata {
  GitHubReleaseResponse({
    required super.version,
    super.releaseNotes,
    super.assets,
  });

  /// Parse from GitHub API JSON response.
  factory GitHubReleaseResponse.fromJson(Map<String, dynamic> json) {
    final assets = <ReleaseAsset>[];
    final assetList = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assetList) {
      assets.add(GitHubAsset.fromJson(asset as Map<String, dynamic>));
    }

    return GitHubReleaseResponse(
      version: json['tag_name'] as String? ?? '',
      releaseNotes: json['body'] as String?,
      assets: assets,
    );
  }
}

/// GitHub API asset.
class GitHubAsset extends ReleaseAsset {
  GitHubAsset({required super.name, required super.downloadUrl});

  /// Parse from GitHub API JSON.
  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Self-hosted Release Response
// ---------------------------------------------------------------------------

/// Self-hosted release response (customizable JSON structure).
class SelfHostedReleaseResponse extends ReleaseMetadata {
  SelfHostedReleaseResponse({
    required super.version,
    super.releaseNotes,
    super.assets,
  });

  /// Parse from custom JSON structure.
  /// [versionKey], [notesKey], [assetsKey] allow customizing JSON paths.
  factory SelfHostedReleaseResponse.fromJson(
    Map<String, dynamic> json, {
    String versionKey = 'version',
    String? notesKey,
    String assetsKey = 'assets',
  }) {
    final assets = <ReleaseAsset>[];
    final assetList = json[assetsKey] as List<dynamic>? ?? [];
    for (final asset in assetList) {
      assets.add(SelfHostedAsset.fromJson(asset as Map<String, dynamic>));
    }

    return SelfHostedReleaseResponse(
      version: json[versionKey] as String? ?? '',
      releaseNotes: notesKey != null ? json[notesKey] as String? : null,
      assets: assets,
    );
  }
}

/// Self-hosted release asset.
class SelfHostedAsset extends ReleaseAsset {
  SelfHostedAsset({required super.name, required super.downloadUrl});

  /// Parse from custom JSON structure.
  /// [nameKey], [urlKey] allow customizing JSON paths.
  factory SelfHostedAsset.fromJson(
    Map<String, dynamic> json, {
    String nameKey = 'name',
    String urlKey = 'url',
  }) {
    return SelfHostedAsset(
      name: json[nameKey] as String? ?? '',
      downloadUrl: json[urlKey] as String? ?? '',
    );
  }
}
