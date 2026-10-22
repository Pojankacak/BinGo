import 'package:flutter/material.dart';

void main() => runApp(const BinGoApp());

const forest = Color(0xFF176B49);
const dark = Color(0xFF123B30);
const mint = Color(0xFFE8F5EC);
const pageBg = Color(0xFFF5F8F5);

enum WasteKind { domestic, recycle }
enum PickupStage { requested, assigned, collecting, atHub, completed }

class Pickup {
  Pickup({required this.id, required this.type, required this.address,
    required this.amount, required this.material, required this.createdAt});
  final String id;
  final WasteKind type;
  final String address;
  final double amount;
  final String material;
  final DateTime createdAt;
  PickupStage stage = PickupStage.requested;
  bool verified = false;
  bool rejected = false;
  bool rewarded = false;
  double? verifiedKg; // Hub staff-confirmed weight; never trust the resident estimate for rewards.
  String get destination => type == WasteKind.recycle
      ? 'Recycling Hub' : 'Domestic Waste Hub';
  int get points => type == WasteKind.recycle && verifiedKg != null
      ? (verifiedKg! * 10).round() : 0;
}

String stageName(PickupStage s) {
  switch (s) {
    case PickupStage.requested: return 'Requested';
    case PickupStage.assigned: return 'Runner assigned';
    case PickupStage.collecting: return 'On the way';
    case PickupStage.atHub: return 'At collection hub';
    case PickupStage.completed: return 'Completed';
  }
}

String when(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class BinGoApp extends StatelessWidget {
  const BinGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BinGo • Township Waste Collection',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBg,
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest),
      appBarTheme: const AppBarTheme(backgroundColor: pageBg, foregroundColor: dark,
        elevation: 0, centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: forest, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    ),
    home: const BinGoShell(),
  );
}

class BinGoShell extends StatefulWidget {
  const BinGoShell({super.key});
  @override
  State<BinGoShell> createState() => _BinGoShellState();
}

class _BinGoShellState extends State<BinGoShell> {
  int tab = 0;
  int nextId = 1001;
  int totalPoints = 120;
  final List<Pickup> pickups = [];
  final addressController = TextEditingController(text: 'No. 12, Jalan Harmoni 3, EcoTown');
  WasteKind selectedType = WasteKind.recycle;
  String selectedMaterial = 'Mixed recyclables';
  double selectedKg = 2;
  bool binFull = true;
  bool nfcUnlocked = false;
  bool robotCameraPassed = false;
  bool lidarEnabled = true;
  bool robotCharging = false;
  int batteryPercent = 84;
  String robotMode = 'Human-supervised demo';
  final String robotId = 'AB-01';

  @override
  void dispose() { addressController.dispose(); super.dispose(); }

  void toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message),
      behavior: SnackBarBehavior.floating));
  }

  void submitPickup() {
    final address = addressController.text.trim();
    if (address.isEmpty) { toast('Please enter your pickup address.'); return; }
    setState(() {
      pickups.insert(0, Pickup(id: 'BG-${nextId++}', type: selectedType,
        address: address, amount: selectedKg,
        material: selectedType == WasteKind.recycle ? selectedMaterial : 'General waste',
        createdAt: DateTime.now()));
      tab = 1;
    });
    toast('Pickup requested! Township runner will be assigned.');
  }

  void moveForward(Pickup p) {
    if (p.rejected) return;
    if (p.stage == PickupStage.completed) return;
    if (p.stage == PickupStage.atHub && p.type == WasteKind.recycle && p.verifiedKg == null) {
      toast('Hub staff must confirm the verified recycling weight first.'); return;
    }
    if (p.stage == PickupStage.collecting && p.type == WasteKind.recycle && !p.verified) {
      toast('Verify the recycling load first in the operator panel.'); return;
    }
    setState(() {
      p.stage = PickupStage.values[p.stage.index + 1];
      if (p.stage == PickupStage.completed && !p.rewarded && p.type == WasteKind.recycle) {
        totalPoints += p.points;
        p.rewarded = true;
      }
    });
    toast(p.stage == PickupStage.completed
      ? 'Collection completed${p.type == WasteKind.recycle ? ' • +${p.points} points' : ''}!'
      : 'Request updated: ${stageName(p.stage)}');
  }

  void confirmHubWeight(Pickup p) {
    if (p.type != WasteKind.recycle || p.stage != PickupStage.atHub || p.rejected) return;
    setState(() => p.verifiedKg = p.amount);
    toast('Recycling hub verified ${p.verifiedKg!.toStringAsFixed(1)} kg. Rewards ready on completion.');
  }

  void verify(Pickup p, bool valid) {
    setState(() { p.verified = valid; p.rejected = !valid; });
    toast(valid ? 'Demo CV check: recyclable waste approved.'
      : 'Demo CV check: contamination flagged. Ask resident to separate waste.');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [homePage(), trackingPage(), autobinPage(), rewardsPage(), operatorPage()];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.recycling_rounded, color: forest, size: 26)),
          const SizedBox(width: 10),
          const Text('BinGo', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900,
              letterSpacing: -1)),
          const Text('  •  EcoTown', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500, color: Colors.black54)),
        ]),
        actions: [IconButton(tooltip: 'Prototype information',
          onPressed: () => showDialog<void>(context: context,
            builder: (_) => AlertDialog(title: const Text('Hackathon prototype'),
              content: const Text('This is a local Flutter demo. NFC, AI camera, GPS/LiDAR, route positions, battery and robot movements are simulated; no physical Autobin, GPS, NFC or backend is connected. Rewards use operator verification and hub-confirmed weight.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])),
          icon: const Icon(Icons.info_outline_rounded))],
      ),
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy), label: 'Autobin'),
          NavigationDestination(icon: Icon(Icons.stars_outlined),
            selectedIcon: Icon(Icons.stars), label: 'Rewards'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard), label: 'Operator'),
        ],
      ),
    );
  }

  Widget homePage() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      Container(padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [dark, forest],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('A cleaner township starts here',
            style: TextStyle(color: Colors.white, fontSize: 26, height: 1.15,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('On-demand doorstep collection, without waiting for the weekly truck.',
            style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14)),
          const SizedBox(height: 16),
          const Row(children: [Icon(Icons.electric_rickshaw, color: Colors.white70, size: 21),
            SizedBox(width: 8), Text('Human-supervised Autobin / electric buggy prototype',
            style: TextStyle(color: Colors.white, fontSize: 12))]),
        ])),
      const SizedBox(height: 24),
      const Text('Request a pickup', style: TextStyle(fontSize: 21,
        fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 5),
      const Text('Choose the type of waste you want us to collect.',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: wasteTypeCard(WasteKind.domestic, 'Domestic',
            'Household trash', Icons.delete_outline_rounded)),
        const SizedBox(width: 12),
        Expanded(child: wasteTypeCard(WasteKind.recycle, 'Recycle',
            'Earn green points', Icons.recycling_rounded)),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(17), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pickup details', style: TextStyle(fontWeight: FontWeight.w800,
            fontSize: 17, color: dark)),
          const SizedBox(height: 14),
          TextField(controller: addressController,
            decoration: const InputDecoration(labelText: 'House / pickup location',
              prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          if (selectedType == WasteKind.recycle) ...[
            DropdownButtonFormField<String>(initialValue: selectedMaterial,
              decoration: const InputDecoration(labelText: 'Recyclable items',
                border: OutlineInputBorder()),
              items: ['Mixed recyclables', 'Plastic', 'Paper / cardboard', 'Metal', 'Glass']
                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => selectedMaterial = value!)),
            const SizedBox(height: 12),
            const Text('You can combine approved recyclables. Sorting happens at the recycling hub.',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 12),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Estimated weight', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${selectedKg.toStringAsFixed(1)} kg',
              style: const TextStyle(color: forest, fontWeight: FontWeight.w800))]),
          Slider(value: selectedKg, min: .5, max: 10, divisions: 19,
            label: '${selectedKg.toStringAsFixed(1)} kg',
            onChanged: (value) => setState(() => selectedKg = value)),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
            title: const Text('My bin is full'),
            subtitle: const Text('Or request an ad-hoc pickup anytime'),
            value: binFull, onChanged: (v) => setState(() => binFull = v)),
          const SizedBox(height: 5),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            icon: const Icon(Icons.send_rounded),
            onPressed: submitPickup, label: const Text('Call BinGo / Panggil Bin'))),
          if (selectedType == WasteKind.recycle) ...[
            const SizedBox(height: 10),
            Center(child: Text('Potential reward: up to ${(selectedKg * 10).round()} points (hub-verified weight only)',
              style: const TextStyle(color: forest, fontWeight: FontWeight.w600,
                fontSize: 12))),
          ],
        ]))),
      const SizedBox(height: 15),
      const Text('How BinGo works', style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 10),
      infoTile(Icons.touch_app_outlined, '1. Request',
        'Choose domestic or recycling pickup at your doorstep.'),
      infoTile(Icons.directions_car_outlined, '2. Collect',
        'Supervised Autobin travels on approved township sidewalks.'),
      infoTile(Icons.warehouse_outlined, '3. Deliver',
        'Waste goes to the matching domestic or recycling hub.'),
    ]);

  Widget wasteTypeCard(WasteKind value, String name, String subtitle, IconData icon) {
    final selected = selectedType == value;
    return InkWell(onTap: () => setState(() => selectedType = value),
      borderRadius: BorderRadius.circular(18),
      child: Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: selected ? mint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? forest : Colors.black12,
            width: selected ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 34, color: selected ? forest : Colors.blueGrey),
          const SizedBox(height: 13),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])));
  }

  Widget trackingPage() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
    children: [
      const Text('My collections', style: TextStyle(fontSize: 23,
        fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 6),
      const Text('Follow each pickup from request to the central hub.',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      if (pickups.isEmpty) emptyState(Icons.local_shipping_outlined,
        'No pickups yet', 'Go to Home to request your first collection.'),
      for (final p in pickups) pickupCard(p),
    ]);

  Widget pickupCard(Pickup p) => Card(margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(18), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(p.type == WasteKind.recycle ? Icons.recycling : Icons.delete_outline,
            color: forest),
          const SizedBox(width: 9),
          Expanded(child: Text('${p.type == WasteKind.recycle ? 'Recycling' : 'Domestic'} • ${p.id}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(when(p.createdAt), style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Text('${p.amount.toStringAsFixed(1)} kg • ${p.material}',
          style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 5),
        Text(p.address, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 15),
        LinearProgressIndicator(value: (p.stage.index + 1) / PickupStage.values.length,
          minHeight: 8, borderRadius: BorderRadius.circular(8),
          backgroundColor: mint),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.circle, color: forest, size: 10),
          const SizedBox(width: 7),
          Expanded(child: Text(p.rejected ? 'Flagged: contamination detected' : stageName(p.stage),
            style: TextStyle(fontWeight: FontWeight.bold,
              color: p.rejected ? Colors.red : forest))),
        ]),
        const SizedBox(height: 9),
        Text('Destination: ${p.destination}', style: const TextStyle(fontSize: 12)),
        if (p.type == WasteKind.recycle)
          Text('Rewards: ${p.rewarded ? '+${p.points} points credited' : 'pending hub weight verification'}',
            style: const TextStyle(color: forest, fontSize: 12)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: pageBg, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [Icon(Icons.route_outlined, color: forest),
            SizedBox(width: 9),
            Expanded(child: Text('Demo route: Central Hub → EcoTown walkway → Your house → Matching waste hub',
              style: TextStyle(fontSize: 12)))])),
      ])));

  Widget autobinPage() {
    final active = pickups.where((p) => !p.rejected && p.stage != PickupStage.completed).toList();
    final chosen = active.isEmpty ? null : active.first;
    final domesticLoads = pickups.where((p) => p.type == WasteKind.domestic &&
      p.stage == PickupStage.collecting).length;
    final recycleLoads = pickups.where((p) => p.type == WasteKind.recycle &&
      p.stage == PickupStage.collecting).length;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      const Text('Autobin control centre', style: TextStyle(fontSize: 23,
        fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 5),
      const Text('Prototype simulation / Simulasi robot',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [dark, forest]),
          borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.smart_toy_outlined, color: Colors.white, size: 35),
            SizedBox(width: 11), Expanded(child: Text('Autobin AB-01 • Dual-compartment',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)))]),
          const SizedBox(height: 14),
          Text('$batteryPercent% battery • ${robotCharging ? 'Docked / charging' : robotMode}',
            style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 9),
          LinearProgressIndicator(value: batteryPercent / 100, minHeight: 9,
            backgroundColor: Colors.white24, color: Colors.lightGreenAccent,
            borderRadius: BorderRadius.circular(10)),
          const SizedBox(height: 12),
          const Text('GPS / LiDAR collision sensing and autonomous navigation are conceptual, not connected.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: compartmentCard('Domestic / Sisa Domestik',
          Icons.delete_outline_rounded, domesticLoads, Colors.blueGrey)),
        const SizedBox(width: 10),
        Expanded(child: compartmentCard('Recycle / Kitar Semula',
          Icons.recycling_rounded, recycleLoads, forest)),
      ]),
      const SizedBox(height: 17),
      const Text('Resident access • NFC / QR demo',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(children: [Icon(nfcUnlocked ? Icons.lock_open : Icons.lock_outline, color: forest),
          const SizedBox(width: 10), Expanded(child: Text(nfcUnlocked
            ? 'Access granted (simulation)' : 'Compartments locked',
            style: const TextStyle(fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () { setState(() => nfcUnlocked = !nfcUnlocked);
            toast(nfcUnlocked ? 'Demo NFC scan approved; lid unlocked.' : 'Autobin locked.'); },
          icon: const Icon(Icons.nfc),
          label: Text(nfcUnlocked ? 'Lock compartments' : 'Simulate NFC / QR scan'))),
      ]))),
      const SizedBox(height: 15),
      const Text('AI camera & waste verification',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('A future camera can check whether an item is recyclable. For now, this uses a manual simulated result.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () { setState(() => robotCameraPassed = true);
              toast('Simulated scan: recyclable item accepted.'); },
              icon: const Icon(Icons.check_circle_outline), label: const Text('Demo: recyclable')),
            OutlinedButton.icon(onPressed: () { setState(() => robotCameraPassed = false);
              toast('Simulated scan: domestic/contaminated waste detected.'); },
              icon: const Icon(Icons.warning_amber), label: const Text('Demo: contaminated')),
          ]),
          const SizedBox(height: 8),
          Text(robotCameraPassed ? 'Last demo result: recyclable ✓' : 'Last demo result: not approved / no scan',
            style: const TextStyle(color: forest, fontWeight: FontWeight.w600)),
        ]))),
      const SizedBox(height: 15),
      const Text('Township walkway routing',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.route, color: forest), SizedBox(width: 8),
            Text('Simulated route / Laluan demo',
              style: TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 11),
          const Text('Central station  →  approved sidewalks  →  resident home  →  appropriate waste hub',
            style: TextStyle(height: 1.5)),
          const SizedBox(height: 10),
          Text(chosen == null ? 'No active pickup. Make a request to begin.'
            : 'Current job: ${chosen.id} • ${stageName(chosen.stage)} • ${chosen.destination}',
            style: const TextStyle(fontSize: 12, color: forest)),
          const SizedBox(height: 9),
          const Text('Routing, robot position and ETA are not live. An operator supervises all simulated travel.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]))),
      const SizedBox(height: 15),
      const Text('Central transfer / Rumah sampah',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 8),
      infoTile(Icons.delete_outline, 'Domestic Waste Hub',
        'Domestic compartment unloads here; municipal collection happens at the hub.'),
      infoTile(Icons.recycling_rounded, 'Recycling Hub',
        'Recycling compartment unloads here; staff sort and weigh accepted material.'),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () {
        setState(() { robotCharging = !robotCharging;
          if (robotCharging) batteryPercent = 100; });
        toast(robotCharging ? 'Demo: Autobin docked and charged.' : 'Demo: Autobin undocked.');
      }, icon: const Icon(Icons.battery_charging_full),
        label: Text(robotCharging ? 'Undock Autobin (demo)' : 'Simulate docking / charging')),
    ]);
  }

  Widget compartmentCard(String title, IconData icon, int count, Color color) =>
    Container(padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 32), const SizedBox(height: 9),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('$count collecting', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]));

  Widget rewardsPage() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
    children: [
      const Text('Green rewards', style: TextStyle(fontSize: 23,
        fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 13),
      Container(padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [forest, dark]),
          borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 33),
          const SizedBox(height: 12),
          const Text('Your green points', style: TextStyle(color: Colors.white70)),
          Text('$totalPoints', style: const TextStyle(color: Colors.white, fontSize: 43,
            fontWeight: FontWeight.w900)),
          const Text('10 demo points per kg weighed and approved at the recycling hub',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
      const SizedBox(height: 20),
      const Text('How to earn', style: TextStyle(fontSize: 19,
        color: dark, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      infoTile(Icons.recycling, 'Recycle responsibly',
        'Request a recycling pickup for clean, accepted materials.'),
      infoTile(Icons.verified_outlined, 'Get your load verified',
        'The operator checks materials and hub staff confirms accepted weight.'),
      infoTile(Icons.stars_outlined, 'Receive green points',
        'Points are credited after the collection is completed.'),
      const SizedBox(height: 20),
      const Text('Reward ideas • demo only', style: TextStyle(fontSize: 19,
        color: dark, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      rewardTile('EcoTown reusable tote', '250 points', Icons.shopping_bag_outlined),
      rewardTile('Community garden voucher', '500 points', Icons.park_outlined),
      const SizedBox(height: 8),
      const Text('Redemption is a future feature. These are illustrative rewards, not live offers.',
        style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);

  Widget rewardTile(String title, String price, IconData icon) => Card(
    child: ListTile(leading: Icon(icon, color: forest, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(price), trailing: const Icon(Icons.lock_outline)));

  Widget operatorPage() {
    final active = pickups.where((p) => p.stage != PickupStage.completed && !p.rejected).length;
    final finished = pickups.where((p) => p.stage == PickupStage.completed).length;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      const Text('Township operations', style: TextStyle(fontSize: 23,
        color: dark, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Demo dispatch panel • human-supervised Autobin collection',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: metricCard('Requests', '${pickups.length}', Icons.receipt_long)),
        const SizedBox(width: 10),
        Expanded(child: metricCard('Active', '$active', Icons.electric_rickshaw)),
        const SizedBox(width: 10),
        Expanded(child: metricCard('Done', '$finished', Icons.check_circle_outline)),
      ]),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Collection hubs', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: dark)),
          const SizedBox(height: 13),
          hubRow(Icons.delete_outline, 'Domestic Waste Hub',
            pickups.where((p) => p.type == WasteKind.domestic &&
              p.stage.index >= PickupStage.atHub.index).length),
          const Divider(),
          hubRow(Icons.recycling, 'Recycling Hub',
            pickups.where((p) => p.type == WasteKind.recycle &&
              p.stage.index >= PickupStage.atHub.index).length),
        ]))),
      const SizedBox(height: 19),
      const Text('Dispatch queue', style: TextStyle(fontSize: 19,
        color: dark, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (pickups.isEmpty) emptyState(Icons.inbox_outlined,
        'No jobs in the queue', 'Create a request on Home to test dispatch.'),
      for (final p in pickups) Card(margin: const EdgeInsets.only(bottom: 12),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${p.id} • ${p.material}',
                style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('${p.amount.toStringAsFixed(1)} kg',
                style: const TextStyle(color: Colors.black54))]),
            const SizedBox(height: 7),
            Text('Status: ${p.rejected ? 'Flagged' : stageName(p.stage)}',
              style: const TextStyle(color: forest)),
            Text('Delivery: ${p.destination}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (p.type == WasteKind.recycle && p.stage == PickupStage.collecting && !p.verified) ...[
              const SizedBox(height: 11),
              const Text('Simulated waste recognition (not actual camera AI)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => verify(p, true),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Accept as recyclable')),
                OutlinedButton.icon(onPressed: () => verify(p, false),
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Flag contamination')),
              ]),
            ],
            if (p.type == WasteKind.recycle && p.stage == PickupStage.atHub &&
                !p.rejected) ...[
              const SizedBox(height: 11),
              Text(p.verifiedKg == null
                ? 'Recycling hub: verify accepted weight (demo uses estimated ${p.amount.toStringAsFixed(1)} kg)'
                : 'Hub-approved weight: ${p.verifiedKg!.toStringAsFixed(1)} kg · ${p.points} points',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              if (p.verifiedKg == null)
                OutlinedButton.icon(onPressed: () => confirmHubWeight(p),
                  icon: const Icon(Icons.scale_outlined), label: const Text('Confirm hub weight')),
            ],
            if (p.rejected) ...[
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => setState(() {
                p.rejected = false; p.verified = false;
              }), child: const Text('Reset verification')),
            ],
            if (!p.rejected && p.stage != PickupStage.completed) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => moveForward(p),
                icon: const Icon(Icons.arrow_forward),
                label: Text(p.stage == PickupStage.requested ? 'Assign township runner'
                  : p.stage == PickupStage.assigned ? 'Start collection route'
                  : p.stage == PickupStage.collecting ? 'Arrived at waste hub'
                  : 'Complete delivery'))),
            ],
          ]))),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(15)),
        child: const Text('MVP: operators supervise Autobin along township-approved sidewalks, with sorting at two central hubs. GPS/LiDAR navigation, real NFC, AI classification and automated unloading require hardware integration.',
          style: TextStyle(fontSize: 12, color: dark))),
    ]);
  }

  Widget hubRow(IconData icon, String title, int count) => Row(children: [
    Icon(icon, color: forest), const SizedBox(width: 12),
    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
    Text('$count loads', style: const TextStyle(color: forest,
      fontWeight: FontWeight.w700)),
  ]);

  Widget metricCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: forest), const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900,
        color: dark, fontSize: 23)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]));

  Widget infoTile(IconData icon, String title, String subtitle) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: forest)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12))));

  Widget emptyState(IconData icon, String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(children: [Icon(icon, size: 42, color: forest),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54))]));
}
