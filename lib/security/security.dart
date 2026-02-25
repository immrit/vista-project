import '../services/vista_node_service.dart';

Future<String> getIpAddress() async {
  // Use Node.js backend to get public IP securely
  return await VistaNodeService.getPublicIp();
}

Future<void> updateIpAddress() async {
  // 🔒 FIX: Deprecated. IP tracking is handled by the server.
  return;
}
