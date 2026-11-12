# Состояние переноса Watery — 2026-11-11

## Актуальный статус по CI runs `43161880409` и `43162602752`

- Текущий scope — исходная алгоритмическая логика на Rust с сохранением
  поведения; Horizon demo и визуальная интеграция не являются результатом или
  критерием приёмки.
- Сохранены две differential-tested CPU-оптимизации: block-major
  `terrain::voxelize` и section-tiled `SolidCache::extract_region`. В paired
  CI run `43161880409` измерены соответственно 2.62–2.68× и 1.67–1.76× на
  двух размерах synthetic workload; числа в README — медианы одного runner,
  не гарантия для другой машины.
- GPU CI failure разобран. В run `43159597391` report на Radeon RX 580 был
  устаревшим tracked-файлом, а не выводом текущего запуска. После добавления
  очистки report CI показал настоящую compile-ошибку `E0382` в surface test
  (`Globals` перемещался повторно); исправлено через `clone()` в commit
  `0fc5b7c`. Run `43160670530` прошёл GPU и core jobs.
- В workflow добавлен строгий `cargo clippy --all-targets ... -D warnings`.
  Первый запуск выявил прежние lint warnings в atlas/network codecs; применены
  typed chunk slices и `NonZeroU64`, добавлен regression test для полностью
  прозрачной текстуры. Run `43161880409` целиком зелёный: format, tests, Clippy,
  paired benchmarks, deterministic package, pinned Horizon compile/package
  reader и GPU validation. Повторный run `43162602752` после обновления только
  документации и GPU report также прошёл полностью.
- GPU report [`gpu-check-report.md`](gpu-check-report.md) получен именно из
  run `43161880409`: 61/61 shader pipelines и семь execution checks на
  llvmpipe/Vulkan. Это не physics-equivalence, GPU-performance или Horizon
  runtime proof.
- Локально `cargo`/`rustc`/`rustfmt` отсутствуют; compile, unit tests, Clippy и
  benchmarks подтверждены последним GitHub Actions run. README, continuation
  status и tracked GPU report синхронизированы с этим результатом.
- Полный Rust rewrite остаётся частичным. Подтверждены ускорения двух CPU
  функций; другие алгоритмы ещё не профилировались и их ускорение не заявляется.

## Цель и статус

Актуальный scope по уточнению пользователя: переписывать и оптимизировать
алгоритмическую логику оригинала на Rust, сохраняя поведение и проверяя его
тестами/benchmarks. Horizon launcher, gameplay adapter и визуальный demo не
являются целью или критерием приёмки. Текущий adapter — диагностический артефакт
с неудовлетворительным рендером; дальнейшие игровые тесты пользователю не нужны.

## Предыдущая handoff-запись (до диагностики runs `43160126724`–`43161880409`)

- Обновлены README и native development notes: убраны устаревшие заявления,
  что adapter и `.hnmod` отсутствуют; явно обозначены диагностический scope,
  ограничения и непроверенная runtime-интеграция.
- Добавлен `rust-toolchain.toml` с Rust 1.99.1, rustfmt и clippy.
- Добавлен `.github/workflows/ci.yml`: pinned Horizon checkout, core-тесты,
  две последовательные сборки пакета с проверкой одинакового SHA, Horizon
  `Bundle::read` integration test и GPU pipeline/regression job на lavapipe.
  Первые два GitHub Actions runs завершились ошибкой; после сборочного исправления
  третий run прошёл core/package job, но GPU regression остался красным (ниже).
- `tools/check_native.py` и `tools/check_horizon.py` больше не зависят только от
  Windows-пути `K:\Rust\...`; они используют `CARGO`/PATH с Windows fallback,
  `--locked` и project `target/`. Генераторы settings/uniforms аналогично ищут
  `rustfmt` через PATH.
- `tools/package_native.py` теперь делает корневой `.hnmod` byte-identical
  копией canonical-пакета в `artifacts/` и создаёт `native-bundle/` — его
  распакованный источник для GitHub Launcher's source-archive fallback.
  Integration test расширен проверкой исходников/шейдера/ресурсов/лицензии и
  равенства двух `.hnmod` файлов.
- Ветка `arena/46e97339-watery` запушена; tag `watery-1.2.2-dev` указывает на
  `1d066e9bcacd885184e5a6e6e633f9fd1384648f`. GitHub prerelease создан.
  Попытка прикрепить `.hnmod` к release упёрлась в EOF на `uploads.github.com`,
  поэтому asset отсутствует. Для Horizon `Add from GitHub` работает source-
  fallback: codeload-архив тега содержит проверенный в GitHub tree `native-bundle/`;
  launcher перепакует его сам. Готовый `.hnmod` также лежит в `artifacts/` и в
  корне репозитория, но не является release asset.
- Пользователь приложил Windows `build.log` из `main` (commit `47df5b8`). В нём
  точный отказ компилятора: `E0425`, отсутствуют `projection::water_level` и
  `projection::sand_layers` в `src/flow_sounds.rs`; `watery-core` завершился с
  code 101. Повторное нажатие Build каждый раз запускало ту же неуспешную сборку;
  сообщения `mimalloc` — предупреждения, не причина отказа.
- Добавлены недостающие projection wrappers, использующие существующие
  liquid/sand thresholds, и unit test для vanilla level/layer mapping. Собран
  новый package `1.2.2-dev.1`; старый tag `watery-1.2.2-dev` намеренно не меняется.
  Требуется удалить старую версию из тестового instance и добавить новый tag.
- GitHub Actions runs 43107007344 и 43107372714 были failure: core job завершился
  exit 101; GPU job — при установке Vulkan driver (exit 1), до GPU checks. В run
  43110851912 на commit `0ecbb40` после исправления core job прошёл полностью:
  `cargo test`, повторная deterministic package build, Horizon adapter compilation
  и `Bundle::read` — PASS. Обновлённый поиск Lavapipe ICD тоже прошёл.
- Тот же run `43110851912` всё ещё overall failure: шаг `Run GPU pipeline and
  simulation checks` завершился exit 101. Raw logs и GPU report artifact из Actions
  недоступны из этого окружения (EOF), точная причина не установлена. Это не
  полный зелёный CI и не проверка в реальном Horizon runtime.
- Первая measured-оптимизация: `terrain::voxelize` проходит блоками, кеширует
  subcell centers, пропускает пустые блоки и рядами заполняет full cubes.
  Differential test сравнивает маску со старым cell-major oracle на resolutions
  1/2/3/4/7 и edge cases. На следующих paired CI runs результат колебался между
  2.5× и 3.6× в зависимости от runner.
- Добавлен paired benchmark для `SolidCache::extract_region` с сохранённым
  reference-алгоритмом под feature `bench-reference`. Рефакторинг обходит регион
  плитками 16×16×16 и делает lookup секции один раз на плитку вместо каждого
  блока; добавлены differential tests для отрицательных координат, отсутствующих
  секций и обоих режимов `unloaded_solid`, а также отказ на world-coordinate
  overflow. В CI run `43157229793` core/test/bench и package job прошли. На
  одинаковом runner получено: diagnostic 4×4×4 / res 4 — 3,135 → 2,106 ns
  (1.49×); 16×8×16 / res 4 — 106,101 → 59,393 ns (1.79×). Это синтетические
  paired measurements, не гарантированный коэффициент для других машин.
- Тот же run подтвердил для terrain: 4×4×4 / res 6 — 51,922 → 18,908 ns
  (2.75×); 16×8×16 / res 6 — 1,694,488 → 603,705 ns (2.81×).
- GPU regression job в run `43157229793` снова завершилась exit 101. Check-run
  подтверждает только exit code; raw log и 929-byte artifact
  `gpu-check-report` не скачиваются из этого окружения (EOF), поэтому причина
  остаётся неизвестной.
- Версия `watery-1.2.2-dev.1` пересобрана дважды детерминированно: 207 entries,
  SHA256 `43f62d359bc6174bb516beb557f7e99d4a761dcce33cc5128f63465a19d60cdd`;
  root copy byte-identical, `native-bundle/` содержит исправленный `projection.rs`.
  `tools/verify_reference.py`, Python `py_compile` и `git diff --check` прошли.
  Создан prerelease `watery-1.2.2-dev.1` на commit `0ecbb406e8692f183c59a7a1b3723086e2eabeba`;
  у него нет release assets, installation идёт через GitHub source archive.
- Пользователь подтвердил запуск `watery-1.2.2-dev.1` на Horizon 0.1.0 и Radeon
  RX 580 (Vulkan): мир загрузился, Watery-команды зарегистрировались,
  `/watery diagnostic water` создал регион `[3, 103, 3]`, сетка `24×24×24`
  (13 824 ячейки), `paused=false`, `sections=1`, `terrain_pending=false`.
  Однако визуальная симуляция оценена как неприемлемая: жидкость почти прозрачная
  и зеркальная, исчезает при контакте с блоками, есть высокий spawn в воздухе.
  Это подтверждает только запуск/команду, не нужный пользователю Rust rewrite.

## Технические детали адаптера, сохранённые в workspace

В `native/src/lib.rs` верхняя граница диагностического origin ограничена так,
чтобы размер области не переполнял `i32`; camera grid явно имеет тип `[f32; 3]`.
Collision boxes сохраняются до chunk invalidation; resolution 4 использует
`SolidCache`, прочие resolution — worker voxelization. Block-fill readback
использует `map_async` и `try_recv`, без ожидания GPU на render thread.
Core, Horizon adapter и чтение пакета прошли CI compilation/test; поведение этих
GPU-путей внутри игры всё ещё требует визуальной проверки.

## Проверки, записанные в предыдущем handoff (исторические)

- `python3 tools/verify_reference.py` — PASS: JAR SHA256 не изменился,
  проверены 713 inventory entries и 165 byte-identical ресурсов.
- Историческая версия `watery-1.2.2-dev` собиралась детерминированно: 207 entries,
  2 379 406 expanded bytes, SHA256
  `2c52b8899c003730ef9017d9412a74c19be6cf29df1f927ac65b616a9f383f94`.
- Для `watery-1.2.2-dev.1` сборщик запускался дважды; ZIP CRC и JSON checksum
  проверены, `artifacts/` и корневой `.hnmod` byte-identical. Пакет содержит
  207 entries / 2 380 711 expanded bytes, SHA256
  `43f62d359bc6174bb516beb557f7e99d4a761dcce33cc5128f63465a19d60cdd`.
  Source archive bundle включает исправленные `water_level` и `sand_layers`.
- `python3 -m py_compile` прошёл для изменённых Python-инструментов; workflow
  YAML распарсен PyYAML. Tree-sitter синтаксически проверил 38 Rust-файлов без
  ошибок; это не Rust typecheck и не сборка.
- `cargo`, `rustc`, `rustfmt` и `rust-analyzer` сейчас отсутствуют в PATH;
  локальные Rust checks не запускались. Последний CI run подтвердил core tests,
  adapter compilation и package reader; GPU checks завершились ошибкой 101.
- Локальный путь `vendor/horizon/` отсутствует. Снимок Horizon найден только
  вне репозитория в `/tmp/watery_analysis/handoff/vendor/horizon`; его revision
  указан в `reference/horizon-source.json`.
- Был один пользовательский runtime smoke test в Horizon 0.1.0 на Radeon RX 580:
  startup + diagnostic command успешны. Визуальное отображение/движение воды, GPU
  kernels в пользовательской сцене, другие материалы и сравнение Java/Rust ещё не
  подтверждены.

## Ранее записанные результаты — исторические, не перепроверены сейчас

Предыдущая continuation-запись сообщала Rust 1.99.1 и Horizon
`b880384691b88d317553067109d28e785990bda3`, 14 core tests и 4 GPU allocation
checks, а также запуск 60 compute pipelines и сцен GPU на Radeon RX 580/Vulkan.
Там же записаны MPM/FLIP проверки, multilevel pressure oracle на размерах
17×9×7, 24×24×24, 33×29×27 и 43×41×39, плюс автономные emitter/remove/blast
регрессии. Эти результаты сохранены как история проекта; они не являются
результатом текущей сессии и ещё требуют запуска в CI.

## Следующие шаги

Продолжать автономно исходную Rust-работу; не просить пользователя проверять
Horizon visuals и не заявлять parity без доказательств.

1. Использовать сохранённые bytecode/GLSL и текущие regression tests, чтобы
   выбрать следующий CPU/GPU алгоритм для профилирования; не оптимизировать код
   только по интуиции.
2. Для кандидата сначала добавить воспроизводимый workload/benchmark и
   differential test, затем менять реализацию и сравнивать парные результаты.
3. Сохранять зелёный strict Clippy/core/package/GPU CI; GPU pipeline report не
   считать physics-equivalence или performance proof.
4. Полный Rust rewrite и parity остаются незавершёнными; продолжать работу на
   этой ветке и фиксировать оставшиеся ограничения/реальные замеры.
