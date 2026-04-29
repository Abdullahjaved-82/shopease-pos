import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/invoices/application/currency_service.dart';
import 'package:pos_system/features/invoices/application/invoice_pdf_service.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:printing/printing.dart';

class InvoiceFormPage extends ConsumerStatefulWidget {
  const InvoiceFormPage({super.key, this.invoiceId, this.docType = DocumentType.invoice});

  final int? invoiceId;
  final DocumentType docType;

  @override
  ConsumerState<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends ConsumerState<InvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberCtrl = TextEditingController();
  final _billToNameCtrl = TextEditingController();
  final _billToAddressCtrl = TextEditingController();
  final _billToPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _exchangeRateCtrl = TextEditingController(text: '1');

  final List<_InvoiceItemDraft> _items = [
    _InvoiceItemDraft(),
  ];

  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _expiryDate;
  int? _customerId;
  String _currencyCode = 'PKR';
  String _invoiceLanguage = 'en';
  InvoiceTemplate _invoiceTemplate = InvoiceTemplate.modern;
  bool _makeRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;
  DateTime _recurringStartDate = DateTime.now();
  late DocumentType _docType;

  String _discountMode = 'percent';
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _docType = widget.docType;
    _bootstrap();
  }

  @override
  void dispose() {
    _invoiceNumberCtrl.dispose();
    _billToNameCtrl.dispose();
    _billToAddressCtrl.dispose();
    _billToPhoneCtrl.dispose();
    _notesCtrl.dispose();
    _termsCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(invoiceRepositoryProvider);
    final settings = ref.read(shopSettingsControllerProvider).valueOrNull ?? ShopSettings.defaults();
    if (widget.invoiceId == null) {
      _invoiceNumberCtrl.text = await repo.getNextDocumentNumber(widget.docType);
      _currencyCode = settings.currency;
      _invoiceLanguage = settings.defaultInvoiceLanguage;
      _invoiceTemplate = InvoiceTemplate.fromDb(settings.defaultInvoiceTemplate);
      _exchangeRateCtrl.text = _currencyCode == 'PKR' ? '1' : '278';
      _dueDate = widget.docType == DocumentType.quotation ? null : DateTime.now().add(const Duration(days: 30));
      _expiryDate = widget.docType == DocumentType.quotation ? DateTime.now().add(const Duration(days: 15)) : null;
      return;
    }

    final invoice = await repo.getInvoiceById(widget.invoiceId!);
    if (invoice == null) return;
    _docType = DocumentType.fromDb(invoice.docType);
    final items = await repo.getItemsByInvoiceId(invoice.id);

    _invoiceNumberCtrl.text = invoice.invoiceNumber;
    _issueDate = invoice.issueDate;
    _dueDate = invoice.dueDate;
    _expiryDate = invoice.expiryDate;
    _customerId = invoice.customerId;
    _billToNameCtrl.text = invoice.billToName ?? '';
    _billToAddressCtrl.text = invoice.billToAddress ?? '';
    _billToPhoneCtrl.text = invoice.billToPhone ?? '';
    _notesCtrl.text = invoice.notes ?? '';
    _termsCtrl.text = invoice.terms ?? '';
    _currencyCode = invoice.currencyCode;
    _invoiceLanguage = invoice.invoiceLanguage;
    _invoiceTemplate = InvoiceTemplate.fromDb(invoice.template);
    _exchangeRateCtrl.text = invoice.exchangeRateToPkr.toStringAsFixed(4);
    _discountCtrl.text = invoice.discountAmount.toStringAsFixed(2);
    _discountMode = 'fixed';
    _taxCtrl.text = invoice.subtotal > 0 ? ((invoice.taxAmount / invoice.subtotal) * 100).toStringAsFixed(2) : '0';

    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..addAll(
        items
            .map(
              (item) => _InvoiceItemDraft(
                description: item.description,
                qty: item.qty.toString(),
                unitPrice: item.unitPrice.toString(),
              ),
            )
            .toList(),
      );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersRepo = ref.watch(customersRepositoryProvider);
    final subtotal = _subtotal;
    final discountAmount = _discountAmount(subtotal);
    final taxAmount = _taxAmount(subtotal - discountAmount);
    final total = (subtotal - discountAmount + taxAmount).clamp(0, double.maxFinite).toDouble();

    final title = widget.invoiceId == null ? 'New ${_docType.title}' : 'Edit ${_docType.title}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _invoiceNumberCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice Number'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _dateField(
                    label: 'Issue Date',
                    value: _issueDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _issueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _issueDate = picked);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _dateField(
                    label: _docType == DocumentType.quotation ? 'Expiry Date' : 'Due Date',
                    value: _docType == DocumentType.quotation ? _expiryDate : _dueDate,
                    nullable: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: (_docType == DocumentType.quotation ? _expiryDate : _dueDate) ?? _issueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          if (_docType == DocumentType.quotation) {
                            _expiryDate = picked;
                          } else {
                            _dueDate = picked;
                          }
                        });
                      }
                    },
                    onClear: () => setState(() {
                      if (_docType == DocumentType.quotation) {
                        _expiryDate = null;
                      } else {
                        _dueDate = null;
                      }
                    }),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('currency-$_currencyCode'),
                    initialValue: _currencyCode,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: CurrencyService.supported
                        .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.code} (${c.symbol})')))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _currencyCode = value;
                        if (_currencyCode == 'PKR') {
                          _exchangeRateCtrl.text = '1';
                        }
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: _exchangeRateCtrl,
                    decoration: const InputDecoration(labelText: 'Rate to PKR (1 unit = ?)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('lang-$_invoiceLanguage'),
                    initialValue: _invoiceLanguage,
                    decoration: const InputDecoration(labelText: 'PDF Language'),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    ],
                    onChanged: (value) => setState(() => _invoiceLanguage = value ?? 'en'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<InvoiceTemplate>(
                    key: ValueKey('template-${_invoiceTemplate.dbValue}'),
                    initialValue: _invoiceTemplate,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: InvoiceTemplate.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _invoiceTemplate = value ?? InvoiceTemplate.modern),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Customer>>(
              future: customersRepo.getAll(),
              builder: (context, snapshot) {
                final customers = snapshot.data ?? const [];
                return DropdownButtonFormField<int?>(
                  initialValue: _customerId,
                  decoration: const InputDecoration(labelText: 'Bill To Customer (optional)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Manual Entry')),
                    ...customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (value) {
                    setState(() => _customerId = value);
                    if (value != null) {
                      final customer = customers.firstWhere((c) => c.id == value);
                      _billToNameCtrl.text = customer.name;
                      _billToAddressCtrl.text = customer.address ?? '';
                      _billToPhoneCtrl.text = customer.phone ?? '';
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _billToNameCtrl, decoration: const InputDecoration(labelText: 'Bill To Name')),
            const SizedBox(height: 8),
            TextFormField(controller: _billToAddressCtrl, decoration: const InputDecoration(labelText: 'Bill To Address')),
            const SizedBox(height: 8),
            TextFormField(controller: _billToPhoneCtrl, decoration: const InputDecoration(labelText: 'Bill To Phone')),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_InvoiceItemDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (_items.length * 104).clamp(140, 380).toDouble(),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final row = _items[index];
                  return Card(
                    key: ValueKey(row.key),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_indicator),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: row.descriptionCtrl,
                              decoration: const InputDecoration(labelText: 'Description'),
                              validator: (v) {
                                if (_items.length == 1 && (v == null || v.trim().isEmpty)) {
                                  return 'Required';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: row.qtyCtrl,
                              decoration: const InputDecoration(labelText: 'Qty'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: row.unitPriceCtrl,
                              decoration: const InputDecoration(labelText: 'Unit Price'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: Text(row.lineTotal.toStringAsFixed(2), textAlign: TextAlign.right),
                          ),
                          IconButton(
                            onPressed: _items.length == 1
                                ? null
                                : () {
                                    setState(() {
                                      row.dispose();
                                      _items.removeAt(index);
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _discountMode,
                    decoration: const InputDecoration(labelText: 'Discount Type'),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('%')),
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                    ],
                    onChanged: (value) => setState(() => _discountMode = value ?? 'percent'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _discountCtrl,
                    decoration: InputDecoration(labelText: _discountMode == 'percent' ? 'Discount %' : 'Discount Amount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _taxCtrl,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 300,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _sumRow('Subtotal', subtotal),
                        _sumRow('Discount', discountAmount),
                        _sumRow('Tax', taxAmount),
                        const Divider(),
                        _sumRow('Total', total, bold: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            const SizedBox(height: 8),
            TextFormField(controller: _termsCtrl, decoration: const InputDecoration(labelText: 'Payment Terms'), maxLines: 3),
            if (_docType == DocumentType.invoice) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _makeRecurring,
                title: const Text('Make Recurring'),
                onChanged: (v) => setState(() => _makeRecurring = v),
              ),
              if (_makeRecurring)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<RecurringFrequency>(
                        initialValue: _recurringFrequency,
                        key: ValueKey('freq-${_recurringFrequency.dbValue}'),
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: RecurringFrequency.values
                            .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _recurringFrequency = v ?? RecurringFrequency.monthly),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _dateField(
                        label: 'Recurring Start Date',
                        value: _recurringStartDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _recurringStartDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _recurringStartDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(status: 'draft', generatePdf: false),
                  child: const Text('Save as Draft'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(status: 'sent', generatePdf: true),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required Future<void> Function() onTap,
    bool nullable = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: nullable && value != null
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                )
              : const Icon(Icons.calendar_month),
        ),
        child: Text(value == null ? '-' : DateFormat('dd MMM yyyy').format(value)),
      ),
    );
  }

  Widget _sumRow(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(2), style: style),
        ],
      ),
    );
  }

  double get _subtotal => _items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double _discountAmount(double subtotal) {
    final raw = double.tryParse(_discountCtrl.text) ?? 0;
    if (_discountMode == 'percent') {
      return (subtotal * (raw / 100)).clamp(0, subtotal).toDouble();
    }
    return raw.clamp(0, subtotal).toDouble();
  }

  double _taxAmount(double taxable) {
    final raw = double.tryParse(_taxCtrl.text) ?? 0;
    return (taxable * (raw / 100)).clamp(0, double.maxFinite).toDouble();
  }

  Future<void> _save({required String status, required bool generatePdf}) async {
    if (!_formKey.currentState!.validate()) return;

    final validItems = _items
        .where((i) => i.descriptionCtrl.text.trim().isNotEmpty && i.qty > 0 && i.unitPrice >= 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one line item')));
      return;
    }

    setState(() => _saving = true);

    final subtotal = _subtotal;
    final discountAmount = _discountAmount(subtotal);
    final taxAmount = _taxAmount(subtotal - discountAmount);
    final total = subtotal - discountAmount + taxAmount;

    final invoiceCompanion = InvoicesCompanion(
      id: widget.invoiceId == null ? const Value.absent() : Value(widget.invoiceId!),
      invoiceNumber: Value(_invoiceNumberCtrl.text.trim()),
      customerId: Value(_customerId),
      billToName: Value(_billToNameCtrl.text.trim().isEmpty ? null : _billToNameCtrl.text.trim()),
      billToAddress: Value(_billToAddressCtrl.text.trim().isEmpty ? null : _billToAddressCtrl.text.trim()),
      billToPhone: Value(_billToPhoneCtrl.text.trim().isEmpty ? null : _billToPhoneCtrl.text.trim()),
      docType: Value(_docType.dbValue),
      status: Value(status),
      template: Value(_invoiceTemplate.dbValue),
      invoiceLanguage: Value(_invoiceLanguage),
      currencyCode: Value(_currencyCode),
      exchangeRateToPkr: Value(double.tryParse(_exchangeRateCtrl.text) ?? 1),
      issueDate: Value(_issueDate),
      dueDate: Value(_docType == DocumentType.quotation ? null : _dueDate),
      expiryDate: Value(_docType == DocumentType.quotation ? _expiryDate : null),
      subtotal: Value(subtotal),
      discountAmount: Value(discountAmount),
      taxAmount: Value(taxAmount),
      total: Value(total),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      terms: Value(_termsCtrl.text.trim().isEmpty ? null : _termsCtrl.text.trim()),
    );

    final itemCompanions = validItems
        .map(
          (item) => InvoiceItemsCompanion.insert(
            invoiceId: 0,
            description: item.descriptionCtrl.text.trim(),
            qty: Value(item.qty),
            unitPrice: Value(item.unitPrice),
            lineTotal: Value(item.lineTotal),
          ),
        )
        .toList();

    final repo = ref.read(invoiceRepositoryProvider);
    int invoiceId;
    if (widget.invoiceId == null) {
      invoiceId = await repo.createInvoice(invoice: invoiceCompanion, items: itemCompanions);
    } else {
      await repo.updateInvoice(invoice: invoiceCompanion, items: itemCompanions);
      invoiceId = widget.invoiceId!;
    }

    if (_docType == DocumentType.invoice && _makeRecurring) {
      await repo.upsertRecurring(
        templateInvoiceId: invoiceId,
        frequency: _recurringFrequency,
        startDate: _recurringStartDate,
      );
    }

    if (generatePdf && mounted) {
      final invoice = await repo.getInvoiceById(invoiceId);
      final items = await repo.getItemsByInvoiceId(invoiceId);
      if (invoice != null) {
        final settings = ref.read(shopSettingsControllerProvider).valueOrNull ?? ShopSettings.defaults();
        final pdfService = InvoicePdfService();
        final bytes = await pdfService.generateInvoicePdf(
          invoice: invoice,
          items: items,
          settings: settings,
        );
        await Printing.layoutPdf(onLayout: (_) => bytes);
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      context.go('/invoices');
    }
  }
}

class _InvoiceItemDraft {
  _InvoiceItemDraft({String description = '', String qty = '1', String unitPrice = '0'})
      : descriptionCtrl = TextEditingController(text: description),
        qtyCtrl = TextEditingController(text: qty),
        unitPriceCtrl = TextEditingController(text: unitPrice),
        key = UniqueKey().toString();

  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final String key;

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtrl.text) ?? 0;
  double get lineTotal => qty * unitPrice;

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}






