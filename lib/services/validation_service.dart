// lib/services/validation_service.dart
import 'package:flutter/foundation.dart';

/// Simple validation service that checks a Map(String, dynamic) row against a schema.
/// Schema example:
/// {
///   'product_name': {'type': 'string', 'nullable': false},
///   'quantity': {'type': 'number', 'nullable': true},
/// }
class ValidationService {
  /// Validate single row. Returns {'ok': true} or {'ok': false, 'errors': [...]}
  Map<String, dynamic> validateRow(
    Map<String, dynamic> row,
    Map<String, dynamic> schema,
  ) {
    final errors = <String>[];
    try {
      for (final entry in schema.entries) {
        final col = entry.key;
        final rules = Map<String, dynamic>.from(entry.value as Map);
        final value = row[col];

        final isNullable = rules['nullable'] == true;
        final type = (rules['type'] ?? 'string').toString().toLowerCase();

        if (value == null || (value is String && value.trim().isEmpty)) {
          if (!isNullable) errors.add('Column "$col" is required');
          continue;
        }

        switch (type) {
          case 'string':
            if (value is! String) errors.add('Column "$col" must be a string');
            break;
          case 'number':
          case 'int':
          case 'double':
            if (value is! num) {
              // attempt to parse numbers from strings
              if (value is String) {
                final parsed = num.tryParse(value);
                if (parsed == null) {
                  errors.add('Column "$col" must be a number');
                }
              } else {
                errors.add('Column "$col" must be a number');
              }
            }
            break;
          case 'date':
            if (value is! DateTime) {
              if (value is String) {
                final parsed = DateTime.tryParse(value);
                if (parsed == null) {
                  errors.add('Column "$col" must be a valid ISO date string');
                }
              } else {
                errors.add('Column "$col" must be a date');
              }
            }
            break;
          case 'boolean':
            if (value is! bool) errors.add('Column "$col" must be boolean');
            break;
          default:
            errors.add('Unknown type for "$col": $type');
        }
      }
    } catch (e) {
      if (kDebugMode) print('validateRow error: $e');
      return {
        'ok': false,
        'errors': ['validation exception'],
      };
    }
    if (errors.isEmpty) return {'ok': true};
    return {'ok': false, 'errors': errors};
  }
}
