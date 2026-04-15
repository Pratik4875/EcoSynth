import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart' show themeNotifier;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final List<StreamSubscription<dynamic>> _subs = [];

  // Telemetry
  int _batteryPercent = 0;
  double _voltage = 0.0;

  // Connection state — two separate signals:
  // _firebaseConnected: does the Flutter app have a live socket to Firebase?
  // _espLive:           is the ESP8266 actively pushing telemetry? (watchdog)
  bool _firebaseConnected = false;
  bool _espLive = false;
  Timer? _espWatchdog;

  // IMPORTANT: set this >= your ESP8266 data push interval (in seconds).
  // If ESP pushes every 10s, set to 30s. Default: 30 seconds.
  static const int _espTimeoutSeconds = 30;

  // Controls (local mirror)
  bool _charger = false;
  bool _pump = false;
  bool _mist = false;

  // UI state
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  // ── Stream Management ─────────────────────────────────────────────────────

  void _attachListeners() {
    // 1. Firebase socket connection — reflects phone→Firebase connectivity.
    //    Does NOT indicate whether the ESP8266 is online.
    _subs.add(
      FirebaseDatabase.instance.ref('.info/connected').onValue.listen(
        (event) {
          if (mounted) {
            setState(() => _firebaseConnected = event.snapshot.value as bool? ?? false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _firebaseConnected = false);
        },
      ),
    );

    // 2. Telemetry listeners — reset the ESP watchdog on every fresh update.
    _subs.add(
      _db.child('telemetry/percentage').onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v != null && mounted) {
            setState(() => _batteryPercent = (v as num).toInt().clamp(0, 100));
            _resetEspWatchdog(); // ESP just sent data → mark as live
          }
        },
        onError: (e) => _handleStreamError('telemetry/percentage', e),
      ),
    );

    _subs.add(
      _db.child('telemetry/voltage').onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v != null && mounted) {
            setState(() => _voltage = (v as num).toDouble());
            _resetEspWatchdog(); // ESP just sent data → mark as live
          }
        },
        onError: (e) => _handleStreamError('telemetry/voltage', e),
      ),
    );

    _subs.add(
      _db.child('control/charger_relay').onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v != null && !_writing && mounted) {
            setState(() => _charger = v as bool);
          }
        },
        onError: (e) => _handleStreamError('control/charger_relay', e),
      ),
    );

    _subs.add(
      _db.child('control/pump').onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v != null && !_writing && mounted) {
            setState(() => _pump = v as bool);
          }
        },
        onError: (e) => _handleStreamError('control/pump', e),
      ),
    );

    _subs.add(
      _db.child('control/mist').onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v != null && !_writing && mounted) {
            setState(() => _mist = v as bool);
          }
        },
        onError: (e) => _handleStreamError('control/mist', e),
      ),
    );
  }

  void _handleStreamError(String path, dynamic error) {
    debugPrint('Firebase stream error [$path]: $error');
  }

  /// Resets the ESP watchdog timer. Called every time fresh telemetry arrives.
  /// If no data arrives within [_espTimeoutSeconds], _espLive becomes false.
  void _resetEspWatchdog() {
    _espWatchdog?.cancel();
    if (!_espLive && mounted) setState(() => _espLive = true);
    _espWatchdog = Timer(const Duration(seconds: _espTimeoutSeconds), () {
      if (mounted) setState(() => _espLive = false);
    });
  }

  @override
  void dispose() {
    _espWatchdog?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // ── Safety Interlock Logic ────────────────────────────────────────────────
  // RULE: Charger and actuators CANNOT be ON at the same time.
  // Turning ON Pump/Mist → forces Charger OFF first.
  // Turning ON Charger   → forces Pump + Mist OFF first.

  Future<void> _toggle(String device, bool newValue) async {
    if (_writing) return;

    // Save snapshot for rollback
    final prevCharger = _charger;
    final prevPump = _pump;
    final prevMist = _mist;

    if (!mounted) return;
    setState(() {
      _writing = true;
    });

    try {
      if (newValue && (device == 'pump' || device == 'mist')) {
        if (_charger) {
          await _db.child('control/charger_relay').set(false);
          if (mounted) setState(() => _charger = false);
        }
      } else if (newValue && device == 'charger_relay') {
        if (_pump) {
          await _db.child('control/pump').set(false);
          if (mounted) setState(() => _pump = false);
        }
        if (_mist) {
          await _db.child('control/mist').set(false);
          if (mounted) setState(() => _mist = false);
        }
      }

      // ── Write the target node ─────────────────────────────────────────────
      await _db.child('control/$device').set(newValue);
      if (mounted) {
        setState(() {
          if (device == 'charger_relay') _charger = newValue;
          if (device == 'pump') _pump = newValue;
          if (device == 'mist') _mist = newValue;
        });
      }
    } on FirebaseException catch (e) {
      _rollback(prevCharger, prevPump, prevMist);
      _showError('Firebase: ${e.message ?? e.code}');
    } catch (e) {
      _rollback(prevCharger, prevPump, prevMist);
      _showError('Write failed — check connection.');
      debugPrint('Toggle error: $e');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _rollback(bool c, bool p, bool m) {
    if (mounted) {
      setState(() {
        _charger = c;
        _pump = p;
        _mist = m;
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    // Status: green only when ESP is actively sending data
    final bool fullyOnline = _firebaseConnected && _espLive;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, primary, fullyOnline),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Connection banner
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: !fullyOnline
                        ? _DisconnectedBanner(
                            key: const ValueKey('banner'),
                            firebaseOk: _firebaseConnected,
                            espLive: _espLive,
                          )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                  const SizedBox(height: 22),

                  _SectionLabel(label: 'TELEMETRY'),
                  const SizedBox(height: 12),
                  _TelemetryRow(
                    batteryPercent: _batteryPercent,
                    voltage: _voltage,
                  ),
                  const SizedBox(height: 30),

                  _SectionLabel(label: 'CONTROL PANEL'),
                  const SizedBox(height: 12),
                  _ControlPanel(
                    charger: _charger,
                    pump: _pump,
                    mist: _mist,
                    writing: _writing,
                    onToggle: _toggle,
                  ),
                  const SizedBox(height: 24),

                  _InterlockNote(),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Color primary, bool fullyOnline) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 72,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        title: Row(
          children: [
            // Status dot — green ONLY when ESP8266 is actively sending data
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: fullyOnline ? primary : Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (fullyOnline ? primary : Colors.redAccent)
                        .withValues(alpha: 0.55),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'EcoSynth',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111111),
              ),
            ),
            const Spacer(),
            // Status label
            Text(
              fullyOnline ? 'ESP LIVE' : (_firebaseConnected ? 'ESP OFFLINE' : 'NO NETWORK'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: fullyOnline
                    ? primary
                    : (_firebaseConnected ? Colors.orangeAccent : Colors.redAccent),
              ),
            ),
            const SizedBox(width: 6),
            // Theme toggle — inline
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (_, mode, __) {
                final dark = mode == ThemeMode.dark;
                return GestureDetector(
                  onTap: () => themeNotifier.value =
                      dark ? ThemeMode.light : ThemeMode.dark,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      key: ValueKey(dark),
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Subwidgets (stateless, pure) ─────────────────────────────────────────────


class _DisconnectedBanner extends StatelessWidget {
  final bool firebaseOk;
  final bool espLive;

  const _DisconnectedBanner({
    super.key,
    required this.firebaseOk,
    required this.espLive,
  });

  @override
  Widget build(BuildContext context) {
    // Choose message based on which layer is offline
    final bool isEspOffline = firebaseOk && !espLive;
    final color = isEspOffline ? Colors.orangeAccent : Colors.redAccent;
    final icon = isEspOffline
        ? Icons.device_unknown_rounded
        : Icons.wifi_off_rounded;
    final message = isEspOffline
        ? 'ESP8266 offline — no telemetry received in the last ${_DashboardScreenState._espTimeoutSeconds}s.'
        : 'Firebase offline — check credentials, network, and database rules.';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 11,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final int batteryPercent;
  final double voltage;

  const _TelemetryRow({required this.batteryPercent, required this.voltage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TelemetryCard(
            value: '$batteryPercent%',
            label: 'Battery',
            icon: _batteryIcon(batteryPercent),
            accentColor: _batteryColor(batteryPercent),
            subLabel: batteryPercent < 20 ? '⚠ Low — charge now' : 'Level normal',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _TelemetryCard(
            value: '${voltage.toStringAsFixed(2)} V',
            label: 'Voltage',
            icon: Icons.bolt_rounded,
            accentColor: Colors.lightBlueAccent,
            subLabel: '3.20 – 4.20 V range',
          ),
        ),
      ],
    );
  }

  static IconData _batteryIcon(int pct) {
    if (pct >= 80) return Icons.battery_full_rounded;
    if (pct >= 60) return Icons.battery_5_bar_rounded;
    if (pct >= 40) return Icons.battery_3_bar_rounded;
    if (pct >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  static Color _batteryColor(int pct) {
    if (pct > 50) return const Color(0xFF00C9A7);
    if (pct > 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _TelemetryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accentColor;
  final String subLabel;

  const _TelemetryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111111),
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subLabel,
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final bool charger;
  final bool pump;
  final bool mist;
  final bool writing;
  final Future<void> Function(String device, bool value) onToggle;

  const _ControlPanel({
    required this.charger,
    required this.pump,
    required this.mist,
    required this.writing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divColor = isDark
        ? const Color(0xFF252529)
        : const Color(0xFFEEEEF4);

    return Card(
      child: Column(
        children: [
          // Charger — AMBER (visually distinct: power source, not actuator)
          _ControlTile(
            label: 'Charger',
            subtitle: 'TP4056 Charging Relay',
            icon: Icons.electrical_services_rounded,
            value: charger,
            activeColor: const Color(0xFFFFB830),
            disabled: writing,
            onChanged: (v) => onToggle('charger_relay', v),
            warning: (pump || mist)
                ? 'Actuators running — enabling will shut them off'
                : null,
          ),
          Divider(color: divColor, height: 1, thickness: 1),
          // Water Pump — Teal
          _ControlTile(
            label: 'Water Pump',
            subtitle: '5V Actuator via MOSFET',
            icon: Icons.water_drop_rounded,
            value: pump,
            activeColor: const Color(0xFF00C9A7),
            disabled: writing,
            onChanged: (v) => onToggle('pump', v),
            warning: (charger && !pump)
                ? 'Charger ON — will be disabled automatically'
                : null,
          ),
          Divider(color: divColor, height: 1, thickness: 1),
          // Mist Maker — Teal
          _ControlTile(
            label: 'Mist Maker',
            subtitle: '5V Ultrasonic via Relay',
            icon: Icons.cloud_rounded,
            value: mist,
            activeColor: const Color(0xFF00C9A7),
            disabled: writing,
            onChanged: (v) => onToggle('mist', v),
            warning: (charger && !mist)
                ? 'Charger ON — will be disabled automatically'
                : null,
          ),
        ],
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final bool disabled;
  final ValueChanged<bool> onChanged;
  final String? warning;

  const _ControlTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.activeColor,
    required this.disabled,
    required this.onChanged,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: value,
            onChanged: disabled ? null : onChanged,
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF111111),
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 12,
              ),
            ),
            secondary: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: value
                    ? activeColor.withValues(alpha: isDark ? 0.15 : 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: value
                    ? activeColor
                    : (isDark ? Colors.white24 : Colors.black26),
                size: 24,
              ),
            ),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return activeColor;
              return isDark ? Colors.white38 : Colors.black26;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return activeColor.withValues(alpha: 0.28);
              }
              return isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06);
            }),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          if (warning != null)
            Padding(
              padding:
                  const EdgeInsets.only(left: 72, right: 16, bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 13, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning!,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InterlockNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_rounded,
              size: 16,
              color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Safety Interlock Active — Charging and actuation are mutually exclusive to protect the TP4056 module and 18650 cell.',
              style: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
