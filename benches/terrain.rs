use std::{hint::black_box, time::Instant};
use watery_core::{
    solid_cache::{
        SolidCache, reference_extract_region, reference_insert_section,
        reference_insert_section_axis_bitwise,
    },
    terrain::voxelize,
};

const SAMPLES: usize = 9;
const BATCH: usize = 4;
const CACHE_RESOLUTION: usize = 4;
const SECTION_BLOCKS: usize = 16 * 16 * 16;

fn original_cell_major(dims: [usize; 3], resolution: usize, blocks: &[Vec<[f64; 6]>]) -> Vec<u32> {
    let [nx, ny, nz] = dims.map(|v| v * resolution);
    let mut out = vec![0; nx * ny * nz];
    for z in 0..nz {
        for y in 0..ny {
            for x in 0..nx {
                let block =
                    x / resolution + dims[0] * (y / resolution + dims[1] * (z / resolution));
                let p = [x, y, z]
                    .map(|v| (v % resolution) as f64 / resolution as f64 + 0.5 / resolution as f64);
                out[x + nx * (y + ny * z)] = u32::from(
                    blocks[block]
                        .iter()
                        .any(|b| (0..3).all(|i| p[i] >= b[i] && p[i] < b[i + 3])),
                );
            }
        }
    }
    out
}

fn terrain_workload(dims: [usize; 3]) -> Vec<Vec<[f64; 6]>> {
    let shapes = [
        vec![],
        vec![],
        vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
        vec![[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]],
        vec![[0.25, 0.25, 0.25, 0.75, 0.75, 0.75]],
        vec![
            [-0.25, 0.2, 0.8, 0.5, 1.2, 1.5],
            [0.5, 0.5, 0.5, 0.5, 0.9, 0.9],
        ],
        vec![[0.1, 0.1, 0.1, 0.9, 0.9, 0.9]],
        vec![],
    ];
    let count = dims[0] * dims[1] * dims[2];
    (0..count)
        .map(|i| shapes[i % shapes.len()].clone())
        .collect()
}

fn batch_ns(run: &mut impl FnMut()) -> u128 {
    let start = Instant::now();
    for _ in 0..BATCH {
        run();
    }
    start.elapsed().as_nanos() / BATCH as u128
}

fn median(mut values: Vec<u128>) -> u128 {
    values.sort_unstable();
    values[values.len() / 2]
}

fn sample_pair(mut first: impl FnMut(), mut second: impl FnMut()) -> (u128, u128) {
    for _ in 0..3 {
        batch_ns(&mut first);
        batch_ns(&mut second);
    }
    let mut first_samples = Vec::with_capacity(SAMPLES);
    let mut second_samples = Vec::with_capacity(SAMPLES);
    for i in 0..SAMPLES {
        // Alternate order to reduce systematic bias from runner temperature/load.
        if i % 2 == 0 {
            first_samples.push(batch_ns(&mut first));
            second_samples.push(batch_ns(&mut second));
        } else {
            second_samples.push(batch_ns(&mut second));
            first_samples.push(batch_ns(&mut first));
        }
    }
    (median(first_samples), median(second_samples))
}

fn compare_terrain(name: &str, dims: [usize; 3], resolution: usize) {
    let blocks = terrain_workload(dims);
    let expected = original_cell_major(dims, resolution, &blocks);
    let actual = voxelize(dims, resolution, &blocks).expect("valid terrain workload");
    assert_eq!(
        actual, expected,
        "benchmark variants must produce identical masks"
    );

    let original = || {
        black_box(original_cell_major(
            black_box(dims),
            resolution,
            black_box(blocks.as_slice()),
        ));
    };
    let block_major = || {
        black_box(
            voxelize(black_box(dims), resolution, black_box(blocks.as_slice()))
                .expect("valid terrain workload"),
        );
    };
    let (original_ns, block_major_ns) = sample_pair(original, block_major);
    let speedup = original_ns as f64 / block_major_ns as f64;
    println!(
        "BENCH_RESULT|{name}|original_ns={original_ns}|block_major_ns={block_major_ns}|speedup={speedup:.3}x"
    );
}

fn cache_boxes_at(pos: [i32; 3]) -> Vec<[f32; 6]> {
    match (pos[0].rem_euclid(8) + 3 * pos[1].rem_euclid(8) + 5 * pos[2].rem_euclid(8)).rem_euclid(8)
    {
        0 => vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
        1 => vec![[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]],
        2 => vec![[0.25, 0.25, 0.25, 0.75, 0.75, 0.75]],
        _ => Vec::new(),
    }
}

fn cache_workload(origin: [i32; 3], dims: [usize; 3]) -> (SolidCache, Vec<Vec<[f64; 6]>>) {
    let mut cache = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
    for section in cache.missing_sections(origin, dims) {
        let mut blocks = vec![Vec::new(); SECTION_BLOCKS];
        for z in 0..16 {
            for y in 0..16 {
                for x in 0..16 {
                    let world = [
                        section[0] * 16 + x,
                        section[1] * 16 + y,
                        section[2] * 16 + z,
                    ];
                    let index = x as usize + 16 * (y as usize + 16 * z as usize);
                    blocks[index] = cache_boxes_at(world);
                }
            }
        }
        cache
            .insert_section(section, &blocks)
            .expect("valid section workload");
    }

    let mut direct_boxes = Vec::with_capacity(dims[0] * dims[1] * dims[2]);
    for z in 0..dims[2] {
        for y in 0..dims[1] {
            for x in 0..dims[0] {
                let world = [
                    origin[0] + x as i32,
                    origin[1] + y as i32,
                    origin[2] + z as i32,
                ];
                direct_boxes.push(
                    cache_boxes_at(world)
                        .iter()
                        .map(|b| std::array::from_fn(|i| b[i] as f64))
                        .collect(),
                );
            }
        }
    }
    (cache, direct_boxes)
}

fn compare_solid_cache(name: &str, origin: [i32; 3], dims: [usize; 3]) {
    let (cache, direct_boxes) = cache_workload(origin, dims);
    let expected = voxelize(dims, CACHE_RESOLUTION, &direct_boxes).expect("valid cache workload");
    let actual = cache
        .extract_region(origin, dims, true)
        .expect("valid cache extraction");
    let reference =
        reference_extract_region(&cache, origin, dims, true).expect("valid reference extraction");
    assert_eq!(
        actual, expected,
        "cache extraction must match direct voxelization"
    );
    assert_eq!(
        actual, reference,
        "cache variants must produce identical masks"
    );

    let reference_run = || {
        black_box(
            reference_extract_region(&cache, black_box(origin), black_box(dims), true)
                .expect("valid reference extraction"),
        );
    };
    let tiled_run = || {
        black_box(
            cache
                .extract_region(black_box(origin), black_box(dims), true)
                .expect("valid cache extraction"),
        );
    };
    let (reference_ns, tiled_ns) = sample_pair(reference_run, tiled_run);
    let speedup = reference_ns as f64 / tiled_ns as f64;
    println!(
        "BENCH_RESULT|{name}|reference_ns={reference_ns}|section_tiled_ns={tiled_ns}|speedup={speedup:.3}x|dims={}x{}x{}|resolution={CACHE_RESOLUTION}",
        dims[0], dims[1], dims[2]
    );
}

fn compare_solid_cache_insert() {
    let blocks: Vec<_> = (0..SECTION_BLOCKS)
        .map(|index| {
            cache_boxes_at([
                (index & 15) as i32,
                ((index >> 4) & 15) as i32,
                (index >> 8) as i32,
            ])
        })
        .collect();
    let mut reference = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
    let mut axis_bitwise = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
    let mut section_insert = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
    reference_insert_section(&mut reference, [0; 3], &blocks).expect("valid reference insertion");
    reference_insert_section_axis_bitwise(&mut axis_bitwise, [0; 3], &blocks)
        .expect("valid axis-bitwise insertion");
    section_insert
        .insert_section([0; 3], &blocks)
        .expect("valid section insertion");
    let expected = reference
        .extract_region([0; 3], [16; 3], false)
        .expect("valid reference region");
    assert_eq!(
        expected,
        axis_bitwise
            .extract_region([0; 3], [16; 3], false)
            .expect("valid axis-bitwise region"),
        "axis-bitwise and cellwise insertion must produce identical masks"
    );
    assert_eq!(
        expected,
        section_insert
            .extract_region([0; 3], [16; 3], false)
            .expect("valid inserted region"),
        "optimized and cellwise insertion must produce identical masks"
    );

    let reference_run = || {
        let mut cache = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
        reference_insert_section(&mut cache, [0; 3], black_box(blocks.as_slice()))
            .expect("valid reference insertion");
        black_box(cache);
    };
    let axis_bitwise_run = || {
        let mut cache = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
        reference_insert_section_axis_bitwise(&mut cache, [0; 3], black_box(blocks.as_slice()))
            .expect("valid axis-bitwise insertion");
        black_box(cache);
    };
    let mut section_insert_run = || {
        let mut cache = SolidCache::new(CACHE_RESOLUTION).expect("valid cache resolution");
        cache
            .insert_section([0; 3], black_box(blocks.as_slice()))
            .expect("valid section insertion");
        black_box(cache);
    };
    let (reference_ns, section_insert_ns) = sample_pair(reference_run, &mut section_insert_run);
    let speedup = reference_ns as f64 / section_insert_ns as f64;
    println!(
        "BENCH_RESULT|solid-cache-section-insert-16x16x16-res4|reference_ns={reference_ns}|section_insert_ns={section_insert_ns}|speedup={speedup:.3}x|blocks={SECTION_BLOCKS}|resolution={CACHE_RESOLUTION}"
    );
    let (axis_bitwise_ns, mask_insert_ns) = sample_pair(axis_bitwise_run, &mut section_insert_run);
    let mask_speedup = axis_bitwise_ns as f64 / mask_insert_ns as f64;
    println!(
        "BENCH_RESULT|solid-cache-axis-mask-xbit-insert-16x16x16-res4|axis_bitwise_ns={axis_bitwise_ns}|x_mask_ns={mask_insert_ns}|speedup={mask_speedup:.3}x|blocks={SECTION_BLOCKS}|resolution={CACHE_RESOLUTION}"
    );
}

fn main() {
    compare_terrain("diagnostic-4x4x4-res6", [4, 4, 4], 6);
    compare_terrain("chunk-region-16x8x16-res6", [16, 8, 16], 6);
    compare_solid_cache("solid-cache-diagnostic-4x4x4-res4", [14, 63, -2], [4, 4, 4]);
    compare_solid_cache("solid-cache-larger-16x8x16-res4", [14, 63, -2], [16, 8, 16]);
    compare_solid_cache_insert();
}
