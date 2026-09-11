import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../services/digital_contract_signer.dart';

class SignedContractPdfScreen extends StatelessWidget {
  final String contractId;
  final String commodity;
  final String variety;
  final String originCluster;
  final double quantity;
  final String unit;
  final double ratePerUnit;
  final double totalAmount;
  final String buyerName;
  final String fpoName;
  final String? inventoryItemId;
  final DigitalSignatureStamp? stamp;

  const SignedContractPdfScreen({
    super.key,
    required this.contractId,
    required this.commodity,
    required this.variety,
    required this.originCluster,
    required this.quantity,
    required this.unit,
    required this.ratePerUnit,
    required this.totalAmount,
    required this.buyerName,
    required this.fpoName,
    this.inventoryItemId,
    this.stamp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Contract Deed',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.verified, size: 13, color: Color(0xFF4ADE80)),
                const SizedBox(width: 4),
                Text(
                  'Section 10A IT Act 2000 Verified • DigiLocker e-Signed',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4ADE80),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: (format) => DigitalContractSigner.generateSignedContractPdf(
          contractId: contractId,
          commodity: commodity,
          variety: variety,
          originCluster: originCluster,
          quantity: quantity,
          unit: unit,
          ratePerUnit: ratePerUnit,
          totalAmount: totalAmount,
          buyerName: buyerName,
          fpoName: fpoName,
          inventoryItemId: inventoryItemId,
          stamp: stamp,
        ),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'AgriChain_Signed_Contract_$contractId.pdf',
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: (context, layout, format) async {
              final pdfBytes = await DigitalContractSigner.generateSignedContractPdf(
                contractId: contractId,
                commodity: commodity,
                variety: variety,
                originCluster: originCluster,
                quantity: quantity,
                unit: unit,
                ratePerUnit: ratePerUnit,
                totalAmount: totalAmount,
                buyerName: buyerName,
                fpoName: fpoName,
                inventoryItemId: inventoryItemId,
                stamp: stamp,
              );
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: 'AgriChain_Signed_Contract_$contractId.pdf',
              );
            },
          ),
        ],
      ),
    );
  }
}
