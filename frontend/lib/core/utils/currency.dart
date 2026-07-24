import 'package:intl/intl.dart';

final _ghsFormat = NumberFormat.currency(locale: 'en_GH', symbol: 'GH₵', decimalDigits: 2);

String formatGhs(num amount) => _ghsFormat.format(amount);
