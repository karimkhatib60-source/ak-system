import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

/// Opens the client form. Returns the saved client's id.
Future<String?> openClientForm(BuildContext context, {Client? client}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ClientForm(client: client),
    ),
  );
}

class ClientForm extends StatefulWidget {
  const ClientForm({super.key, this.client});

  final Client? client;

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client?.name ?? '');
  late final _company = TextEditingController(
    text: widget.client?.company ?? '',
  );
  late final _phone = TextEditingController(text: widget.client?.phone ?? '');
  late final _email = TextEditingController(text: widget.client?.email ?? '');
  late final _country = TextEditingController(
    text: (widget.client?.country ?? 'Lebanon').tr,
  );
  late final _notes = TextEditingController(text: widget.client?.notes ?? '');

  @override
  void dispose() {
    for (final c in [_name, _company, _phone, _email, _country, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final c = widget.client;
    final now = repo.now();
    final id = c?.id ?? repo.newId();
    await repo.saveClient(
      Client(
        id: id,
        createdAt: c?.createdAt ?? now,
        updatedAt: now,
        name: _name.text.trim(),
        company: _company.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        country: _country.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'New client'.tr : 'Edit client'.tr),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(onPressed: _save, child: Text('Save'.tr)),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: widget.client == null,
                decoration: InputDecoration(labelText: 'Client name'.tr),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name'.tr : null,
              ),
              gap,
              TextFormField(
                controller: _company,
                decoration: InputDecoration(labelText: 'Company (if any)'.tr),
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone / WhatsApp'.tr,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _country,
                      decoration: InputDecoration(labelText: 'Country'.tr),
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email'.tr),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(labelText: 'Notes'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
