import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/invoice_list_cubit.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/quote_list_cubit.dart';
import 'package:caribtap/listings/ui/pro_docs/quote_builder_screen.dart';
import 'package:caribtap/listings/ui/pro_docs/quote_detail_screen.dart';
import 'package:caribtap/listings/ui/pro_docs/invoice_detail_screen.dart';
import 'package:caribtap/listings/ui/subscription/paywall_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class QuoteListScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const QuoteListScreen({super.key, required this.currentUser});

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  String _statusFilter = 'all';

  NumberFormat _currencyFor({required String code, required String symbol}) {
    final finalCode = code.isNotEmpty ? code : defaultCurrencyCode();
    final finalSymbol = symbol.isNotEmpty ? symbol : defaultCurrencySymbol(finalCode);
    return NumberFormat.currency(name: finalCode, symbol: finalSymbol);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuoteListCubit(
        quoteService: QuoteService(),
        tierGateService: TierGateService(),
        currentUser: widget.currentUser,
      )..start(),
      child: BlocBuilder<QuoteListCubit, QuoteListState>(
        builder: (context, state) {
          if (state is QuoteListLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is QuoteListLocked) {
            return Scaffold(
              appBar: AppBar(title: Text('Quotes & Invoices'.tr())),
              body: _buildLocked(state.message),
            );
          }
          if (state is QuoteListError) {
            return Scaffold(
              appBar: AppBar(title: Text('Quotes & Invoices'.tr())),
              body: Center(child: Text(state.message)),
            );
          }

          final loaded = state as QuoteListLoaded;
          final quotes = _applyFilter(loaded.quotes);

          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text('Quotes & Invoices'.tr()),
                bottom: TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: 'Quotes'.tr()),
                    Tab(
                      text: 'Invoices'.tr(),
                    ),
                  ],
                ),
              ),
              floatingActionButton: loaded.limitReached
                  ? null
                  : FloatingActionButton(
                      onPressed: () {
                        push(
                          context,
                          QuoteBuilderScreen(currentUser: widget.currentUser),
                        );
                      },
                      child: const Icon(Icons.add_rounded),
                    ),
              body: TabBarView(
                children: [
                  _buildQuotesTab(loaded, quotes),
                  _buildInvoicesTab(loaded.canUseInvoices),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocked(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                push(context, PaywallScreen(currentUser: widget.currentUser));
              },
              child: Text('Upgrade'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesTab(QuoteListLoaded state, List<QuoteModel> quotes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildFilters(),
        if (state.limit != null && state.limitReached)
          _buildLimitCard(state.limit!),
        Expanded(
          child: quotes.isEmpty
              ? Center(
                  child: Text(
                    'No quotes yet'.tr(),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final quote = quotes[index];
                    final currency = _currencyFor(
                      code: quote.currencyCode,
                      symbol: quote.currencySymbol,
                    );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      title: Text(
                        quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'Draft'.tr(),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        _clientLine(quote),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currency.format(quote.total),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          _statusChip(quote.status),
                        ],
                      ),
                      onTap: () {
                        push(
                          context,
                          QuoteDetailScreen(
                            currentUser: widget.currentUser,
                            quoteId: quote.id,
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: quotes.length,
                ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab(bool canUseInvoices) {
    if (!canUseInvoices) {
      return _buildLocked('Upgrade to Professional Plus for invoices'.tr());
    }

    return BlocProvider(
      create: (_) => InvoiceListCubit(
        invoiceService: InvoiceService(),
        uid: widget.currentUser.userID,
      )..start(),
      child: BlocBuilder<InvoiceListCubit, InvoiceListState>(
        builder: (context, state) {
          if (state is InvoiceListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InvoiceListError) {
            return Center(child: Text(state.message));
          }

          final invoices = (state as InvoiceListLoaded).invoices;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (invoices.isEmpty) {
            return Center(
              child: Text(
                'No invoices yet'.tr(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              final currency = _currencyFor(
                code: invoice.currencyCode,
                symbol: invoice.currencySymbol,
              );
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                title: Text(
                  invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'Draft'.tr(),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  _invoiceClientLine(invoice),
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currency.format(invoice.total),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    _statusChip(invoice.status),
                  ],
                ),
                onTap: () {
                  push(
                    context,
                    InvoiceDetailScreen(
                      uid: widget.currentUser.userID,
                      invoiceId: invoice.id,
                      currentUser: widget.currentUser,
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: invoices.length,
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = ['all', 'draft', 'sent', 'accepted', 'declined', 'expired'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final selected = status == _statusFilter;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ChoiceChip(
            label: Text(
              _statusLabel(status),
              style: TextStyle(
                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: selected,
            selectedColor: Theme.of(context).primaryColor,
            backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
            onSelected: (_) {
              setState(() => _statusFilter = status);
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: statuses.length,
      ),
    );
  }

  Widget _buildLimitCard(int limit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text('You reached the $limit quote limit. Upgrade for unlimited history.'.tr()),
          ),
          TextButton(
            onPressed: () {
              push(context, PaywallScreen(currentUser: widget.currentUser));
            },
            child: Text('Upgrade'.tr()),
          ),
        ],
      ),
    );
  }

  List<QuoteModel> _applyFilter(List<QuoteModel> quotes) {
    if (_statusFilter == 'all') return quotes;
    return quotes.where((quote) => quote.status == _statusFilter).toList();
  }

  String _clientLine(QuoteModel quote) {
    final client = quote.clientSnapshot;
    if (client == null) return 'No client'.tr();
    if (client.companyName.isNotEmpty) return '${client.name} · ${client.companyName}';
    return client.name.isNotEmpty ? client.name : 'Client'.tr();
  }

  String _invoiceClientLine(InvoiceModel invoice) {
    final client = invoice.clientSnapshot;
    if (client == null) return 'No client'.tr();
    if (client.companyName.isNotEmpty) return '${client.name} · ${client.companyName}';
    return client.name.isNotEmpty ? client.name : 'Client'.tr();
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft'.tr();
      case 'sent':
        return 'Sent'.tr();
      case 'accepted':
        return 'Accepted'.tr();
      case 'declined':
        return 'Declined'.tr();
      case 'expired':
        return 'Expired'.tr();
      case 'paid':
        return 'Paid'.tr();
      case 'overdue':
        return 'Overdue'.tr();
      default:
        return status == 'all' ? 'All'.tr() : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
