/*
Author: Wong Cheng Wen
*/
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test_app/main.dart';

class HomeScreen extends StatefulWidget {
  //const HomeScreen({super.key});
  final String? access_token;
  final String? refresh_token;
  const HomeScreen({super.key, required this.access_token, required this.refresh_token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late double screenHeight, screenWidth, cardwitdh;
  String _status = "Null";
  //String userDetail = "";
  String user_id = "";
  String? _accessToken = "";

    @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

 Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              // onPressed: (){
              //   Navigator.pushReplacement(
              //     context,
              //     //MaterialPageRoute(builder: (context) => const HomePage()),
              //     MaterialPageRoute(builder: (context) => CreateGroup(access_token: widget.access_token, refresh_token: widget.refresh_token)),
              //   );
              // },
              onPressed: () => _showAddGroupDialog(context),
              child: Text("Add Group"),
            ),
            const SizedBox(height:10),
            ElevatedButton(
              onPressed: logout,
              child: Text("Join Group"),
            ),
            const SizedBox(height:10),
            ElevatedButton(
              onPressed: logout,
              child: Text("Skip"),
            ),
            const SizedBox(height:10),
            ElevatedButton(
              onPressed: logout,
              child: Text("Logout"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> fetchUserInfo() async {

    Map<String, dynamic> userDetail = {}; // Store the response as a Map

    final userInfoUrl = 'http://localhost:8080/realms/fml/protocol/openid-connect/userinfo';

    try {
      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.access_token}', // Use the access token here
        },
      );

      print(response.statusCode);

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        print("User Info: ${userInfo.toString()}");
        setState(() {
          userDetail = userInfo; // Store the decoded response as a Map
          String userID = userDetail['sub'];
          user_id = userID;
        });
      } else {
        print("fail");
      }
    } catch (e) {
      print("fail");
    }
  }

  Future<void> logout() async {
    final logoutUrl = 'http://localhost:8080/realms/fml/protocol/openid-connect/logout';

    final response = await http.post(
      Uri.parse(logoutUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer ${widget.access_token}',
      },
      body: {
        'client_id': 'fml_client',
        'client_secret': '',
        'refresh_token': widget.refresh_token, // Pass the refresh token here
      },
    );
    print(widget.refresh_token);
    if (response.statusCode == 204) {
      print("Successfully logged out.");
      Navigator.pushReplacement(
          context,
          //MaterialPageRoute(builder: (context) => const HomePage()),
          MaterialPageRoute(builder: (context) => SignInScreen()),
        );
    } else {
      print("Logout failed with status: ${response.statusCode}");
    }
  }

Future<void> _showAddGroupDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Company Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async{
                final groupName = nameController.text;
                final description = descriptionController.text;
                await createGroup(groupName, description);
                // if (groupId != null) {
                //   await _addUserToGroup(groupId, accessToken);
                // }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getAccessToken() async {
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
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _accessToken = data['access_token'];
          _status = "Access Token: ${data['access_token']}";
        });
        //print(_status);
        return data['access_token'];
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

  Future<void> createGroup(String groupName, String description) async {
    String? accessToken = await _getAccessToken();
    //_getAccessToken();
    print(groupName);
    if(accessToken == ""){
      print("yes");
    }
    print(accessToken);
    
    final url = 'http://localhost:8080/admin/realms/fml/groups';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'name': groupName,
        "attributes": {
          "description": [description]
        }
      }),
    );
    print(response.body);
    if (response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          final groupId = jsonDecode(response.body)['id'];
          print('Group ID: $groupId');

          // Add child groups (Admin, Account, HR, Packer) under the created company group
          await createSubGroup(groupId, accessToken);

          //return groupId;
        } 
        else {
          // Attempt to fetch the group by name if response is empty
          final groupFetchUrl = Uri.parse(
              'http://localhost:8080/admin/realms/fml/groups?search=$groupName');
          final fetchResponse = await http.get(
            groupFetchUrl,
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );

          if (fetchResponse.statusCode == 200) {
            final groups = jsonDecode(fetchResponse.body) as List;
            if (groups.isNotEmpty) {
              final groupId = groups.first['id'];
              print('Fetched Group ID: $groupId');

              // Add child groups (Admin, Account, HR, Packer) under the created company group
              await createSubGroup(groupId, accessToken);

              //return groupId;
            }
          }
        }
      } else {
        print('Failed to create company group: ${response.body}');
      }
  }

  Future<void> createSubGroup(String id, String? accessToken) async {
    print(_accessToken);
    List<String> subGroupNames = ['Admin', 'HR', 'Packer', 'DeliveryMan'];

    for (String subGroupName in subGroupNames) {
      final url = 'http://localhost:8080/admin/realms/fml/groups/$id/children';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'name': subGroupName,
        }),
      );
      print(response.statusCode);
      if (response.statusCode == 201) {
        final group = json.decode(response.body);
        print('SubGroup "$subGroupName" created successfully.');
        await _getRole(group['id'], accessToken, subGroupName);
      } else {
        print('Failed to create subgroup "$subGroupName": ${response.statusCode}');
      }
      //_addUserToGroup(group['id'], accessToken);
  }
}

  Future<void> _getRole(String groupID, String? accessToken, String subGroupName) async {
    String roleName = "";
    if(subGroupName == "Admin"){
      roleName = "admin";
    }
    else if (subGroupName == "HR"){
      roleName = "hr";
    }
    else if (subGroupName == "Packer"){
      roleName = "packer";
    }
    else{
      roleName = "deliveryman";
    }
    final String url = 'http://localhost:8080/admin/realms/fml/clients/ed8241ee-7bd3-45eb-b7e8-d9cb09f79236/roles/$roleName';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Get role successfully.');
      await _assignRoleToGroup(groupID, data['id'], accessToken, roleName); //subgroup id
    } else {
      print('Failed to assign admin role: ${response.statusCode}');
    }
  }

  Future<void> _assignRoleToGroup(String groupID, String roleID, String? accessToken, String roleName) async {
    final String url = 'http://localhost:8080/admin/realms/fml/groups/$groupID/role-mappings/clients/ed8241ee-7bd3-45eb-b7e8-d9cb09f79236';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode([
      {
        'id': roleID,
        'name': roleName
      }
    ]),
    );

    print(response.statusCode);
    if (response.statusCode == 204) {
      final data = json.decode(response.body);
      print('Get role to group successfully.');
      
    } else {
      print('Failed to assign admin role: ${response.statusCode}');
    }
  }

  Future<void> _addUserToGroup(String groupId, final accessToken) async {
    final String url = 'http://localhost:8080/admin/realms/fml/users/${user_id}/groups/$groupId';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 204) {
      print('User added to group successfully.');
    } else {
      print('Failed to add user to group: ${response.statusCode}');
    }
  }

}