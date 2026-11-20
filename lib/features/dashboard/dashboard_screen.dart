import 'package:flutter/material.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/neo_card.dart';
import '../../core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const actions = <(String, IconData)>[
    ('उधार एंट्री', Icons.add_card),
    ('उधार वापसी', Icons.assignment_return),
    ('मासिक जमा', Icons.savings_outlined),
    ('खर्च', Icons.receipt_long),
    ('अतिरिक्त राशि', Icons.add_circle_outline),
    ('पैसा वितरण', Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('हमारी चिट फण्ड फैमिली 2.0',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('मेन्यू स्क्रीन अगले चरण में जोड़ी जाएगी।')),
                  ),
                ),
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.cloud_done_outlined)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.list(children: [
                  const Text('समूह का हिसाब', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.deepForest)),
                  const SizedBox(height: 5),
                  const Text('आपके समूह का वित्तीय सारांश',
                    style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 16),
                  const Wrap(spacing: 12, runSpacing: 12, children: [
                    _SummaryTile(title: 'उपलब्ध राशि', amount: '₹ 0'),
                    _SummaryTile(title: 'कुल मासिक जमा', amount: '₹ 0'),
                    _SummaryTile(title: 'सक्रिय उधार', amount: '₹ 0'),
                    _SummaryTile(title: 'वसूल ब्याज', amount: '₹ 0'),
                  ]),
                  const SizedBox(height: 24),
                  const Text('त्वरित एंट्री', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepForest)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: actions.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                      childAspectRatio: 1.65,
                    ),
                    itemBuilder: (context, index) => NeoCard(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${actions[index].$1} स्क्रीन अगले चरण में बनेगी।')),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(actions[index].$2, color: AppColors.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(actions[index].$1, textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('हाल की गतिविधियाँ', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepForest)),
                  const SizedBox(height: 10),
                  const NeoCard(child: Text('अभी कोई नई गतिविधि उपलब्ध नहीं है।')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.title, required this.amount});
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 44) / 2,
    child: NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      const SizedBox(height: 8),
      Text(amount, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
        color: AppColors.deepForest)),
    ])),
  );
}
