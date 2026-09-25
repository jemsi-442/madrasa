import 'package:flutter/material.dart';

import 'public_shell.dart';

class PublicSiteFooter extends StatelessWidget {
  const PublicSiteFooter({super.key, required this.onNavigate});

  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Material(
      color: publicBrandBlue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const introduction = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For schools. For families.\nFor the future.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Faith, knowledge and a community that grows together.',
                          style: TextStyle(
                            color: Color(0xFFBCCBDC),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: 20),
                        _TelegramIcon(),
                      ],
                    );
                    final support = _FooterLinks(
                      title: 'Support',
                      links: const [
                        ('Contact Office', '/contact'),
                        ('Parent Access', '/parent-access'),
                        ('Help Signing In', '/forgot-password'),
                      ],
                      onNavigate: onNavigate,
                    );
                    final information = _FooterLinks(
                      title: 'Information',
                      links: const [
                        ('Terms & Conditions', '/terms'),
                        ('Privacy Policy', '/privacy'),
                      ],
                      onNavigate: onNavigate,
                    );
                    if (constraints.maxWidth >= 850) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 5, child: introduction),
                          const SizedBox(width: 64),
                          Expanded(flex: 3, child: support),
                          const SizedBox(width: 40),
                          Expanded(flex: 3, child: information),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        introduction,
                        const SizedBox(height: 32),
                        if (constraints.maxWidth >= 250)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: support),
                              const SizedBox(width: 24),
                              Expanded(child: information),
                            ],
                          )
                        else ...[
                          support,
                          const SizedBox(height: 24),
                          information,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const PublicFooter(showDivider: true),
        ],
      ),
    ),
  );
}

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 46,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF123652),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF52708B)),
      ),
      child: const IconButton(
        key: ValueKey('footer-telegram'),
        tooltip: 'Telegram link coming soon',
        onPressed: null,
        disabledColor: Color(0xFFD3E0ED),
        icon: Icon(Icons.telegram, size: 24),
      ),
    ),
  );
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({
    required this.title,
    required this.links,
    required this.onNavigate,
  });

  final String title;
  final List<(String, String)> links;
  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
            color: publicHeaderAccent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      for (final (label, path) in links)
        TextButton(
          key: ValueKey('footer-link-$path'),
          onPressed: () => onNavigate(path),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE3EAF2),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: const Size(48, 44),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansDisplay',
              fontSize: 14,
              height: 1.4,
            ),
          ),
          child: Text(label),
        ),
    ],
  );
}
