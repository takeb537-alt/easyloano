import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';

class PdfService {
  static final _fmt = NumberFormat('#,##0.00', 'en_IN');
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Future<String> generateLoanAgreement({
    required UserModel user,
    required LoanModel loan,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#1565C0');
    final lightBlue = PdfColor.fromHex('#E3F2FD');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── Header ──────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'EasyLoan',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'LOAN AGREEMENT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Loan ID & Date ──────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBlue,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Loan ID: ${loan.id}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Date: ${_dateFmt.format(loan.appliedDate)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Borrower Details ────────────────────
          _sectionTitle('BORROWER DETAILS', primaryColor),
          _infoRow('Full Name', user.fullName),
          _infoRow('Mobile Number', user.mobile),
          _infoRow('PAN Card', user.pan),
          _infoRow('Date of Birth', user.dob),
          _infoRow('UPI ID', user.upiId),
          pw.SizedBox(height: 16),

          // ── Loan Details ────────────────────────
          _sectionTitle('LOAN DETAILS', primaryColor),
          _infoRow('Principal Amount', '₹${_fmt.format(loan.amount)}'),
          _infoRow('Processing Fee', '₹${_fmt.format(loan.fee)}'),
          _infoRow('Total Disbursed', '₹${_fmt.format(loan.amount)}'),
          _infoRow('Total Repayable',
              '₹${_fmt.format(loan.amount + loan.fee)}'),
          _infoRow('Loan Tenure', '15 Days'),
          _infoRow('Applied Date', _dateFmt.format(loan.appliedDate)),
          _infoRow('Due Date', _dateFmt.format(loan.dueDate)),
          pw.SizedBox(height: 16),

          // ── Penalty Schedule ────────────────────
          _sectionTitle('PENALTY SCHEDULE', primaryColor),
          pw.Text(
            'A ONE-TIME penalty is applied if repayment is not made by the due date:',
            style: pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryColor),
                children: [
                  _tableHeader('Loan Amount'),
                  _tableHeader('Penalty'),
                ],
              ),
              _tableRow('₹100', '₹50'),
              _tableRow('₹200 – ₹500', '₹100'),
              _tableRow('₹600 – ₹1000', '₹200'),
              _tableRow('₹1100 – ₹1500', '₹250'),
              _tableRow('₹1600 – ₹2000', '₹300'),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Terms ───────────────────────────────
          _sectionTitle('TERMS & CONDITIONS', primaryColor),
          _termPoint(
              '1. The borrower agrees to repay ₹${_fmt.format(loan.amount + loan.fee)} by ${_dateFmt.format(loan.dueDate)}.'),
          _termPoint(
              '2. A one-time penalty will be levied if payment is not received by the due date.'),
          _termPoint(
              '3. EasyLoan reserves the right to report defaults to credit bureaus.'),
          _termPoint(
              '4. Partial payments are accepted; remaining balance with penalty must be cleared within 7 days.'),
          _termPoint(
              '5. This agreement is legally binding under Indian Contract Act, 1872.'),
          _termPoint(
              '6. Disputes shall be resolved via arbitration in the jurisdiction of India.'),
          pw.SizedBox(height: 20),

          // ── Digital Signature ───────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DIGITAL SIGNATURE',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
                pw.SizedBox(height: 8),
                pw.Text('I, ${user.fullName}, hereby agree to all the terms '
                    'and conditions stated in this loan agreement.'),
                pw.SizedBox(height: 8),
                pw.Text(
                    'Signed by: ${user.fullName}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Timestamp: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}'),
                pw.Text('Loan ID: ${loan.id}'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Footer ──────────────────────────────
          pw.Divider(),
          pw.Text(
            'EasyLoan • Instant Emergency Loans • This is a computer-generated document.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/EasyLoan_${loan.id}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  // Helpers
  static pw.Widget _sectionTitle(String title, PdfColor color) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: color)),
          pw.Divider(color: color),
          pw.SizedBox(height: 4),
        ],
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          children: [
            pw.SizedBox(
                width: 140,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

  static pw.Widget _termPoint(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  static pw.TableRow _tableRow(String col1, String col2) => pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(col1, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(col2, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      );

  static pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white),
        ),
      );
}
