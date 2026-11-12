# Watery native adapter: experimental test build

**Это ограниченный диагностический стенд, не законченный порт и не стабильный
игровой мод.** По запросу подготовлен prerelease `watery-1.2.2-dev.2` для
изолированного smoke test. В нём нет регистрации оригинальных предметов в
креативе и полной игровой логики воды, песка или лавы.

Закреплённый host source: Horizon
`b880384691b88d317553067109d28e785990bda3` (см. `horizon-source.json`).
Соответствие этому commit установленной игре/launcher не подтверждено.
Пакет `artifacts/watery-1.2.2-dev.2.hnmod` собран из текущего source bundle;
CI проверяет сборку и чтение пакета, но фактическую установку и запуск в Horizon
нужно проверить отдельно.

## Диагностическая область

Команды адаптера:

- `/watery diagnostic [water|sand|lava|slime]` — создать временную тестовую
  область около текущей камеры; без аргумента используется вода;
- `/watery status` — вывести состояние активной области;
- `/watery pause` — переключить паузу симуляции;
- `/watery clear` — очистить тестовый runtime и кэши.

Область имеет размер 4×4×4 блока. Размер simulation grid равен размеру блока,
умноженному на resolution выбранного материала из `Settings::default()`.
Runtime остаётся привязан к вычисленному при запуске origin; перемещение игрока
само по себе не переносит область. Команды не записывают блоки и не меняют
сохранение мира.

## Что соединено в коде

- Hooks `frame`, `world_drawn`, `client_level_unload`, `commands` и `command`.
- Client chunk snapshot и collision boxes считываются на host thread. Секции
  обновляют `SolidCache`; при незагруженном чанке адаптер считает ячейки твёрдыми.
  Дополнительная voxelization collision boxes передаётся в Horizon worker pool.
- Для жидкостей записываются FLIP шаги, source inflow, surface reconstruction и
  fluid mesh/composite rendering; whitewater renderer подключается по настройкам.
  Для песка записываются MPM шаги и sand-grain rendering.
- Текстуры slime/sand периодически опрашиваются через `ClientResources` и
  загружаются в GPU-буферы.
- GPU block-fill readback выполняется асинхронно и используется для `FlowSounds`.
  Он **не** применяет заполнение к блокам мира.

Это описание вызовов из исходного кода, а не доказательство успешной сборки или
runtime-корректности. Отдельные автономные GPU-тесты не проверяют интеграцию
рендер-хуков Horizon.

## Не реализовано / не подтверждено

- Нет полноценной регистрации игровых материалов, жидкостей или песка и нет
  обработки игровых источников/вёдер как в оригинале.
- Block-fill не записывает мир; нет завершённой обработки поршней, сущностей,
  взрывов и всех игровых событий.
- `src/network.rs` не является подключённой authoritative sync-системой.
  Сохранение, восстановление, UI, запись роликов и настройки Horizon не связаны
  с runtime.
- Текстуры и освещение не обеспечивают полного паритета. Совместимость frame
  targets, прозрачности, depth, форматов и всех API-контрактов требует проверки
  на реальном Horizon runtime.
- Нет сравнения состояния симуляции с Java-оригиналом и нет замеров ускорения.

Не используйте `.hnmod` в основном мире или как завершённый мод.

## Как попробовать prerelease `watery-1.2.2-dev.2`

Это пересобранный экспериментальный диагностический пакет с текущими исходниками.
Предыдущий `dev.1` в пользовательском smoke test показал плохую картинку:
жидкость выглядела почти прозрачной/зеркальной, пропадала при контакте с блоками,
наблюдался высокий spawn в воздухе. `dev.2` не заявляет об исправлении этих
визуальных и игровых проблем; он нужен для ограниченного повторного теста.

Релиз и исходники доступны по тегу:

<https://github.com/maksummatatov10-spec1231/watery/releases/tag/watery-1.2.2-dev.2>

Отдельный бинарный asset к релизу не прикладывается: файл
`artifacts/watery-1.2.2-dev.2.hnmod` и исходный `native-bundle/` находятся в
source archive тега. В Horizon Launcher откройте **Mods → Add from GitHub** и
выберите тег `watery-1.2.2-dev.2`; запускайте Build только в отдельном тестовом
instance. Пакет исполняет нативный код с правами пользователя и не sandboxed;
запускайте его лишь если доверяете коду. Не устанавливайте его в основной
instance или мир.

В отдельном тестовом мире команды `/watery diagnostic [water|sand|lava|slime]`,
`/watery status`, `/watery pause` и `/watery clear` управляют временной областью
4×4×4 около камеры. Симуляция не записывает состояние в блоки мира. В игре не
добавлены оригинальные предметы в креатив, вёдра/источники или полноценные
взаимодействия — этим пакетом их проверить нельзя. Если тестируете, пришлите
полный build/runtime log, версию Horizon и выбранный материал.

## Локальная разработка

Нужен Rust toolchain из корневого `rust-toolchain.toml`, Python 3 и исходники
закреплённого Horizon revision в `vendor/horizon/`. Этот каталог игнорируется
Git; его нужно получить отдельно:

```sh
git clone https://github.com/horizon-rust/horizon.git vendor/horizon
git -C vendor/horizon checkout --detach b880384691b88d317553067109d28e785990bda3
python3 tools/verify_reference.py
cargo test --locked
python3 tools/package_native.py
python3 tools/check_native.py --test
cargo run --locked --manifest-path tools/gpu-check/Cargo.toml
```

`tools/check_native.py` без `--test` выполняет только `cargo check`. Пакетный
integration test `native/tests/package.rs` читает `.hnmod` через
`horizon_mods::index::native::Bundle::read`; сборщик запускается до теста.
GPU-check требует Vulkan-совместимый GPU или Mesa lavapipe. CI описан в
`.github/workflows/ci.yml` и не заменяет запуск внутри Horizon.

Исходный автор Watery — ItsBlueDD. Оригинал и производный порт распространяются
по GPL-3.0-only; лицензия и notice включены в development-пакет.
