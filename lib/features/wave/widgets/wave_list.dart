import 'package:flutter/material.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/models/wave.dart';

class WaveList extends StatefulWidget {
  final List<Wave> waves;
  final Function(Wave) onWaveTap;
  final VoidCallback? onClose;
  final String? activeWaveId;

  const WaveList({
    super.key,
    required this.waves,
    required this.onWaveTap,
    this.onClose,
    this.activeWaveId,
  });

  @override
  State<WaveList> createState() => _WaveListState();
}

class _WaveListState extends State<WaveList> {
  String _search = '';
  String _sortBy = 'listeners';

  List<Wave> get _filtered {
    var list = widget.waves.where((w) {
      if (_search.isEmpty) return true;
      return w.name.toLowerCase().contains(_search.toLowerCase()) ||
          w.djName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    if (_sortBy == 'listeners') {
      list.sort((a, b) => b.listenersCount.compareTo(a.listenersCount));
    } else {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  String get _sortLabel => _sortBy == 'listeners' ? 'Cantidad escuchando' : 'Nombre wave';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WavyTheme.cardBackground,
      child: Column(
        children: [
          // Header with search
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: WavyTheme.textPrimary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: WavyTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Buscar wave...',
                      hintStyle: TextStyle(color: WavyTheme.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.cancel, color: WavyTheme.textPrimary, size: 22),
                  ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radio, size: 60, color: WavyTheme.textSecondary),
                        SizedBox(height: 12),
                        Text('No hay waves en línea', style: TextStyle(color: WavyTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final wave = _filtered[i];
                      final isActive = wave.id == widget.activeWaveId;
                      return _WaveItem(
                        wave: wave,
                        isActive: isActive,
                        isOdd: i.isOdd,
                        onTap: () => widget.onWaveTap(wave),
                      );
                    },
                  ),
          ),
          // Footer sort
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
            child: Row(
              children: [
                const Icon(Icons.sort, color: WavyTheme.textPrimary, size: 16),
                const SizedBox(width: 6),
                const Text('Filtrar: ', style: TextStyle(color: WavyTheme.textFaded, fontSize: 13)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _sortBy = _sortBy == 'listeners' ? 'name' : 'listeners';
                    });
                  },
                  child: Text(_sortLabel, style: const TextStyle(color: WavyTheme.cornflowerBlue, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveItem extends StatelessWidget {
  final Wave wave;
  final bool isActive;
  final bool isOdd;
  final VoidCallback onTap;

  const _WaveItem({required this.wave, required this.isActive, required this.isOdd, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        color: isActive
            ? WavyTheme.activeBg
            : isOdd
                ? WavyTheme.itemBgOdd
                : WavyTheme.itemBgEven,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: WavyTheme.textPrimary, width: 2),
                gradient: const LinearGradient(colors: [Color(0xFF32334F), Color(0xFF4F527E)]),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
              ),
              child: const Icon(Icons.headphones, color: WavyTheme.primaryRed, size: 20),
            ),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wave.name,
                          style: TextStyle(
                            color: isActive ? WavyTheme.primaryRed : WavyTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.headphones, color: WavyTheme.cornflowerBlue, size: 13),
                      const SizedBox(width: 3),
                      Text('${wave.listenersCount}', style: const TextStyle(color: WavyTheme.cornflowerBlue, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'DJ: ${wave.djName}',
                    style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Online LED
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 18, left: 8),
              decoration: BoxDecoration(
                color: wave.isOnline ? WavyTheme.greenOnline : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
