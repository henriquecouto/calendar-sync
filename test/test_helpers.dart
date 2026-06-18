import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialized = false;

void initTestDb() {
  if (!_initialized) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initialized = true;
  }
}
