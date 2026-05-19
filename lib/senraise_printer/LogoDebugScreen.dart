import 'dart:typed_data';

import 'package:collector_app/senraise_printer/LogoCacheService.dart';
import 'package:flutter/material.dart';

class LogoDebugScreen extends StatefulWidget {
  final String clientAlias;

  const LogoDebugScreen({super.key, required this.clientAlias});

  @override
  State<LogoDebugScreen> createState() => _LogoDebugScreenState();
}

class _LogoDebugScreenState extends State<LogoDebugScreen> {
  Uint8List? _imageBytes;
  String _status = '—';
  String _source = '—';
  String _size = '—';
  String _time = '—';
  bool _loading = false;
  bool _hasError = false;
  final List<String> _logs = [];

  void _log(String msg) {
    final ts = TimeOfDay.now().format(context);
    setState(() => _logs.insert(0, '[$ts] $msg'));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  Future<void> _fetchLogo() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _imageBytes = null;
      _status = '...';
      _source = '...';
      _size = '...';
      _time = '...';
    });

    _log('Testing alias: "${widget.clientAlias}"');
    final stopwatch = Stopwatch()..start();

    try {
      final bytes =
          await LogoCacheService.instance.getLogoBytes(widget.clientAlias);
      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      if (bytes == null) {
        _log('✗ No bytes returned (offline + no cache)');
        setState(() {
          _status = '✗ No image';
          _source = 'None';
          _time = '${elapsed}ms';
          _loading = false;
          _hasError = true;
        });
        return;
      }

      _log('✓ Got ${_formatBytes(bytes.length)} in ${elapsed}ms');

      setState(() {
        _imageBytes = bytes;
        _status = '✓ OK';
        _size = _formatBytes(bytes.length);
        _time = '${elapsed}ms';
        _loading = false;
      });
    } catch (e) {
      stopwatch.stop();
      _log('✗ Error: $e');
      setState(() {
        _status = '✗ Error';
        _time = '${stopwatch.elapsedMilliseconds}ms';
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _clearCache() async {
    await LogoCacheService.instance.clearCache(widget.clientAlias);
    _log('Cache cleared for "${widget.clientAlias}"');
    setState(() {
      _imageBytes = null;
      _status = '—';
      _source = '—';
      _size = '—';
      _time = '—';
      _hasError = false;
    });
  }

  Future<void> _preFetch() async {
    _log('Pre-fetching logo...');
    await LogoCacheService.instance.preFetchLogo(widget.clientAlias);
    _log('Pre-fetch complete');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logo Cache Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Client alias chip ──────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'client_alias: ${widget.clientAlias}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade800,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),

            // ── Action buttons ─────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _fetchLogo,
                  icon: const Icon(Icons.download),
                  label: const Text('Fetch Logo'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _preFetch,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Pre-Fetch'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Cache'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Metric cards ───────────────────────────────────────────────
            Row(
              children: [
                _metricCard('Status', _status,
                    color: _hasError ? Colors.red : Colors.green),
                const SizedBox(width: 8),
                _metricCard('Source', _source),
                const SizedBox(width: 8),
                _metricCard('Size', _size),
                const SizedBox(width: 8),
                _metricCard('Time', _time),
              ],
            ),
            const SizedBox(height: 20),

            // ── Preview ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator()
                  : _imageBytes != null
                      ? Column(
                          children: [
                            const SizedBox(height: 12),
                            Image.memory(
                              _imageBytes!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '✓ Image loaded — printer will receive this',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        )
                      : _hasError
                          ? Column(
                              children: [
                                const SizedBox(height: 24),
                                Icon(Icons.broken_image_outlined,
                                    size: 40, color: Colors.red.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  'Logo unavailable\nPrinter will skip the logo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red.shade400),
                                ),
                                const SizedBox(height: 24),
                              ],
                            )
                          : Text(
                              'Tap Fetch Logo to test',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500),
                            ),
            ),
            const SizedBox(height: 20),

            // ── Log ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Log',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _logs.isEmpty
                  ? Text('No logs yet',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => Text(
                        _logs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: _logs[i].contains('✗')
                              ? Colors.red.shade400
                              : _logs[i].contains('✓')
                                  ? Colors.green.shade600
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}