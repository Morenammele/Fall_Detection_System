import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:http/http.dart' as http;

/// Replace with your actual Android or iOS OAuth Client ID
const String clientId =
    "895166271616-8q63fpqeofc89tue32lk2lrmtrnob9qo.apps.googleusercontent.com";

class GoogleDriveService {
  static const List<String> _scopes = [DriveApi.driveReadonlyScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Call this once during app startup
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: null, // No backend server
    );
  }

  /// Authenticate user and create Drive API client
  Future<DriveApi?> getDriveApi() async {
    try {
      final account = await _googleSignIn.authenticate();
      if (account == null) {
        print('Sign in failed or cancelled');
        return null;
      }

      final authHeaders = await account.authorizationClient
          .authorizationHeaders(_scopes);
      if (authHeaders == null) {
        print('Authorization headers are null');
        return null;
      }

      final client = GoogleAuthClient(authHeaders);
      return DriveApi(client);
    } catch (e) {
      print('Google Drive error: $e');
      return null;
    }
  }

  /// Get the download URL of a Drive file by file ID
  Future<String?> getVideoDownloadUrl(String fileId) async {
    final drive = await getDriveApi();
    if (drive == null) return null;

    try {
      final file =
          await drive.files.get(fileId, $fields: 'webContentLink') as File;
      return file.webContentLink;
    } catch (e) {
      print('Error retrieving file: $e');
      return null;
    }
  }
}

/// HTTP client that adds Authorization headers
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
