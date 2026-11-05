import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/geo_matrix.dart';
import 'services/spp_bluetooth_service.dart';
import 'widgets/contour_heatmap.dart';

void main() {
  runApp(const GeoPulseApp());
}

class GeoPulseApp extends StatelessWidget {
  const GeoPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoPulse - نبض الأرض',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1218),
        primaryColor: const Color(0xFF00E5FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B24),
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SppBluetoothService _btService = SppBluetoothService();
  bool _isConnecting = false;
  String _statusMessage = "Disconnected (Target: TEFSM_DEVICE)";

  Future<void> _handleConnect() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    setState(() {
      _isConnecting = true;
      _statusMessage = "Connecting to TEFSM_DEVICE...";
    });

    try {
      final bool connected = await _btService.connectToTefsmDevice();
      if (connected && mounted) {
        setState(() => _statusMessage = "Connected to TEFSM_DEVICE");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FilesScreen(btService: _btService),
          ),
        ).then((_) {
          setState(() {
            _statusMessage = _btService.isConnected
                ? "Connected to TEFSM_DEVICE"
                : "Disconnected";
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = "Connection Failed");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _runFieldDemo() {
    const String demoCsv = """
Line,Site,Frequency,Voltage
1,1,200,145.0
1,1,170,125.4
1,1,120,90.2
1,1,60,130.0
1,2,200,140.2
1,2,170,110.1
1,2,120,42.5
1,2,60,122.0
1,3,200,138.0
1,3,170,105.0
1,3,120,35.8
1,3,60,118.4
1,4,200,148.0
1,4,170,132.0
1,4,120,115.0
1,4,60,140.0
""";
    final matrix = GeoMatrix.fromCsvString(demoCsv);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(filename: "demo_survey.csv", matrix: matrix),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = _btService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text("GeoPulse | نبض الأرض"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: connected
                      ? Colors.green.withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: connected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: connected ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: connected ? Colors.greenAccent : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 240,
                height: 240,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: const Color(0xFF1A2332),
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 3),
                    elevation: 12,
                  ),
                  onPressed: _isConnecting ? null : _handleConnect,
                  child: _isConnecting
                      ? const CircularProgressIndicator(color: Color(0xFF00E5FF))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar, size: 64, color: Color(0xFF00E5FF)),
                            SizedBox(height: 12),
                            Text(
                              "Connect to Device",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "TEFSM_DEVICE",
                              style: TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _runFieldDemo,
                icon: const Icon(Icons.terrain, color: Colors.amberAccent),
                label: const Text(
                  "تشغيل نموذج محاكاة الخريطة (Demo)",
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilesScreen extends StatefulWidget {
  final SppBluetoothService btService;

  const FilesScreen({super.key, required this.btService});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<String> _csvFiles = [];
  final Map<String, File> _downloadedMap = {};
  bool _isLoadingList = true;
  String? _activeDownload;

  @override
  void initState() {
    super.initState();
    _loadFilesFromEsp32();
  }

  Future<void> _loadFilesFromEsp32() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await widget.btService.fetchFileList();
      if (mounted) setState(() => _csvFiles = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تعذر جلب القائمة: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _downloadCsv(String filename) async {
    setState(() => _activeDownload = filename);
    try {
      final File file = await widget.btService.downloadCsvFile(filename);
      if (mounted) {
        setState(() => _downloadedMap[filename] = file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم تنزيل $filename بنجاح"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل التنزيل: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _activeDownload = null);
    }
  }

  Future<void> _openGenerateMapScreen(String filename, File localFile) async {
    final String content = await localFile.readAsString();
    final GeoMatrix matrix = GeoMatrix.fromCsvString(content);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(filename: filename, matrix: matrix),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 Survey Files"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFilesFromEsp32,
          ),
        ],
      ),
      body: _isLoadingList
          ? const Center(child: CircularProgressIndicator())
          : _csvFiles.isEmpty
              ? const Center(child: Text("لا توجد ملفات CSV على الجهاز"))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _csvFiles.length,
                  itemBuilder: (context, index) {
                    final String fname = _csvFiles[index];
                    final bool isDownloaded = _downloadedMap.containsKey(fname);
                    final bool isDownloading = _activeDownload == fname;

                    return Card(
                      color: const Color(0xFF1A202C),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          isDownloaded ? Icons.check_circle : Icons.description,
                          color: isDownloaded ? Colors.greenAccent : const Color(0xFF00E5FF),
                        ),
                        title: Text(fname, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isDownloaded ? "جاهز لتوليد الخريطة" : "اضغط تنزيل لجلب البيانات"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download, color: Color(0xFF00E5FF)),
                              onPressed: isDownloading ? null : () => _downloadCsv(fname),
                            ),
                            if (isDownloaded)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text("Generate Map"),
                                onPressed: () => _openGenerateMapScreen(fname, _downloadedMap[fname]!),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final String filename;
  final GeoMatrix matrix;

  const MapScreen({super.key, required this.filename, required this.matrix});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _mapGenerated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("GeoPulse Map - Line ${widget.matrix.lineId}"),
      ),
      body: !_mapGenerated
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_on, size: 72, color: Color(0xFF00E5FF)),
                  const SizedBox(height: 16),
                  Text(
                    "الملف: ${widget.filename}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "عدد النقاط (Sites): ${widget.matrix.sites.length} | عدد الترددات: ${widget.matrix.frequencies.length}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    icon: const Icon(Icons.auto_graph),
                    label: const Text(
                      "Generate Map",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => setState(() => _mapGenerated = true),
                  ),
                ],
              ),
            )
          : ContourHeatmap(matrix: widget.matrix),
    );
  }
}