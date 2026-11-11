//! Host-independent GPU execution; the Horizon lifecycle adapter lives in `native/`.
//! Kernels and bindings live across frames. Recording never submits or waits.
pub mod composite;
pub mod fluid;
pub mod grains;
mod large_pressure;
pub mod render;
pub mod sand;
pub mod surface;
mod validation;
pub mod whitewater;

pub(crate) struct Kernel {
    pipeline: wgpu::ComputePipeline,
    constants: bool,
    unused_fluid_flags: bool,
    unused_globals: bool,
}
impl Kernel {
    pub fn new(device: &wgpu::Device, name: &str, source: &'static str) -> Self {
        let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some(name),
            source: wgpu::ShaderSource::Wgsl(source.into()),
        });
        Self {
            pipeline: device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
                label: Some(name),
                layout: None,
                module: &module,
                entry_point: Some("main"),
                compilation_options: Default::default(),
                cache: None,
            }),
            constants: source.contains("@group(1)"),
            unused_fluid_flags: name == "g2p",
            unused_globals: matches!(name, "cg_reduce" | "blast" | "mesh_args"),
        }
    }
    pub fn bind(
        &self,
        device: &wgpu::Device,
        buffers: &[&wgpu::Buffer],
        pc: &[u32],
    ) -> BoundKernel {
        let entries: Vec<_> = buffers
            .iter()
            .enumerate()
            .filter(|(binding, _)| {
                !(self.unused_fluid_flags && *binding == 6)
                    && !(self.unused_globals && *binding == 0)
            })
            .map(|(binding, buffer)| wgpu::BindGroupEntry {
                binding: binding as u32,
                resource: buffer.as_entire_binding(),
            })
            .collect();
        let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &self.pipeline.get_bind_group_layout(0),
            entries: &entries,
        });
        let constants = self.constants.then(|| {
            use wgpu::util::DeviceExt;
            assert!(pc.len() <= 16);
            let mut bytes = vec![0u8; (pc.len() * 4).max(32).div_ceil(16) * 16];
            for (out, value) in bytes.chunks_exact_mut(4).zip(pc) {
                out.copy_from_slice(&value.to_le_bytes());
            }
            let buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: Some("Watery immutable dispatch parameters"),
                contents: &bytes,
                usage: wgpu::BufferUsages::UNIFORM,
            });
            device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &self.pipeline.get_bind_group_layout(1),
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: buffer.as_entire_binding(),
                }],
            })
        });
        BoundKernel {
            pipeline: self.pipeline.clone(),
            group,
            constants,
        }
    }
}
pub(crate) struct BoundKernel {
    pipeline: wgpu::ComputePipeline,
    group: wgpu::BindGroup,
    constants: Option<wgpu::BindGroup>,
}
impl BoundKernel {
    pub fn record(&self, encoder: &mut wgpu::CommandEncoder, count: Dispatch<'_>) {
        // Separate passes retain producer/consumer transitions. Do not elide
        // barriers to reduce CPU overhead: wgpu tracks these storage accesses.
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &self.group, &[]);
        if let Some(constants) = &self.constants {
            pass.set_bind_group(1, constants, &[]);
        }
        match count {
            Dispatch::Direct(x) => pass.dispatch_workgroups(x, 1, 1),
            Dispatch::Indirect(buffer) => pass.dispatch_workgroups_indirect(buffer, 0),
            Dispatch::IndirectAt(buffer, offset) => {
                pass.dispatch_workgroups_indirect(buffer, offset)
            }
        }
    }
}
pub(crate) fn metadata_seed(device: &wgpu::Device) -> wgpu::Buffer {
    use wgpu::util::DeviceExt;
    let values = [u32::MAX, u32::MAX, u32::MAX, 0, 0, 0, 0, 0];
    let bytes: Vec<_> = values.into_iter().flat_map(u32::to_le_bytes).collect();
    device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Watery per-step metadata seed"),
        contents: &bytes,
        usage: wgpu::BufferUsages::COPY_SRC,
    })
}
pub(crate) enum Dispatch<'a> {
    Direct(u32),
    Indirect(&'a wgpu::Buffer),
    IndirectAt(&'a wgpu::Buffer, u64),
}
