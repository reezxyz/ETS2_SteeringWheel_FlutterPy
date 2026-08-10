import 'dart:async';
import 'dart:io';

import 'package:nsd/nsd.dart';

class DiscoveredDevice {
  final String name;
  final String id;
  final String ip;
  final int port;

  const DiscoveredDevice({
    required this.name,
    required this.id,
    required this.ip,
    required this.port,
  });

  String get websocketUrl => 'ws://$ip:$port';
}

class DeviceDiscovery {
  static const String serviceType =
      '_ets2controller._tcp';

  Discovery? _discovery;

  bool _scanning = false;

  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_scanning) {
      return [];
    }

    _scanning = true;

    final devices = <String, DiscoveredDevice>{};

    try {
      print(
        '[mDNS] Starting discovery for $serviceType',
      );

      _discovery = await startDiscovery(
        serviceType,
        autoResolve: true,
        ipLookupType: IpLookupType.v4,
      );

      final completer = Completer<void>();

      _discovery!.addServiceListener(
        (service, status) async {
          try {
            if (status != ServiceStatus.found) {
              return;
            }

            print(
              '[mDNS] Service found: '
              '${service.name}',
            );

            print(
              '[mDNS] Host: ${service.host}',
            );

            print(
              '[mDNS] Port: ${service.port}',
            );

            String? ip;

            // The nsd plugin resolves the service and can provide
            // its host address. We prefer IPv4 because the current
            // WebSocket endpoint is using ws://IPv4:8765.
            if (service.host != null &&
                service.host!.isNotEmpty) {
              try {
                final addresses =
                    await InternetAddress.lookup(
                  service.host!,
                  type: InternetAddressType.IPv4,
                );

                if (addresses.isNotEmpty) {
                  ip = addresses.first.address;
                }
              } catch (e) {
                print(
                  '[mDNS] Host lookup failed: $e',
                );
              }
            }

            // Some platform implementations expose the resolved
            // host directly as an IP address.
            if (ip == null &&
                service.host != null &&
                InternetAddress.tryParse(
                      service.host!,
                    ) !=
                    null) {
              ip = service.host;
            }

            if (ip == null ||
                service.port == null) {
              print(
                '[mDNS] Service has no usable IPv4/port.',
              );
              return;
            }

            final name =
                service.name?.trim().isNotEmpty == true
                    ? service.name!.trim()
                    : 'ETS2 Controller';

            final id =
                '${name.toLowerCase()}@$ip';

            devices[id] = DiscoveredDevice(
              name: name,
              id: id,
              ip: ip,
              port: service.port!,
            );

            print(
              '[mDNS] Device discovered: '
              '$name ($ip:${service.port})',
            );

            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            print(
              '[mDNS] Service processing error: $e',
            );
          }
        },
      );

      // Give mDNS time to receive the service announcement.
      await Future.any([
        completer.future,
        Future.delayed(timeout),
      ]);

      // Small additional window allows multiple PCs to appear.
      await Future.delayed(
        const Duration(milliseconds: 300),
      );
    } catch (e) {
      print(
        '[mDNS] Discovery failed: $e',
      );

      rethrow;
    } finally {
      final activeDiscovery = _discovery;
      _discovery = null;

      if (activeDiscovery != null) {
        try {
          await stopDiscovery(
            activeDiscovery,
          );
        } catch (e) {
          print(
            '[mDNS] Failed to stop discovery: $e',
          );
        }
      }

      _scanning = false;

      print(
        '[mDNS] Scan finished. '
        'Found ${devices.length} device(s).',
      );
    }

    return devices.values.toList();
  }

  void dispose() {
    final activeDiscovery = _discovery;
    _discovery = null;

    if (activeDiscovery != null) {
      stopDiscovery(activeDiscovery);
    }

    _scanning = false;
  }
}
