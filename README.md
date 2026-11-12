# Watery 1.2.2 — Rust rewrite / optimization

**Цель: переписать и оптимизировать алгоритмическую логику на Rust. Это не
задача по созданию игрового Horizon-мода.** Исходный JAR, ресурсы и bytecode
сохранены для сверки поведения; Rust rewrite пока частичный. Horizon adapter и
`.hnmod` — отдельный неудачный диагностический эксперимент, не результат порта.

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
- `artifacts/watery-1.2.2-dev.1.hnmod` — воспроизводимый development-пакет;
  `watery-1.2.2-dev.1.hnmod` в корне — его byte-identical копия для удобства.
  Проверка пакета через `Bundle::read` находится в `native/tests/package.rs`.
- `.github/workflows/ci.yml` — CI для core/native/package reader и GPU-регрессий.
  Используется закреплённый снимок Horizon из `reference/horizon-source.json`.

Пользовательский smoke test Horizon 0.1.0 / Radeon RX 580 (Vulkan) подтвердил
только запуск и создание диагностического региона. Сам визуальный результат был
неприемлем: почти прозрачная зеркальная жидкость исчезала при контакте с блоками,
также наблюдался высокий spawn в воздухе. Пререлиз
[`watery-1.2.2-dev.1`](https://github.com/maksummatatov10-spec1231/watery/releases/tag/watery-1.2.2-dev.1)
оставлен лишь как исторический diagnostic artifact; **не используйте его как
игровой мод и не тратьте время на дополнительные игровые тесты**.

Работа сосредоточена на поведении и производительности Rust-кода. В CI run
`43157229793` core tests, benchmark, adapter compilation и package reader прошли;
отдельный GPU regression job всё ещё завершился exit 101, причина не установлена.
Игровой adapter не является acceptance target.

## Дальнейшая Rust-работа

- Сверять алгоритмы с исходным Java bytecode / GLSL и сохранять численную
  совместимость regression-тестами.
- Сначала находить hot paths на реалистичных данных, затем сравнивать baseline и
  изменение в optimized bench profile; не принимать интуитивные micro-оптимизации.
- Продолжить перенос и оптимизацию CPU/GPU алгоритмов. Исправление игрового
  рендера, интеграция блоков, UI и выпуск Horizon-мода не входят в текущий scope.
- Отдельно разобраться с падающим GPU regression CI; этот failure не скрывать.

## Сборка и проверки Rust core

Нужен Rust toolchain из `rust-toolchain.toml` (Rust 1.99.1):

```sh
cargo test --locked
cargo bench --locked --bench terrain --features bench-reference
```

Bench проверяет точное совпадение результатов и сравнивает старый cell-major
voxelizer с block-major вариантом, а также прежнее извлечение `SolidCache` с
обходом секционными плитками. В CI run `43157229793` на одном runner:

| Workload | Baseline | Новая версия | Ускорение |
| --- | ---: | ---: | ---: |
| Terrain, 4×4×4, res 6 | 51,922 ns | 18,908 ns | 2.75× |
| Terrain, 16×8×16, res 6 | 1,694,488 ns | 603,705 ns | 2.81× |
| SolidCache, 4×4×4, res 4 | 3,135 ns | 2,106 ns | 1.49× |
| SolidCache, 16×8×16, res 4 | 106,101 ns | 59,393 ns | 1.79× |

Замеры синтетические и не обещают тот же коэффициент на другой машине; обе
версии в каждой паре выполнялись поочерёдно в одном процессе, медиана 9 samples.
`bench-reference` включает только benchmark oracle. Полный статус CI и
ограничения — в [`reference/continuation-status.md`](reference/continuation-status.md).

Оригинальный мод: Watery 1.2.2, Fabric, Minecraft 26.3, Java ≥25,
GPL-3.0-only. Автор оригинала — ItsBlueDD. SHA256 исходного JAR:
`d5b4e546ed6e7e3834a8a31ddfd3066500540adde53f723545ea5ebdf307d973`.
Производный код и ресурсы распространяются с соблюдением GPL-3.0-only;
лицензионные сведения включены в development-пакет.
