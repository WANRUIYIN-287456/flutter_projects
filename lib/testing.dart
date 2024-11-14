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

void loadGAPI() {
  // Wait a bit for the page to fully load before calling the JavaScript function
  Future.delayed(Duration(seconds: 30), () {
    // This ensures that the JavaScript method is available before calling it
    if (js.context.hasProperty('initializeGoogleAPI')) {
      js.context.callMethod('initializeGoogleAPI');
    } else {
      print('initializeGoogleAPI function is not available yet');
    }
  });
}

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

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Keycloak Auth App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: Scaffold(
//         appBar: AppBar(
//           title: Text('Keycloak Authentication'),
//         ),
//         body: Login(),
//       ),
//     );
//   }
// }

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

  @override
  void initState() {
    super.initState();
    // Attempt silent sign-in on load
    // Listen for the Google Identity Services token event
    // html.window.addEventListener('credential-response', (event) {
    //   final credential = (event as html.CustomEvent).detail as String;
    //   _authenticateWithKeycloak(credential);
    // });
    //loadGAPI(); 
  }

  // Future<void> _signInSilently() async {
  //   try {
  //     final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
  //     if (googleUser != null) {
  //       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  //       await _authenticateWithKeycloak(googleAuth.idToken!);
  //     } else {
  //       setState(() {
  //         _status = "User not signed in";
  //       });
  //     }
  //   } catch (error) {
  //     setState(() {
  //       _status = "Silent sign-in error: $error";
  //     });
  //   }
  // }

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
          _status = "User authenticated successfully. Access Token: ${data['access_token']}";
        });
        print(_status);
        // Navigate to Home Page if needed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
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

//   Future<void> createUserInKeycloak(String accessToken, String email, String name) async {
//   final response = await http.post(
//     Uri.parse('192.168.11.226:8080/admin/realms/fml/users'),
//     headers: {
//       'Authorization': 'Bearer $accessToken',
//       'Content-Type': 'application/json',
//     },
//     body: json.encode({
//       "username": email,
//       "email": email,
//       "firstName": name,
//       "enabled": true,
//       "attributes": {
//         "googleUser": ["true"]
//       }
//     }),
//   );

//   if (response.statusCode == 201) {
//     print('User created in Keycloak');
//   } else {
//     print('Failed to create user in Keycloak: ${response.statusCode}');
//   }
// }

Future<void> signInWithGoogle() async {
  try {
    final authInstance = js.context['gapi']['auth2']['getAuthInstance']();
    final user = await authInstance.callMethod('signIn');
    final idToken = user['getAuthResponse']()['id_token'];
    final accessToken = user['getAuthResponse']()['access_token'];
    
    print('ID Token: $idToken');
    print('Access Token: $accessToken');
    
    // Authenticate with Keycloak using the access token or id token
    await _authenticateWithKeycloak(idToken);
  } catch (error) {
    print("Error during Google Sign-In: $error");
  }
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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(child: Text("Welcome Home!")),
    );
  }
}
