/*
Author: Wong Cheng Wen
*/

import 'dart:developer';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:html' as html;

import 'package:test_app/home.dart';
import 'package:test_app/homepage.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1073063686887-7a7ffst3b41dpv9nvvier1fve35cq0eu.apps.googleusercontent.com',
    scopes: [
    'email',
    'openid',
    'profile',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
  );
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SignInScreen(),
    );
  }
}

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  String _status = "Not signed in";
  String? _accessToken;
  String? _refreshToken;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _authenticateWithKeycloak(String idToken) async {
    final keycloakTokenUrl = 'http://localhost:8080/realms/fml/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(keycloakTokenUrl),
        headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        //'Authorization': 'Bearer $idToken', // Send the Google Access Token here
      },
        body: {
          'client_id': 'fml_client',
          'client_secret': '',
          'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
          'subject_token_type': 'urn:ietf:params:oauth:token-type:access_token',
          'subject_token': idToken,
          'subject_issuer': 'google',
          'redirect_uri': 'http://192.168.11.226:9080/', // e.g., http://localhost:3000
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _accessToken = data['access_token'];
          _status = "User authenticated successfully. Access Token: ${data['access_token']} Refresh Token: ${data['refresh_token']}";
          _refreshToken = data['refresh_token'];
        });
        print(_status);
        // Navigate to Home Page if needed
        //fetchUserInfo(data['access_token']);
        //logout(data['access_token'], data['refresh_token']);
        Navigator.pushReplacement(
          context,
          //MaterialPageRoute(builder: (context) => const HomePage()),
          MaterialPageRoute(builder: (context) => HomeScreen(access_token: _accessToken, refresh_token: _refreshToken)),
        );
      } else {
        setState(() {
          _status = "Keycloak Authentication Failed: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error authenticating with Keycloak: $e";
      });
    }
  }

  Future<void> handleGoogleSignIn() async {
  try {
    // Attempt silent sign-in to use existing session if available
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

    if (googleUser == null) {
      // If no session, prompt the user to sign in
      googleUser = await _googleSignIn.signIn();
    }

    if (googleUser != null) {
      log(googleUser.toString());
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? serverAuthCode = googleUser.serverAuthCode;
      final String? idToken = googleAuth.idToken;
      print(googleUser.displayName);
      print(accessToken);
      print('Server Auth Code: $serverAuthCode');

      if (accessToken != null) {
        // Proceed to authenticate with Keycloak
        await _authenticateWithKeycloak(accessToken);
      } else {
        print('accessToken is null');
      }
    } else {
      print('Failed to sign in with Google');
    }
  } catch (error) {
    print('Error during Google Sign-In: $error');
  }
}


  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: handleGoogleSignIn,
      child: Text("Sign in with Google"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Google Sign-In with Keycloak")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            _buildGoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}

Future<void> fetchUserInfo(String accessToken) async {

  final userInfoUrl = 'http://localhost:8080/realms/fml/protocol/openid-connect/userinfo';

  try {
    final response = await http.get(
      Uri.parse(userInfoUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken', // Use the access token here
      },
    );

    print(response.statusCode);

    if (response.statusCode == 200) {
      final userInfo = json.decode(response.body);
      print("User Info: ${userInfo.toString()}");
    } else {
      print("fail");
    }
  } catch (e) {
    print("fail");
  }
}

Future<void> logout(String accessToken, String refreshToken) async {
  final logoutUrl = 'http://localhost:8080/realms/fml/protocol/openid-connect/logout';

  final response = await http.post(
    Uri.parse(logoutUrl),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Bearer $accessToken',
    },
    body: {
      'client_id': 'fml_client',
      'client_secret': '',
      'refresh_token': refreshToken, // Pass the refresh token here
    },
  );

  if (response.statusCode == 200) {
    print("Successfully logged out.");
  } else {
    print("Logout failed with status: ${response.statusCode}");
  }
}

// class HomeScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Home")),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text("hi")
//           ],
//         ),
//       ),
//     );
//   }
// }
