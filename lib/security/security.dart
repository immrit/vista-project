import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> getIpAddress() async {
  final response =
      await http.get(Uri.parse('https://api.ipify.org?format=json'));
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['ip'];
  } else {
    throw Exception('Failed to fetch IP address');
  }
}

Future<void> updateIpAddress() async {
  try {
    final ipAddress = await getIpAddress();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final result = await Supabase.instance.client
        .from('profiles')
        .update({'last_ip': ipAddress}).eq('id', user.id);

    if (result == null) {
      throw Exception('Failed to execute query: result is null');
    }

    if (result.error != null) {
      throw Exception('Failed to update IP: ${result.error!.message}');
    }

    print('IP updated successfully');
  } catch (error) {
    print('Error updating IP: $error');
  }
}
