import 'package:flutter/material.dart';

import 'public_shell.dart';
import 'app_layout.dart';

enum PublicDocument { terms, privacy }

class PublicInformationScreen extends StatelessWidget {
  const PublicInformationScreen({
    super.key,
    required this.document,
    required this.onNavigate,
  });

  final PublicDocument document;
  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final mobile = AppLayoutScope.isMobile(context);
    final privacy = document == PublicDocument.privacy;
    final title = privacy ? 'Privacy Policy' : 'Terms & Conditions';
    return Theme(
      data: publicTheme(context),
      child: Scaffold(
        backgroundColor: publicCream,
        appBar: mobile
            ? AppBar(
                backgroundColor: publicCream,
                leading: MobileBackButton(onNavigate: onNavigate),
                title: Text(title),
              )
            : null,
        body: SafeArea(
          top: false,
          bottom: mobile,
          left: mobile,
          right: mobile,
          child: Column(
            children: [
              if (!mobile)
                PublicHeaderBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: () => onNavigate('/'),
                            borderRadius: BorderRadius.circular(8),
                            child: PublicBrand(
                              light: true,
                              compact: MediaQuery.sizeOf(context).width < 600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () => onNavigate('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Home'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  primary: true,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: mobile ? 24 : 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              privacy
                                  ? Icons.privacy_tip_outlined
                                  : Icons.description_outlined,
                              color: publicGold,
                              size: 36,
                            ),
                            const SizedBox(height: 20),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: publicInk,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: publicBorder),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Publication Pending',
                                    style: TextStyle(
                                      color: publicInk,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    privacy
                                        ? 'Our privacy policy has not been published yet. Please contact the office with questions about your personal information.'
                                        : 'Our terms and conditions have not been published yet. Please contact the office for information about using our services.',
                                    style: const TextStyle(
                                      color: publicMuted,
                                      fontSize: 15,
                                      height: 1.7,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  OutlinedButton.icon(
                                    onPressed: () => onNavigate('/contact'),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 19,
                                    ),
                                    label: const Text('Contact Office'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () =>
                                  onNavigate(privacy ? '/terms' : '/privacy'),
                              child: Text(
                                privacy
                                    ? 'Terms & Conditions'
                                    : 'Privacy Policy',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!mobile) const PublicFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
