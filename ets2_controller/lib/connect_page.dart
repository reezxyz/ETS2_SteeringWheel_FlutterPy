import 'dart:async';

import 'package:flutter/material.dart';

import 'device_discovery.dart';
import 'controller_page.dart';
import 'websocket_manager.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final DeviceDiscovery _discovery = DeviceDiscovery();

  List<DiscoveredDevice> _devices = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final devices = await _discovery.scan();

      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Discovery failed: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _scanning = false;
      });
    }
  }

  Future<void> _connect(DiscoveredDevice device) async {
    if (_scanning) return;

    setState(() {
      _error = null;
    });

    final manager = WebSocketManager(device.websocketUrl);

    try {
      await manager.connect();

      if (!mounted) {
        manager.dispose();
        return;
      }

      final channel = manager.channel;

      if (channel == null) {
        throw Exception('WebSocket channel is unavailable.');
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ControllerPage(
            channel: channel,
          ),
        ),
      );
    } catch (e) {
      manager.dispose();

      if (!mounted) return;

      setState(() {
        _error = 'Could not connect to ${device.name} (${device.ip}): $e';
      });
    }
  }

  @override
  void dispose() {
    _discovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Connect to PC'),
        actions: [
          IconButton(
            tooltip: 'Scan again',
            onPressed: _scanning ? null : _scanDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Available Devices',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_scanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Expanded(
                child: _buildDeviceList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _scanning
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _scanning ? Icons.wifi_find : Icons.wifi,
              color: _scanning ? Colors.orange : Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanning ? 'Searching for servers...' : 'Ready',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _scanning
                      ? 'Looking for ETS2 Controller Server on local Wi-Fi'
                      : 'Tap a PC below to connect',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_scanning && _devices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.computer_outlined,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            const Text(
              'No controller server found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure ETS2 Controller Server is running\non the same Wi-Fi network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = _devices[index];

        return _DeviceCard(
          device: device,
          onConnect: () => _connect(device),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;

  const _DeviceCard({
    required this.device,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.computer,
              color: Colors.blueAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  device.ip,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'WebSocket : ${device.port}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onConnect,
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
