import 'package:csv/csv.dart';

class GeoMatrix {
  final int lineId;
  final List<int> sites;           // المحور الأفقي X (نقاط القياس)
  final List<double> frequencies;  // المحور الرأسي Y (الترددات معكوسة: الأعمق في الأسفل)
  final List<List<double>> zValues;// قيم الجهد [row_freq][col_site]
  final double minVoltage;
  final double maxVoltage;

  GeoMatrix({
    required this.lineId,
    required this.sites,
    required this.frequencies,
    required this.zValues,
    required this.minVoltage,
    required this.maxVoltage,
  });

  factory GeoMatrix.fromCsvString(String rawCsv) {
    final cleanCsv = rawCsv.replaceAll('\r\n', '\n').trim();
    final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(cleanCsv);

    final Set<int> uniqueSites = {};
    final Set<double> uniqueFreqs = {};
    final Map<String, double> lookup = {};

    int detectedLine = 1;
    double minV = double.infinity;
    double maxV = double.negativeInfinity;

    for (final row in rows) {
      if (row.length < 4) continue;
      if (row[0].toString().toLowerCase().contains('line')) continue;

      try {
        detectedLine = int.parse(row[0].toString().trim());
        final int site = int.parse(row[1].toString().trim());
        final double freq = double.parse(row[2].toString().trim());
        final double voltage = double.parse(row[3].toString().trim());

        uniqueSites.add(site);
        uniqueFreqs.add(freq);
        lookup['${freq}_$site'] = voltage;

        if (voltage < minV) minV = voltage;
        if (voltage > maxV) maxV = voltage;
      } catch (_) {
        continue;
      }
    }

    final List<int> sortedSites = uniqueSites.toList()..sort();

    // عكس محور Y: الترددات الأعلى في الأعلى، والترددات المنخفضة (الأعمق) في أسفل الخريطة
    final List<double> sortedFreqs = uniqueFreqs.toList()
      ..sort((a, b) => b.compareTo(a));

    final List<List<double>> matrix = List.generate(
      sortedFreqs.length,
      (fIdx) => List.generate(
        sortedSites.length,
        (sIdx) {
          final key = '${sortedFreqs[fIdx]}_${sortedSites[sIdx]}';
          return lookup[key] ?? (minV != double.infinity ? minV : 0.0);
        },
      ),
    );

    if (minV == double.infinity) {
      minV = 0.0;
      maxV = 100.0;
    }

    return GeoMatrix(
      lineId: detectedLine,
      sites: sortedSites,
      frequencies: sortedFreqs,
      zValues: matrix,
      minVoltage: minV,
      maxVoltage: maxV,
    );
  }
}