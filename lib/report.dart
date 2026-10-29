import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Where "Report a problem" sends reports: the feedback receiver in
/// feedback-receiver/, hosted as described in docs/deployment.md.
const reportEndpoint = 'https://packet-mail.m0lte.uk/v1/report';

/// Where a report shared by hand should go, if sending fails.
const reportAddress = 'app-support@tomfanning.name';
const reportSubject = 'Packet Mail problem report';
const reportFileName = 'packet-mail-traffic.jsonl';

/// The rolling log of BBS traffic. Opened in main; none in tests unless set.
final trafficLogProvider = Provider<TrafficLog?>((ref) => null);

/// The app and phone software versions a report carries.
class AppDetails {
  const AppDetails({required this.version, required this.build, required this.platform, required this.osVersion});

  final String version;
  final String build;
  final String platform;
  final String osVersion;

  @override
  String toString() => 'Packet Mail $version (build $build)\n$platform $osVersion';
}

final appDetailsProvider = FutureProvider<AppDetails>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppDetails(
    version: info.version,
    build: info.buildNumber,
    platform: Platform.operatingSystem,
    osVersion: Platform.operatingSystemVersion,
  );
});

/// A problem report, ready to preview or send.
class ProblemReport {
  ProblemReport({
    required this.description,
    required this.includeMessageText,
    required this.appDetails,
    required List<LoggedSession> sessions,
  })  : attachment = reportTraffic(sessions, includeMessageText: includeMessageText),
        banners = bbsBanners(sessions);

  final String description;
  final bool includeMessageText;
  final AppDetails appDetails;

  /// The traffic, in the recording format.
  final String attachment;
  final List<String> banners;

  String get body => '${description.trim().isEmpty ? '(No description)' : description.trim()}\n'
      '\n'
      '$appDetails\n'
      'BBS: ${banners.isEmpty ? 'none seen' : banners.join(' ')}\n'
      'Message text: ${includeMessageText ? 'included' : 'removed'}\n';

  /// What is posted to [reportEndpoint].
  Map<String, Object> toJson() => {
        'description': description.trim(),
        'includeMessageText': includeMessageText,
        'appVersion': appDetails.version,
        'build': appDetails.build,
        'platform': appDetails.platform,
        'osVersion': appDetails.osVersion,
        'bbsBanners': banners,
        'traffic': attachment,
      };
}

/// Sends a report to the developer. Throws if it wasn't accepted.
typedef ReportSender = Future<void> Function(ProblemReport report);

final reportSenderProvider = Provider<ReportSender>((ref) => postReport);

/// Shares a report by hand. [origin] is where the share sheet points from
/// on a tablet.
typedef ReportSharer = Future<void> Function(ProblemReport report, Rect? origin);

final reportSharerProvider = Provider<ReportSharer>((ref) => shareReport);

/// Thrown when the receiver can't be reached or turns a report down.
class ReportNotSent implements Exception {
  ReportNotSent(this.reason);
  final String reason;
  @override
  String toString() => 'ReportNotSent: $reason';
}

Future<void> postReport(ProblemReport report) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(Uri.parse(reportEndpoint)).timeout(const Duration(seconds: 15));
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(report.toJson())));
    final response = await request.close().timeout(const Duration(seconds: 45));
    await response.drain<void>();
    if (response.statusCode != 200) throw ReportNotSent('HTTP ${response.statusCode}');
  } on IOException catch (e) {
    throw ReportNotSent(e.toString());
  } finally {
    client.close(force: true);
  }
}

/// Opens the share sheet with the traffic attached and the subject set.
/// The user picks their own app and pastes [reportAddress].
Future<void> shareReport(ProblemReport report, Rect? origin) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$reportFileName');
  await file.writeAsString(report.attachment);
  await SharePlus.instance.share(ShareParams(
    subject: reportSubject,
    text: report.body,
    files: [XFile(file.path, mimeType: 'text/plain')],
    sharePositionOrigin: origin,
  ));
}
