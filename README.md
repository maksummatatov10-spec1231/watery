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

Работа сосредоточена на поведении и производительности Rust-кода. Последний
полный CI run `43253870317` на commit `9440234` прошёл rustfmt, core tests,
строгий Clippy, paired benchmarks, детерминированную сборку пакета, Horizon
adapter/package reader и GPU regressions. GPU report подтверждает 61/61 shader
pipelines и 7 ограниченных execution-проверок на llvmpipe/Vulkan. Это проверка
компиляции и выбранных регрессий, а не доказательство физической эквивалентности,
скорости GPU или поведения в Horizon runtime. Игровой adapter не является
acceptance target.

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
voxelizer с block-major axis-mask вариантом, а также эталонное извлечение
`SolidCache` с обходом секционными плитками и эталонную классификацию при
вставке секции. Для voxelizer при resolution ≤64 каждая collision box один раз
даёт три маски занятых sample-координат; Cartesian product этих битов выставляет
ячейки результата. При большей resolution сохраняется прямой fallback. В
`SolidCache` интервалы подячеек precompute при создании кэша, затем маски
классификатора собираются по каждой оси; `x`-mask сдвигается целой строкой.
Differential tests покрывают границы 63/64/65, unions, вырожденные/внеблочные
формы, отрицательные координаты и изменение отдельных блоков.

Последний paired benchmark в CI run `43253870317` (один runner):

| Workload | Baseline | Новая версия | Ускорение |
| --- | ---: | ---: | ---: |
| Terrain, 4×4×4, res 6 | 36,047 ns | 3,291 ns | 10.95× |
| Terrain, 16×8×16, res 6 | 1,169,165 ns | 117,183 ns | 9.98× |
| SolidCache insert, cellwise → axis-mask, 16³/res4 | 178,358 ns | 50,659 ns | 3.52× |
| SolidCache insert, x-bit-loop → x-mask, 16³/res4 | 58,932 ns | 50,129 ns | 1.18× |
| SolidCache extract, 4×4×4, res 4 | 2,466 ns | 1,690 ns | 1.46× |
| SolidCache extract, 16×8×16, res 4 | 77,340 ns | 50,209 ns | 1.54× |

Не все проверенные идеи оставлены: integer range-check для network sync показал
0.67–0.69× baseline и удалён; запись terrain occupancy целыми X-диапазонами
также проиграла прежнему set-bit traversal и откатана. Текущие bench-пары
измеряют оставленные варианты отдельно. Замеры синтетические и не обещают тот
же коэффициент на другой машине; в каждой паре 9 чередующихся samples одного
runner. `bench-reference` включает только benchmark oracles. Полный статус CI и
ограничения — в [`reference/continuation-status.md`](reference/continuation-status.md).

Оригинальный мод: Watery 1.2.2, Fabric, Minecraft 26.3, Java ≥25,
GPL-3.0-only. Автор оригинала — ItsBlueDD. SHA256 исходного JAR:
`d5b4e546ed6e7e3834a8a31ddfd3066500540adde53f723545ea5ebdf307d973`.
Производный код и ресурсы распространяются с соблюдением GPL-3.0-only;
лицензионные сведения включены в development-пакет.
