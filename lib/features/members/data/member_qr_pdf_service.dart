import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/attendance/member_qr_payload.dart';
import '../../../data/models/models.dart';

class MemberQrPdfService {
  static const _fontAsset = 'assets/fonts/Cairo.ttf';

  Future<Uint8List> build({required List<MemberEntity> members}) async {
    final activeMembers = members.where((member) => member.isActive).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (activeMembers.isEmpty) {
      throw Exception('لا يوجد أعضاء نشطون لإنشاء ملف QR.');
    }

    final fontData = await rootBundle.load(_fontAsset);
    final arabicFont = pw.Font.ttf(fontData);
    final document = pw.Document(
      title: 'LinkApp Member QR Cards',
      author: 'LinkApp',
      creator: 'LinkApp',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'بطاقات حضور الأعضاء',
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1F3B68'),
                  ),
                ),
                pw.Text(
                  'LinkApp · ${activeMembers.length}',
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: arabicFont,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activeMembers
                .map((member) => _buildMemberCard(member, arabicFont))
                .toList(),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildMemberCard(MemberEntity member, pw.Font font) {
    final payload = MemberQrPayload(
      memberId: member.id,
      churchId: member.churchId,
    ).encode();
    final code = member.code?.trim();

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: 255,
        height: 230,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColor.fromHex('#DCE4EE')),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: payload,
              width: 130,
              height: 130,
              drawText: false,
              color: PdfColor.fromHex('#0F172A'),
            ),
            pw.SizedBox(height: 9),
            pw.Text(
              member.fullName,
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
            if (code != null && code.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'كود العضو: $code',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
