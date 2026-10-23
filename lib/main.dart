import 'package:flutter/material.dart';
import 'dart:math' as math;

// BinGo — hackathon demo. All data and hardware events are simulated locally.
void main() => runApp(const BinGoApp());

const green = Color(0xFF18794B);
const deep = Color(0xFF143D30);
const pale = Color(0xFFE9F6ED);
const canvas = Color(0xFFF2F7F4);

enum WasteType { recycling }
enum JobStage { requested, dispatched, arrived, collected, atHub, completed }

extension WasteDetails on WasteType {
  String get title => 'Recycling';
  String get malay => 'Kitar Semula';
  String get description => 'Paper, plastic, glass, and metal';
  String get destination => 'Recycling Hub';
  IconData get icon => Icons.recycling_rounded;
  Color get color => green;
}

String stageText(JobStage s) => switch (s) {
  JobStage.requested => 'Request received',
  JobStage.dispatched => 'Autobin dispatched',
  JobStage.arrived => 'Autobin at your house',
  JobStage.collected => 'Waste collected',
  JobStage.atHub => 'Arrived at collection hub',
  JobStage.completed => 'Delivery completed',
};

class CollectionJob {
  CollectionJob({required this.id, required this.type, required this.address,
    required this.kg, required this.material, required this.created});
  final String id;
  final WasteType type;
  final String address;
  final double kg;
  final String material;
  final DateTime created;
  JobStage stage = JobStage.requested;
  bool scanned = false;
  bool approved = false;
  bool credited = false;
  double verifiedKg = 0;
  int get points => type == WasteType.recycling && approved
      ? (verifiedKg * 10).round() : 0;
}

// Sample rewards for hackathon demonstration; not real merchant offers.
class RewardOffer {
  const RewardOffer(this.name, this.description, this.cost, this.icon, this.category,
      {this.quantity = 5});
  final String name;
  final String description;
  final int cost;
  final IconData icon;
  final String category;
  final int quantity;
}

class RedeemedReward {
  RedeemedReward(this.offer, this.code, this.time);
  final RewardOffer offer;
  final String code;
  final DateTime time;
}

const rewardCatalog = <RewardOffer>[
  RewardOffer('RM5 Eco Voucher', 'Demo township partner voucher', 50,
      Icons.local_offer_outlined, 'Vouchers'),
  RewardOffer('Reusable Shopping Bag', 'Carry groceries without single-use bags', 80,
      Icons.shopping_bag_outlined, 'Eco Products'),
  RewardOffer('Bamboo Toothbrush', 'Reusable-handle-inspired eco item', 100,
      Icons.brush_outlined, 'Eco Products'),
  RewardOffer('Reusable Water Bottle', 'Stay hydrated with less plastic waste', 150,
      Icons.water_drop_outlined, 'Eco Products'),
  RewardOffer('RM10 Community Voucher', 'Demo local business voucher', 200,
      Icons.card_giftcard_outlined, 'Vouchers'),
  RewardOffer('Seed Starter Kit', 'Start growing herbs at home', 120,
      Icons.spa_outlined, 'Community'),
  RewardOffer('Community Garden Pass', 'Demo gardening workshop entry', 250,
      Icons.park_outlined, 'Community'),
  RewardOffer('Recycling Champion Badge', 'Digital recognition for eco heroes', 30,
      Icons.workspace_premium_outlined, 'Digital'),
];

class BinGoApp extends StatelessWidget {
  const BinGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BinGo | Township for Tomorrow',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: deep),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: green, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13))),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    ),
    home: const BinGoDemo(),
  );
}

class BinGoDemo extends StatefulWidget {
  const BinGoDemo({super.key});
  @override
  State<BinGoDemo> createState() => _BinGoDemoState();
}

class _BinGoDemoState extends State<BinGoDemo> {
  int tab = 0;
  int nextNumber = 1001;
  int greenPoints = 0;
  int nextRedemption = 1;
  String rewardFilter = 'All';
  final List<RedeemedReward> redemptionHistory = [];

  WasteType chosen = WasteType.recycling;
  String material = 'Mixed recyclables';
  double weight = 2.0;
  bool full = true;
  bool unlocked = false;
  bool cameraSimulated = false;
  final address = TextEditingController(text: 'No. 12, Jalan Harmoni 3, EcoTown');
  final jobs = <CollectionJob>[];

  CollectionJob? get current => jobs.isEmpty ? null : jobs.first;

  @override
  void dispose() { address.dispose(); super.dispose(); }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),
      behavior: SnackBarBehavior.floating));
  }

  void request() {
    if (address.text.trim().isEmpty) {
      message('Please enter a collection address.');
      return;
    }
    setState(() {
      jobs.insert(0, CollectionJob(
        id: 'BG-${nextNumber++}', type: chosen, address: address.text.trim(),
        kg: weight, material: material,
        created: DateTime.now(),
      ));
      unlocked = false;
      cameraSimulated = false;
      tab = 1;
    });
    message('${chosen.title} pickup requested! Open Autobin to simulate the journey.');
  }

  void advance(CollectionJob job) {
    if (job.stage == JobStage.completed) return;
    if (job.stage == JobStage.arrived && !unlocked && identical(job, current)) {
      message('First simulate QR / NFC access in the Autobin tab.');
      return;
    }
    if (job.stage == JobStage.collected && !job.scanned) {
      message('First run the simulated camera waste check in the Operator tab.');
      return;
    }
    if (job.stage == JobStage.collected && !job.approved) {
      message('Waste needs to be accepted before reaching the hub.');
      return;
    }
    if (job.stage == JobStage.atHub && job.type == WasteType.recycling &&
        job.verifiedKg <= 0) {
      message('Confirm the recycling weight in Operator before completing.');
      return;
    }
    setState(() {
      job.stage = JobStage.values[job.stage.index + 1];
      if (job.stage == JobStage.completed && job.type == WasteType.recycling &&
          !job.credited) {
        greenPoints += job.points;
        job.credited = true;
      }
    });
    message(stageText(job.stage));
  }

  void inspect(CollectionJob job, bool accept) {
    setState(() {
      job.scanned = true;
      job.approved = accept;
      if (!accept) job.verifiedKg = 0;
    });
    message(accept ? 'Demo inspection: ${job.type.title} waste accepted.' :
      'Demo inspection: contamination flagged. Recheck materials.');
  }

  void confirmWeight(CollectionJob job) {
    if (!job.approved || job.stage != JobStage.atHub) return;
    setState(() => job.verifiedKg = job.kg);
    message('Demo hub verified ${job.kg.toStringAsFixed(1)} kg.');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [residentPage(), trackingPage(), autobinPage(),
      rewardsPage(), operatorPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.recycling_rounded, color: green, size: 32),
          SizedBox(width: 7),
          Text('BinGo', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.info_outline),
          tooltip: 'Prototype information', onPressed: () => showDialog<void>(
            context: context, builder: (context) => AlertDialog(
              title: const Text('Hackathon demonstration'),
              content: const Text('BinGo Recycle is a software-only demo. The satellite-inspired map, pseudo-3D robot, QR/NFC, AI camera, GPS and route tracking are simulated. No real robot, map service, or shared backend is connected.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('OK'))]))),
          const SizedBox(width: 8)],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: IndexedStack(index: tab, children: pages)))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'Autobin'),
          NavigationDestination(icon: Icon(Icons.stars_outlined), label: 'Rewards'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Ops'),
        ],
      ),
    );
  }

  Widget residentPage() => ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [deep, green]),
      borderRadius: BorderRadius.circular(24)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SIME DARBY • TOWNSHIP FOR TOMORROW', style: TextStyle(color: Colors.white70, fontSize: 13)),
        SizedBox(height: 7),
        Text('Recycling, reimagined.', style: TextStyle(color: Colors.white,
          fontSize: 27, fontWeight: FontWeight.w900)),
        SizedBox(height: 9),
        Text('One tap to collect your recyclables. Track every step, earn Green Points.',
          style: TextStyle(color: Colors.white70)),
        SizedBox(height: 10),
        Text('DEMO • Autonomous Autobin concept / human-runner-ready workflow',
          style: TextStyle(color: Colors.white70, fontSize: 11)),
      ])),
    const SizedBox(height: 23),
    heading('Your recycling collection'),
    const SizedBox(height: 10),
    const Card(child: Padding(padding: EdgeInsets.all(17), child: Row(children: [
      CircleAvatar(backgroundColor: pale, radius: 26,
        child: Icon(Icons.recycling_rounded, color: green, size: 30)),
      SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('Recyclables only', style: TextStyle(fontSize: 17,
          color: deep, fontWeight: FontWeight.w800)),
          Text('Plastic • Paper • Glass • Metal', style: TextStyle(color: Colors.black54, fontSize: 12))])),
      Icon(Icons.check_circle_rounded, color: green),
    ]))),
    const SizedBox(height: 16),
    Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Pickup details'), const SizedBox(height: 14),
        TextField(controller: address, decoration: const InputDecoration(
          labelText: 'House address / Alamat rumah', prefixIcon: Icon(Icons.place_outlined))),
        if (chosen == WasteType.recycling) ...[
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            value: material, decoration: const InputDecoration(labelText: 'Recycling material'),
            items: ['Mixed recyclables', 'Plastic', 'Paper / cardboard', 'Metal', 'Glass']
              .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => material = v ?? material)),
          const SizedBox(height: 8),
          const Text('Accepted recyclables are sorted by workers at the recycling hub.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Estimated load'), Text('${weight.toStringAsFixed(1)} kg',
            style: const TextStyle(color: green, fontWeight: FontWeight.bold)),
        ]),
        Slider(min: 0.5, max: 10, divisions: 19, value: weight,
          onChanged: (v) => setState(() => weight = v)),
        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
          title: const Text('My bin is full / Tong saya penuh'),
          subtitle: const Text('Or request an ad-hoc pickup'),
          value: full, onChanged: (v) => setState(() => full = v)),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: request, icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Call BinGo / Panggil BinGo'))),
        if (chosen == WasteType.recycling) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Potential reward: ${(weight * 10).round()} points (after hub verification)',
            textAlign: TextAlign.center, style: const TextStyle(color: green, fontSize: 12))),
      ]))),
    const SizedBox(height: 17),
    heading('How it works'),
    info(Icons.touch_app_outlined, '1. Request', 'Resident schedules a doorstep recycling pickup.'),
    info(Icons.smart_toy_outlined, '2. Collect', 'Simulated Autobin travels via township-approved paths.'),
    info(Icons.warehouse_outlined, '3. Deliver', 'Recyclables reach the central sorting hub.'),
  ]);

  Widget trackingPage() => ListView(padding: const EdgeInsets.all(18), children: [
    heading('Live journey preview'),
    const Text('Satellite-inspired route and animated milestone tracking • demo data.',
      style: TextStyle(color: Colors.black54)),
    const SizedBox(height: 17),
    if (jobs.isEmpty) empty('No pickups yet', 'Create one on Home to start the demo.'),
    for (final j in jobs) Card(margin: const EdgeInsets.only(bottom: 14),
      child: Padding(padding: const EdgeInsets.all(17), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(j.type.icon, color: j.type.color), const SizedBox(width: 9),
            Expanded(child: Text('${j.type.title} • ${j.id}', style:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Text('${j.kg.toStringAsFixed(1)} kg')]),
          const SizedBox(height: 8), Text(j.address),
          const SizedBox(height: 13),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (j.stage.index + 1) / JobStage.values.length),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            builder: (context, progress, _) => LinearProgressIndicator(
              value: progress, minHeight: 9, borderRadius: BorderRadius.circular(8),
              backgroundColor: pale)),
          const SizedBox(height: 9),
          Text(stageText(j.stage), style: const TextStyle(color: green,
            fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          routeVisual(j),
          const SizedBox(height: 12),
          AnimatedTrackingTimeline(key: ValueKey('timeline-${j.id}'), stage: j.stage, type: j.type),
          const SizedBox(height: 8),
          Text('Destination: ${j.type.destination}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          if (j.type == WasteType.recycling)
            Text('Green Points: ${j.credited ? '+${j.points} credited' : 'Pending hub verification'}',
              style: const TextStyle(color: green, fontSize: 12)),
        ]))),
  ]);

  Widget routeVisual(CollectionJob j) => AnimatedAutobinRoute(
    key: ValueKey('route-${j.id}'), stage: j.stage, wasteType: j.type,
  );

  Widget autobinPage() {
    final j = current;
    return ListView(padding: const EdgeInsets.all(18), children: [
      heading('Autobin • Digital Twin'),
      const Text('Floating 3D-style robot • interactive collection controls',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [deep, green]),
        borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const SizedBox(height: 208, child: FloatingAutobin()),
          const SizedBox(height: 7),
          const Text('BinGo Autobin 01', style: TextStyle(fontSize: 23,
            color: Colors.white, fontWeight: FontWeight.w800)),
          const Text('GPS + LiDAR navigation • future hardware integration',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 13),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const RobotMetric('Battery', '85%', Icons.battery_5_bar),
            const RobotMetric('Navigation', 'Demo', Icons.route_outlined),
            const RobotMetric('Mode', 'Simulated', Icons.settings_remote_outlined),
          ]),
        ])),
      const SizedBox(height: 17),
      heading('One streamlined recycling service'),
      const SizedBox(height: 9),
      info(Icons.recycling_rounded, 'Recycling / Kitar Semula',
        'Plastic, paper, glass and metal are collected and sorted by hub workers.'),
      const Text('The robot illustration is a pseudo-3D Flutter animation, not a physical 3D model.',
        style: TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 18),
      heading('Robot interaction simulator'),
      const SizedBox(height: 9),
      if (j == null) empty('No active delivery', 'Request a collection on Home.'),
      if (j != null) Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${j.id} • ${j.type.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6), Text(stageText(j.stage)),
          const SizedBox(height: 11),
          routeVisual(j),
          const SizedBox(height: 12),
          if (j.stage == JobStage.arrived) SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: unlocked ? null : () { setState(() => unlocked = true);
                message('Demo QR/NFC approved — compartment unlocked.'); },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(unlocked ? 'Demo access granted' : 'Simulate QR / NFC unlock'))),
          if (j.stage == JobStage.collected) const Text(
            'Material checking happens on the Operator tab before hub arrival.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
          if (j.stage == JobStage.completed) const Text('Autobin returned to base (demo).',
            style: TextStyle(color: green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (j.stage != JobStage.completed)
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => advance(j), icon: const Icon(Icons.play_arrow),
              label: Text(switch (j.stage) {
                JobStage.requested => 'Dispatch Autobin (demo)',
                JobStage.dispatched => 'Arrive at house',
                JobStage.arrived => 'Confirm pickup',
                JobStage.collected => 'Travel to matching hub',
                JobStage.atHub => 'Complete hub delivery',
                JobStage.completed => 'Completed',
              }))),
        ]))),
      const SizedBox(height: 12),
      info(Icons.visibility_outlined, 'AI Camera / Computer Vision',
        'Operator simulates identification of acceptable and contaminated materials.'),
      info(Icons.sensors_outlined, 'Sensors and mobility',
        'LiDAR, obstacle avoidance and autonomous driving are concept features, not connected hardware.'),
    ]);
  }

  int remainingStock(RewardOffer offer) => offer.quantity -
      redemptionHistory.where((entry) => identical(entry.offer, offer)).length;

  void redeemReward(RewardOffer offer) async {
    if (greenPoints < offer.cost) {
      message('Not enough points. You need ${offer.cost - greenPoints} more.');
      return;
    }
    if (remainingStock(offer) <= 0) {
      message('This demo reward is out of stock.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redeem reward?'),
        content: Text('Redeem ${offer.name} for ${offer.cost} Green Points? '
            'This is a demo redemption only; no physical reward is issued.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm redeem')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // Check again after the dialog, so a reward cannot overspend points.
    if (greenPoints < offer.cost || remainingStock(offer) <= 0) {
      message('Points or inventory have changed. Please try again.');
      return;
    }
    final code = 'DEMO-${(nextRedemption++).toString().padLeft(4, '0')}';
    setState(() {
      greenPoints -= offer.cost;
      redemptionHistory.insert(0, RedeemedReward(offer, code, DateTime.now()));
    });
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Row(children: [Icon(Icons.check_circle, color: green),
          SizedBox(width: 10), Text('Redeemed!')]),
      content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(offer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText('Demo redemption code: $code'),
          const SizedBox(height: 8),
          const Text('Simulation only. No real voucher or product is issued.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'))],
    ));
  }

  Widget rewardCard(RewardOffer offer) {
    final remaining = remainingStock(offer);
    final affordable = greenPoints >= offer.cost;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
      padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 54, height: 54,
              decoration: BoxDecoration(color: pale,
                borderRadius: BorderRadius.circular(14)),
              child: Icon(offer.icon, color: green, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.name, style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(offer.description, style: const TextStyle(
                    color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 5),
                Text(offer.category, style: const TextStyle(
                    color: green, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.stars_rounded, color: Color(0xFFE4A327), size: 19),
            const SizedBox(width: 5),
            Text('${offer.cost} pts', style: const TextStyle(
                fontWeight: FontWeight.w800, color: deep)),
            const SizedBox(width: 12),
            Expanded(child: Text('$remaining left (demo)',
                style: const TextStyle(color: Colors.black54, fontSize: 11))),
            FilledButton(
              onPressed: remaining <= 0 ? null : () => redeemReward(offer),
              child: Text(remaining <= 0 ? 'Sold out' :
                  affordable ? 'Redeem' : 'Need ${offer.cost - greenPoints} pts'),
            ),
          ]),
        ],
      ),
    ));
  }

  Widget rewardsPage() {
    final offers = rewardCatalog.where((offer) =>
        rewardFilter == 'All' || offer.category == rewardFilter).toList();
    final earned = jobs.where((job) => job.credited)
        .fold<int>(0, (sum, job) => sum + job.points);
    final spent = redemptionHistory.fold<int>(0,
        (sum, entry) => sum + entry.offer.cost);
    return ListView(padding: const EdgeInsets.all(18), children: [
      heading('Green Rewards / Ganjaran Hijau'),
      const SizedBox(height: 6),
      const Text('Recycle, collect Green Points and redeem demo rewards.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [green, deep]),
        borderRadius: BorderRadius.circular(23)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.stars_rounded, size: 32,
              color: Colors.amberAccent), SizedBox(width: 8),
              Text('AVAILABLE POINTS', style: TextStyle(color: Colors.white70,
                  fontSize: 12, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text('$greenPoints', style: const TextStyle(color: Colors.white,
              fontSize: 47, fontWeight: FontWeight.w900)),
          const Text('10 points per verified kg of recycling',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('Earned: $earned', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600))),
            Text('Redeemed: $spent', style: const TextStyle(color: Colors.white)),
          ]),
        ])),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hackathon test controls', style: TextStyle(
              fontWeight: FontWeight.w800, color: deep)),
          const SizedBox(height: 5),
          const Text('Try the shop without completing 30 recycling trips. '
              'These are simulated points, not real earned credits.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () {
            setState(() => greenPoints += 300);
            message('Added 300 DEMO points for reward testing.');
          }, icon: const Icon(Icons.science_outlined),
              label: const Text('Add 300 demo points')),
        ]))),
      const SizedBox(height: 15),
      heading('Reward Shop'),
      const SizedBox(height: 7),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
        children: ['All', 'Eco Products', 'Vouchers', 'Community', 'Digital']
          .map((category) => Padding(padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(label: Text(category),
              selected: category == rewardFilter,
              onSelected: (_) => setState(() => rewardFilter = category))))
          .toList(),
      )),
      const SizedBox(height: 9),
      for (final offer in offers) rewardCard(offer),
      const SizedBox(height: 8),
      heading('My Redemptions'),
      const SizedBox(height: 9),
      if (redemptionHistory.isEmpty)
        info(Icons.receipt_long_outlined, 'No redemptions yet',
            'Redeem an item above to receive a demo redemption code.'),
      for (final entry in redemptionHistory)
        Card(child: ListTile(leading: const Icon(Icons.verified, color: green),
          title: Text(entry.offer.name),
          subtitle: Text('${entry.code} • ${entry.time.day}/${entry.time.month} '
              '${entry.time.hour.toString().padLeft(2, '0')}:'
              '${entry.time.minute.toString().padLeft(2, '0')}'),
          trailing: Text('-${entry.offer.cost} pts',
              style: const TextStyle(fontWeight: FontWeight.bold)))),
      const SizedBox(height: 10),
      heading('Recycling Points History'),
      if (!jobs.any((job) => job.credited))
        info(Icons.recycling_rounded, 'No verified pickups yet',
            'Complete a recycling pickup and confirm the weight in Ops.'),
      for (final job in jobs.where((job) => job.credited))
        info(Icons.check_circle_outline, '${job.id}: +${job.points} points',
            '${job.verifiedKg.toStringAsFixed(1)} kg verified recycling'),
      const Padding(padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('Hackathon simulation only: offers, inventory, points, '
            'and redemption codes are not connected to real merchants. '
            'All data resets when the app reloads.',
            style: TextStyle(fontSize: 11, color: Colors.black54))),
    ]);
  }

  Widget operatorPage() {
    final active = jobs.where((j) => j.stage != JobStage.completed).length;
    final done = jobs.where((j) => j.stage == JobStage.completed).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      heading('Recycling control centre'),
      const Text('Operator-led verification, dispatch and central hubs',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: stat('${jobs.length}', 'Requests')),
        const SizedBox(width: 8),
        Expanded(child: stat('$active', 'Active')),
        const SizedBox(width: 8),
        Expanded(child: stat('$done', 'Delivered')),
      ]),
      const SizedBox(height: 16),
      heading('Recycling collection hub'),
      info(Icons.warehouse_outlined, 'Recycling Hub',
        '${jobs.where((j) => j.stage.index >= JobStage.atHub.index).length} loads received • manual sorting at hub'),
      const SizedBox(height: 15), heading('Active dispatch queue'),
      if (jobs.isEmpty) empty('No requests', 'Create a pickup from the Home tab.'),
      for (final j in jobs) Card(margin: const EdgeInsets.only(bottom: 13),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${j.id} • ${j.type.title}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            Text('${j.material} • ${j.kg.toStringAsFixed(1)} kg (estimated)'),
            Text('Stage: ${stageText(j.stage)}'),
            Text('Hub: ${j.type.destination}', style: const TextStyle(fontSize: 12)),
            if (j.stage == JobStage.collected) ...[
              const SizedBox(height: 12),
              const Text('SIMULATED MATERIAL CHECK', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 11, color: deep)),
              const Text('Judge can accept a valid load or flag contamination. Not a real AI model.',
                style: TextStyle(color: Colors.black54, fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                OutlinedButton.icon(onPressed: () => inspect(j, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept material')),
                OutlinedButton.icon(onPressed: () => inspect(j, false),
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Flag contamination')),
              ]),
              if (j.scanned) Text(j.approved ? 'Material accepted' :
                'Contamination flagged — correct before dispatch',
                style: TextStyle(color: j.approved ? green : Colors.red,
                  fontWeight: FontWeight.w600)),
            ],
            if (j.type == WasteType.recycling && j.stage == JobStage.atHub) ...[
              const SizedBox(height: 11),
              Text(j.verifiedKg > 0
                ? 'Confirmed: ${j.verifiedKg.toStringAsFixed(1)} kg • ${j.points} points'
                : 'Hub staff must verify weight before awarding points.'),
              const SizedBox(height: 6),
              OutlinedButton.icon(onPressed: j.verifiedKg > 0 ? null : () => confirmWeight(j),
                icon: const Icon(Icons.scale_outlined),
                label: const Text('Confirm demo weight')),
            ],
            if (j.stage == JobStage.completed) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Delivered and closed', style: TextStyle(color: green,
                fontWeight: FontWeight.bold))),
          ]))),
      const SizedBox(height: 10),
      const Text('Presentation note: Human-operated collection is the realistic initial rollout. Autonomous navigation and AI camera recognition are future features. Recyclables are sorted by hub staff.',
        style: TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }

  Widget stat(String value, String label) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [Text(value, style: const TextStyle(fontSize: 24,
      fontWeight: FontWeight.w900, color: deep)), Text(label, style:
      const TextStyle(fontSize: 12, color: Colors.black54))]));

  Widget heading(String text) => Text(text, style: const TextStyle(
    fontSize: 19, fontWeight: FontWeight.w800, color: deep));

  Widget info(IconData icon, String title, String body) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: green)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(body, style: const TextStyle(fontSize: 12))));

  Widget empty(String title, String subtitle) => Container(
    width: double.infinity, padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(children: [const Icon(Icons.inbox_outlined, color: green, size: 37),
      const SizedBox(height: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54))]));
}

class RobotMetric extends StatelessWidget {
  const RobotMetric(this.label, this.value, this.icon, {super.key});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: Colors.white70, size: 21),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);
}


// Visual simulation only: animations reflect stage changes triggered by demo buttons.
// There is no GPS connection or continuously updating physical robot position.
class AnimatedAutobinRoute extends StatelessWidget {
  const AnimatedAutobinRoute({super.key, required this.stage, required this.wasteType});
  final JobStage stage;
  final WasteType wasteType;
  double get position => switch (stage) {
    JobStage.requested => .03,
    JobStage.dispatched => .25,
    JobStage.arrived => .49,
    JobStage.collected => .57,
    JobStage.atHub => .94,
    JobStage.completed => 1.0,
  };
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(color: const Color(0xFF132C29), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [const Icon(Icons.satellite_alt_outlined,
              color: Color(0xFF9CF0C1), size: 17),
            const SizedBox(width: 8),
            const Expanded(child: Text('SATELLITE-STYLE TOWNSHIP VIEW',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF294A40),
                borderRadius: BorderRadius.circular(30)),
              child: const Text('SIMULATION', style: TextStyle(fontSize: 9,
                fontWeight: FontWeight.bold, color: Color(0xFFA8F8C6))))])),
        AspectRatio(aspectRatio: 1.72, child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1300),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(end: position),
          builder: (context, progress, _) => CustomPaint(
            painter: TownshipMapPainter(progress: progress)))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 15),
          child: Row(children: [const Icon(Icons.circle, color: Color(0xFF81E5AD), size: 10),
            const SizedBox(width: 8), Expanded(child: Text(stageText(stage),
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 12)))])),
      ])));
}

class TownshipMapPainter extends CustomPainter {
  TownshipMapPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bg = Paint()..color = const Color(0xFF284F47);
    canvas.drawRect(Offset.zero & size, bg);
    final park = Paint()..color = const Color(0xFF356B55);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.06,h*.1,w*.28,h*.28), const Radius.circular(10)),park);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.67,h*.57,w*.26,h*.32), const Radius.circular(12)),park);
    final road = Paint()..color = const Color(0xFF84938B)..style = PaintingStyle.stroke..strokeWidth=19..strokeCap=StrokeCap.round;
    final streets = <List<Offset>>[
      [Offset(w*.12,h*.72),Offset(w*.87,h*.72)],
      [Offset(w*.48,h*.10),Offset(w*.48,h*.88)],
      [Offset(w*.12,h*.22),Offset(w*.87,h*.22)],
    ];
    for (final pts in streets) { final p=Path()..moveTo(pts[0].dx,pts[0].dy)..lineTo(pts[1].dx,pts[1].dy);canvas.drawPath(p,road);}
    final curb=Paint()..color=const Color(0xFFBEC8BF)..strokeWidth=1..style=PaintingStyle.stroke;
    for(final pts in streets){final p=Path()..moveTo(pts[0].dx,pts[0].dy)..lineTo(pts[1].dx,pts[1].dy);canvas.drawPath(p,curb);}
    final building=Paint()..color=const Color(0xFFB5BCA8);
    final roof=Paint()..color=const Color(0xFF697E70);
    for(var row=0;row<3;row++){
      for(var col=0;col<7;col++){
        final x=w*(.08+col*.125),y=h*(.04+row*.30);
        if((col==3)||(row==2&&col>4)||(row==0&&col<3))continue;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w*.075,h*.11),const Radius.circular(2)),building);
        canvas.drawRect(Rect.fromLTWH(x+3,y+3,w*.075-6,h*.11-6),roof);
      }
    }
    final points=[Offset(w*.14,h*.72),Offset(w*.48,h*.72),Offset(w*.48,h*.22),Offset(w*.82,h*.22)];
    final path=Path()..moveTo(points[0].dx,points[0].dy);
    for(var i=1;i<points.length;i++)path.lineTo(points[i].dx,points[i].dy);
    canvas.drawPath(path,Paint()..color=const Color(0xFF0D392B)..style=PaintingStyle.stroke..strokeWidth=9..strokeCap=StrokeCap.round);
    canvas.drawPath(path,Paint()..color=const Color(0xFF90F2A5)..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
    final segment=(progress*3).clamp(0.0,2.9999).toDouble();
    final idx=segment.floor(), frac=segment-idx;
    final here=Offset.lerp(points[idx],points[idx+1],frac)!;
    canvas.drawCircle(here,15,Paint()..color=const Color(0x5587FFC5));
    canvas.drawCircle(here,9,Paint()..color=const Color(0xFF0B6445));
    canvas.drawCircle(here,5,Paint()..color=Colors.white);
    for(final pt in [points[0],points[2],points[3]]) {
      canvas.drawCircle(pt,7,Paint()..color=const Color(0xFFDEFFB0));
      canvas.drawCircle(pt,4,Paint()..color=const Color(0xFF175C3E));
    }
    _label(canvas,'BASE',points[0]+const Offset(-12,-23));
    _label(canvas,'HOUSE',points[2]+const Offset(10,-22));
    _label(canvas,'RECYCLE HUB',points[3]+const Offset(-72,15));
  }
  void _label(Canvas c,String text,Offset at) {
    final p=TextPainter(text:TextSpan(text:text,style:const TextStyle(
      color:Colors.white,fontSize:10,fontWeight:FontWeight.w800)),
      textDirection:TextDirection.ltr)..layout();
    p.paint(c,at);
  }
  @override
  bool shouldRepaint(covariant TownshipMapPainter oldDelegate)=>oldDelegate.progress!=progress;
}

class FloatingAutobin extends StatefulWidget {
  const FloatingAutobin({super.key});
  @override
  State<FloatingAutobin> createState()=>_FloatingAutobinState();
}
class _FloatingAutobinState extends State<FloatingAutobin>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller=AnimationController(
    vsync:this,duration:const Duration(milliseconds:2300))..repeat(reverse:true);
  @override
  void dispose(){controller.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AnimatedBuilder(animation:controller,
    builder:(context,_)=>Transform.translate(
      offset:Offset(0,-5*math.sin(controller.value*math.pi)),
      child:CustomPaint(painter:Autobin3DPainter(controller.value),
        child:const SizedBox.expand())));
}
class Autobin3DPainter extends CustomPainter {
  Autobin3DPainter(this.motion);
  final double motion;
  @override
  void paint(Canvas c,Size size){
    final center=size.width/2, base=size.height*.78;
    c.drawOval(Rect.fromCenter(center:Offset(center,base+12),width:175,height:23),
      Paint()..color=const Color(0x66042017));
    final chassis=Path()..moveTo(center-103,base-40)..lineTo(center+50,base-40)
      ..lineTo(center+95,base-72)..lineTo(center-56,base-72)..close();
    c.drawPath(chassis,Paint()..color=const Color(0xFF172E29));
    for(final x in [center-65,center+58]){
      c.drawOval(Rect.fromCenter(center:Offset(x,base-28),width:29,height:47),
        Paint()..color=const Color(0xFF081F1A));
      c.drawOval(Rect.fromCenter(center:Offset(x,base-28),width:11,height:22),
        Paint()..color=const Color(0xFF6DCDA0));
    }
    final front=Path()..moveTo(center-80,base-145)..lineTo(center+53,base-145)
      ..lineTo(center+53,base-48)..lineTo(center-80,base-48)..close();
    c.drawPath(front,Paint()..shader=const LinearGradient(
      colors:[Color(0xFFE9FFF5),Color(0xFF70D2AD)],
      begin:Alignment.topLeft,end:Alignment.bottomRight)
      .createShader(Rect.fromLTWH(center-80,base-145,133,98)));
    final side=Path()..moveTo(center+53,base-145)..lineTo(center+93,base-170)
      ..lineTo(center+93,base-72)..lineTo(center+53,base-48)..close();
    c.drawPath(side,Paint()..color=const Color(0xFF2B8F73));
    final top=Path()..moveTo(center-80,base-145)..lineTo(center-40,base-172)
      ..lineTo(center+93,base-170)..lineTo(center+53,base-145)..close();
    c.drawPath(top,Paint()..color=const Color(0xFFD8FCE8));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center-58,base-128,85,36),
      const Radius.circular(7)),Paint()..color=const Color(0xFF165843));
    final tp=TextPainter(text:const TextSpan(text:'BinGo',style:TextStyle(
      color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
    tp.paint(c,Offset(center-47,base-122));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center-54,base-82,74,11),
      const Radius.circular(5)),Paint()..color=const Color(0xFFB5FFD7));
    final lid=Path()..moveTo(center-81,base-149-8*motion)
      ..lineTo(center-40,base-182-13*motion)
      ..lineTo(center+93,base-180-13*motion)
      ..lineTo(center+53,base-149-8*motion)..close();
    c.drawPath(lid,Paint()..color=const Color(0xFF2E6D53));
    c.drawPath(lid,Paint()..color=const Color(0xFFB4F8CC)..style=PaintingStyle.stroke..strokeWidth=2);
    c.drawCircle(Offset(center+71,base-114),5,Paint()..color=const Color(0xFF92FFA6));
  }
  @override
  bool shouldRepaint(covariant Autobin3DPainter oldDelegate)=>oldDelegate.motion!=motion;
}

class AnimatedTrackingTimeline extends StatelessWidget {
  const AnimatedTrackingTimeline({super.key, required this.stage, required this.type});
  final JobStage stage;
  final WasteType type;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      'Request received',
      'Autobin dispatched',
      'Arrived at house • unlock QR/NFC',
      'Waste collected • verify material',
      'At ${type.destination} • check load',
      'Delivery completed',
    ];
    final icons = <IconData>[
      Icons.receipt_long_outlined,
      Icons.smart_toy_outlined,
      Icons.home_outlined,
      Icons.delete_outline,
      Icons.warehouse_outlined,
      Icons.check_circle_outline,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('COLLECTION STEPS', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w900, color: deep)),
      const SizedBox(height: 9),
      for (var i = 0; i < labels.length; i++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: i == stage.index ? pale : Colors.white,
            border: Border.all(
              color: i == stage.index ? green : Colors.black12,
              width: i == stage.index ? 2 : 1),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 450),
              width: 33, height: 33,
              decoration: BoxDecoration(
                color: i <= stage.index ? green : const Color(0xFFE6E9E7),
                shape: BoxShape.circle),
              child: Icon(i < stage.index ? Icons.check : icons[i], size: 18,
                color: i <= stage.index ? Colors.white : Colors.blueGrey)),
            const SizedBox(width: 10),
            Expanded(child: Text(labels[i], style: TextStyle(
              fontSize: 12, color: i > stage.index ? Colors.black54 : deep,
              fontWeight: i == stage.index ? FontWeight.w800 : FontWeight.w500))),
            if (i == stage.index) const Text('NOW', style: TextStyle(
              fontSize: 10, color: green, fontWeight: FontWeight.w900))
            else if (i < stage.index) const Icon(Icons.check_circle, color: green, size: 17)
            else const Text('NEXT', style: TextStyle(fontSize: 9, color: Colors.black45)),
          ]),
        ),
        if (i < labels.length - 1)
          Padding(padding: const EdgeInsets.only(left: 27),
            child: Container(width: 3, height: 13,
              color: i < stage.index ? green : Colors.black12)),
      ],
    ]);
  }
}
