import 'dart:io';

enum AddressKind {
  lan('Red local'),
  vpn('Tailscale / ZeroTier / VPN'),
  other('Otra');

  const AddressKind(this.label);
  final String label;
}

class LocalAddress {
  LocalAddress(this.address, this.interfaceName, this.kind);
  final String address;
  final String interfaceName;
  final AddressKind kind;
}

/// Direcciones IPv4 de este dispositivo a las que se podrían conectar los jugadores.
Future<List<LocalAddress>> localAddresses() async {
  final out = <LocalAddress>[];
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        out.add(LocalAddress(a.address, i.name, classify(a.address, i.name)));
      }
    }
  } on Object {
    // Algunas plataformas no permiten listar interfaces; no es grave.
  }
  out.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return out;
}

AddressKind classify(String ip, [String interfaceName = '']) {
  final name = interfaceName.toLowerCase();
  final p = ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  if (p.length != 4) return AddressKind.other;
  // 100.64.0.0/10: CGNAT, que Tailscale usa para su red privada.
  if (p[0] == 100 && p[1] >= 64 && p[1] <= 127) return AddressKind.vpn;
  if (name.contains('tailscale') ||
      name.contains('zt') ||
      name.contains('zerotier') ||
      name.contains('tun') ||
      name.contains('wg')) {
    return AddressKind.vpn;
  }
  if (p[0] == 10 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && p[1] >= 16 && p[1] <= 31)) {
    return AddressKind.lan;
  }
  return AddressKind.other;
}
