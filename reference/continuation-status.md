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
  Workflow создан, но в этой сессии не запускался на GitHub.
- `tools/check_native.py` и `tools/check_horizon.py` больше не зависят только от
  Windows-пути `K:\Rust\...`; они используют `CARGO`/PATH с Windows fallback,
  `--locked` и project `target/`. Генераторы settings/uniforms аналогично ищут
  `rustfmt` через PATH.
- `tools/package_native.py` теперь делает корневой `.hnmod` byte-identical
  копией canonical-пакета в `artifacts/`. Integration test расширен проверкой
  исходников/шейдера/ресурсов/лицензии и равенства двух файлов.

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
  Пакет: 207 entries, 2 379 004 expanded bytes, SHA256
  `c3048a652bdf04bb81757ae0be1b4fcdcac2024f77061ebb008adfa1ec525ccc`.
  `zipfile.testzip()` вернул `None`; JSON checksum совпадает с артефактом.
  Проверено наличие adapter/core/GPU source, composite shader, original GLSL,
  LICENSE и NOTICE.
- `python3 -m py_compile` прошёл для изменённых Python-инструментов; workflow
  YAML распарсен PyYAML. Tree-sitter синтаксически проверил 38 Rust-файлов без
  ошибок; это не Rust typecheck и не сборка.
- `cargo`, `rustc`, `rustfmt` и `rust-analyzer` сейчас отсутствуют в PATH;
  Rust build/test, Horizon package reader test и GPU-check не выполнены.
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
