//! Persistent original MPM pass graph; lifecycle/world/collision extraction still belongs to host.
use crate::{BoundKernel, Dispatch, Kernel};
use watery_core::{Particle, uniforms::Globals};

pub struct Sand {
    particles: [wgpu::Buffer; 2],
    states: [wgpu::Buffer; 2],
    counters: wgpu::Buffer,
    metadata: wgpu::Buffer,
    globals: wgpu::Buffer,
    solid: wgpu::Buffer,
    args: wgpu::Buffer,
    counts: wgpu::Buffer,
    flags: wgpu::Buffer,
    grid_buffer: wgpu::Buffer,
    clear: BoundKernel,
    make_args: [BoundKernel; 2],
    p2g: [BoundKernel; 2],
    grid: BoundKernel,
    g2p: [BoundKernel; 2],
    classify: BoundKernel,
    blockfill_kernel: Kernel,
    current: usize,
    dims: [i32; 3],
    capacity: u32,
}
impl Sand {
    /// Caller must supply a device supporting SUBGROUP and the original 256-wide groups.
    /// Creation must be inside the host's wgpu validation scope.
    pub fn new(device: &wgpu::Device, dims: [i32; 3], capacity: u32) -> Result<Self, &'static str> {
        if dims.iter().any(|&d| d < 5) || capacity == 0 {
            return Err("invalid sand domain or capacity");
        }
        let cells = dims
            .iter()
            .try_fold(1u64, |a, &v| a.checked_mul(v as u64))
            .ok_or("cell overflow")?;
        let limits = device.limits();
        crate::validation::limits(&limits, 7)?;
        if !device.features().contains(wgpu::Features::SUBGROUP) {
            return Err("sand requires GPU subgroups");
        }
        if cells > i32::MAX as u64 || capacity > i32::MAX as u32 / 28 {
            return Err("original signed shader index overflow");
        }
        if limits.max_compute_invocations_per_workgroup < 256
            || limits.max_compute_workgroup_size_x < 256
        {
            return Err("256-wide compute unsupported");
        }
        if cells.div_ceil(256) > limits.max_compute_workgroups_per_dimension as u64
            || (capacity as u64).div_ceil(256) > limits.max_compute_workgroups_per_dimension as u64
        {
            return Err("domain exceeds single-dimensional dispatch limit");
        }
        for size in [cells * 16, capacity as u64 * 112] {
            if size > limits.max_buffer_size || size > limits.max_storage_buffer_binding_size as u64
            {
                return Err("sand buffer exceeds device limits");
            }
        }
        let storage = wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_DST
            | wgpu::BufferUsages::COPY_SRC;
        let create = |size, usage| {
            device.create_buffer(&wgpu::BufferDescriptor {
                label: None,
                size,
                usage,
                mapped_at_creation: false,
            })
        };
        let particles = std::array::from_fn(|_| create(capacity as u64 * 32, storage));
        let states = std::array::from_fn(|_| create(capacity as u64 * 112, storage));
        let counters = create(64, storage);
        let globals = create(
            Globals::BYTE_SIZE as u64,
            wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        );
        let solid = create(cells * 4, storage);
        let args = create(112, storage | wgpu::BufferUsages::INDIRECT);
        let grid_buffer = create(cells * 16, storage);
        let counts = create(cells * 4, storage);
        let flags = create(cells * 4, storage);
        let classify = Kernel::new(
            device,
            "classify",
            include_str!("../../generated/shaders/classify.wgsl"),
        )
        .bind(device, &[&globals, &solid, &counts, &flags], &[0; 8]);
        let blockfill_kernel = Kernel::new(
            device,
            "blockfill_mpm",
            include_str!("../../generated/shaders/blockfill_mpm.wgsl"),
        );
        let clear = Kernel::new(
            device,
            "mpm_clear",
            include_str!("../../generated/shaders/mpm_clear.wgsl"),
        )
        .bind(device, &[&globals, &grid_buffer, &counts], &[0; 8]);
        let args_kernel = Kernel::new(
            device,
            "args",
            include_str!("../../generated/shaders/args.wgsl"),
        );
        let p2g_kernel = Kernel::new(
            device,
            "mpm_p2g",
            include_str!("../../generated/shaders/mpm_p2g.wgsl"),
        );
        let g2p_kernel = Kernel::new(
            device,
            "mpm_g2p",
            include_str!("../../generated/shaders/mpm_g2p.wgsl"),
        );
        let grid = Kernel::new(
            device,
            "mpm_grid",
            include_str!("../../generated/shaders/mpm_grid.wgsl"),
        )
        .bind(device, &[&globals, &grid_buffer, &solid], &[0; 8]);
        let make_args = std::array::from_fn(|i| {
            args_kernel.bind(
                device,
                &[&globals, &counters, &args],
                &[i as u32, 2, 0, 0, 0, 0, 0, 0],
            )
        });
        let p2g = std::array::from_fn(|i| {
            p2g_kernel.bind(
                device,
                &[
                    &globals,
                    &particles[i],
                    &states[i],
                    &grid_buffer,
                    &counts,
                    &counters,
                ],
                &[i as u32, 0, 0, 0, 0, 0, 0, 0],
            )
        });
        let g2p = std::array::from_fn(|i| {
            g2p_kernel.bind(
                device,
                &[
                    &globals,
                    &particles[i],
                    &particles[1 - i],
                    &counters,
                    &grid_buffer,
                    &states[i],
                    &states[1 - i],
                    &solid,
                ],
                &[i as u32, (1 - i) as u32, 0, 0, 0, 0, 0, 0],
            )
        });
        Ok(Self {
            particles,
            states,
            counters,
            metadata: crate::metadata_seed(device),
            globals,
            solid,
            args,
            counts,
            flags,
            grid_buffer,
            clear,
            make_args,
            p2g,
            grid,
            g2p,
            classify,
            blockfill_kernel,
            current: 0,
            dims,
            capacity,
        })
    }
    /// Uploads a fresh population, invalidating old MPM state. Submit previously
    /// recorded work before calling; queue writes precede the next submission.
    pub fn reset(
        &mut self,
        queue: &wgpu::Queue,
        particles: &[Particle],
    ) -> Result<(), &'static str> {
        if particles.len() > self.capacity as usize
            || particles.iter().any(|p| {
                p.position
                    .iter()
                    .chain(p.velocity.iter())
                    .any(|v| !v.is_finite())
                    || p.position[3] >= 0.5
                    || p.position[3] < 0.0
            })
        {
            return Err("new sand must be finite and have uninitialized MPM marker in [0, 0.5)");
        }
        let bytes: Vec<u8> = particles
            .iter()
            .flat_map(|p| p.position.into_iter().chain(p.velocity))
            .flat_map(f32::to_le_bytes)
            .collect();
        if !bytes.is_empty() {
            queue.write_buffer(&self.particles[0], 0, &bytes);
        }
        let mut counters = [0u8; 64];
        counters[..4].copy_from_slice(&(particles.len() as u32).to_le_bytes());
        queue.write_buffer(&self.counters, 0, &counters);
        self.current = 0;
        Ok(())
    }
    /// Host must submit before modifying uniforms again. Multiple steps in one
    /// encoder intentionally share the uploaded constants (e.g. fixed dt).
    pub fn upload_globals(
        &self,
        queue: &wgpu::Queue,
        globals: &Globals,
    ) -> Result<(), &'static str> {
        if globals.dims[..3] != self.dims
            || globals.dims[3] != self.dims.iter().product::<i32>()
            || globals.caps[0] != self.capacity as i32
            || globals.boxMin[..3] != [0; 3]
            || globals.boxMax[..3] != self.dims
            || globals.boxMin[3] != globals.dims[3]
        {
            return Err("uniforms do not match allocated full sand domain");
        }
        crate::validation::globals(globals, true)?;
        let mut data = [0u8; Globals::BYTE_SIZE];
        globals.write_le(&mut data).map_err(|_| "uniform size")?;
        queue.write_buffer(&self.globals, 0, &data);
        Ok(())
    }
    pub fn upload_solids(&self, queue: &wgpu::Queue, solids: &[u32]) -> Result<(), &'static str> {
        if solids.len() as u64 * 4 != self.solid.size() {
            return Err("solid field size mismatch");
        }
        let bytes: Vec<_> = solids.iter().flat_map(|v| v.to_le_bytes()).collect();
        queue.write_buffer(&self.solid, 0, &bytes);
        Ok(())
    }
    /// Records the original five-pass graph, no allocation, readback or CPU wait.
    /// Steps must be submitted in the same order they are recorded. Discarding
    /// an encoder after this call invalidates the CPU/GPU ping-pong state.
    pub fn record_step(&mut self, encoder: &mut wgpu::CommandEncoder) {
        let i = self.current;
        encoder.clear_buffer(&self.counters, ((1 - i) * 4) as u64, Some(4));
        encoder.clear_buffer(&self.counters, 24, Some(4));
        encoder.copy_buffer_to_buffer(&self.metadata, 0, &self.counters, 32, 32);
        self.clear.record(
            encoder,
            Dispatch::Direct((self.dims.iter().product::<i32>() as u32).div_ceil(256)),
        );
        self.make_args[i].record(encoder, Dispatch::Direct(1));
        self.p2g[i].record(encoder, Dispatch::Indirect(&self.args));
        self.grid.record(
            encoder,
            Dispatch::Direct((self.dims.iter().product::<i32>() as u32).div_ceil(256)),
        );
        self.g2p[i].record(encoder, Dispatch::Indirect(&self.args));
        self.current = 1 - i;
        self.make_args[self.current].record(encoder, Dispatch::Direct(1));
    }
    pub fn record_args(&self, encoder: &mut wgpu::CommandEncoder) {
        self.make_args[self.current].record(encoder, Dispatch::Direct(1));
    }
    /// Classify MPM cell occupancy and compute per-block `full | (fast << 8)` values.
    pub fn record_block_fill(
        &self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        block_origin: [i32; 3],
        block_dims: [u32; 3],
        out_fill: &wgpu::Buffer,
    ) -> Result<(), &'static str> {
        if block_dims.contains(&0) {
            return Err("blockfill dimensions must be non-zero");
        }
        let total = block_dims
            .iter()
            .try_fold(1u64, |a, &d| a.checked_mul(d as u64))
            .ok_or("blockfill count overflow")?;
        if total > i32::MAX as u64 || out_fill.size() < total * 4 {
            return Err("blockfill output buffer too small or count overflow");
        }
        let groups = (total as u32).div_ceil(64);
        if groups > device.limits().max_compute_workgroups_per_dimension {
            return Err("blockfill dispatch exceeds device limits");
        }
        let cells = self.dims.iter().product::<i32>() as u32;
        self.classify
            .record(encoder, Dispatch::Direct(cells.div_ceil(256)));
        let bound = self.blockfill_kernel.bind(
            device,
            &[
                &self.globals,
                &self.counts,
                &self.flags,
                out_fill,
                &self.grid_buffer,
            ],
            &[
                block_origin[0] as u32,
                block_origin[1] as u32,
                block_origin[2] as u32,
                0,
                block_dims[0],
                block_dims[1],
                block_dims[2],
                0,
            ],
        );
        bound.record(encoder, Dispatch::Direct(groups));
        Ok(())
    }
    pub fn args_buffer(&self) -> &wgpu::Buffer {
        &self.args
    }
    pub fn solid_buffer(&self) -> &wgpu::Buffer {
        &self.solid
    }
    pub fn particle_buffer(&self) -> &wgpu::Buffer {
        &self.particles[self.current]
    }
    pub fn state_buffer(&self) -> &wgpu::Buffer {
        &self.states[self.current]
    }
    pub fn counter_buffer(&self) -> &wgpu::Buffer {
        &self.counters
    }
    pub fn current_counter(&self) -> usize {
        self.current
    }
}
