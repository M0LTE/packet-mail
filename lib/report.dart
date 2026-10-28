import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Where problem reports go.
const reportAddress = 'tom@m0lte.uk';
const reportSubject = 'Packet Mail problem report';
const reportFileName = 'packet-mail-traffic.jsonl';

/// The rolling log of BBS traffic. Opened in main; none in tests unless set.
final trafficLogProvider = Provider<TrafficLog?>((ref) => null);

/// App version, build, platform and OS version, one per line.
final appDetailsProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'Packet Mail ${info.version} (build ${info.buildNumber})\n'
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
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
  final String appDetails;
  final String attachment;
  final List<String> banners;

  String get body => '${description.trim().isEmpty ? '(No description)' : description.trim()}\n'
      '\n'
      '$appDetails\n'
      'BBS: ${banners.isEmpty ? 'none seen' : banners.join(' ')}\n'
      'Message text: ${includeMessageText ? 'included' : 'removed'}\n';
}

/// Sends a report. [origin] is where the share sheet points from on a tablet.
typedef ReportSender = Future<void> Function(ProblemReport report, Rect? origin);

final reportSenderProvider = Provider<ReportSender>((ref) => sendReport);

/// Opens an email to [reportAddress] with the traffic attached, or the share
/// sheet with the address in the text when no mail app can take attachments.
Future<void> sendReport(ProblemReport report, Rect? origin) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$reportFileName');
  await file.writeAsString(report.attachment);

  try {
    final can = await FlutterEmailSender.getCapabilities();
    if (can.canSend && can.supportsAttachments) {
      await FlutterEmailSender.send(Email(
        recipients: const [reportAddress],
        subject: reportSubject,
        body: report.body,
        attachmentPaths: [file.path],
      ));
      return;
    }
  } on FlutterEmailSenderException {
    // No mail app that takes attachments; share instead.
  }
  await SharePlus.instance.share(ShareParams(
    subject: reportSubject,
    text: 'Please email this to $reportAddress with the attached file.\n\n${report.body}',
    files: [XFile(file.path, mimeType: 'text/plain')],
    sharePositionOrigin: origin,
  ));
}
