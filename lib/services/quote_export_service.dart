import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/coordination_details.dart';
import '../models/quote_line.dart';

/// Creates portable quote documents without sending customer data to a server.
///
/// PDF and XLSX bytes are generated on the device. [savePdf] and [saveXlsx]
/// then use the native/browser save mechanism exposed by `file_saver`.
abstract final class QuoteExportService {
  static Future<Uint8List> buildPdf({
    required String quoteId,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
    DateTime? generatedAt,
  }) async {
    final createdAt = generatedAt ?? DateTime.now();
    final subtotal = _subtotal(lines);
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final document = pw.Document(
      title: 'Cotización $quoteId',
      author: 'Expresiones',
      subject: 'Cotización referencial de materiales',
      creator: 'Aplicación Expresiones',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Expresiones',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Materiales y detalles artesanales · Huancayo'),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7E7ED'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      quoteId,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Cotización referencial',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Producto',
              'Código',
              'Cantidad',
              'Precio unit.',
              'Importe',
            ],
            data: [
              for (final item in lines)
                [
                  _productDescription(item),
                  item.code ?? '',
                  item.line.quantity.toString(),
                  _money(item.unitPrice),
                  _money(item.total),
                ],
            ],
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#201A1B'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(7),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.4),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.4),
            },
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Subtotal',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _money(subtotal),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Coordinación',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _pdfDetail('Cliente', details.name.trim()),
          _pdfDetail('Teléfono', details.phone.trim()),
          _pdfDetail('Entrega', details.deliveryLabel),
          if (details.deliveryMethod == DeliveryMethod.shalom &&
              details.shalomAgencyId.isNotEmpty) ...[
            _pdfDetail('Agencia', details.shalomAgencyName),
            _pdfDetail('Ubicación', details.shalomAgencyLocality),
            _pdfDetail('Dirección', details.shalomAgencyAddress),
          ],
          _pdfDetail(
            'Fecha deseada',
            details.desiredDate == null
                ? 'Por coordinar'
                : DateFormat('dd/MM/yyyy').format(details.desiredDate!),
          ),
          if (details.note.trim().isNotEmpty)
            _pdfDetail('Nota', details.note.trim()),
          pw.SizedBox(height: 24),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F5F1EE'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Esta cotización no confirma el pedido. Stock, precio final, '
              'fecha y costo de envío se coordinan por WhatsApp.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Uint8List buildXlsx({
    required String quoteId,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
    DateTime? generatedAt,
  }) {
    final createdAt = generatedAt ?? DateTime.now();
    final workbook = Excel.createExcel();
    const sheetName = 'Cotización';
    final sheet = workbook[sheetName];
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.delete(defaultSheet);
    }
    workbook.setDefaultSheet(sheetName);

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.fromHexString('#201A1B'),
    );
    final labelStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#201A1B'),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#201A1B'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final moneyStyle = CellStyle(
      numberFormat: NumFormat.custom(formatCode: 'S/ #,##0.00'),
    );

    _setText(sheet, 0, 0, 'EXPRESIONES', style: titleStyle);
    _setText(sheet, 0, 1, 'Cotización referencial');
    _setText(sheet, 3, 0, 'Código', style: labelStyle);
    _setText(sheet, 4, 0, quoteId);
    _setText(sheet, 3, 1, 'Generada', style: labelStyle);
    _setText(sheet, 4, 1, DateFormat('dd/MM/yyyy HH:mm').format(createdAt));

    const tableRow = 3;
    const headers = [
      'Producto',
      'Código',
      'Cantidad',
      'Precio unitario',
      'Importe',
    ];
    for (var column = 0; column < headers.length; column++) {
      _setText(sheet, column, tableRow, headers[column], style: headerStyle);
    }

    for (var index = 0; index < lines.length; index++) {
      final item = lines[index];
      final row = tableRow + index + 1;
      _setText(sheet, 0, row, _productDescription(item));
      _setText(sheet, 1, row, item.code ?? '');
      _setInt(sheet, 2, row, item.line.quantity);
      _setDouble(sheet, 3, row, item.unitPrice, style: moneyStyle);
      _setDouble(sheet, 4, row, item.total, style: moneyStyle);
    }

    final totalRow = tableRow + lines.length + 2;
    _setText(sheet, 3, totalRow, 'Subtotal', style: labelStyle);
    _setDouble(sheet, 4, totalRow, _subtotal(lines), style: moneyStyle);

    final detailStart = totalRow + 3;
    final detailsRows = <(String, String)>[
      ('Cliente', details.name.trim()),
      ('Teléfono', details.phone.trim()),
      ('Entrega', details.deliveryLabel),
      if (details.deliveryMethod == DeliveryMethod.shalom &&
          details.shalomAgencyId.isNotEmpty) ...[
        ('Agencia Shalom', details.shalomAgencyName),
        ('Ubicación', details.shalomAgencyLocality),
        ('Dirección', details.shalomAgencyAddress),
      ],
      (
        'Fecha deseada',
        details.desiredDate == null
            ? 'Por coordinar'
            : DateFormat('dd/MM/yyyy').format(details.desiredDate!),
      ),
      if (details.note.trim().isNotEmpty) ('Nota', details.note.trim()),
    ];
    for (var index = 0; index < detailsRows.length; index++) {
      _setText(
        sheet,
        0,
        detailStart + index,
        detailsRows[index].$1,
        style: labelStyle,
      );
      _setText(sheet, 1, detailStart + index, detailsRows[index].$2);
    }

    sheet.setColumnWidth(0, 46);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 18);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo XLSX.');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<String?> savePdf({
    required String quoteId,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
  }) async {
    final bytes = await buildPdf(
      quoteId: quoteId,
      lines: lines,
      details: details,
    );
    return FileSaver.instance.saveToDownloads(
      name: _safeFileName('cotizacion_$quoteId'),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      subfolder: 'Expresiones',
    );
  }

  static Future<String?> saveXlsx({
    required String quoteId,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
  }) {
    final bytes = buildXlsx(quoteId: quoteId, lines: lines, details: details);
    return FileSaver.instance.saveToDownloads(
      name: _safeFileName('cotizacion_$quoteId'),
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
      subfolder: 'Expresiones',
    );
  }

  static double _subtotal(List<ResolvedQuoteLine> lines) =>
      lines.fold(0, (sum, item) => sum + item.total);

  static String _productDescription(ResolvedQuoteLine item) {
    final customization = item.line.customization.trim();
    return customization.isEmpty
        ? item.displayName
        : '${item.displayName}\n$customization';
  }

  static String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

  static String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static pw.Widget _pdfDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }

  static void _setText(
    Sheet sheet,
    int column,
    int row,
    String value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    if (style != null) cell.cellStyle = style;
  }

  static void _setInt(
    Sheet sheet,
    int column,
    int row,
    int value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = IntCellValue(value);
    if (style != null) cell.cellStyle = style;
  }

  static void _setDouble(
    Sheet sheet,
    int column,
    int row,
    double value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = DoubleCellValue(value);
    if (style != null) cell.cellStyle = style;
  }
}
