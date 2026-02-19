import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/pdf_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/quote_builder_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class QuoteBuilderScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final QuoteModel? initialQuote;

  const QuoteBuilderScreen({
    super.key,
    required this.currentUser,
    this.initialQuote,
  });

  @override
  State<QuoteBuilderScreen> createState() => _QuoteBuilderScreenState();
}

class _QuoteBuilderScreenState extends State<QuoteBuilderScreen> {
  final PdfService _pdfService = PdfService();
  static const Map<String, String> _currencyOptions = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'CAD': 'CA\$',
    'JMD': 'J\$',
    'TTD': 'TT\$',
    'XCD': 'EC\$',
    'BBD': 'Bds\$',
  };

  final TextEditingController _currencySymbolController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _clientCompanyController = TextEditingController();
  final TextEditingController _clientAddressController = TextEditingController();
  final TextEditingController _companyRegistrationController = TextEditingController();
  final TextEditingController _vatNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _discountValueController = TextEditingController();
  final TextEditingController _taxValueController = TextEditingController();

  AdjustmentType _discountType = AdjustmentType.amount;
  AdjustmentType _taxType = AdjustmentType.amount;
  DateTime? _validUntil;
  bool _isListingLoading = false;
  List<ListingModel> _listings = [];
  ListingModel? _selectedListing;

  @override
  void initState() {
    super.initState();
    final quote = widget.initialQuote;
    final currencyCode = quote?.currencyCode ?? defaultCurrencyCode();
    _currencySymbolController.text =
        quote?.currencySymbol ?? _defaultSymbolFor(currencyCode);
    if (quote != null) {
      final client = quote.clientSnapshot;
      _clientNameController.text = client?.name ?? '';
      _clientEmailController.text = client?.email ?? '';
      _clientPhoneController.text = client?.phone ?? '';
      _clientCompanyController.text = client?.companyName ?? '';
      _clientAddressController.text = client?.address ?? '';
      _notesController.text = quote.notes;
      _termsController.text = quote.terms;
      _discountType = quote.discount.type;
      _taxType = quote.tax.type;
      _discountValueController.text = quote.discount.value > 0 ? quote.discount.value.toString() : '';
      _taxValueController.text = quote.tax.value > 0 ? quote.tax.value.toString() : '';
      _validUntil = quote.validUntil;
    }
    _loadListings();
  }

  @override
  void dispose() {
    _currencySymbolController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _clientCompanyController.dispose();
    _clientAddressController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _discountValueController.dispose();
    _taxValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuoteBuilderCubit(
        quoteService: QuoteService(),
        tierGateService: TierGateService(),
        currentUser: widget.currentUser,
        initialQuote: widget.initialQuote,
      ),
      child: BlocConsumer<QuoteBuilderCubit, QuoteBuilderState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            (previous.isSending && !current.isSending) ||
            (previous.isSaving && !current.isSaving),
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (!state.isSaving && state.quote.id.isNotEmpty) {
            if (state.quote.status == 'draft') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Quote saved'.tr())),
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          }
          if (!state.isSending && state.quote.status == 'sent') {
            _shareQuotePdf(state.quote);
          }
        },
        builder: (context, state) {
          final quote = state.quote;
          final currency = _currencyFormatter(quote);
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.initialQuote == null ? 'New Quote'.tr() : 'Edit Quote'.tr()),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _sectionTitle('Listing'.tr()),
                _listingSelector(context, quote),
                _listingDetailsPreview(quote.listingContext),
                _companyRegistrationFields(context),
                const SizedBox(height: 16),
                _sectionTitle('Client'.tr()),
                _clientFields(context),
                const SizedBox(height: 16),
                _sectionTitle('Line Items'.tr()),
                _itemsList(context, quote, currency),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showAddItemDialog(context),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: Text(
                      'Add Item'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Currency'.tr()),
                _currencySelector(context, quote),
                const SizedBox(height: 16),
                _sectionTitle('Totals'.tr()),
                _totalsSection(context, quote, currency),
                const SizedBox(height: 16),
                _sectionTitle('Valid Until'.tr()),
                _datePickerRow(
                  context,
                  label: _validUntil == null
                      ? 'Select date'.tr()
                      : DateFormat('MMM d, y').format(_validUntil!),
                  onTap: () => _pickValidUntil(context),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Notes'.tr()),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<QuoteBuilderCubit>().updateNotes(value),
                  decoration: InputDecoration(
                    hintText: 'Optional notes'.tr(),
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Terms'.tr()),
                TextField(
                  controller: _termsController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<QuoteBuilderCubit>().updateTerms(value),
                  decoration: InputDecoration(
                    hintText: 'Optional terms'.tr(),
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
            bottomNavigationBar: _actionBar(context, state),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _clientFields(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _clientNameController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Client name'.tr(),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientEmailController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Email'.tr(),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientPhoneController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Phone'.tr(),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientCompanyController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Company'.tr(),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientAddressController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Address'.tr(),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Future<void> _loadListings() async {
    setState(() => _isListingLoading = true);
    try {
      final listings = await listingApiManager.getMyListings(
        currentUserID: widget.currentUser.userID,
        favListingsIDs: widget.currentUser.likedListingsIDs,
      );
      if (!mounted) return;
      
      final existingContext = widget.initialQuote?.listingContext;
      
      setState(() {
        _listings = listings;

        final existingId = existingContext?.listingId;
        if (existingId != null && listings.isNotEmpty) {
          _selectedListing = listings.cast<ListingModel?>().firstWhere(
            (item) => item?.id == existingId,
            orElse: () => null,
          );
        } else if (listings.length == 1) {
          _selectedListing = listings.first;
          // Note: Auto-selection removed from here since we don't have the right context
          // User must explicitly select the listing to apply it
        }
        _isListingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListingLoading = false);
    }
  }

  void _applyListingSelection(BuildContext context, ListingModel listing) {
    setState(() => _selectedListing = listing);
    _companyRegistrationController.text = listing.companyRegistration;
    _vatNumberController.text = listing.vatNumber;
    final listingContext = ListingContext(
      listingId: listing.id,
      listingTitle: listing.title,
      listingLogoUrl: listing.logo,
      listingPhone: listing.phone,
      listingEmail: listing.email,
      listingAddress: listing.place,
      companyRegistration: listing.companyRegistration,
      vatNumber: listing.vatNumber,
    );
    context.read<QuoteBuilderCubit>().updateListingContext(listingContext);
  }

  Widget _listingSelector(BuildContext context, QuoteModel quote) {
    if (_isListingLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_listings.isEmpty) {
      return Text(
        'No listings found'.tr(),
        style: const TextStyle(color: Colors.white70),
      );
    }

    final selectedId = _selectedListing?.id ?? quote.listingContext?.listingId;
    final hasSelected = selectedId != null &&
        _listings.any((listing) => listing.id == selectedId);
    final items = <DropdownMenuItem<String>>[
      if (!hasSelected && selectedId != null)
        DropdownMenuItem(
          value: selectedId,
          child: Text(
            quote.listingContext?.listingTitle ?? 'Saved listing'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ..._listings.map(
        (listing) => DropdownMenuItem(
          value: listing.id,
          child: Text(listing.title, style: const TextStyle(color: Colors.white)),
        ),
      ),
    ];
    return DropdownButtonFormField<String>(
      value: selectedId,
      dropdownColor: const Color(0xFF2C2C2C),
      style: const TextStyle(color: Colors.white),
      items: items,
      onChanged: (value) {
        if (value == null) return;
        final listing = _listings.cast<ListingModel?>().firstWhere(
          (item) => item?.id == value,
          orElse: () => null,
        );
        if (listing == null) return;
        _applyListingSelection(context, listing);
      },
      decoration: InputDecoration(
        labelText: 'Select listing'.tr(),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _listingDetailsPreview(ListingContext? listingContext) {
    if (listingContext == null) return const SizedBox.shrink();
    final hasDetails = (listingContext.listingTitle?.isNotEmpty ?? false) ||
        (listingContext.listingPhone?.isNotEmpty ?? false) ||
        (listingContext.listingEmail?.isNotEmpty ?? false) ||
        (listingContext.listingAddress?.isNotEmpty ?? false) ||
        (listingContext.listingLogoUrl?.isNotEmpty ?? false);
    if (!hasDetails) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (listingContext.listingLogoUrl != null && listingContext.listingLogoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                listingContext.listingLogoUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
              ),
            ),
          if (listingContext.listingLogoUrl != null && listingContext.listingLogoUrl!.isNotEmpty)
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (listingContext.listingTitle != null && listingContext.listingTitle!.isNotEmpty)
                  Text(
                    listingContext.listingTitle!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                if (listingContext.listingPhone != null && listingContext.listingPhone!.isNotEmpty)
                  Text(listingContext.listingPhone!, style: const TextStyle(color: Colors.white70)),
                if (listingContext.listingEmail != null && listingContext.listingEmail!.isNotEmpty)
                  Text(listingContext.listingEmail!, style: const TextStyle(color: Colors.white70)),
                if (listingContext.listingAddress != null && listingContext.listingAddress!.isNotEmpty)
                  Text(listingContext.listingAddress!, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyRegistrationFields(BuildContext context) {
    if (_selectedListing == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: _companyRegistrationController,
            decoration: InputDecoration(
              labelText: 'Company Registration #'.tr(),
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Optional',
              hintStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefix: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.business, color: Colors.white70, size: 18)),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => _updateListingContextFromFields(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: _vatNumberController,
            decoration: InputDecoration(
              labelText: 'VAT / Tax ID #'.tr(),
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Optional',
              hintStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefix: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.receipt_long, color: Colors.white70, size: 18)),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => _updateListingContextFromFields(context),
          ),
        ),
      ],
    );
  }

  void _updateListingContextFromFields(BuildContext context) {
    if (_selectedListing == null) return;
    final currentContext = context.read<QuoteBuilderCubit>().state.quote.listingContext;
    if (currentContext == null) return;
    
    final updatedContext = ListingContext(
      listingId: currentContext.listingId,
      listingTitle: currentContext.listingTitle,
      listingLogoUrl: currentContext.listingLogoUrl,
      listingPhone: currentContext.listingPhone,
      listingEmail: currentContext.listingEmail,
      listingAddress: currentContext.listingAddress,
      companyRegistration: _companyRegistrationController.text,
      vatNumber: _vatNumberController.text,
    );
    context.read<QuoteBuilderCubit>().updateListingContext(updatedContext);
  }

  String _defaultSymbolFor(String code) {
    return _currencyOptions[code] ?? defaultCurrencySymbol(code);
  }

  NumberFormat _currencyFormatter(QuoteModel quote) {
    final code = quote.currencyCode.isNotEmpty ? quote.currencyCode : defaultCurrencyCode();
    final symbol =
        quote.currencySymbol.isNotEmpty ? quote.currencySymbol : _defaultSymbolFor(code);
    return NumberFormat.currency(name: code, symbol: symbol);
  }

  Widget _currencySelector(BuildContext context, QuoteModel quote) {
    final code = quote.currencyCode.isNotEmpty ? quote.currencyCode : defaultCurrencyCode();
    final codes = [..._currencyOptions.keys];
    if (!codes.contains(code)) {
      codes.insert(0, code);
    }
    if (_currencySymbolController.text.isEmpty && quote.currencySymbol.isNotEmpty) {
      _currencySymbolController.text = quote.currencySymbol;
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: code,
            dropdownColor: const Color(0xFF2C2C2C),
            style: const TextStyle(color: Colors.white),
            items: codes
                .map(
                  (itemCode) => DropdownMenuItem(
                    value: itemCode,
                    child: Text(itemCode, style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(),
            onChanged: (value) => _onCurrencyCodeChanged(context, value),
            decoration: InputDecoration(
              labelText: 'Code'.tr(),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _currencySymbolController,
            onChanged: (value) =>
                context.read<QuoteBuilderCubit>().updateCurrencySymbol(value),
            decoration: InputDecoration(
              labelText: 'Symbol'.tr(),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  void _onCurrencyCodeChanged(BuildContext context, String? code) {
    if (code == null) return;
    context.read<QuoteBuilderCubit>().updateCurrencyCode(code);
    final symbol = _defaultSymbolFor(code);
    _currencySymbolController.text = symbol;
    context.read<QuoteBuilderCubit>().updateCurrencySymbol(symbol);
  }

  Widget _itemsList(BuildContext context, QuoteModel quote, NumberFormat currency) {
    if (quote.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No items yet'.tr(), style: const TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: quote.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white.withOpacity(0.95),
          child: ListTile(
            title: Text(
              item.description,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${item.qty} x ${currency.format(item.unitPrice)}',
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency.format(item.lineTotal),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  onPressed: () => context.read<QuoteBuilderCubit>().removeItem(index),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _totalsSection(BuildContext context, QuoteModel quote, NumberFormat currency) {
    return Column(
      children: [
        _totalRow('Subtotal'.tr(), currency.format(quote.subtotal)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _adjustmentDropdown(_discountType, (value) => _onDiscountType(context, value))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _discountValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => _onDiscountValue(context, value),
                decoration: InputDecoration(
                  labelText: 'Discount'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _adjustmentDropdown(_taxType, (value) => _onTaxType(context, value))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _taxValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => _onTaxValue(context, value),
                decoration: InputDecoration(
                  labelText: 'Tax'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _totalRow('Total'.tr(), currency.format(quote.total), isBold: true),
      ],
    );
  }

  Widget _adjustmentDropdown(AdjustmentType type, ValueChanged<AdjustmentType> onChanged) {
    return DropdownButtonFormField<AdjustmentType>(
      value: type,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      dropdownColor: const Color(0xFF2C2C2C),
      items: [
        DropdownMenuItem(
          value: AdjustmentType.amount,
          child: Text('Amount'.tr(), style: const TextStyle(color: Colors.white)),
        ),
        DropdownMenuItem(
          value: AdjustmentType.percent,
          child: Text('Percent'.tr(), style: const TextStyle(color: Colors.white)),
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Type'.tr(),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: Colors.white,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: Colors.white,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _datePickerRow(BuildContext context, {required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context, QuoteBuilderState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: state.isSaving
                    ? null
                    : () => context.read<QuoteBuilderCubit>().saveDraft(),
                child: state.isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Save Draft'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateClientSnapshot(BuildContext context) {
    final snapshot = ClientSnapshot(
      name: _clientNameController.text.trim(),
      email: _clientEmailController.text.trim(),
      phone: _clientPhoneController.text.trim(),
      companyName: _clientCompanyController.text.trim(),
      address: _clientAddressController.text.trim(),
    );
    context.read<QuoteBuilderCubit>().updateClient(snapshot, clientId: widget.initialQuote?.clientId);
  }

  void _onDiscountType(BuildContext context, AdjustmentType type) {
    setState(() => _discountType = type);
    final value = double.tryParse(_discountValueController.text) ?? 0;
    context.read<QuoteBuilderCubit>().updateDiscount(type, value);
  }

  void _onDiscountValue(BuildContext context, String value) {
    final parsed = double.tryParse(value) ?? 0;
    context.read<QuoteBuilderCubit>().updateDiscount(_discountType, parsed);
  }

  void _onTaxType(BuildContext context, AdjustmentType type) {
    setState(() => _taxType = type);
    final value = double.tryParse(_taxValueController.text) ?? 0;
    context.read<QuoteBuilderCubit>().updateTax(type, value);
  }

  void _onTaxValue(BuildContext context, String value) {
    final parsed = double.tryParse(value) ?? 0;
    context.read<QuoteBuilderCubit>().updateTax(_taxType, parsed);
  }

  Future<void> _pickValidUntil(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: const Color(0xFF2C2C2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
      context.read<QuoteBuilderCubit>().updateValidUntil(picked);
    }
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Item'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Unit Price'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text('Cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final description = descriptionController.text.trim();
                        final qty = double.tryParse(qtyController.text) ?? 0;
                        final price = double.tryParse(priceController.text) ?? 0;
                        if (description.isEmpty || qty <= 0 || price < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Enter valid item details'.tr())),
                          );
                          return;
                        }
                        context.read<QuoteBuilderCubit>().addItem(
                              ProDocLineItem(
                                description: description,
                                qty: qty,
                                unitPrice: price,
                              ),
                            );
                        Navigator.pop(sheetContext);
                      },
                      child: Text('Add'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  bool _canSend(QuoteModel quote) {
    final clientName = _clientNameController.text.trim();
    return quote.items.isNotEmpty && clientName.isNotEmpty;
  }

  Future<void> _shareQuotePdf(QuoteModel quote) async {
    final tier = TierGateService().resolveTierFromUser(widget.currentUser);
    final canBrand = TierGateService().canUseBranding(tier);
    final businessName = canBrand ? _displayName(widget.currentUser) : null;
    await _pdfService.shareQuotePdf(
      quote,
      businessName: businessName,
      includeWatermark: !canBrand,
      hideFooter: canBrand,
    );
  }

  Future<void> _downloadQuotePdf(QuoteModel quote) async {
    try {
      final tier = TierGateService().resolveTierFromUser(widget.currentUser);
      final canBrand = TierGateService().canUseBranding(tier);
      final businessName = canBrand ? _displayName(widget.currentUser) : null;
      final path = await _pdfService.downloadQuotePdf(
        quote,
        businessName: businessName,
        includeWatermark: !canBrand,
        hideFooter: canBrand,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded to: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF: $e')),
      );
    }
  }

  String _displayName(ListingsUser user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : 'CaribTap Business';
  }
}
