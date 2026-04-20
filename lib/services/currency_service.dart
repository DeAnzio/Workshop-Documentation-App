import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const String _baseUrl = 'https://api.exchangerate-api.com/v4/latest';

  // Supported currencies with their symbols
  static const Map<String, Map<String, String>> supportedCurrencies = {
    'USD': {'name': 'US Dollar', 'symbol': '\$'},
    'EUR': {'name': 'Euro', 'symbol': '€'},
    'JPY': {'name': 'Japanese Yen', 'symbol': '¥'},
    'GBP': {'name': 'British Pound', 'symbol': '£'},
    'IDR': {'name': 'Indonesian Rupiah', 'symbol': 'Rp'},
    'SGD': {'name': 'Singapore Dollar', 'symbol': 'S\$'},
    'AUD': {'name': 'Australian Dollar', 'symbol': 'A\$'},
    'CAD': {'name': 'Canadian Dollar', 'symbol': 'C\$'},
    'CHF': {'name': 'Swiss Franc', 'symbol': 'CHF'},
    'CNY': {'name': 'Chinese Yuan', 'symbol': '¥'},
    'KRW': {'name': 'South Korean Won', 'symbol': '₩'},
    'THB': {'name': 'Thai Baht', 'symbol': '฿'},
    'MYR': {'name': 'Malaysian Ringgit', 'symbol': 'RM'},
    'HKD': {'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
    'NZD': {'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
  };

  static Map<String, double>? _exchangeRates;
  static DateTime? _lastFetchTime;

  // Cache exchange rates for 1 hour
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<Map<String, double>> getExchangeRates() async {
    // Return cached rates if still valid
    if (_exchangeRates != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _exchangeRates!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/USD'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _exchangeRates = Map<String, double>.from(data['rates']);
        _lastFetchTime = DateTime.now();
        return _exchangeRates!;
      } else {
        throw Exception('Failed to load exchange rates');
      }
    } catch (e) {
      // Return default rates if API fails
      _exchangeRates ??= {
        'USD': 1.0,
        'EUR': 0.85,
        'JPY': 110.0,
        'GBP': 0.73,
        'IDR': 15000.0,
        'SGD': 1.35,
        'AUD': 1.30,
        'CAD': 1.25,
        'CHF': 0.92,
        'CNY': 6.45,
        'KRW': 1180.0,
        'THB': 27.5,
        'MYR': 4.15,
        'HKD': 7.8,
        'NZD': 1.4,
      };
      _lastFetchTime = DateTime.now();
      return _exchangeRates!;
    }
  }

  static Future<double> convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) {
      return amount;
    }

    final rates = await getExchangeRates();

    // Convert to USD first, then to target currency
    final amountInUSD = fromCurrency == 'USD'
        ? amount
        : amount / (rates[fromCurrency] ?? 1.0);

    final convertedAmount = toCurrency == 'USD'
        ? amountInUSD
        : amountInUSD * (rates[toCurrency] ?? 1.0);

    return convertedAmount;
  }

  static String formatCurrency(double amount, String currencyCode) {
    final currencyInfo = supportedCurrencies[currencyCode];
    if (currencyInfo == null) return amount.toStringAsFixed(2);

    final symbol = currencyInfo['symbol'] ?? currencyCode;

    // Format based on currency
    switch (currencyCode) {
      case 'IDR':
        // Indonesian Rupiah - no decimal places for large amounts
        return '$symbol${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
      case 'JPY':
      case 'KRW':
        // Japanese Yen and Korean Won - no decimal places
        return '$symbol${amount.round()}';
      case 'EUR':
      case 'GBP':
      case 'CHF':
        // European currencies - use comma as decimal separator
        return '$symbol${amount.toStringAsFixed(2).replaceAll('.', ',')}';
      default:
        // Standard formatting for other currencies
        return '$symbol${amount.toStringAsFixed(2)}';
    }
  }

  static String getCurrencyName(String currencyCode) {
    return supportedCurrencies[currencyCode]?['name'] ?? currencyCode;
  }

  static String getCurrencySymbol(String currencyCode) {
    return supportedCurrencies[currencyCode]?['symbol'] ?? currencyCode;
  }

  static List<String> getSupportedCurrencyCodes() {
    return supportedCurrencies.keys.toList()..sort();
  }
}
