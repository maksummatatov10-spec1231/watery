use std::{hint::black_box, time::Instant};
use watery_core::terrain::voxelize;

const SAMPLES: usize = 9;
const BATCH: usize = 4;

fn original_cell_major(
    dims: [usize; 3],
    resolution: usize,
    blocks: &[Vec<[f64; 6]>],
) -> Vec<u32> {
    let [nx, ny, nz] = dims.map(|v| v * resolution);
    let mut out = vec![0; nx * ny * nz];
    for z in 0..nz {
        for y in 0..ny {
            for x in 0..nx {
                let block = x / resolution + dims[0] * (y / resolution + dims[1] * (z / resolution));
                let p = [x, y, z].map(|v| {
                    (v % resolution) as f64 / resolution as f64
                        + 0.5 / resolution as f64
                });
                out[x + nx * (y + ny * z)] = u32::from(blocks[block].iter().any(|b| {
                    (0..3).all(|i| p[i] >= b[i] && p[i] < b[i + 3])
                }));
            }
        }
    }
    out
}

fn workload(dims: [usize; 3]) -> Vec<Vec<[f64; 6]>> {
    let shapes = [
        vec![],
        vec![],
        vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
        vec![[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]],
        vec![[0.25, 0.25, 0.25, 0.75, 0.75, 0.75]],
        vec![[-0.25, 0.2, 0.8, 0.5, 1.2, 1.5], [0.5, 0.5, 0.5, 0.5, 0.9, 0.9]],
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

fn compare(name: &str, dims: [usize; 3], resolution: usize) {
    let blocks = workload(dims);
    let expected = original_cell_major(dims, resolution, &blocks);
    let actual = voxelize(dims, resolution, &blocks).expect("valid benchmark workload");
    assert_eq!(actual, expected, "benchmark variants must produce identical masks");

    let mut original = || {
        black_box(original_cell_major(
            black_box(dims),
            resolution,
            black_box(blocks.as_slice()),
        ));
    };
    let mut block_major = || {
        black_box(
            voxelize(
                black_box(dims),
                resolution,
                black_box(blocks.as_slice()),
            )
            .expect("valid benchmark workload"),
        );
    };

    for _ in 0..3 {
        batch_ns(&mut original);
        batch_ns(&mut block_major);
    }
    let mut original_samples = Vec::with_capacity(SAMPLES);
    let mut block_major_samples = Vec::with_capacity(SAMPLES);
    for i in 0..SAMPLES {
        // Alternate order to reduce systematic bias from runner temperature/load.
        if i % 2 == 0 {
            original_samples.push(batch_ns(&mut original));
            block_major_samples.push(batch_ns(&mut block_major));
        } else {
            block_major_samples.push(batch_ns(&mut block_major));
            original_samples.push(batch_ns(&mut original));
        }
    }

    let original_ns = median(original_samples);
    let block_major_ns = median(block_major_samples);
    let speedup = original_ns as f64 / block_major_ns as f64;
    println!(
        "BENCH_RESULT|{name}|original_ns={original_ns}|block_major_ns={block_major_ns}|speedup={speedup:.3}x"
    );
}

fn main() {
    compare("diagnostic-4x4x4-res6", [4, 4, 4], 6);
    compare("chunk-region-16x8x16-res6", [16, 8, 16], 6);
}
