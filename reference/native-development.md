# Watery native adapter: development notes

**Это ограниченный интеграционный стенд, не законченный порт и не release.**
Закреплённый host source: Horizon
`b880384691b88d317553067109d28e785990bda3` (см. `horizon-source.json`).
Соответствие этому commit установленной игре/launcher не подтверждено.
Пакет `artifacts/watery-1.2.2-dev.1.hnmod` несёт пометку `1.2.2-dev.1`; фактическую
установку и запуск в Horizon пока нельзя считать проверенными.

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

## Как попробовать prerelease

**Важно:** прежний prerelease `watery-1.2.2-dev` не собирался из-за двух
отсутствующих функций в `projection`. Не запускайте Build снова для старой
версии. Удалите её из тестового instance, затем добавьте исправленную
`watery-1.2.2-dev.1` по ссылке ниже.

Предварительно собранный development-файл находится в
`artifacts/watery-1.2.2-dev.1.hnmod` (byte-identical копия — в корне репозитория).
В Horizon Launcher выберите отдельный тестовый instance, откройте **Mods → Add
from GitHub** и укажите точную ссылку на prerelease:

<https://github.com/maksummatatov10-spec1231/watery/releases/tag/watery-1.2.2-dev.1>

У prerelease нет прикреплённого бинарного asset: Horizon Launcher получает
`native-bundle/` из source archive, формирует `.hnmod` и проверяет его. Пакет
исполняет нативный код с правами пользователя и не sandboxed. Принимайте
предупреждение о доверии только если готовы запускать этот исходный код.
Далее нажмите **Build** для выбранного instance; первая сборка может занять
20–30 минут. Если launcher предупреждает о закреплённом Horizon revision,
следуйте его сообщению и не переключайте основной instance.

В отдельном тестовом мире выполни `/watery diagnostic water` и `/watery status`.
Можно попробовать `sand`, `lava` и `slime`; `/watery clear` удаляет временный
runtime. Диагностическая симуляция не записывает состояние в блоки мира.
При ошибке пришлите полный текст build/runtime log, версию Horizon и выбранный
материал. Этот prerelease не прошёл фактический запуск в игре.

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
