import 'package:flutter/material.dart';

// BinGo — hackathon demo. All data and hardware events are simulated locally.
void main() => runApp(const BinGoApp());

const green = Color(0xFF18794B);
const deep = Color(0xFF143D30);
const pale = Color(0xFFE9F6ED);
const canvas = Color(0xFFF5F8F5);

enum WasteType { general, recycling, organic }
enum JobStage { requested, dispatched, arrived, collected, atHub, completed }

extension WasteDetails on WasteType {
  String get title => switch (this) {
    WasteType.general => 'General',
    WasteType.recycling => 'Recycling',
    WasteType.organic => 'Organic',
  };
  String get malay => switch (this) {
    WasteType.general => 'Sisa Domestik',
    WasteType.recycling => 'Kitar Semula',
    WasteType.organic => 'Sisa Organik',
  };
  String get description => switch (this) {
    WasteType.general => 'Non-recyclable household waste',
    WasteType.recycling => 'Clean plastic, paper, metal or glass',
    WasteType.organic => 'Food scraps and garden waste',
  };
  String get destination => switch (this) {
    WasteType.general => 'Domestic Waste Hub',
    WasteType.recycling => 'Recycling Hub',
    WasteType.organic => 'Organic / Compost Hub',
  };
  IconData get icon => switch (this) {
    WasteType.general => Icons.delete_outline_rounded,
    WasteType.recycling => Icons.recycling_rounded,
    WasteType.organic => Icons.eco_rounded,
  };
  Color get color => switch (this) {
    WasteType.general => const Color(0xFF64748B),
    WasteType.recycling => const Color(0xFF16864E),
    WasteType.organic => const Color(0xFFC28A32),
  };
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
        kg: weight, material: chosen == WasteType.recycling ? material :
          chosen == WasteType.organic ? 'Food / garden scraps' : 'General household waste',
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
              content: const Text('This is a clickable software prototype. Autobin navigation, GPS/LiDAR, QR/NFC access, AI camera inspection, weights and rewards are SIMULATED. No physical robot or shared backend is connected. Organic composting is the proposed third stream.'),
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
        Text('Township for Tomorrow', style: TextStyle(color: Colors.white70, fontSize: 13)),
        SizedBox(height: 7),
        Text('Waste pickup at your doorstep.', style: TextStyle(color: Colors.white,
          fontSize: 27, fontWeight: FontWeight.w900)),
        SizedBox(height: 9),
        Text('Choose your waste type and call BinGo on demand.',
          style: TextStyle(color: Colors.white70)),
        SizedBox(height: 10),
        Text('DEMO • Autonomous Autobin concept / human-runner-ready workflow',
          style: TextStyle(color: Colors.white70, fontSize: 11)),
      ])),
    const SizedBox(height: 23),
    heading('Select Waste Type / Pilih Jenis Sampah'),
    const SizedBox(height: 10),
    LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 530;
      final cards = WasteType.values.map(wasteCard).toList();
      return narrow ? Column(children: [for (final c in cards) Padding(
        padding: const EdgeInsets.only(bottom: 9), child: c)]) :
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i != 0) const SizedBox(width: 10), Expanded(child: cards[i]),
          ],
        ]);
    }),
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
    info(Icons.touch_app_outlined, '1. Request', 'Resident chooses General, Recycling or Organic.'),
    info(Icons.smart_toy_outlined, '2. Collect', 'Simulated Autobin travels via township-approved paths.'),
    info(Icons.warehouse_outlined, '3. Deliver', 'Waste reaches its matching hub. Trucks stay at central stations.'),
  ]);

  Widget wasteCard(WasteType type) {
    final picked = chosen == type;
    return InkWell(onTap: () => setState(() => chosen = type),
      borderRadius: BorderRadius.circular(17),
      child: Container(width: double.infinity, padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: picked ? pale : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: picked ? green : Colors.black12, width: picked ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(type.icon, size: 31, color: type.color),
            const Spacer(), if (picked) const Icon(Icons.check_circle, color: green)]),
          const SizedBox(height: 9),
          Text(type.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Text(type.malay, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 5),
          Text(type.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ])));
  }

  Widget trackingPage() => ListView(padding: const EdgeInsets.all(18), children: [
    heading('Track your collection'),
    const Text('Track each stage of the simulated Autobin journey.',
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
      heading('Meet your Autobin'),
      const Text('Autonomous smart collection concept • interactive demo',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [deep, green]),
        borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const Icon(Icons.smart_toy_rounded, size: 74, color: Colors.white),
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
      heading('Three waste streams'),
      const SizedBox(height: 9),
      for (final w in WasteType.values) info(w.icon,
        '${w.title} / ${w.malay}', '${w.description} → ${w.destination}'),
      const Text('Concept note: the robot illustration has dual compartments. This demo models a third organic collection stream as a separate collection trip; it does not claim three physical compartments.',
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

  Widget rewardsPage() => ListView(padding: const EdgeInsets.all(18), children: [
    heading('Green Points / Mata Ganjaran'),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [green, deep]),
      borderRadius: BorderRadius.circular(23)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.stars_rounded, size: 40, color: Colors.amberAccent),
        const SizedBox(height: 8),
        Text('$greenPoints', style: const TextStyle(color: Colors.white,
          fontSize: 48, fontWeight: FontWeight.w900)),
        const Text('Verified recycling points', style: TextStyle(color: Colors.white70)),
      ])),
    const SizedBox(height: 17),
    info(Icons.recycling, 'Earn 10 points per verified kg',
      'Only recycling loads earn points after accepted inspection and hub verification.'),
    info(Icons.delete_outline, 'General waste', 'No rewards for ordinary domestic waste.'),
    info(Icons.eco_outlined, 'Organic waste',
      'Diverted to a proposed composting hub; organic rewards are not enabled.'),
    const SizedBox(height: 12),
    heading('Reward concepts • not redeemable in this demo'),
    info(Icons.shopping_bag_outlined, '250 points', 'Reusable tote bag'),
    info(Icons.park_outlined, '500 points', 'Community garden voucher'),
    if (jobs.any((j) => j.credited)) ...[
      const SizedBox(height: 10), heading('Reward history'),
      for (final j in jobs.where((j) => j.credited))
        info(Icons.check_circle_outline, '${j.id}: +${j.points} points',
          '${j.verifiedKg.toStringAsFixed(1)} kg verified recycling'),
    ],
  ]);

  Widget operatorPage() {
    final active = jobs.where((j) => j.stage != JobStage.completed).length;
    final done = jobs.where((j) => j.stage == JobStage.completed).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      heading('Township operations / JMB'),
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
      heading('Collection destinations'),
      for (final w in WasteType.values) info(w.icon, w.destination,
        '${jobs.where((j) => j.type == w && j.stage.index >= JobStage.atHub.index).length} load(s) received'),
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
              const Text('SIMULATED CAMERA CHECK', style: TextStyle(
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
      const Text('Presentation note: Human-operated buggies are the realistic initial rollout. Autonomous navigation and hardware controls are future-ready concepts. Organic collection is modeled as a separate trip to a composting hub.',
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
class AnimatedAutobinRoute extends StatefulWidget {
  const AnimatedAutobinRoute({super.key, required this.stage, required this.wasteType});
  final JobStage stage;
  final WasteType wasteType;

  @override
  State<AnimatedAutobinRoute> createState() => _AnimatedAutobinRouteState();
}

class _AnimatedAutobinRouteState extends State<AnimatedAutobinRoute>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() { pulse.dispose(); super.dispose(); }

  double get distance {
    switch (widget.stage) {
      case JobStage.requested: return 0;
      case JobStage.dispatched: return .28;
      case JobStage.arrived: return .50;
      case JobStage.collected: return .64;
      case JobStage.atHub: return .94;
      case JobStage.completed: return 1;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('AUTOBIN JOURNEY • SIMULATION', style: TextStyle(
        color: deep, fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(stageText(widget.stage), style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: green)),
      const SizedBox(height: 19),
      LayoutBuilder(builder: (context, bounds) {
        final trackWidth = (bounds.maxWidth - 44).clamp(0.0, double.infinity).toDouble();
        return SizedBox(height: 57, child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 22, right: 22, top: 19,
            child: Container(height: 5, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8)))),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: distance),
            duration: const Duration(milliseconds: 950),
            curve: Curves.easeInOutCubic,
            builder: (context, progress, child) => Stack(children: [
              Positioned(left: 22, top: 19,
                child: Container(width: trackWidth * progress, height: 5,
                  decoration: BoxDecoration(color: green,
                    borderRadius: BorderRadius.circular(8)))),
              Positioned(left: (trackWidth * progress).clamp(0.0, trackWidth), top: 1,
                child: AnimatedBuilder(animation: pulse,
                  builder: (context, _) => Container(
                    width: 44, height: 43,
                    decoration: BoxDecoration(
                      color: Color.lerp(Colors.white, pale, pulse.value),
                      shape: BoxShape.circle,
                      border: Border.all(color: green, width: 2)),
                    child: const Icon(Icons.smart_toy_rounded, color: green, size: 25)))),
            ]),
          ),
        ]));
      }),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const _RouteLabel(Icons.warehouse_outlined, 'Base'),
        const _RouteLabel(Icons.home_outlined, 'House'),
        _RouteLabel(widget.wasteType.icon, 'Hub'),
      ]),
      const SizedBox(height: 11),
      const Text('Demo animation only • Position advances when a stage is confirmed. No live GPS or ETA.',
        style: TextStyle(fontSize: 10, color: Colors.black54)),
    ]),
  );
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: deep, size: 18),
    Text(text, style: const TextStyle(color: deep, fontSize: 11)),
  ]);
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
