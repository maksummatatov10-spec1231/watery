//! Original whitewater billboard pass (`particle.vert` + `whitewater.frag`).
//! Renders spray, foam, and underwater bubbles into an additive `Rgba16Float`
//! foam attachment consumed by `Composite` at binding 5.
use watery_core::uniforms::Globals;

#[derive(Clone, Copy, Debug)]
pub struct WhitewaterParams {
    pub radius: f32,
    pub max_pixels: f32,
    pub foam_size: f32,
}

impl Default for WhitewaterParams {
    fn default() -> Self {
        let s = watery_core::settings::Settings::default();
        Self {
            radius: s.wwRadius,
            max_pixels: s.wwMaxPixels,
            foam_size: s.foamSize,
        }
    }
}

pub struct WhitewaterRenderer {
    pipeline: wgpu::RenderPipeline,
    globals: wgpu::Buffer,
    view: wgpu::Buffer,
    constants: wgpu::Buffer,
}

pub struct WhitewaterGroups {
    main: wgpu::BindGroup,
    constants: wgpu::BindGroup,
    samplers: wgpu::BindGroup,
}

impl WhitewaterRenderer {
    pub fn new(device: &wgpu::Device) -> Self {
        let buf_entry = |binding, visibility, read_only_storage| wgpu::BindGroupLayoutEntry {
            binding,
            visibility,
            ty: wgpu::BindingType::Buffer {
                ty: if read_only_storage {
                    wgpu::BufferBindingType::Storage { read_only: true }
                } else {
                    wgpu::BufferBindingType::Uniform
                },
                has_dynamic_offset: false,
                min_binding_size: None,
            },
            count: None,
        };
        let tex_entry = |binding| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Texture {
                sample_type: wgpu::TextureSampleType::Float { filterable: false },
                view_dimension: wgpu::TextureViewDimension::D2,
                multisampled: false,
            },
            count: None,
        };
        let group0 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Watery whitewater group0"),
            entries: &[
                buf_entry(0, wgpu::ShaderStages::VERTEX_FRAGMENT, false),
                buf_entry(1, wgpu::ShaderStages::VERTEX, true),
                tex_entry(2),
                tex_entry(3),
                buf_entry(4, wgpu::ShaderStages::VERTEX_FRAGMENT, true),
            ],
        });
        let group1 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Watery whitewater constants"),
            entries: &[buf_entry(0, wgpu::ShaderStages::VERTEX, false)],
        });
        let group2 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Watery whitewater samplers"),
            entries: &[2u32, 3u32].map(|binding| wgpu::BindGroupLayoutEntry {
                binding,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::NonFiltering),
                count: None,
            }),
        });
        let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Watery whitewater"),
            bind_group_layouts: &[Some(&group0), Some(&group1), Some(&group2)],
            immediate_size: 0,
        });
        let module = |source: &'static str| {
            device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("Watery whitewater"),
                source: wgpu::ShaderSource::Wgsl(source.into()),
            })
        };
        let vs = module(include_str!("../../data/shaders/particle_vert.wgsl"));
        let fs = module(include_str!("../../data/shaders/whitewater_frag.wgsl"));
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Watery whitewater"),
            layout: Some(&layout),
            vertex: wgpu::VertexState {
                module: &vs,
                entry_point: Some("main"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &fs,
                entry_point: Some("main"),
                compilation_options: Default::default(),
                targets: &[crate::render::target(wgpu::TextureFormat::Rgba16Float, true)],
            }),
            primitive: Default::default(),
            depth_stencil: None,
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        let alloc = |size| {
            device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("Watery whitewater"),
                size,
                usage: wgpu::BufferUsages::UNIFORM
                    | wgpu::BufferUsages::STORAGE
                    | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            })
        };
        Self {
            pipeline,
            globals: alloc(Globals::BYTE_SIZE as u64),
            view: alloc(16),
            constants: alloc(32),
        }
    }

    pub fn bind(
        &self,
        device: &wgpu::Device,
        whitewater_particles: &wgpu::Buffer,
        scene_depth: &wgpu::TextureView,
        gbuffer: &wgpu::TextureView,
    ) -> WhitewaterGroups {
        self.bind_with_view(
            device,
            whitewater_particles,
            scene_depth,
            gbuffer,
            &self.view,
        )
    }

    pub fn bind_with_view(
        &self,
        device: &wgpu::Device,
        whitewater_particles: &wgpu::Buffer,
        scene_depth: &wgpu::TextureView,
        gbuffer: &wgpu::TextureView,
        view_state: &wgpu::Buffer,
    ) -> WhitewaterGroups {
        let mk_group = |index, entries: &[wgpu::BindGroupEntry<'_>]| {
            device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &self.pipeline.get_bind_group_layout(index),
                entries,
            })
        };
        let main = mk_group(
            0,
            &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: self.globals.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: whitewater_particles.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: wgpu::BindingResource::TextureView(scene_depth),
                },
                wgpu::BindGroupEntry {
                    binding: 3,
                    resource: wgpu::BindingResource::TextureView(gbuffer),
                },
                wgpu::BindGroupEntry {
                    binding: 4,
                    resource: view_state.as_entire_binding(),
                },
            ],
        );
        let constants = mk_group(
            1,
            &[wgpu::BindGroupEntry {
                binding: 0,
                resource: self.constants.as_entire_binding(),
            }],
        );
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor::default());
        let samplers = mk_group(
            2,
            &[2u32, 3u32].map(|binding| wgpu::BindGroupEntry {
                binding,
                resource: wgpu::BindingResource::Sampler(&sampler),
            }),
        );
        WhitewaterGroups {
            main,
            constants,
            samplers,
        }
    }

    pub fn upload(
        &self,
        queue: &wgpu::Queue,
        g: &Globals,
        underwater: bool,
        params: WhitewaterParams,
    ) -> Result<(), &'static str> {
        if [params.radius, params.max_pixels, params.foam_size]
            .iter()
            .any(|v| !v.is_finite() || *v < 0.0)
            || params.radius <= 0.0
        {
            return Err("invalid whitewater render parameters");
        }
        let mut bytes = vec![0u8; Globals::BYTE_SIZE];
        g.write_le(&mut bytes).map_err(|_| "globals size")?;
        queue.write_buffer(&self.globals, 0, &bytes);
        queue.write_buffer(
            &self.view,
            0,
            &(if underwater { 1.0f32 } else { 0.0 }).to_le_bytes(),
        );
        // Matches WaterRenderer.java lines 1146..1189:
        // pc.a = [wwRadius, 0.5, 0.3, wwMaxPixels], pc.b = [foamSize, 0, 0, 0].
        let words = [
            params.radius,
            0.5,
            0.3,
            params.max_pixels,
            params.foam_size,
            0.0,
            0.0,
            0.0,
        ];
        let pc_bytes: Vec<u8> = words.into_iter().flat_map(f32::to_le_bytes).collect();
        queue.write_buffer(&self.constants, 0, &pc_bytes);
        Ok(())
    }

    /// Record instanced billboard draw from `fluid_args` byte offset 64 (`args[16..20]`).
    pub fn record(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        groups: &WhitewaterGroups,
        fluid_args: &wgpu::Buffer,
        foam: &wgpu::TextureView,
        clear: bool,
    ) {
        let load = if clear {
            wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT)
        } else {
            wgpu::LoadOp::Load
        };
        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Watery whitewater"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: foam,
                resolve_target: None,
                depth_slice: None,
                ops: wgpu::Operations {
                    load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            ..Default::default()
        });
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &groups.main, &[]);
        pass.set_bind_group(1, &groups.constants, &[]);
        pass.set_bind_group(2, &groups.samplers, &[]);
        pass.draw_indirect(fluid_args, 64);
    }
}
