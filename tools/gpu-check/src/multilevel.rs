//! Multilevel allocation/indexing, nonzero pressure and static collision regression.
//! This is not a Java-versus-Rust physics equivalence comparison.
use crate::execution::read;
use watery_core::{Particle, uniforms::Globals};

pub fn run(device: &wgpu::Device, queue: &wgpu::Queue) -> Result<(), Box<dyn std::error::Error>> {
    let settings = watery_core::settings::Settings::default();
    for dims in [[17, 9, 7], [24, 24, 24], [33, 29, 27], [43, 41, 39]] {
        let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
        let [x, y, z] = dims;
        let cells = x * y * z;
        let mut fluid = watery_gpu::fluid::Fluid::new(
            device,
            dims,
            64,
            settings.cgIterations as u32,
            settings.mgCoarseSweeps as u32,
            settings.extrapolationLayers as u32,
        )?;
        let mut g = Globals::zeroed();
        g.dims = [x, y, z, cells];
        g.faces = [(x + 1) * y * z, x * (y + 1) * z, x * y * (z + 1), 0];
        g.faces[3] = g.faces[..3].iter().sum();
        g.caps = [64, 1, 0, 0];
        g.boxMin = [0, 0, 0, cells];
        g.boxMax = [x, y, z, 0];
        g.gravityDt = [0.0, -settings.gravity, 0.0, 1.0 / 120.0];
        g.simA = [settings.flipRatio, 8.0, 1.0, 1.0];
        g.simB = [100.0, 1.0 / 6.0, 0.0, 0.0];
        g.matB = [0.0, 100.0, 0.0, 1.0];
        g.killInfo = [-100.0, 10.0, 0.0, 0.0];
        g.camGrid[3] = 6.0;
        fluid.upload_globals(queue, &g)?;
        let mut solids = vec![0; cells as usize];
        for zz in 0..z {
            for yy in 0..2 {
                for xx in 0..x {
                    solids[(xx + x * (yy + y * zz)) as usize] = 1;
                }
            }
        }
        fluid.upload_solids(queue, &solids)?;
        let particles: Vec<_> = (0..64)
            .map(|i| Particle {
                position: [
                    4.125 + (i % 4) as f32 * 0.25,
                    2.05 + ((i / 4) % 4) as f32 * 0.25,
                    3.125 + (i / 16) as f32 * 0.25,
                    0.0,
                ],
                velocity: [if i % 4 < 2 { 1.0 } else { -1.0 }, -3.0, 0.0, 0.0],
            })
            .collect();
        fluid.reset(queue, &particles)?;
        if let Some(error) = pollster::block_on(scope.pop()) {
            return Err(error.into());
        }
        let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
        for step in 0..12 {
            let mut encoder = device.create_command_encoder(&Default::default());
            fluid.record_step(&mut encoder);
            queue.submit([encoder.finish()]);
            let counters = read(device, queue, fluid.counter_buffer())?;
            let offset = fluid.current_counter() * 4;
            assert_eq!(
                u32::from_le_bytes(counters[offset..offset + 4].try_into()?),
                64,
                "multilevel lost particles dims={dims:?} step={step}"
            );
            let bytes = read(device, queue, fluid.particle_buffer())?;
            for row in bytes.as_chunks::<32>().0 {
                let values: [f32; 8] = std::array::from_fn(|i| {
                    f32::from_le_bytes(row[i * 4..i * 4 + 4].try_into().unwrap())
                });
                assert!(values.iter().all(|v| v.is_finite()), "nonfinite {dims:?}");
                assert!(
                    values[1] >= 2.0,
                    "penetrated solid floor {dims:?}: {values:?}"
                );
            }
            let bytes = read(device, queue, fluid.pressure_buffer())?;
            let pressure: Vec<_> = bytes
                .as_chunks::<4>()
                .0
                .iter()
                .map(|v| f32::from_le_bytes(*v))
                .collect();
            assert!(pressure.iter().all(|v| v.is_finite()), "nonfinite pressure");
            let flags = read(device, queue, fluid.flags_buffer())?;
            let flags: Vec<_> = flags
                .as_chunks::<4>()
                .0
                .iter()
                .map(|v| u32::from_le_bytes(*v))
                .collect();
            let rhs = read(device, queue, fluid.divergence_buffer())?;
            let rhs: Vec<_> = rhs
                .as_chunks::<4>()
                .0
                .iter()
                .map(|v| f32::from_le_bytes(*v))
                .collect();
            crate::pressure_oracle::compare(dims, &flags, &rhs, &pressure);
            if step == 0 {
                assert!(
                    pressure.iter().any(|v| v.abs() > 1e-6),
                    "test must exercise nonzero pressure, not only free fall"
                );
            }
        }
        if let Some(error) = pollster::block_on(scope.pop()) {
            return Err(error.into());
        }
    }
    println!(
        "GPU multilevel FLIP: small/large PCG, odd grids, CPU pressure oracle, floor/count/finite PASS"
    );
    Ok(())
}
