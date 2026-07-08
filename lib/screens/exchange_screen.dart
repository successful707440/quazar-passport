import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exchange.dart';
import '../providers/auth_provider.dart';
import '../providers/exchange_provider.dart';
import '../utils/constants.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<ExchangeProvider>(context, listen: false).loadAll(auth);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExchangeProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            _BalanceCard(balance: provider.balance),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Предложения', icon: Icon(Icons.storefront)),
                Tab(text: 'Заказы', icon: Icon(Icons.receipt_long)),
                Tab(text: 'Продать', icon: Icon(Icons.add_business)),
              ],
            ),
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  provider.error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: provider.isLoading && provider.offers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _OffersTab(provider: provider, onRefresh: _load),
                        _OrdersTab(provider: provider, onRefresh: _load),
                        _CreateOfferTab(provider: provider, onCreated: _load),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final ExchangeBalance? balance;

  const _BalanceCard({this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.deepPurple.shade700),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Баланс ${Constants.currencyName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  balance != null
                      ? '${balance!.amount} ${Constants.currencyName}'
                      : '—',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersTab extends StatelessWidget {
  final ExchangeProvider provider;
  final VoidCallback onRefresh;

  const _OffersTab({required this.provider, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final offers = provider.activeOffers;

    if (offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Нет активных предложений')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final isMine = provider.isMyOffer(offer, auth);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.service,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Цена: ${offer.price} ${Constants.currencyName} / шт.'),
                  Text('В наличии: ${offer.quantity} шт.'),
                  Text(
                    'Продавец: ${_shortId(offer.seller)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isMine)
                        TextButton(
                          onPressed: () => _cancelOffer(context, offer),
                          child: const Text(
                            'Отменить',
                            style: TextStyle(color: Colors.red),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _buyOffer(context, offer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Купить'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _buyOffer(BuildContext context, ExchangeOffer offer) async {
    final qtyController = TextEditingController(text: '1');
    final quantity = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Купить: ${offer.service}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Цена: ${offer.price} ${Constants.currencyName} / шт.'),
            Text('Доступно: ${offer.quantity} шт.'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty > 0 && qty <= offer.quantity) {
                Navigator.pop(ctx, qty);
              }
            },
            child: const Text('Купить'),
          ),
        ],
      ),
    );

    if (quantity == null || !context.mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await provider.buyOffer(
      auth,
      offer: offer,
      quantity: quantity,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ?? 'Покупка выполнена'),
          backgroundColor: result != null ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> _cancelOffer(BuildContext context, ExchangeOffer offer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить предложение?'),
        content: Text(offer.service),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await provider.cancelOffer(auth, offer);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Предложение отменено'),
          backgroundColor: error != null ? Colors.red : Colors.green,
        ),
      );
    }
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }
}

class _OrdersTab extends StatelessWidget {
  final ExchangeProvider provider;
  final VoidCallback onRefresh;

  const _OrdersTab({required this.provider, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (provider.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('У вас пока нет заказов')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.orders.length,
        itemBuilder: (context, index) {
          final order = provider.orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text('Заказ ${_shortId(order.id)}'),
              subtitle: Text(
                '${order.quantity} шт. · ${order.totalPrice} ${Constants.currencyName}\n'
                'Статус: ${order.status}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }
}

class _CreateOfferTab extends StatefulWidget {
  final ExchangeProvider provider;
  final VoidCallback onCreated;

  const _CreateOfferTab({required this.provider, required this.onCreated});

  @override
  State<_CreateOfferTab> createState() => _CreateOfferTabState();
}

class _CreateOfferTabState extends State<_CreateOfferTab> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _selectedSvodCode;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillPrice());
  }

  void _prefillPrice() {
    final services = widget.provider.svodServices;
    if (services.isEmpty) return;
    final code = _selectedSvodCode ?? services.first.code;
    final item = services.firstWhere((s) => s.code == code);
    if (_priceController.text.isEmpty) {
      _priceController.text = item.basePrice.toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final services = widget.provider.svodServices;
    if (services.isEmpty) return;

    final svodCode = (_selectedSvodCode != null &&
            services.any((s) => s.code == _selectedSvodCode))
        ? _selectedSvodCode!
        : services.first.code;

    setState(() => _submitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final error = await widget.provider.createOffer(
      auth,
      svodCode: svodCode,
      price: int.parse(_priceController.text.trim()),
      quantity: int.parse(_quantityController.text.trim()),
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (error == null) {
        _priceController.clear();
        _quantityController.text = '1';
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предложение создано'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.provider.svodServices;

    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.provider.isLoading
                ? 'Загрузка Свода…'
                : 'Свод услуг пуст. Обновите экран или обратитесь к администратору.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final effectiveCode = (_selectedSvodCode != null &&
            services.any((s) => s.code == _selectedSvodCode))
        ? _selectedSvodCode!
        : services.first.code;

    final selected = services.firstWhere((s) => s.code == effectiveCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Разместить услугу на бирже',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Услуга выбирается из Свода Оснований для Созидания',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: effectiveCode,
              decoration: const InputDecoration(
                labelText: 'Услуга из Свода',
                border: OutlineInputBorder(),
              ),
              items: services
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.code,
                      child: Text('${s.name} (${s.code})'),
                    ),
                  )
                  .toList(),
              onChanged: (code) {
                if (code == null) return;
                final item = services.firstWhere((s) => s.code == code);
                setState(() {
                  _selectedSvodCode = code;
                  _priceController.text = item.basePrice.toString();
                });
              },
            ),
            if (selected.description != null &&
                selected.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                selected.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Мин. цена: ${selected.basePrice} ${Constants.currencyName} · '
              'кол-во: ${selected.minQuantity}–${selected.maxQuantity}',
              style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Цена за единицу (${Constants.currencyName})',
                border: const OutlineInputBorder(),
                helperText:
                    'Не менее ${selected.basePrice} ${Constants.currencyName}',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Укажите цену > 0';
                if (n < selected.basePrice) {
                  return 'Минимум ${selected.basePrice} ${Constants.currencyName}';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Количество',
                border: const OutlineInputBorder(),
                helperText:
                    'От ${selected.minQuantity} до ${selected.maxQuantity}',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Укажите количество > 0';
                if (n < selected.minQuantity) {
                  return 'Минимум ${selected.minQuantity}';
                }
                if (n > selected.maxQuantity) {
                  return 'Максимум ${selected.maxQuantity}';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Создать предложение'),
            ),
          ],
        ),
      ),
    );
  }
}
