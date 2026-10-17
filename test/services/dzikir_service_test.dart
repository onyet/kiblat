import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/services/dzikir_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DzikirService.instance.debugReset();
  });

  test('loads morning and evening packs from assets', () async {
    await DzikirService.instance.load();
    expect(DzikirService.instance.pagiNotifier.value, isNotEmpty);
    expect(DzikirService.instance.petangNotifier.value, isNotEmpty);
    final pagi = DzikirService.instance.pagiNotifier.value;
    final first = pagi.first;
    expect(first.arabic, isNotEmpty);
    expect(first.meaning, isNotEmpty);
    expect(first.repeat, greaterThan(0));
    final withLatin = pagi.where((e) => e.latin.isNotEmpty).length;
    expect(withLatin, greaterThan(pagi.length ~/ 2));
  });

  test('increment respects repeat target and marks complete', () async {
    await DzikirService.instance.load();
    final item = DzikirService.instance.pagiNotifier.value.firstWhere(
      (e) => e.repeat == 1,
    );
    expect(DzikirService.instance.isComplete(item), isFalse);
    await DzikirService.instance.increment(item);
    expect(DzikirService.instance.countFor(item.id), 1);
    expect(DzikirService.instance.isComplete(item), isTrue);
    await DzikirService.instance.increment(item);
    expect(DzikirService.instance.countFor(item.id), 1);
  });
}
