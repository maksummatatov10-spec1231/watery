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
`43161880409` прошли core tests, строгий Clippy для всех targets, paired
benchmarks, детерминированная сборка пакета, Horizon adapter/package reader и
GPU regressions; дополнительный полный run `43162602752` после обновления
документации тоже прошёл. GPU report подтверждает 61/61 shader pipelines и 7
ограниченных execution-проверок на llvmpipe/Vulkan. Это проверка компиляции и
выбранных регрессий, а не доказательство физической эквивалентности, скорости
GPU или поведения в Horizon runtime. Игровой adapter не является acceptance
target.

## Дальнейшая Rust-работа

- Сверять алгоритмы с исходным Java bytecode / GLSL и сохранять численную
  совместимость regression-тестами.
- Сначала находить hot paths на реалистичных данных, затем сравнивать baseline и
  изменение в optimized bench profile; не принимать интуитивные micro-оптимизации.
- Продолжить перенос и оптимизацию CPU/GPU алгоритмов с differential-тестами;
  измерять только сопоставимые версии на одинаковом workload.
- Лавпайп-проверки считать shader/execution regressions, но не physics parity;
  Horizon runtime, игровой рендер, UI и выпуск мода не входят в acceptance scope.

## Сборка и проверки Rust core

Нужен Rust toolchain из `rust-toolchain.toml` (Rust 1.99.1):

```sh
cargo test --locked
cargo clippy --locked --all-targets --features bench-reference -- -D warnings
cargo bench --locked --bench terrain --features bench-reference
```

Bench проверяет точное совпадение результатов и сравнивает старый cell-major
voxelizer с block-major вариантом, а также прежнее извлечение `SolidCache` с
обходом секционными плитками. В CI run `43161880409` на одном runner получены
следующие paired measurements:

| Workload | Baseline | Новая версия | Ускорение |
| --- | ---: | ---: | ---: |
| Terrain, 4×4×4, res 6 | 36,956 ns | 13,790 ns | 2.68× |
| Terrain, 16×8×16, res 6 | 1,170,416 ns | 447,655 ns | 2.62× |
| SolidCache, 4×4×4, res 4 | 2,694 ns | 1,612 ns | 1.67× |
| SolidCache, 16×8×16, res 4 | 84,829 ns | 48,256 ns | 1.76× |

Замеры синтетические и не обещают тот же коэффициент на другой машине; обе
версии в каждой паре выполнялись поочерёдно в одном процессе, медиана 9 samples.
`bench-reference` включает только benchmark oracle. Полный статус CI и
ограничения — в [`reference/continuation-status.md`](reference/continuation-status.md).

Оригинальный мод: Watery 1.2.2, Fabric, Minecraft 26.3, Java ≥25,
GPL-3.0-only. Автор оригинала — ItsBlueDD. SHA256 исходного JAR:
`d5b4e546ed6e7e3834a8a31ddfd3066500540adde53f723545ea5ebdf307d973`.
Производный код и ресурсы распространяются с соблюдением GPL-3.0-only;
лицензионные сведения включены в development-пакет.
