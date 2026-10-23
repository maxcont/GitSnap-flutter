import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';

class UpdateButton extends StatefulWidget {
  const UpdateButton({super.key});

  @override
  State<UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<UpdateButton> {
  UpdateService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<UpdateService>();
    if (identical(service, _service)) return;
    _service?.removeListener(_onUpdateChanged);
    _service = service;
    service.addListener(_onUpdateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(service.initialize());
    });
  }

  void _onUpdateChanged() {
    final message = _service?.errorMessage;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  @override
  void dispose() {
    _service?.removeListener(_onUpdateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<UpdateService>();
    if (!service.enabled) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.system_update_alt),
      tooltip: 'Controlla aggiornamenti - GitSnap ${UpdateService.version}',
      onPressed: service.checkForUpdates,
    );
  }
}
