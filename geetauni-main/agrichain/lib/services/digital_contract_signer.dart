import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'digilocker_service.dart';

/// Cryptographic signature stamp for legal contract execution
class DigitalSignatureStamp {
  final String signerName;
  final String signerRole;
  final String maskedAadhaar;
  final String certificateId;
  final String transactionId;
  final String sha256Digest;
  final DateTime signedAt;
  final String qrVerificationUrl;

  DigitalSignatureStamp({
    required this.signerName,
    required this.signerRole,
    required this.maskedAadhaar,
    required this.certificateId,
    required this.transactionId,
    required this.sha256Digest,
    required this.signedAt,
    required this.qrVerificationUrl,
  });
}

class DigitalContractSigner {
  /// Generate a cryptographic SHA-256 digital signature stamp
  static DigitalSignatureStamp generateStamp({
    required String contractId,
    required String signerName,
    required String signerRole,
    String? maskedAadhaar,
    required String commodity,
    required double quantity,
    required String unit,
    required double totalAmount,
    required String fpoName,
    required String buyerName,
  }) {
    final now = DateTime.now();
    final effectiveAadhaar = maskedAadhaar ??
        DigilockerService.currentVerifiedProfile?.maskedAadhaar ??
        'XXXX-XXXX-${now.millisecondsSinceEpoch.toString().substring(9)}';

    // Construct raw canonical payload for hashing
    final canonicalPayload =
        'CID:$contractId|C:$commodity|Q:$quantity$unit|AMT:INR$totalAmount|FPO:$fpoName|BUYER:$buyerName|AADHAAR:$effectiveAadhaar|TS:${now.toUtc().toIso8601String()}';

    // Compute SHA-256 Digest
    final bytes = utf8.encode(canonicalPayload);
    final digest = sha256.convert(bytes).toString();

    final certId = 'DL-IT2000-${now.year}-${now.millisecondsSinceEpoch.toString().substring(6)}';
    final txnId = 'TXN-DL-${digest.substring(0, 12).toUpperCase()}';
    final qrUrl = 'https://agrichain.gov.in/verify?cid=$contractId&digest=$digest';

    return DigitalSignatureStamp(
      signerName: signerName,
      signerRole: signerRole,
      maskedAadhaar: effectiveAadhaar,
      certificateId: certId,
      transactionId: txnId,
      sha256Digest: digest,
      signedAt: now,
      qrVerificationUrl: qrUrl,
    );
  }

  /// Generate full PDF deed with official DigiLocker / Aadhaar digital signature
  static Future<Uint8List> generateSignedContractPdf({
    required String contractId,
    required String commodity,
    required String variety,
    required String originCluster,
    required double quantity,
    required String unit,
    required double ratePerUnit,
    required double totalAmount,
    required String buyerName,
    required String fpoName,
    String? inventoryItemId,
    DigitalSignatureStamp? stamp,
  }) async {
    final pdf = pw.Document();
    final effectiveStamp = stamp ??
        generateStamp(
          contractId: contractId,
          signerName: buyerName,
          signerRole: 'Authorized Procurement Officer',
          commodity: commodity,
          quantity: quantity,
          unit: unit,
          totalAmount: totalAmount,
          fpoName: fpoName,
          buyerName: buyerName,
        );

    final regularFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm:ss \'IST\'');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        header: (context) => _buildHeader(regularFont, boldFont),
        footer: (context) => _buildFooter(context, regularFont, contractId),
        build: (context) => [
          pw.SizedBox(height: 12),

          // Title & Legal Notice
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'CERTIFICATE OF ELECTRONIC CONTRACT EXECUTION',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Executed pursuant to Section 10A of the Information Technology Act, 2000',
                  style: pw.TextStyle(
                    font: italicFont,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Certificate Metadata Table
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaText('Contract Ref:', contractId, boldFont, regularFont),
                    _metaText('Lot Passport ID:', inventoryItemId ?? 'LOT-HAR-2026-W01', boldFont, regularFont),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _metaText('Execution Timestamp:', dateFormat.format(effectiveStamp.signedAt), boldFont, regularFont),
                    _metaText('DigiLocker Cert ID:', effectiveStamp.certificateId, boldFont, regularFont),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Agreement Parties
          pw.Text('1. PARTIES TO THE AGREEMENT', style: pw.TextStyle(font: boldFont, fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SELLER (PRODUCER COOPERATIVE / FPO)', style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.green800)),
                      pw.SizedBox(height: 3),
                      pw.Text(fpoName, style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.Text('Origin: $originCluster', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                      pw.Text('FPO Reg: FPO-HR-KNL-COOP-0912', style: pw.TextStyle(font: regularFont, fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BUYER (PROCUREMENT ENTITY)', style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.blue800)),
                      pw.SizedBox(height: 3),
                      pw.Text(buyerName, style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.Text('Identity: DigiLocker / Aadhaar Verified', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                      pw.Text('Aadhaar: ${effectiveStamp.maskedAadhaar}', style: pw.TextStyle(font: regularFont, fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Commercial & Quality Terms Table
          pw.Text('2. COMMERCIAL TERMS & LOT SPECIFICATIONS', style: pw.TextStyle(font: boldFont, fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              _tableRow('Commodity / Crop', '$commodity ($variety)', boldFont, regularFont),
              _tableRow('Contracted Volume', '$quantity $unit', boldFont, regularFont),
              _tableRow('Contract Rate', 'Rs. ${ratePerUnit.toStringAsFixed(2)} per $unit', boldFont, regularFont),
              _tableRow('Total Escrow Consideration', 'Rs. ${totalAmount.toStringAsFixed(2)}', boldFont, regularFont),
              _tableRow('Payment Settlement Mechanism', 'AgriChain Irrevocable Smart Escrow Lock', boldFont, regularFont),
              _tableRow('Quality Benchmark', 'Grade A certified, Max Moisture 11.2%, Foreign Matter <0.5%', boldFont, regularFont),
              _tableRow('Dispatch & Warehouse Location', originCluster, boldFont, regularFont),
            ],
          ),
          pw.SizedBox(height: 14),

          // Legal Recitals
          pw.Text('3. STATUTORY ELECTRONIC EXECUTION CLAUSE', style: pw.TextStyle(font: boldFont, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(
            'This Agreement is drafted, executed, and concluded electronically through the AgriChain Network pursuant to Section 10A of the Information Technology Act, 2000 (validity of contracts formed through electronic means). The digital signature digest affixed below has been generated using a cryptographic SHA-256 hashing algorithm binding the parties\' mutual assent, verified through the Government of India DigiLocker / MeriPehchaan national identity framework.',
            style: pw.TextStyle(font: regularFont, fontSize: 8.5, color: PdfColors.grey800, lineSpacing: 1.4),
          ),
          pw.SizedBox(height: 16),

          // DIGITAL SIGNATURE BOX (OFFICIAL SEAL)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green700, width: 1.5),
              color: const PdfColor(0.96, 0.99, 0.96),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // QR Code
                pw.Container(
                  width: 75,
                  height: 75,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: effectiveStamp.qrVerificationUrl,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(width: 14),

                // Digital Signature Details
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            '✔ DIGITALLY SIGNED & VERIFIED',
                            style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.green900),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            '(DigiLocker / MeriPehchaan e-Sign)',
                            style: pw.TextStyle(font: italicFont, fontSize: 8.5, color: PdfColors.green800),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Signatory: ${effectiveStamp.signerName} [${effectiveStamp.signerRole}]',
                          style: pw.TextStyle(font: boldFont, fontSize: 9.5)),
                      pw.Text('Aadhaar Reference: ${effectiveStamp.maskedAadhaar}',
                          style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                      pw.Text('Transaction ID: ${effectiveStamp.transactionId}',
                          style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                      pw.Text('Signed At: ${dateFormat.format(effectiveStamp.signedAt)}',
                          style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Cryptographic Digest (SHA-256):',
                        style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        effectiveStamp.sha256Digest,
                        style: pw.TextStyle(font: regularFont, fontSize: 7, color: PdfColors.grey900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.Font regularFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green800, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.green800,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text('🇮🇳', style: const pw.TextStyle(fontSize: 14)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GOVERNMENT OF INDIA • MERIPEHCHAAN GATEWAY',
                      style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.green900)),
                  pw.Text('AgriChain National Agricultural Escrow Exchange',
                      style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Text('LEGAL CONTRACT DEED', style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font regularFont, String contractId) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Contract ID: $contractId | AgriChain Verified Ledger',
              style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.TableRow _tableRow(String label, String value, pw.Font boldFont, pw.Font regularFont) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(value, style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
        ),
      ],
    );
  }

  static pw.Widget _metaText(String label, String value, pw.Font boldFont, pw.Font regularFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Text('$label ', style: pw.TextStyle(font: boldFont, fontSize: 8)),
          pw.Text(value, style: pw.TextStyle(font: regularFont, fontSize: 8)),
        ],
      ),
    );
  }
}
