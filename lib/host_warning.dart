import 'dart:io';

/// A gentle tip under the host when [hostMayBeOnInternet] says so. It
/// blocks nothing: internet addresses are fine.
const internetHostWarning = 'On the internet your password travels unencrypted. Tailscale keeps it private.';

/// True unless [host] is clearly on the local network or on Tailscale.
///
/// Private and loopback ranges, link-local, IPv6 unique local (which includes
/// Tailscale's), 100.64.0.0/10, .local, .lan and .ts.net names and
/// single-label hostnames all count as safe. An empty host gets no warning.
bool hostMayBeOnInternet(String host) {
  var h = host.trim().toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h.isEmpty) return false;

  final ip = InternetAddress.tryParse(h);
  if (ip != null) {
    if (ip.isLoopback || ip.isLinkLocal) return false;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      if (b[0] == 10) return false;
      if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return false;
      if (b[0] == 192 && b[1] == 168) return false;
      if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return false;
      return true;
    }
    return (b[0] & 0xfe) != 0xfc;
  }

  if (!h.contains('.')) return false;
  return !(h.endsWith('.local') || h.endsWith('.lan') || h.endsWith('.ts.net'));
}
