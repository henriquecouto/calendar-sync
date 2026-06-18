## 1. Core change

- [x] 1.1 Replace `startsWith` with `contains` in `_classifySingle` title comparison

## 2. Tests

- [x] 2.1 Update existing "title detection" test to assert `contains` behavior
- [x] 2.2 Add test: HTML-wrapped description is correctly recognized as unchanged

## 3. Cleanup

- [x] 3.1 Run `flutter analyze` and fix any warnings
- [x] 3.2 Run `flutter test` and confirm all tests pass
