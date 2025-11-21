import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/gmail.readonly'],
  );

  Future<String?> signInAndGetAccessToken() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        print("⚠️ User did not grant permissions.");
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      print("🔑 Access Token: ${auth.accessToken}");
      return auth.accessToken;
    } catch (error) {
      print("Google Sign-In error: $error");
      return null;
    }
  }
}

void queryGmailAPI(String accessToken) {
  final String url = 'https://www.googleapis.com/gmail/v1/users/me/messages?q=is:unread';
  print("📤 Gmail API Query URL: $url");
}
