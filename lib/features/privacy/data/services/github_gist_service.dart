import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

const String _kClientId = 'Ov23liUv1fqODZSzuBmm';
const String _kGistFilename = 'personal_ai_assistant_sync.json';
const String _kTokenKey = 'github.gist.access_token.v1';

class GitHubDeviceCodeResponse {
  const GitHubDeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  factory GitHubDeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return GitHubDeviceCodeResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
    );
  }
}

sealed class GitHubTokenResult {
  const GitHubTokenResult();
}

class GitHubTokenSuccess extends GitHubTokenResult {
  GitHubTokenSuccess({required this.accessToken});

  final String accessToken;
}

class GitHubTokenPending extends GitHubTokenResult {
  const GitHubTokenPending();
}

class GitHubTokenError extends GitHubTokenResult {
  GitHubTokenError({required this.message});

  final String message;
}

class GitHubUserInfo {
  const GitHubUserInfo({required this.login, required this.id});

  final String login;
  final int id;

  factory GitHubUserInfo.fromJson(Map<String, dynamic> json) {
    return GitHubUserInfo(
      login: json['login'] as String,
      id: json['id'] as int,
    );
  }
}

class GistData {
  const GistData({required this.content, required this.updatedAt});

  final String content;
  final DateTime updatedAt;
}

class GitHubGistService {
  GitHubGistService({required KeychainPreferencesStore preferences})
      : _preferences = preferences;

  final KeychainPreferencesStore _preferences;

  Future<GitHubDeviceCodeResponse> initiateDeviceFlow() async {
    final response = await http.post(
      Uri.parse('https://github.com/login/device/code'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'client_id': _kClientId,
        'scope': 'gist',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Device flow initiation failed: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GitHubDeviceCodeResponse.fromJson(json);
  }

  Stream<GitHubTokenResult> pollForToken(
    String deviceCode,
    int intervalSeconds,
  ) async* {
    var currentInterval = intervalSeconds;

    while (true) {
      await Future<void>.delayed(Duration(seconds: currentInterval));

      final http.Response response;
      try {
        response = await http.post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'client_id': _kClientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          }),
        );
      } catch (e) {
        yield GitHubTokenError(message: 'Network error: $e');
        return;
      }

      if (response.statusCode != 200) {
        yield GitHubTokenError(message: 'HTTP ${response.statusCode}');
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as String?;

      if (error != null) {
        switch (error) {
          case 'authorization_pending':
            yield const GitHubTokenPending();
          case 'slow_down':
            currentInterval += 5;
            yield const GitHubTokenPending();
          case 'expired_token':
            yield GitHubTokenError(message: '设备码已过期，请重新授权');
            return;
          case 'access_denied':
            yield GitHubTokenError(message: '用户拒绝了授权请求');
            return;
          default:
            yield GitHubTokenError(message: error);
            return;
        }
        continue;
      }

      final accessToken = json['access_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _preferences.saveString(_kTokenKey, accessToken);
        yield GitHubTokenSuccess(accessToken: accessToken);
        return;
      }

      yield const GitHubTokenPending();
    }
  }

  Future<GitHubUserInfo> getAuthenticatedUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get user info: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GitHubUserInfo.fromJson(json);
  }

  Future<String?> findPrivateGistId(String accessToken) async {
    var page = 1;

    while (true) {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/gists?per_page=100&page=$page',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to list gists: ${response.statusCode}');
      }

      final gists = jsonDecode(response.body) as List<dynamic>;
      if (gists.isEmpty) return null;

      for (final gist in gists) {
        final gistMap = gist as Map<String, dynamic>;
        final files = gistMap['files'] as Map<String, dynamic>?;
        if (files != null && files.containsKey(_kGistFilename)) {
          return gistMap['id'] as String;
        }
      }

      if (gists.length < 100) return null;
      page++;
    }
  }

  Future<String> createPrivateGist(
    String accessToken,
    String encryptedContent,
  ) async {
    final response = await http.post(
      Uri.parse('https://api.github.com/gists'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: jsonEncode({
        'description': 'Personal AI Assistant Sync (encrypted)',
        'public': false,
        'files': {
          _kGistFilename: {'content': encryptedContent},
        },
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create gist: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  Future<GistData> readGist(String accessToken, String gistId) async {
    final response = await http.get(
      Uri.parse('https://api.github.com/gists/$gistId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to read gist: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final files = json['files'] as Map<String, dynamic>;
    final fileEntry = files[_kGistFilename] as Map<String, dynamic>?;

    if (fileEntry == null) {
      throw Exception('Sync file not found in gist');
    }

    final rawContent = fileEntry['content'] as String?;
    final truncated = fileEntry['truncated'] as bool? ?? false;

    if (truncated || rawContent == null || rawContent.isEmpty) {
      final rawUrl = fileEntry['raw_url'] as String?;
      if (rawUrl != null) {
        final rawResponse = await http.get(
          Uri.parse(rawUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (rawResponse.statusCode != 200) {
          throw Exception(
            'Failed to fetch raw gist content: ${rawResponse.statusCode}',
          );
        }
        final updatedAt = DateTime.parse(json['updated_at'] as String);
        return GistData(content: rawResponse.body, updatedAt: updatedAt);
      }
      throw Exception('Gist content is empty or unavailable');
    }

    final updatedAt = DateTime.parse(json['updated_at'] as String);
    return GistData(content: rawContent, updatedAt: updatedAt);
  }

  Future<void> updateGist(
    String accessToken,
    String gistId,
    String encryptedContent,
  ) async {
    final response = await http.patch(
      Uri.parse('https://api.github.com/gists/$gistId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: jsonEncode({
        'files': {
          _kGistFilename: {'content': encryptedContent},
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update gist: ${response.statusCode}');
    }
  }

  Future<String?> loadStoredToken() {
    return _preferences.readString(_kTokenKey);
  }

  Future<void> clearStoredToken() async {
    await _preferences.saveString(_kTokenKey, '');
  }
}

final githubGistServiceProvider = Provider<GitHubGistService>((ref) {
  return GitHubGistService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});
