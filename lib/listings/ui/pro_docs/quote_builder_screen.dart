import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/catalog_item.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/model/rental_catalog_item.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/pdf_service.dart';
import 'package:caribtap/listings/services/rental_catalog_service.dart';
import 'package:caribtap/listings/services/store_service.dart';
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
  final PaymentDetailsService _paymentDetailsService = PaymentDetailsService();

  Future<PaymentDetailsPublic?> _getPaymentDetails() async {
    try {
      final details = await _paymentDetailsService.getPublic(widget.currentUser.userID);
      return details.hasAnyPaymentMethod ? details : null;
    } catch (_) {
      return null;
    }
  }
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
              SnackBar(content: Text(state.errorMessage!.tr())),
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
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── Listing ─────────────────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Listing'.tr(), Icons.store_rounded),
                      const SizedBox(height: 12),
                      _listingSelector(context, quote),
                      if ((quote.listingContext?.listingTitle?.isNotEmpty ?? false) ||
                          (quote.listingContext?.listingLogoUrl?.isNotEmpty ?? false)) ...[  
                        const SizedBox(height: 12),
                        _listingDetailsPreview(context, quote.listingContext),
                      ],
                      if (_selectedListing != null) ...[  
                        const SizedBox(height: 12),
                        _companyRegistrationFields(context),
                      ],
                    ],
                  ),
                ),
                // ── Client ──────────────────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Client'.tr(), Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _clientFields(context),
                    ],
                  ),
                ),
                // ── Line Items ──────────────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Line Items'.tr(), Icons.receipt_long_rounded),
                      const SizedBox(height: 12),
                      _itemsList(context, quote, currency),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showAddItemDialog(context),
                          icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary),
                          label: Text(
                            'Add Item'.tr(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Currency & Totals ───────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Currency'.tr(), Icons.attach_money_rounded),
                      const SizedBox(height: 12),
                      _currencySelector(context, quote),
                      const SizedBox(height: 20),
                      _sectionHeader(context, 'Totals'.tr(), Icons.calculate_rounded),
                      const SizedBox(height: 12),
                      _totalsSection(context, quote, currency),
                    ],
                  ),
                ),
                // ── Valid Until ─────────────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Valid Until'.tr(), Icons.event_rounded),
                      const SizedBox(height: 12),
                      _datePickerRow(
                        context,
                        label: _validUntil == null
                            ? 'Select date'.tr()
                            : DateFormat('MMM d, y').format(_validUntil!),
                        onTap: () => _pickValidUntil(context),
                      ),
                    ],
                  ),
                ),
                // ── Notes & Terms ───────────────────────────────────────
                _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'Notes'.tr(), Icons.notes_rounded),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (value) => context.read<QuoteBuilderCubit>().updateNotes(value),
                        decoration: InputDecoration(hintText: 'Optional notes'.tr()),
                      ),
                      const SizedBox(height: 20),
                      _sectionHeader(context, 'Terms'.tr(), Icons.gavel_rounded),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _termsController,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (value) => context.read<QuoteBuilderCubit>().updateTerms(value),
                        decoration: InputDecoration(hintText: 'Optional terms'.tr()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            ),
            bottomNavigationBar: _actionBar(context, state),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0.4,
          ),
        ),
      ],
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
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientEmailController,
          onChanged: (_) => _updateClientSnapshot(context),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email'.tr(),
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientPhoneController,
          onChanged: (_) => _updateClientSnapshot(context),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone'.tr(),
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientCompanyController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Company'.tr(),
            prefixIcon: const Icon(Icons.business_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientAddressController,
          onChanged: (_) => _updateClientSnapshot(context),
          decoration: InputDecoration(
            labelText: 'Address'.tr(),
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
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
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
          ),
        ),
      ..._listings.map(
        (listing) => DropdownMenuItem(
          value: listing.id,
          child: Text(listing.title),
        ),
      ),
    ];
    return DropdownButtonFormField<String>(
      value: selectedId,
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
      ),
    );
  }

  Widget _listingDetailsPreview(BuildContext context, ListingContext? listingContext) {
    if (listingContext == null) return const SizedBox.shrink();
    final hasDetails = (listingContext.listingTitle?.isNotEmpty ?? false) ||
        (listingContext.listingPhone?.isNotEmpty ?? false) ||
        (listingContext.listingEmail?.isNotEmpty ?? false) ||
        (listingContext.listingAddress?.isNotEmpty ?? false) ||
        (listingContext.listingLogoUrl?.isNotEmpty ?? false);
    if (!hasDetails) return const SizedBox.shrink();

    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                    style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
                  ),
                if (listingContext.listingPhone != null && listingContext.listingPhone!.isNotEmpty)
                  Text(listingContext.listingPhone!, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
                if (listingContext.listingEmail != null && listingContext.listingEmail!.isNotEmpty)
                  Text(listingContext.listingEmail!, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
                if (listingContext.listingAddress != null && listingContext.listingAddress!.isNotEmpty)
                  Text(listingContext.listingAddress!, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyRegistrationFields(BuildContext context) {
    if (_selectedListing == null) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: _companyRegistrationController,
            decoration: InputDecoration(
              labelText: 'Company Registration #'.tr(),
              labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.7)),
              hintText: 'Optional'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefix: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.business, color: onSurface.withValues(alpha: 0.7), size: 18)),
            ),
            onChanged: (_) => _updateListingContextFromFields(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: _vatNumberController,
            decoration: InputDecoration(
              labelText: 'VAT / Tax ID #'.tr(),
              labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.7)),
              hintText: 'Optional'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefix: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.receipt_long, color: onSurface.withValues(alpha: 0.7), size: 18)),
            ),
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
            items: codes
                .map(
                  (itemCode) => DropdownMenuItem(
                    value: itemCode,
                    child: Text(itemCode),
                  ),
                )
                .toList(),
            onChanged: (value) => _onCurrencyCodeChanged(context, value),
            decoration: InputDecoration(
              labelText: 'Code'.tr(),
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
          child: ListTile(
            title: Text(
              item.description,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${item.qty} x ${currency.format(item.unitPrice)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency.format(item.lineTotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
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
        _totalRow(context, 'Subtotal'.tr(), currency.format(quote.subtotal)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _adjustmentDropdown(context, _discountType, (value) => _onDiscountType(context, value))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _discountValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => _onDiscountValue(context, value),
                decoration: InputDecoration(
                  labelText: 'Discount'.tr(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _adjustmentDropdown(context, _taxType, (value) => _onTaxType(context, value))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _taxValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => _onTaxValue(context, value),
                decoration: InputDecoration(
                  labelText: 'Tax'.tr(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 12),
        _totalRow(context, 'Total'.tr(), currency.format(quote.total), isBold: true),
      ],
    );
  }

  Widget _adjustmentDropdown(BuildContext context, AdjustmentType type, ValueChanged<AdjustmentType> onChanged) {
    return DropdownButtonFormField<AdjustmentType>(
      value: type,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      items: [
        DropdownMenuItem(
          value: AdjustmentType.amount,
          child: Text('Amount'.tr()),
        ),
        DropdownMenuItem(
          value: AdjustmentType.percent,
          child: Text('Percent'.tr()),
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Type'.tr(),
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value, {bool isBold = false}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: onSurface,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: onSurface,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _datePickerRow(BuildContext context, {required String label, required VoidCallback onTap}) {
    final hasDate = _validUntil != null;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate ? primary.withValues(alpha: 0.6) : Theme.of(context).dividerColor,
            width: hasDate ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: hasDate ? primary : onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: hasDate ? onSurface : onSurface.withValues(alpha: 0.45),
                fontSize: 15,
              ),
            ),
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
            colorScheme: Theme.of(context).colorScheme,
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
    final cubit = context.read<QuoteBuilderCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddItemSheet(
        listing: _selectedListing,
        onItemAdded: (item) => cubit.addItem(item),
      ),
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
    final paymentDetails = await _getPaymentDetails();
    await _pdfService.shareQuotePdf(
      quote,
      businessName: businessName,
      includeWatermark: !canBrand,
      hideFooter: canBrand,
      paymentDetails: paymentDetails,
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
        paymentDetails: await _getPaymentDetails(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF downloaded to'.tr()}: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to download PDF'.tr()}: $e')),
      );
    }
  }

  String _displayName(ListingsUser user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : 'CaribTap Business'.tr();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Item Sheet
// ─────────────────────────────────────────────────────────────────────────────

enum _AddItemTab { services, store, rental, manual }

class _AddItemSheet extends StatefulWidget {
  final ListingModel? listing;
  final ValueChanged<ProDocLineItem> onItemAdded;

  const _AddItemSheet({
    required this.listing,
    required this.onItemAdded,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  _AddItemTab _tab = _AddItemTab.services;

  // Manual entry controllers
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  // Async catalog data
  List<ServiceItem>? _services;
  List<CatalogItem>? _storeItems;
  List<RentalCatalogItem>? _rentalItems;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTab(_tab);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTab(_AddItemTab tab) async {
    final listing = widget.listing;
    if (listing == null) return;
    setState(() { _loading = true; _tab = tab; });
    try {
      switch (tab) {
        case _AddItemTab.services:
          setState(() { _services = listing.services; _loading = false; });
        case _AddItemTab.store:
          final items = await StoreService().getCatalogItems(listing.id).first;
          if (mounted) setState(() { _storeItems = items; _loading = false; });
        case _AddItemTab.rental:
          final items = await RentalCatalogService().getRentalCatalogItems(listing.id).first;
          if (mounted) setState(() { _rentalItems = items; _loading = false; });
        case _AddItemTab.manual:
          if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addManual() {
    final description = _descCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (description.isEmpty || qty <= 0 || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter valid item details'.tr())),
      );
      return;
    }
    widget.onItemAdded(ProDocLineItem(description: description, qty: qty, unitPrice: price));
    Navigator.pop(context); // dismiss the _AddItemSheet itself
  }

  @override
  Widget build(BuildContext context) {
    final hasListing = widget.listing != null;
    final scheme = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Add Item'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            // Tab bar (only show catalog tabs when a listing is selected)
            if (hasListing)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _TabChip(label: 'Services'.tr(), icon: Icons.design_services_rounded, selected: _tab == _AddItemTab.services, onTap: () => _loadTab(_AddItemTab.services)),
                    const SizedBox(width: 8),
                    _TabChip(label: 'Store'.tr(), icon: Icons.storefront_rounded, selected: _tab == _AddItemTab.store, onTap: () => _loadTab(_AddItemTab.store)),
                    const SizedBox(width: 8),
                    _TabChip(label: 'Rentals'.tr(), icon: Icons.key_rounded, selected: _tab == _AddItemTab.rental, onTap: () => _loadTab(_AddItemTab.rental)),
                    const SizedBox(width: 8),
                    _TabChip(label: 'Manual'.tr(), icon: Icons.edit_rounded, selected: _tab == _AddItemTab.manual, onTap: () => _loadTab(_AddItemTab.manual)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTabContent(insets, scheme),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(EdgeInsets insets, ColorScheme scheme) {
    if (!hasListing || _tab == _AddItemTab.manual) return _buildManualTab(insets, scheme);
    switch (_tab) {
      case _AddItemTab.services:
        return _buildServicesList();
      case _AddItemTab.store:
        return _buildStoreList();
      case _AddItemTab.rental:
        return _buildRentalList();
      case _AddItemTab.manual:
        return _buildManualTab(insets, scheme);
    }
  }

  bool get hasListing => widget.listing != null;

  /// Shows a small bottom dialog to confirm/edit qty before adding a catalog item.
  Future<void> _confirmAndAdd(String description, double unitPrice) async {
    final navigator = Navigator.of(context); // capture before async gap
    final qtyCtrl = TextEditingController(text: '1');
    double? confirmedQty;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unit price: ${unitPrice.toStringAsFixed(2)}',
              style: TextStyle(color: Theme.of(dlgCtx).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantity'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) return;
              confirmedQty = qty;
              Navigator.pop(dlgCtx);
            },
            child: Text('Add'.tr()),
          ),
        ],
      ),
    );

    // Do NOT dispose qtyCtrl here — the dialog's exit animation may still be
    // running, which keeps the TextField alive and listening to the controller.
    // As a local variable it will be GC'd once this method returns.

    // Call onItemAdded and dismiss the sheet only after the dialog is fully
    // dismissed. Use the pre-captured navigator to avoid context-across-async-gap.
    if (confirmedQty != null && mounted) {
      widget.onItemAdded(ProDocLineItem(
        description: description,
        qty: confirmedQty!,
        unitPrice: unitPrice,
      ));
      navigator.pop(); // dismiss the _AddItemSheet itself
    }
  }

  // ── Services ──────────────────────────────────────────────────────────────

  Widget _buildServicesList() {
    final services = _services ?? [];
    if (services.isEmpty) {
      return _emptyState('No services on this listing'.tr(), Icons.design_services_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: services.length,
      itemBuilder: (_, i) {
        final s = services[i];
        return ListTile(
          leading: const Icon(Icons.design_services_rounded),
          title: Text(s.name),
          subtitle: s.duration.isNotEmpty ? Text(s.duration) : null,
          trailing: Text(
            s.price.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _confirmAndAdd(s.name, s.price),
        );
      },
    );
  }

  // ── Store ─────────────────────────────────────────────────────────────────

  Widget _buildStoreList() {
    final items = _storeItems ?? [];
    if (items.isEmpty) {
      return _emptyState('No store items on this listing'.tr(), Icons.storefront_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final price = item.variants.isNotEmpty ? item.variants.first.price : item.price;
        return ListTile(
          leading: item.photos.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(item.photos.first, width: 40, height: 40, fit: BoxFit.cover),
                )
              : const Icon(Icons.storefront_rounded),
          title: Text(item.name),
          subtitle: item.description != null && item.description!.isNotEmpty
              ? Text(item.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: Text(
            price.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _confirmAndAdd(item.name, price),
        );
      },
    );
  }

  // ── Rental ────────────────────────────────────────────────────────────────

  Widget _buildRentalList() {
    final items = _rentalItems ?? [];
    if (items.isEmpty) {
      return _emptyState('No rental items on this listing'.tr(), Icons.key_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final unitLabel = item.pricingUnit.name; // e.g. 'daily'
        return ListTile(
          leading: item.photos.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(item.photos.first, width: 40, height: 40, fit: BoxFit.cover),
                )
              : const Icon(Icons.key_rounded),
          title: Text(item.name),
          subtitle: Text('${item.basePrice.toStringAsFixed(2)} / $unitLabel'),
          trailing: Text(
            item.basePrice.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _confirmAndAdd('${item.name} (${item.pricingUnit.name})', item.basePrice),
        );
      },
    );
  }

  // ── Manual ────────────────────────────────────────────────────────────────

  Widget _buildManualTab(EdgeInsets insets, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: insets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: 'Description'.tr(),
              hintText: 'e.g. Consultation fee'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Unit Price'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _addManual,
            child: Text('Add Item'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 16, color: selected ? scheme.onPrimary : scheme.onSurface),
      label: Text(label),
      selectedColor: scheme.primary,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }
}
