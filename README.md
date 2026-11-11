# Watery 1.2.2 → Rust / Horizon

**Статус: development-порт, не завершённый игровой порт и не production-релиз.**
Исходный JAR сохранён без изменений. Ветка содержит Rust/GPU-реализацию и
диагностический адаптер Horizon, но полного паритета с оригинальным Fabric-модом
пока нет.

## Что уже есть в репозитории

- `reference/original/` и `reference/bytecode/` — неизменённые ресурсы и
  справочное дизассемблирование Watery 1.2.2. Проверка `tools/verify_reference.py`
  сверяет SHA256 JAR и сохранённые ресурсы.
- `src/` — перенос настроек, uniforms, материалов, индексации, collision
  voxelization/cache, текстур атласа, части flow-sound и сетевых данных.
- `gpu/` и `generated/shaders/` — GPU-графы FLIP для жидкостей, MPM для песка,
  восстановление поверхности, mesh/composite rendering, whitewater и sand-grain
  rendering. WGSL происходит из сохранённых GLSL-ресурсов/переносов.
- `native/src/` — Horizon hooks для **диагностической** области около камеры:
  получение collision snapshot, загрузка текстур материала, команды, GPU-запись
  кадров и асинхронный block-fill readback для звуковых событий.
- `artifacts/watery-1.2.2-dev.hnmod` — воспроизводимый development-пакет;
  `watery-1.2.2-dev.hnmod` в корне — его byte-identical копия для удобства.
  Проверка пакета через `Bundle::read` находится в `native/tests/package.rs`.
- `.github/workflows/ci.yml` — CI для core/native/package reader и GPU-регрессий.
  Используется закреплённый снимок Horizon из `reference/horizon-source.json`.

Перечень встроенных функций не означает, что они уже проверены внутри самой
игры. В частности, компиляция Horizon adapter, чтение `.hnmod` через Horizon и
GPU execution должны подтверждаться выполнением соответствующих CI jobs.

## Диагностический режим

После сборки адаптера команды `/watery diagnostic [water|sand|lava|slime]`,
`/watery status`, `/watery pause` и `/watery clear` запускают или очищают
ограниченную временную сцену. Область занимает 4×4×4 блока около камеры;
размер сетки зависит от разрешения материала. Мир и сохранение не изменяются.

Это стенд для интеграции и проверки рендеринга, а не реализация игрового
создания жидкостей/песка. Не устанавливайте development-пакет в основной мир.

## Как попробовать development-сборку

В Horizon Launcher выбери отдельный тестовый instance → **Mods → Add from
GitHub** и вставь ссылку на точный prerelease:

<https://github.com/maksummatatov10-spec1231/watery/releases/tag/watery-1.2.2-dev>

Подтверди предупреждение о доверии только если готов запускать native-код из
этого репозитория: `.hnmod` не sandboxed и получает права игры/пользователя.
Затем нажми **Build** для этого instance. Первая native-сборка может занять
20–30 минут; Horizon может предложить использовать закреплённую версию исходников.
После запуска войди в отдельный тестовый мир и выполни `/watery diagnostic water`
(или `sand`, `lava`, `slime`), затем `/watery status`. `/watery clear` удаляет
временную диагностическую область; она не записывает содержимое в мир.

Если сборка, загрузка или рендер не проходят, пришли текст ошибки из окна
сборки/лога и версию Horizon. Это development-пакет, поэтому возможен отказ;
не используй его в основном instance или мире.

## Что ещё не завершено

- Полная игровая parity с Watery 1.2.2, сравнение Java/Rust на одинаковых сценах
  и подтверждение производительности.
- Игровые источники и вёдра, запись симуляции обратно в блоки мира, реакции
  материалов и взаимодействия, полный server-authoritative network sync.
- Сохранение/восстановление, UI, запись роликов и прочие игровые lifecycle hooks.
- Проверка адаптера на реальном Horizon runtime, нескольких драйверах и GPU.
- Проверка того, что закреплённая версия Horizon соответствует установленной у
  пользователя игре и launcher.

См. [`reference/native-development.md`](reference/native-development.md) и
[`reference/continuation-status.md`](reference/continuation-status.md) для
ограничений и фактического статуса проверок.

## Сборка и проверки

Требуется Rust toolchain из `rust-toolchain.toml` (Rust 1.99.1), Python 3 и
закреплённый Horizon source в игнорируемом каталоге `vendor/horizon/`:

```sh
git clone https://github.com/horizon-rust/horizon.git vendor/horizon
git -C vendor/horizon checkout --detach b880384691b88d317553067109d28e785990bda3
python3 tools/verify_reference.py
cargo test --locked
python3 tools/package_native.py
python3 tools/check_native.py --test
cargo run --locked --manifest-path tools/gpu-check/Cargo.toml
```

GPU execution требует Vulkan-совместимый адаптер; CI использует Mesa lavapipe.
`tools/check_native.py` также доступен в режиме `cargo check` без `--test`.
Сборка пакета намеренно помечена `1.2.2-dev`; она не является релизной
установкой мода.

Оригинальный мод: Watery 1.2.2, Fabric, Minecraft 26.3, Java ≥25,
GPL-3.0-only. Автор оригинала — ItsBlueDD. SHA256 исходного JAR:
`d5b4e546ed6e7e3834a8a31ddfd3066500540adde53f723545ea5ebdf307d973`.
Производный код и ресурсы распространяются с соблюдением GPL-3.0-only;
лицензионные сведения включены в development-пакет.
