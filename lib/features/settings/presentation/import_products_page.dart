import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/application/data_tools_providers.dart';
import 'package:pos_system/features/settings/application/import_service.dart';

class ImportProductsPage extends ConsumerStatefulWidget {
  const ImportProductsPage({super.key});

  @override
  ConsumerState<ImportProductsPage> createState() => _ImportProductsPageState();
}

class _ImportProductsPageState extends ConsumerState<ImportProductsPage> {
  List<ProductImportRow> _rows = const [];
  String? _filePath;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(importServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import Products')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Select CSV/Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final path = await service.createTemplateCsv();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template saved: $path')));
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download Template CSV'),
                ),
                if (_rows.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _busy ? null : _confirmImport,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm Import'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_filePath != null) Align(alignment: Alignment.centerLeft, child: Text('File: $_filePath')),
            const SizedBox(height: 10),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('No file loaded'))
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = _rows[index];
                        return ListTile(
                          dense: true,
                          title: Text('${r.name} (${r.sku})'),
                          subtitle: Text('${r.category} • cost ${r.costPrice} • sale ${r.salePrice} • stock ${r.stock}'),
                          trailing: r.isValid
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : Tooltip(
                                  message: r.skipReason ?? 'Invalid row',
                                  child: const Icon(Icons.error, color: Colors.orange),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final service = ref.read(importServiceProvider);
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx']);
    if (picked == null || picked.files.single.path == null) return;

    setState(() {
      _busy = true;
      _filePath = picked.files.single.path;
    });

    try {
      final rows = await service.parseFile(_filePath!);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to parse file: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final service = ref.read(importServiceProvider);
    setState(() => _busy = true);
    try {
      final summary = await service.importRows(_rows);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Summary'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Added: ${summary.added}'),
                Text('Updated: ${summary.updated}'),
                Text('Skipped: ${summary.skipped}'),
                const SizedBox(height: 8),
                if (summary.skippedReasons.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: ListView(
                      children: summary.skippedReasons.map((s) => Text('- $s')).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

