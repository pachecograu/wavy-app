import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wave_provider.dart';

class BitsVisualizationWidget extends StatefulWidget {
  const BitsVisualizationWidget({super.key});

  @override
  State<BitsVisualizationWidget> createState() => _BitsVisualizationWidgetState();
}

class _BitsVisualizationWidgetState extends State<BitsVisualizationWidget>
    with TickerProviderStateMixin {
  String _currentBits = '';
  int _totalBytes = 0;
  String _lastUpdate = '';
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateBits(String bitsData, int byteSize) {
    if (mounted) {
      setState(() {
        _currentBits = bitsData;
        _totalBytes += byteSize;
        _lastUpdate = DateTime.now().toString().substring(11, 19);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WaveProvider>(
      builder: (context, waveProvider, child) {
        // Solo mostrar para oyentes
        if (waveProvider.currentWave == null || waveProvider.isOwner) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Icon(
                        Icons.radio,
                        color: Colors.red.withOpacity(_pulseAnimation.value),
                        size: 20,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TRANSMISIÓN EN VIVO',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _currentBits.isEmpty 
                        ? '00000000 11111111 01010101 10101010 00110011 11001100...'
                        : _formatBits(_currentBits),
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📊 $_totalBytes bytes',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '⏰ $_lastUpdate',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatBits(String bits) {
    if (bits.isEmpty) return '';
    
    // Agregar espacios cada 8 bits para mejor legibilidad
    String formatted = '';
    for (int i = 0; i < bits.length; i += 8) {
      if (i + 8 <= bits.length) {
        formatted += bits.substring(i, i + 8) + ' ';
      } else {
        formatted += bits.substring(i);
      }
    }
    return formatted.trim();
  }
}