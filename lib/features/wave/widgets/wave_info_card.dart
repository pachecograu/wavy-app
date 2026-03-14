import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/models/wave.dart';
import '../providers/wave_provider.dart';
import '../../track/providers/track_provider.dart';

class WaveInfoCard extends StatefulWidget {
  final Wave wave;
  const WaveInfoCard({super.key, required this.wave});

  @override
  State<WaveInfoCard> createState() => _WaveInfoCardState();
}

class _WaveInfoCardState extends State<WaveInfoCard> {
  final Map<String, bool> _editing = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleEdit(String field, String currentValue) {
    setState(() {
      if (_editing[field] == true) {
        // Save
        final value = _controllers[field]?.text ?? currentValue;
        context.read<WaveProvider>().updateField(field, value);
        _editing[field] = false;
      } else {
        // Start editing
        _controllers[field] = TextEditingController(text: currentValue);
        _editing[field] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WaveProvider, TrackProvider>(
      builder: (context, wp, tp, _) {
        final isOwner = wp.isOwner;
        final state = wp.emisorState;
        final track = tp.currentTrack;
        final wave = widget.wave;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // State LED + text (top right)
              Row(
                children: [
                  const Spacer(),
                  _led(state, isOwner),
                  const SizedBox(width: 6),
                  _stateText(state, isOwner),
                ],
              ),
              const SizedBox(height: 8),

              // Avatar + genre + title (like AudiShare station header)
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: WavyTheme.borderColor, width: 2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: WavyTheme.textPrimary, width: 2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF32334F), Color(0xFF4F527E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
                      ),
                      child: const Icon(Icons.headphones, color: WavyTheme.primaryRed, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Genre (editable for owner)
                          _editableField(
                            field: 'genre',
                            value: wave.genre,
                            isOwner: isOwner,
                            style: TextStyle(
                              color: WavyTheme.textPrimary.withValues(alpha: 0.7),
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          // Title (editable for owner)
                          _editableField(
                            field: 'name',
                            value: wave.name,
                            isOwner: isOwner,
                            style: const TextStyle(
                              color: WavyTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Description (editable for owner)
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: WavyTheme.borderColor, width: 2)),
                ),
                child: _editableField(
                  field: 'description',
                  value: wave.description,
                  isOwner: isOwner,
                  style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 13),
                  multiline: true,
                ),
              ),
              const SizedBox(height: 10),

              // DJ + track info
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: WavyTheme.borderColor, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DJ name (editable for owner)
                    Row(
                      children: [
                        const Text('DJ: ', style: TextStyle(color: WavyTheme.textFaded, fontSize: 13)),
                        Expanded(
                          child: _editableField(
                            field: 'djName',
                            value: wave.djName,
                            isOwner: isOwner,
                            style: const TextStyle(color: WavyTheme.textPrimary, fontSize: 13),
                            inline: true,
                          ),
                        ),
                      ],
                    ),
                    if (track != null) ...[
                      _infoRow('Reproduciendo:', track.title, color: WavyTheme.cornflowerBlue),
                      if (track.artist.isNotEmpty) _infoRow('Por:', track.artist),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Reconnecting / disconnected banners
              if (!isOwner && state == EmisorState.reconnecting)
                _banner(Icons.sync, 'DJ reconectando...', Colors.orange),
              if (!isOwner && state == EmisorState.disconnected)
                _banner(Icons.signal_wifi_off, 'DJ desconectado', Colors.red),

              // Buttons row (listeners count)
              Row(
                children: [
                  _ctaBtn(Icons.headphones, '${wave.listenersCount}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _editableField({
    required String field,
    required String value,
    required bool isOwner,
    required TextStyle style,
    bool multiline = false,
    bool inline = false,
  }) {
    final isEditing = _editing[field] == true;

    if (!isOwner) {
      return Text(value, style: style, overflow: TextOverflow.ellipsis, maxLines: multiline ? 3 : 1);
    }

    return Row(
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (isEditing)
          Expanded(
            child: multiline
                ? TextField(
                    controller: _controllers[field],
                    style: style,
                    maxLines: 2,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: WavyTheme.textSecondary),
                      ),
                    ),
                  )
                : TextField(
                    controller: _controllers[field],
                    style: style,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: WavyTheme.textSecondary),
                      ),
                    ),
                  ),
          )
        else
          Expanded(
            child: Text(value, style: style, overflow: TextOverflow.ellipsis, maxLines: multiline ? 3 : 1),
          ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _toggleEdit(field, value),
          child: Icon(
            isEditing ? Icons.check : Icons.edit,
            size: 14,
            color: WavyTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _led(EmisorState s, bool owner) {
    Color c = owner
        ? WavyTheme.greenOnline
        : s == EmisorState.connected
            ? WavyTheme.greenOnline
            : s == EmisorState.reconnecting
                ? Colors.orange
                : Colors.red;
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }

  Widget _stateText(EmisorState s, bool owner) {
    if (owner) return const Text('EN VIVO', style: TextStyle(color: WavyTheme.greenOnline, fontSize: 12, fontWeight: FontWeight.w700));
    switch (s) {
      case EmisorState.connected:
        return const Text('EN VIVO', style: TextStyle(color: WavyTheme.greenOnline, fontSize: 12, fontWeight: FontWeight.w700));
      case EmisorState.reconnecting:
        return const Text('RECONECTANDO', style: TextStyle(color: Colors.orange, fontSize: 12));
      case EmisorState.disconnected:
      case EmisorState.offline:
        return const Text('DESCONECTADO', style: TextStyle(color: Colors.red, fontSize: 12));
      default:
        return const Text('EN VIVO', style: TextStyle(fontSize: 12));
    }
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: WavyTheme.textFaded, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value, style: TextStyle(color: color ?? WavyTheme.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _banner(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _ctaBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WavyTheme.accentRed,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WavyTheme.ctaPink, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: WavyTheme.ctaPink, fontSize: 13)),
        ],
      ),
    );
  }
}
