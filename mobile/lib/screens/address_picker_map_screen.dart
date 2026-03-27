import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/osm_geocoding_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';

class AddressPickerMapScreen extends StatefulWidget {
  const AddressPickerMapScreen({super.key, this.initialSelection});

  final LatLng? initialSelection;

  @override
  State<AddressPickerMapScreen> createState() => _AddressPickerMapScreenState();
}

class _AddressPickerMapScreenState extends State<AddressPickerMapScreen> {
  static const LatLng _defaultBrazilCenter = LatLng(-14.235004, -51.92528);

  final OsmGeocodingService _geocodingService = OsmGeocodingService();

  LatLng? _selectedPoint;
  String _userAgentPackageName = 'com.example.rv_sistema_mobile';
  bool _resolvingAddress = false;
  bool _tileLoadIssue = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialSelection;
    _loadPackageName();
  }

  Future<void> _loadPackageName() async {
    final packageName = await OsmGeocodingService.resolvePackageName();
    if (!mounted) return;
    setState(() => _userAgentPackageName = packageName);
  }

  void _selectPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
    });
  }

  Future<void> _confirmSelection() async {
    final selectedPoint = _selectedPoint;
    if (selectedPoint == null) {
      _showSnackBar('Selecione um ponto no mapa antes de continuar.');
      return;
    }

    setState(() => _resolvingAddress = true);

    try {
      final resolvedAddress = await _geocodingService.reverseGeocode(
        latitude: selectedPoint.latitude,
        longitude: selectedPoint.longitude,
      );
      if (!mounted) return;
      if (resolvedAddress == null || resolvedAddress.trim().isEmpty) {
        _showSnackBar(
          'Nao foi possivel obter o endereco automaticamente. Voce pode voltar e preencher manualmente.',
        );
        return;
      }
      Navigator.of(context).pop(resolvedAddress);
    } on OsmGeocodingException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Nao foi possivel obter o endereco automaticamente. Voce pode voltar e preencher manualmente.',
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initialCenter = _selectedPoint ?? _defaultBrazilCenter;
    final initialZoom = _selectedPoint == null ? 4.5 : 16.5;

    return AppScaffold(
      title: 'Selecionar endereco',
      subtitle: 'Toque ou pressione o mapa para marcar o local',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O endereco sera preenchido no cadastro e continuara editavel manualmente antes de salvar.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: initialZoom,
                      onTap: (_, point) => _selectPoint(point),
                      onLongPress: (_, point) => _selectPoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: OsmGeocodingService.tileUrlTemplate,
                        userAgentPackageName: _userAgentPackageName,
                        maxNativeZoom: 19,
                        errorTileCallback: (_, __, ___) {
                          if (!_tileLoadIssue && mounted) {
                            setState(() => _tileLoadIssue = true);
                          }
                        },
                      ),
                      if (_selectedPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedPoint!,
                              width: 56,
                              height: 56,
                              child: const _AddressMarker(),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppDarkColors.surface2.withValues(alpha: 0.94)
                            : theme.colorScheme.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(
                          _selectedPoint == null
                              ? 'Toque no mapa para escolher o ponto do endereco.'
                              : 'Ponto selecionado: ${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  if (_tileLoadIssue)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Text(
                            'Nao foi possivel carregar todos os tiles do mapa. Se necessario, volte e preencha o endereco manualmente.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppDarkColors.backgroundSecondary.withValues(alpha: 0.92)
                            : theme.colorScheme.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          'Mapas © OpenStreetMap contributors',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _resolvingAddress ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _resolvingAddress ? null : _confirmSelection,
                  icon: _resolvingAddress
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _resolvingAddress
                        ? 'Consultando...'
                        : 'Usar este endereco',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressMarker extends StatelessWidget {
  const _AddressMarker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.location_on_rounded,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
