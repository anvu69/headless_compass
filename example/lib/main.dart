import 'dart:async';

import 'package:flutter/material.dart';
import 'package:headless_compass/headless_compass.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: HeadingScreen());
}

class HeadingScreen extends StatefulWidget {
  const HeadingScreen({super.key});

  @override
  State<HeadingScreen> createState() => _HeadingScreenState();
}

class _HeadingScreenState extends State<HeadingScreen> {
  final _compass = HeadingSource();

  StreamSubscription<HeadingSample>? _sub;
  bool? _available;
  HeadingSample? _sample;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Ask at runtime. Never infer from the device model: an iPad Air M3 WiFi
    // does have a magnetometer.
    final available = await _compass.isAvailable();
    if (!mounted) return;

    setState(() => _available = available);
    if (!available) return;

    _sub = _compass.watch().listen((sample) {
      // A negative accuracy is Apple saying "do not trust this". Showing it
      // anyway is showing a wrong number with no sign that it is wrong.
      if (!sample.isUsable || !mounted) return;
      setState(() => _sample = sample);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;

    return Scaffold(
      appBar: AppBar(title: const Text('headless_compass')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_available == null)
              const CircularProgressIndicator()
            else if (_available == false)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No magnetometer on this device.\n'
                  'Simulators always land here.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              Text(
                sample == null
                    ? '—'
                    : '${sample.deg.toStringAsFixed(1)}°',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                sample == null
                    ? 'waiting for the first reading'
                    : '±${sample.accuracyDeg.toStringAsFixed(0)}° · '
                        '${sample.kind.name}',
              ),
              const SizedBox(height: 24),
              // The only place that asks for location. Denial is not fatal:
              // the stream keeps running on magnetic heading.
              FilledButton(
                onPressed: () async {
                  final granted = await _compass.requestTrueNorth();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(granted
                          ? 'True north enabled'
                          : 'Denied — staying on magnetic heading'),
                    ),
                  );
                },
                child: const Text('Use true north'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
