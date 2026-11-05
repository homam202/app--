import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:path_provider/path_provider.dart';

class SppBluetoothService {
  static const String targetDeviceName = "TEFSM_DEVICE";

  BluetoothConnection? _connection;
  final StringBuffer _buffer = StringBuffer();
  Completer<String>? _responseCompleter;
  String _expectedTerminator = "";

  bool get isConnected => _connection != null && _connection!.isConnected;

  Future<bool> connectToTefsmDevice() async {
    final List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    BluetoothDevice? targetDevice;
    for (final d in bondedDevices) {
      if (d.name == targetDeviceName) {
        targetDevice = d;
        break;
      }
    }

    if (targetDevice == null) {
      throw Exception("لم يتم العثور على جهاز مقترن باسم $targetDeviceName. يرجى الاقتران من إعدادات البلوتوث أولاً.");
    }

    _connection = await BluetoothConnection.toAddress(targetDevice.address);

    _connection!.input!.listen(
      _onDataReceived,
      onDone: () => disconnect(),
      onError: (_) => disconnect(),
    );

    return isConnected;
  }

  void _onDataReceived(Uint8List data) {
    final String chunk = utf8.decode(data, allowMalformed: true);
    _buffer.write(chunk);

    final String currentContent = _buffer.toString();
    if (_expectedTerminator.isNotEmpty && currentContent.contains(_expectedTerminator)) {
      final String payload = currentContent.split(_expectedTerminator).first;
      _buffer.clear();
      _expectedTerminator = "";
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.complete(payload);
      }
    }
  }

  Future<String> _sendCommand({
    required String command,
    required String terminator,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!isConnected) throw Exception("الجهاز غير متصل");

    _buffer.clear();
    _expectedTerminator = terminator;
    _responseCompleter = Completer<String>();

    _connection!.output.add(Uint8List.fromList(utf8.encode(command)));
    await _connection!.output.allSent;

    return _responseCompleter!.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException("انتهت مهلة الاستجابة من TEFSM_DEVICE"),
    );
  }

  Future<List<String>> fetchFileList() async {
    final String rawList = await _sendCommand(
      command: "LIST\n",
      terminator: "END_LIST\n",
    );

    return rawList
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.endsWith('.csv'))
        .toList();
  }

  Future<File> downloadCsvFile(String filename) async {
    final String csvData = await _sendCommand(
      command: "GET $filename\n",
      terminator: "END_FILE\n",
      timeout: const Duration(seconds: 60),
    );

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File localFile = File('${appDocDir.path}/$filename');
    await localFile.writeAsString(csvData);
    return localFile;
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}