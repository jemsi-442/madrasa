import 'package:flutter/material.dart';

import 'api_client.dart';
import 'foundation_ui.dart';
import 'public_pages.dart';

enum _JoiningAs { child, adult, parent }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.api,
    required this.onNavigate,
  });

  final MifApiClient api;
  final PublicNavigate onNavigate;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final studentController = TextEditingController();
  final noteController = TextEditingController();
  _JoiningAs joiningAs = _JoiningAs.child;
  bool sending = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    studentController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending || !formKey.currentState!.validate()) return;
    setState(() {
      sending = true;
      error = null;
    });

    final subject = switch (joiningAs) {
      _JoiningAs.child => 'Child admission',
      _JoiningAs.adult => 'Online course enrollment',
      _JoiningAs.parent => 'Parent access',
    };
    final description = switch (joiningAs) {
      _JoiningAs.child => 'I would like to enroll my child.',
      _JoiningAs.adult => 'I would like to join an online course.',
      _JoiningAs.parent =>
        'I am a parent and would like access to my child’s school information.',
    };
    final student = studentController.text.trim();
    final note = noteController.text.trim();
    final message = [
      description,
      if (joiningAs != _JoiningAs.adult && student.isNotEmpty)
        'Student: $student.',
      if (note.isNotEmpty) 'Additional details: $note',
    ].join(' ');

    try {
      await widget.api.request(
        '/api/public/inquiries',
        method: 'POST',
        body: {
          'inquiryType': joiningAs == _JoiningAs.parent
              ? 'PARENT_SUPPORT'
              : 'ADMISSIONS',
          'fullName': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'subject': subject,
          'message': message,
          'preferredContact': 'phone',
          'sourcePage': joiningAs == _JoiningAs.parent
              ? 'parent-access'
              : 'admissions',
        },
      );
      if (mounted) setState(() => sent = true);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PublicFrame(
      path: '/register',
      onNavigate: widget.onNavigate,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 40 : 18,
              vertical: wide ? 55 : 26,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 8, child: _RegistrationIntro()),
                          const SizedBox(width: 62),
                          Expanded(flex: 11, child: _form()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _RegistrationIntro(),
                          const SizedBox(height: 20),
                          _form(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _form() {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    if (sent) {
      return SurfacePanel(
        padding: const EdgeInsets.all(34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 29,
              backgroundColor: Color(0xFFE7F3EB),
              child: Icon(Icons.check_rounded, color: forest, size: 31),
            ),
            const SizedBox(height: 23),
            Text(
              'Your details are in.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 13),
            const Text(
              'The foundation office will contact you about the next step. An account has not been opened yet.',
              style: TextStyle(color: muted, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 27),
            FilledButton.icon(
              onPressed: () => widget.onNavigate('/'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to home'),
            ),
          ],
        ),
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.all(narrow ? 22 : 27),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (narrow) ...[
              const SectionLabel('Choose your path'),
              const SizedBox(height: 19),
            ] else ...[
              const SectionLabel('Start here'),
              const SizedBox(height: 11),
              Text(
                'Tell us about you.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose how you would like to join.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 25),
            ],
            _JoiningChoices(
              selected: joiningAs,
              onChanged: (value) => setState(() => joiningAs = value),
            ),
            const SizedBox(height: 25),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 8
                  ? 'Enter a valid phone number.'
                  : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            if (joiningAs != _JoiningAs.adult) ...[
              const SizedBox(height: 15),
              TextFormField(
                controller: studentController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Child’s name',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter the child’s name.'
                    : null,
              ),
            ],
            const SizedBox(height: 15),
            TextFormField(
              controller: noteController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Anything else? (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 11),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFF9B3528)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                iconAlignment: IconAlignment.end,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: const Text('Send details'),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'The office will guide you through the next step.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationIntro extends StatelessWidget {
  const _RegistrationIntro();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: EdgeInsets.only(top: narrow ? 0 : 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Join the foundation'),
          const SizedBox(height: 17),
          Text(
            'A new chapter\nstarts here.',
            style: TextStyle(
              color: ink,
              fontFamily: 'NotoSerifDisplay',
              fontSize: narrow ? 38 : 51,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 17),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: const Text(
              'For your child, for yourself or for your family, choose a path below.',
              style: TextStyle(color: muted, height: 1.5, fontSize: 16),
            ),
          ),
          if (!narrow) ...[
            const SizedBox(height: 43),
            Container(width: 180, height: 2, color: gold),
            const SizedBox(height: 25),
            const BrandMark(),
          ],
        ],
      ),
    );
  }
}

class _JoiningChoices extends StatelessWidget {
  const _JoiningChoices({required this.selected, required this.onChanged});

  final _JoiningAs selected;
  final ValueChanged<_JoiningAs> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 390;
        final options = [
          (_JoiningAs.child, Icons.school_outlined, 'For my child'),
          (_JoiningAs.adult, Icons.auto_stories_outlined, 'For myself'),
          (_JoiningAs.parent, Icons.family_restroom_rounded, 'Parent access'),
        ];
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: options.map((option) {
            final active = selected == option.$1;
            return SizedBox(
              width: stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 18) / 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => onChanged(option.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFFF5DF) : paper,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: active ? gold : line,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(option.$2, size: 19, color: active ? ink : muted),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          option.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
