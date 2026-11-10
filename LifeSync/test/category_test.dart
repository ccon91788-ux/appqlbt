import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/data/models.dart';
import 'package:lifesync/data/repo.dart';
import 'package:lifesync/stickers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    Repo.useDb(await Repo.openAt(inMemoryDatabasePath, factory: databaseFactoryFfi));
  });
  tearDown(() async {
    await Repo.closeForTest();
    catStyles.clear();
  });

  test('Tạo danh mục tự đặt với sticker và màu viền', () async {
    final ok = await Repo.saveCategory(
      CatStyle(name: 'Mèo', isIncome: false, sticker: 'file:/x/a.png', border: 0xFFD94A2F, custom: true),
    );
    expect(ok, true);
    expect(catStickerName('Mèo'), 'file:/x/a.png');
    expect(catBorder('Mèo'), 0xFFD94A2F);
  });

  test('Không cho trùng tên với danh mục mặc định hoặc đã có', () async {
    expect(await Repo.saveCategory(CatStyle(name: 'Ăn uống', isIncome: false, custom: true)), false);
    expect(await Repo.saveCategory(CatStyle(name: 'Mèo', isIncome: false, custom: true)), true);
    expect(await Repo.saveCategory(CatStyle(name: 'Mèo', isIncome: false, custom: true)), false);
  });

  test('Sửa sticker danh mục mặc định, đổi tên danh mục tự tạo cập nhật giao dịch', () async {
    expect(await Repo.saveCategory(CatStyle(name: 'Ăn uống', isIncome: false, sticker: 'coffee'), oldName: 'Ăn uống'), true);
    expect(catStickerName('Ăn uống'), 'coffee');

    await Repo.saveCategory(CatStyle(name: 'Mèo', isIncome: false, custom: true));
    await Repo.saveTxn(Txn(isIncome: false, amount: 1000, category: 'Mèo', date: DateTime(2026, 10, 6)));
    expect(await Repo.saveCategory(CatStyle(name: 'Thú cưng', isIncome: false, custom: true), oldName: 'Mèo'), true);
    expect((await Repo.txns()).single.category, 'Thú cưng');
    expect(catStyles.containsKey('Mèo'), false);
  });

  test('Ghi chú lưu sticker và viền', () async {
    final n = Note(title: 'a', updated: DateTime.now(), sticker: 'pet', border: 0xFF4B8B57);
    await Repo.saveNote(n);
    final r = (await Repo.notes()).single;
    expect(r.sticker, 'pet');
    expect(r.border, 0xFF4B8B57);
  });
}
