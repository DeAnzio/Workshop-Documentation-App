import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';

class CurrencySelector extends StatefulWidget {
  final String selectedCurrency;
  final Function(String) onCurrencyChanged;
  final bool showFlag;

  const CurrencySelector({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.showFlag = false,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.selectedCurrency;
  }

  @override
  Widget build(BuildContext context) {
    final currencies = CurrencyService.getSupportedCurrencyCodes();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          isExpanded: true,
          items: currencies.map((currencyCode) {
            final currencyName = CurrencyService.getCurrencyName(currencyCode);
            final currencySymbol = CurrencyService.getCurrencySymbol(
              currencyCode,
            );

            return DropdownMenuItem<String>(
              value: currencyCode,
              child: Row(
                children: [
                  if (widget.showFlag) ...[
                    _buildCurrencyFlag(currencyCode),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '$currencySymbol $currencyCode',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currencyName,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCurrency = value;
              });
              widget.onCurrencyChanged(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCurrencyFlag(String currencyCode) {
    // Simple flag representation using emoji flags
    const flagEmojis = {
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'JPY': '🇯🇵',
      'GBP': '🇬🇧',
      'IDR': '🇮🇩',
      'SGD': '🇸🇬',
      'AUD': '🇦🇺',
      'CAD': '🇨🇦',
      'CHF': '🇨🇭',
      'CNY': '🇨🇳',
      'KRW': '🇰🇷',
      'THB': '🇹🇭',
      'MYR': '🇲🇾',
      'HKD': '🇭🇰',
      'NZD': '🇳🇿',
    };

    return Text(
      flagEmojis[currencyCode] ?? '🏳️',
      style: const TextStyle(fontSize: 16),
    );
  }
}

class CurrencyDisplay extends StatelessWidget {
  final double amount;
  final String currencyCode;
  final TextStyle? style;
  final bool showCurrencyCode;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    required this.currencyCode,
    this.style,
    this.showCurrencyCode = true,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = CurrencyService.formatCurrency(
      amount,
      currencyCode,
    );

    return Text(
      showCurrencyCode
          ? formattedAmount
          : formattedAmount.replaceAll(currencyCode, '').trim(),
      style:
          style ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }
}

class CurrencyConverter extends StatefulWidget {
  final double baseAmount;
  final String baseCurrency;
  final String targetCurrency;
  final TextStyle? style;

  const CurrencyConverter({
    super.key,
    required this.baseAmount,
    required this.baseCurrency,
    required this.targetCurrency,
    this.style,
  });

  @override
  State<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends State<CurrencyConverter> {
  double? _convertedAmount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _convertCurrency();
  }

  @override
  void didUpdateWidget(CurrencyConverter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseAmount != widget.baseAmount ||
        oldWidget.baseCurrency != widget.baseCurrency ||
        oldWidget.targetCurrency != widget.targetCurrency) {
      _convertCurrency();
    }
  }

  Future<void> _convertCurrency() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final converted = await CurrencyService.convertCurrency(
        widget.baseAmount,
        widget.baseCurrency,
        widget.targetCurrency,
      );

      if (mounted) {
        setState(() {
          _convertedAmount = converted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _convertedAmount = widget.baseAmount; // Fallback to original amount
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return CurrencyDisplay(
      amount: _convertedAmount ?? widget.baseAmount,
      currencyCode: widget.targetCurrency,
      style: widget.style,
    );
  }
}
