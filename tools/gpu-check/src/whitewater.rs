//! End-to-end original whitewater transport, expiration and emission.
use crate::execution::read;
use watery_core::{Particle, uniforms::Globals};
pub fn run(device: &wgpu::Device, queue: &wgpu::Queue) -> Result<(), Box<dyn std::error::Error>> {
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let mut fluid = watery_gpu::fluid::Fluid::new(device, [8; 3], 64, 8, 4, 3)?;
    let mut g = Globals::zeroed();
    g.dims = [8, 8, 8, 512];
    g.faces = [576, 576, 576, 1728];
    g.caps = [64, 64, 0, 0];
    g.boxMin = [0, 0, 0, 512];
    g.boxMax = [8, 8, 8, 0];
    g.gravityDt = [0.0, -9.81, 0.0, 0.01];
    g.simA = [0.99, 8.0, 1.0, 1.0];
    g.simB = [100.0, 1.0, 0.0, 0.0];
    g.camGrid[3] = 1.0;
    g.matB = [0.0, 100.0, 0.0, 1.0];
    g.killInfo = [-100.0, 10.0, 0.0, 0.0];
    g.wwB = [0.0, 1.0, 0.0, 1.0];
    g.wwC = [1.0, 2.0, 2.5, 0.6];
    g.wwD = [0.4, 3.0, 6.0, 4.0];
    g.flags[3] = 12;
    fluid.configure_whitewater(device, true, 42);
    fluid.upload_globals(queue, &g)?;
    fluid.upload_solids(queue, &[0; 512])?;
    fluid.reset(queue, &[])?;
    fluid.reset_whitewater(
        queue,
        &[
            Particle {
                position: [3.0, 3.0, 3.0, 1.0],
                velocity: [1.0, 0.0, 0.0, 1.0],
            },
            Particle {
                position: [4.0, 4.0, 4.0, 0.005],
                velocity: [0.0; 4],
            },
        ],
    )?;
    for step in 0..2 {
        let mut encoder = device.create_command_encoder(&Default::default());
        fluid.record_step(&mut encoder);
        queue.submit([encoder.finish()]);
        let c = read(device, queue, fluid.counter_buffer())?;
        let offset = fluid.whitewater_counter() * 4;
        assert_eq!(
            u32::from_le_bytes(c[offset..offset + 4].try_into()?),
            1,
            "expiration/ping-pong step={step}"
        );
        let b = read(device, queue, fluid.whitewater_buffer())?;
        let f: [f32; 8] =
            std::array::from_fn(|i| f32::from_le_bytes(b[i * 4..i * 4 + 4].try_into().unwrap()));
        assert!((f[3] - (1.0 - (step + 1) as f32 * 0.01)).abs() < 1e-6);
        assert_eq!(f[7], 0.0, "isolated whitewater becomes spray");
        assert!(f[0] > 3.0 && f[1] < 3.0 && f.iter().all(|v| v.is_finite()));
    }
    fluid.reset(queue, &[])?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let c = read(device, queue, fluid.counter_buffer())?;
    let offset = fluid.whitewater_counter() * 4;
    assert_eq!(&c[offset..offset + 4], &[0; 4], "reset revived foam");
    // Negative activation thresholds force a known positive emission amount;
    // emission still runs the real potential and G2P shaders, not a CPU mock.
    g.wwA = [10000.0, 10000.0, -2.0, -1.0];
    g.wwB = [-2.0, -1.0, -2.0, -1.0];
    fluid.upload_globals(queue, &g)?;
    fluid.reset(
        queue,
        &[Particle {
            position: [3.5, 3.5, 3.5, 0.0],
            velocity: [0.0; 4],
        }],
    )?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let c = read(device, queue, fluid.counter_buffer())?;
    let offset = fluid.whitewater_counter() * 4;
    assert_eq!(
        u32::from_le_bytes(c[offset..offset + 4].try_into()?),
        4,
        "G2P emission cap"
    );
    let b = read(device, queue, fluid.whitewater_buffer())?;
    for row in b[..128].chunks_exact(32) {
        let life = f32::from_le_bytes(row[12..16].try_into()?);
        assert!((1.0..=2.0).contains(&life));
    }
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    println!("GPU whitewater: emission, spray, expiration, ping-pong and reset PASS");
    Ok(())
}
