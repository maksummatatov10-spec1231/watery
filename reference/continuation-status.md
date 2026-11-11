# Состояние переноса Watery — 2026-11-11

## Цель и статус

Цель остаётся полной Rust/Horizon-реализацией Watery 1.2.2: lifecycle/render
adapter, GPU-симуляция, terrain/material integrations, проверка Java-поведения,
воспроизводимая сборка `.hnmod` и CI. Порт **не завершён**: текущий Horizon
adapter запускает только диагностическую область и не означает gameplay parity.
Вёдра, полная запись в мир, network sync, сохранение, UI/recording и другие
игровые взаимодействия остаются незавершёнными.

## Действия этого продолжения

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
- Версия `watery-1.2.2-dev.1` пересобрана дважды детерминированно: 207 entries,
  SHA256 `43f62d359bc6174bb516beb557f7e99d4a761dcce33cc5128f63465a19d60cdd`;
  root copy byte-identical, `native-bundle/` содержит исправленный `projection.rs`.
  `tools/verify_reference.py`, Python `py_compile` и `git diff --check` прошли.
  Создан prerelease `watery-1.2.2-dev.1` на commit `0ecbb406e8692f183c59a7a1b3723086e2eabeba`;
  у него нет release assets, installation идёт через GitHub source archive.

## Технические детали адаптера, сохранённые в workspace

В `native/src/lib.rs` верхняя граница диагностического origin ограничена так,
чтобы размер области не переполнял `i32`; camera grid явно имеет тип `[f32; 3]`.
Collision boxes сохраняются до chunk invalidation; resolution 4 использует
`SolidCache`, прочие resolution — worker voxelization. Block-fill readback
использует `map_async` и `try_recv`, без ожидания GPU на render thread.
Эти пути остаются неподтверждёнными компилятором и runtime.

## Проверено в текущем окружении

- `python3 tools/verify_reference.py` — PASS: JAR SHA256 не изменился,
  проверены 713 inventory entries и 165 byte-identical ресурсов.
- После обновления документации, GPU-комментариев и сборщика
  `python3 tools/package_native.py` запущен дважды: обе сборки совпали, а `cmp`
  подтвердил идентичность `artifacts/watery-1.2.2-dev.hnmod` и корневой копии.
  Пакет: 207 entries, 2 379 406 expanded bytes, SHA256
  `2c52b8899c003730ef9017d9412a74c19be6cf29df1f927ac65b616a9f383f94`.
  `zipfile.testzip()` вернул `None`; JSON checksum совпадает с артефактом.
  Проверено наличие adapter/core/GPU source, composite shader, original GLSL,
  LICENSE и NOTICE.
- `python3 -m py_compile` прошёл для изменённых Python-инструментов; workflow
  YAML распарсен PyYAML. Tree-sitter синтаксически проверил 38 Rust-файлов без
  ошибок; это не Rust typecheck и не сборка.
- `cargo`, `rustc`, `rustfmt` и `rust-analyzer` сейчас отсутствуют в PATH;
  локальные Rust checks не запускались. Последний CI run подтвердил core tests,
  adapter compilation и package reader; GPU checks завершились ошибкой 101.
- Локальный путь `vendor/horizon/` отсутствует. Снимок Horizon найден только
  вне репозитория в `/tmp/watery_analysis/handoff/vendor/horizon`; его revision
  указан в `reference/horizon-source.json`.
- Реальный Horizon runtime/GPU и сравнительный прогон Java/Rust не проверялись.

## Ранее записанные результаты — исторические, не перепроверены сейчас

Предыдущая continuation-запись сообщала Rust 1.99.1 и Horizon
`b880384691b88d317553067109d28e785990bda3`, 14 core tests и 4 GPU allocation
checks, а также запуск 60 compute pipelines и сцен GPU на Radeon RX 580/Vulkan.
Там же записаны MPM/FLIP проверки, multilevel pressure oracle на размерах
17×9×7, 24×24×24, 33×29×27 и 43×41×39, плюс автономные emitter/remove/blast
регрессии. Эти результаты сохранены как история проекта; они не являются
результатом текущей сессии и ещё требуют запуска в CI.

## Следующие шаги

1. Обеспечить Rust toolchain согласно `rust-toolchain.toml` и разместить
   закреплённый Horizon source в `vendor/horizon/`.
2. Запустить `python3 tools/check_native.py --test` после
   `python3 tools/package_native.py`; устранить ошибки typecheck/build и
   подтвердить `Bundle::read` на настоящем пакете.
3. Запустить `cargo run --locked --manifest-path tools/gpu-check/Cargo.toml`
   на GPU или lavapipe, затем проверить job в `.github/workflows/ci.yml`.
4. Проверить мод в отдельной тестовой установке Horizon, затем сравнить
   одинаковые игровые сцены с Java-оригиналом. Не распространять как завершённый
   порт до проверки паритета и незавершённых игровых функций.
