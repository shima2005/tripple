import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/core/theme/app_colors.dart';

class PdfService {
  Future<void> printTripPdf(Trip trip, List<Object> scheduleItems) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.notoSansJPRegular();
    final fontBold = await PdfGoogleFonts.notoSansJPBold();
    
    final primaryColor = PdfColor.fromInt(AppColors.primary.value);
    final accentColor = PdfColor.fromInt(0xFFF5F5F5);

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pw.ImageProvider? coverImage;
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      try {
        final netImage = await networkImage(trip.coverImageUrl!);
        coverImage = netImage;
      } catch (e) {
      }
    }

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      trip.title,
                      style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '${DateFormat('yyyy/MM/dd').format(trip.startDate)} - ${DateFormat('MM/dd').format(trip.endDate)}',
                      style: const pw.TextStyle(fontSize: 16, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              if (coverImage != null)
                pw.Container(
                  height: 250,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    image: pw.DecorationImage(image: coverImage, fit: pw.BoxFit.cover),
                  ),
                ),
              pw.SizedBox(height: 30),

              pw.Text('Packing List', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Divider(color: primaryColor, thickness: 2),
              pw.SizedBox(height: 10),
              
              if (trip.checklist.isEmpty)
                pw.Text('No items', style: const pw.TextStyle(color: PdfColors.grey)),

              pw.Wrap(
                spacing: 20,
                runSpacing: 10,
                children: trip.checklist.map((item) {
                  return pw.Container(
                    width: 220,
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 14, height: 14,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: primaryColor, width: 1.5),
                            borderRadius: pw.BorderRadius.circular(2),
                            color: item.isChecked ? primaryColor : null,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            '${trip.title} - Itinerary',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
        build: (context) {
          return [
            pw.Text('Itinerary', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 20),
            
            ..._buildTimeline(scheduleItems, trip.startDate, primaryColor, accentColor),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'itinerary.pdf',
    );
  }

  List<pw.Widget> _buildTimeline(List<Object> items, DateTime startDate, PdfColor primary, PdfColor accent) {
    final widgets = <pw.Widget>[];
    int currentDay = -1;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      int dayIndex = 0;
      if (item is ScheduledItem) dayIndex = item.dayIndex;
      if (item is RouteItem) dayIndex = item.dayIndex;

      if (dayIndex != currentDay) {
        currentDay = dayIndex;
        final date = startDate.add(Duration(days: dayIndex));
        
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20, bottom: 10),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 6,
                  height: 30,
                  decoration: pw.BoxDecoration(
                    color: primary,
                    borderRadius: const pw.BorderRadius.horizontal(left: pw.Radius.circular(4)),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 30,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                    alignment: pw.Alignment.centerLeft,
                    decoration: pw.BoxDecoration(
                      color: accent,
                      borderRadius: const pw.BorderRadius.horizontal(right: pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'Day ${dayIndex + 1}  -  ${DateFormat('yyyy/MM/dd (E)').format(date)}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (item is ScheduledItem) {
        widgets.add(_buildScheduledRow(item, primary));
      } else if (item is RouteItem) {
        widgets.add(_buildRouteRow(item, primary));
      }
    }
    return widgets;
  }

  pw.Widget _buildScheduledRow(ScheduledItem item, PdfColor color) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Time
        pw.Container(
          width: 50,
          alignment: pw.Alignment.topRight,
          margin: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            DateFormat('HH:mm').format(item.time),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.SizedBox(width: 10),

        // Timeline (Circle + Line)
        pw.Container(
          width: 10, // ★ ここで幅を10に固定
          child: pw.Column(
            children: [
              pw.Container(
                width: 10, height: 10,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: color,
                ),
              ),
              pw.Container(width: 1.5, height: 35, color: PdfColors.grey300),
            ],
          ),
        ),
        pw.SizedBox(width: 12),

        // Content
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              if (item.notes != null && item.notes!.isNotEmpty)
                pw.Text(item.notes!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (item.cost != null && item.cost! > 0)
                pw.Text('Budget: ¥${item.cost!.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildRouteRow(RouteItem item, PdfColor color) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Time (Duration)
        pw.Container(
          width: 50,
          alignment: pw.Alignment.topRight,
          child: pw.Text(
            '${item.durationMinutes} min',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
          ),
        ),
        pw.SizedBox(width: 10),

        // Timeline (Line only)
        // ★ 修正: 幅を10に固定してScheduledItemの丸と中心軸を合わせる
        pw.Container(
          width: 10, 
          child: pw.Column(
            children: [
              pw.Container(width: 1.5, height: 20, color: PdfColors.grey300),
            ],
          ),
        ),
        pw.SizedBox(width: 12),

        // Content
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  item.transportType.name.toUpperCase(),
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}