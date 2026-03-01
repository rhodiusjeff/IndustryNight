import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/google_places_service.dart';

/// A TextFormField with Google Places address autocomplete.
///
/// Falls back to a plain TextFormField when no Google Places API key
/// is configured via --dart-define.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final ValueChanged<PlacePrediction>? onAddressSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.decoration,
    this.validator,
    this.onAddressSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  GooglePlacesService? _placesService;
  Timer? _debounceTimer;
  List<PlacePrediction> _suggestions = [];
  bool _suppressAutocomplete = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasGooglePlaces) {
      _placesService = GooglePlacesService();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _placesService?.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_suppressAutocomplete) {
      _suppressAutocomplete = false;
      return;
    }
    _debounceTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _placesService?.getAutocompletePredictions(value);
      if (mounted) {
        setState(() => _suggestions = results ?? []);
      }
    });
  }

  void _onSuggestionSelected(PlacePrediction prediction) {
    _suppressAutocomplete = true;
    widget.controller.text = prediction.fullText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    setState(() => _suggestions = []);
    _placesService?.resetSession();
    widget.onAddressSelected?.call(prediction);
  }

  @override
  Widget build(BuildContext context) {
    // No API key — plain TextFormField (identical to current behavior)
    if (_placesService == null) {
      return TextFormField(
        controller: widget.controller,
        decoration: widget.decoration,
        validator: widget.validator,
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() => _suggestions = []);
                      _placesService?.resetSession();
                    },
                  )
                : const Icon(Icons.location_on_outlined, size: 18),
          ),
          validator: widget.validator,
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prediction = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(
                    prediction.mainText,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    prediction.secondaryText,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _onSuggestionSelected(prediction),
                );
              },
            ),
          ),
      ],
    );
  }
}
