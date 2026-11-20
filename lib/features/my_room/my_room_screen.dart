import 'eki_in_book.dart';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_scene.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/my_catalog.dart';
import '../../data/my_store.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/purchases.dart';
import 'plate_editor.dart';
import 'share_card.dart';
import 'stamp_book_screen.dart';
import 'station_plate.dart';
import 'train_dex_screen.dart';

const _green = Color(0xFF2E9447);
const _gold = Color(0xFFF2B33D);

/// Train colour in MY when no train colour is equipped (Yamanote green).
const myDefaultLine = Color(0xFF80C241);

/// Badge on seasonal items (期間限定).
const _limitedLabel = LocalizedText({'ja': '期間限定', 'ko': '기간 한정', 'en': 'Limited'});

/// The items the shop shows: seasonal items only in their season, unless
/// already owned. [jst] is the Japan date.
List<MyItem> shopItems(Iterable<MyItem> items, bool Function(String id) owns, DateTime jst) => [
  for (final i in items)
    if (i.onSale(jst) || owns(i.id)) i,
];

/// Station name for an unlock condition like `line:tokyo.ginza`.
String unlockLineName(CityData city, String? unlock, String lang) {
  final id = unlock?.startsWith('line:') == true ? unlock!.substring(5) : null;
  final line = id == null ? null : city.lines.where((l) => l.id == id).firstOrNull;
  return line?.name.of(lang) ?? '';
}

/// MY駅: decorate the station shown at the top of のりば. Pick the station
/// scene, the train colour, roof and platform decorations and effects;
/// buy them with coins earned by riding (or, later, with money).
class MyRoomScreen extends StatefulWidget {
  const MyRoomScreen({super.key, required this.city});
  final CityData city;

  @override
  State<MyRoomScreen> createState() => MyRoomScreenState();
}

class MyRoomScreenState extends State<MyRoomScreen> {
  /// From のりば: show [itemId]'s tab and open its purchase sheet (or just
  /// equip it when it is already owned).
  Future<void> openItem(String itemId) async {
    if (!_store.loaded) await _store.load();
    final cat = _store.catalog;
    if (cat == null || !mounted) return;
    final item = cat.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    setState(() => _tab = item.slot);
    await _tapItem(item);
  }

  /// From the coin chip on のりば.
  Future<void> openCoinShop() => _openCoinShop();

  MyStore get _store => Services.my;
  MySlot _tab = MySlot.scene;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    if (!_store.loaded) _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _tapItem(MyItem item) async {
    // Melodies: hear it first (even on silent: the user asked for it).
    if (item.slot == MySlot.melody) {
      item.sound == null ? Services.melody.stop() : Services.melody.play(item.sound!, force: true);
    }
    if (_store.owns(item.id)) {
      // Sticker packs are not worn: owning them is enough.
      if (item.slot != MySlot.sticker) await _store.equip(item.id);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: PixelColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _BuySheet(item: item, city: widget.city, onCoinShop: _openCoinShop),
    );
  }

  PlateData _plate(String lang) => PlateData.of(_store, fallbackName: _store.sceneItem?.name.of(lang) ?? '');

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: PixelColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => child,
  );

  /// Which widget to add: 'my' (MY駅), 'board' (地下鉄案内) or 'next' (つぎの電車).
  Future<String?> _chooseWidget(AppLocalizations t) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: PixelColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelText(t.widgetChoose, size: 18),
            const SizedBox(height: 12),
            for (final (kind, icon, title, desc) in [
              ('my', Icons.photo_rounded, t.widgetKindMy, t.widgetKindMyDesc),
              ('board', Icons.departure_board_rounded, t.widgetKindBoard, t.widgetKindBoardDesc),
              ('next', Icons.timer_rounded, t.widgetKindNext, t.widgetKindNextDesc),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFFEFF7F1),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(icon, color: _green),
                    title: PixelText(title, size: 17),
                    subtitle: PixelText(desc, size: 12, color: PixelColors.muted),
                    onTap: () => Navigator.pop(context, kind),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  void _editPlate(String lang) => _sheet(PlateEditor(fallbackName: _store.sceneItem?.name.of(lang) ?? ''));

  Future<void> _openCoinShop() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: PixelColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _CoinShop(),
    );
  }

  Future<void> _enterInvite(AppLocalizations t) async {
    final field = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.myInviteEnter),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: t.myInviteField),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, field.text), child: Text(t.myInviteUse))],
      ),
    );
    field.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    final result = await _store.useInvite(code);
    if (!mounted) return;
    final text = switch (result) {
      InviteResult.ok => t.myInviteOk(MyStore.inviteCoins),
      InviteResult.own => t.myInviteOwn,
      InviteResult.used => t.myInviteUsed,
      InviteResult.invalid => t.myInviteInvalid,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final cat = _store.catalog;
    if (cat == null) return const SizedBox.shrink();
    final rules = cat.rules;
    final tabs = {
      MySlot.scene: t.myTabScene,
      MySlot.plate: t.myTabPlate,
      MySlot.train: t.myTabTrain,
      MySlot.roof: t.myTabRoof,
      MySlot.platform: t.myTabPlatform,
      MySlot.effect: t.myTabEffect,
      MySlot.melody: t.myTabMelody,
      MySlot.sticker: t.shareStickers,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Expanded(child: PixelText(t.myTitle, size: 30)),
            _CoinChip(coins: _store.coins, onTap: _openCoinShop),
          ],
        ),
        const SizedBox(height: 14),
        // The same picture as the top of のりば, with everything equipped.
        MyStationView(look: _store.look, plate: _plate(lang), lineColor: myDefaultLine, onTap: () => _editPlate(lang)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionChip(icon: Icons.edit_rounded, label: t.plateEdit, onTap: () => _editPlate(lang)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionChip(
                icon: Icons.approval_rounded,
                label: t.stampOpen,
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => StampBookScreen(city: widget.city))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionChip(
                icon: Icons.ios_share_rounded,
                label: t.shareOpen,
                onTap: () => _sheet(ShareCardSheet(city: widget.city, plate: _plate(lang), lineColor: myDefaultLine)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionChip(
                icon: Icons.widgets_rounded,
                label: t.widgetAdd,
                onTap: () async {
                  final kind = await _chooseWidget(t);
                  if (kind == null || !context.mounted) return;
                  if (await Services.homeWidget.requestPin(kind: kind) || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.widgetManual)));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionChip(
                icon: Icons.train_rounded,
                label: trainDexTitle.of(lang),
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => TrainDexScreen(city: widget.city))),
              ),
            ),
            const SizedBox(width: 8),
            // 駅印帳: the stamps as a 御朱印帳-style book.
            Expanded(
              child: _ActionChip(
                icon: Icons.menu_book_rounded,
                label: _ekiInTitle.of(lang),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkiInBookScreen(city: widget.city, stamps: _store.stamps),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PixelText(
          t.myEarnRules(rules.perTrip, rules.firstVisit, rules.firstTripOfDay),
          size: 12,
          color: PixelColors.muted,
        ),
        // A friend's invite code (from their share card): coins, once.
        if (!_store.inviteUsed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => _enterInvite(t),
              icon: const Icon(Icons.card_giftcard_rounded, size: 16, color: _green),
              label: Text(
                '${t.myInviteEnter} (+${MyStore.inviteCoins})',
                style: const TextStyle(fontSize: 12, color: PixelColors.ink),
              ),
            ),
          ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in tabs.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tab == e.key ? _green : PixelColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _tab == e.key ? _green : PixelColors.line),
                      ),
                      child: PixelText(e.value, size: 16, color: _tab == e.key ? PixelColors.card : PixelColors.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            for (final item in shopItems(
              cat.inSlot(_tab),
              _store.owns,
              DateTime.now().toUtc().add(const Duration(hours: 9)),
            ))
              _ItemCard(
                item: item,
                owned: _store.owns(item.id),
                equipped: _store.isEquipped(item.id),
                onTap: () => _tapItem(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins, required this.onTap});
  final int coins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: PixelColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PixelColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 8),
          PixelText('$coins', size: 20, bold: true),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 18, color: PixelColors.card),
          ),
        ],
      ),
    ),
  );
}

/// Gold coin used wherever coins are shown.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _gold,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFC88A1E), width: size / 10),
    ),
    alignment: Alignment.center,
    child: Text(
      'C',
      style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w900, color: PixelColors.card, height: 1),
    ),
  );
}

/// Small rounded button under the preview.
class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 58,
      decoration: BoxDecoration(
        color: PixelColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PixelColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: _green),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: PixelColors.ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.owned, required this.equipped, required this.onTap});
  final MyItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PixelColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: equipped ? _green : PixelColors.line, width: equipped ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumb(item: item),
                  if (item.season != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5486A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PixelText(_limitedLabel.of(lang), size: 11, bold: true, color: PixelColors.card),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  Expanded(child: PixelText(item.name.of(lang), size: 15, maxLines: 1)),
                  if (equipped)
                    PixelText(t.myEquipped, size: 12, color: _green)
                  else if (owned)
                    PixelText(item.free ? t.myFree : t.myOwned, size: 12, color: PixelColors.muted)
                  else if (item.unlock != null) ...[
                    const Icon(Icons.lock_rounded, size: 14, color: PixelColors.muted),
                    const SizedBox(width: 2),
                    PixelText(t.myLocked, size: 12, color: PixelColors.muted),
                  ] else ...[
                    const CoinIcon(),
                    const SizedBox(width: 4),
                    PixelText('${item.price}', size: 15, bold: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small picture for an item: the scene itself, the train in its colour,
/// or an icon for decorations.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
  final MyItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.slot) {
      case MySlot.scene:
        final path = item.images[DayPart.evening] ?? 'assets/art/scene_evening.png';
        return Image.asset(path, fit: BoxFit.cover, filterQuality: FilterQuality.none);
      case MySlot.plate:
        return ColoredBox(
          color: PixelColors.background,
          child: Center(
            child: LedSign(
              text: item.name.of(langOf(context)),
              colors: (item.plate ?? PlateStyle.basic).colors,
              width: 130,
            ),
          ),
        );
      case MySlot.train:
        return ColoredBox(
          color: PixelColors.background,
          child: Center(
            child: SideTrain(color: item.color ?? const Color(0xFF80C241), art: item.art, scale: 2),
          ),
        );
      case MySlot.sticker:
        // The pack's stickers, two by two.
        return ColoredBox(
          color: const Color(0xFFFFF4E6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final s in item.stickers.take(4))
                  Image.asset('assets/art/stickers/$s.png', filterQuality: FilterQuality.none),
              ],
            ),
          ),
        );
      default:
        final icon = switch (item.id) {
          'roof.lanterns' => Icons.light_rounded,
          'roof.garland' => Icons.auto_awesome_rounded,
          'platform.vending' => Icons.local_drink_rounded,
          'effect.petals' => Icons.filter_vintage_rounded,
          'effect.fireflies' => Icons.flare_rounded,
          'melody.off' => Icons.music_off_rounded,
          _ when item.slot == MySlot.melody => Icons.music_note_rounded,
          _ => Icons.block_rounded,
        };
        return ColoredBox(
          color: PixelColors.background,
          child: Icon(icon, size: 40, color: item.price == 0 ? PixelColors.muted : const Color(0xFFE0513F)),
        );
    }
  }
}

/// The side-view pixel train with its stripe in [color].
class SideTrain extends StatelessWidget {
  const SideTrain({super.key, required this.color, this.art, this.scale = 2});
  final Color color;
  final double scale;

  /// A train with its own pictures (side_base / side_stripe in this folder).
  final String? art;

  @override
  Widget build(BuildContext context) {
    final (w, h) = art == null ? (56.0, 20.0) : (61.0, 18.0);
    Widget img(String a) =>
        Image.asset(a, width: w * scale, height: h * scale, fit: BoxFit.fill, filterQuality: FilterQuality.none);
    return Stack(
      children: [
        img(art == null ? 'assets/art/train_side_base.png' : '$art/side_base.png'),
        ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.modulate),
          child: img(art == null ? 'assets/art/train_side_stripe.png' : '$art/side_stripe.png'),
        ),
      ],
    );
  }
}

class _BuySheet extends StatelessWidget {
  const _BuySheet({required this.item, required this.city, required this.onCoinShop});
  final MyItem item;
  final CityData city;
  final VoidCallback onCoinShop;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final store = Services.my;
    final missing = item.unlock != null ? 0 : item.price - store.coins;
    Future<void> done() async {
      await store.equip(item.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.myGot(item.name.of(lang))), duration: const Duration(seconds: 2)));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(item.name.of(lang), size: 26),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _Thumb(item: item),
              ),
            ),
            const SizedBox(height: 16),
            if (item.unlock != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.approval_rounded, color: Color(0xFFE2A61E)),
                    const SizedBox(width: 10),
                    Expanded(child: PixelText(t.myUnlockHint(unlockLineName(city, item.unlock, lang)), size: 15)),
                  ],
                ),
              ),
            if (item.price > 0 && item.unlock == null)
              _BigButton(
                color: missing > 0 ? PixelColors.soft : _green,
                onTap: missing > 0
                    ? null
                    : () async {
                        if (await store.buyWithCoins(item.id) == BuyResult.ok) await done();
                      },
                child: PixelText(
                  missing > 0 ? t.myNotEnough(missing) : t.myBuyCoins(item.price),
                  size: 18,
                  color: missing > 0 ? PixelColors.muted : PixelColors.card,
                ),
              ),
            if (item.priceYen != null) ...[
              const SizedBox(height: 10),
              _BigButton(
                color: PixelColors.ink,
                onTap: () async {
                  final r = await Services.purchases.buy(item.id);
                  if (r == PurchaseOutcome.purchased) {
                    await store.grant(item.id);
                    await done();
                  } else if (r == PurchaseOutcome.notAvailable && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.myIapNotReady)));
                  }
                },
                child: PixelText(t.myBuyYen(item.priceYen!), size: 18, color: PixelColors.card),
              ),
            ],
            if (missing > 0) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCoinShop();
                },
                child: Text(
                  t.myCoinShop,
                  style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoinShop extends StatelessWidget {
  const _CoinShop();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = Services.my;
    final packs = store.catalog?.packs ?? const [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(t.myCoinShop, size: 24),
            const SizedBox(height: 12),
            for (final p in packs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BigButton(
                  color: PixelColors.background,
                  onTap: () async {
                    final r = await Services.purchases.buy(p.id);
                    if (r == PurchaseOutcome.purchased) {
                      await store.addCoins(p.coins);
                    } else if (r == PurchaseOutcome.notAvailable && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.myIapNotReady)));
                    }
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const CoinIcon(size: 22),
                      const SizedBox(width: 10),
                      PixelText('${p.coins}', size: 20, bold: true),
                      const Spacer(),
                      PixelText('¥${p.priceYen}', size: 18),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
            PixelText(t.myIapNotReady, size: 12, color: PixelColors.muted),
            if (kDebugMode) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: () => store.addCoins(500), child: Text('${t.myTestCoins} (+500)')),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.color, required this.child, this.onTap});
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: child,
    ),
  );
}

const _ekiInTitle = LocalizedText({'ja': '駅印帳', 'ko': '역 도장첩', 'en': 'Station Seal Book'});
