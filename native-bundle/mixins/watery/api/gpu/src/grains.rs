//! Original MPM sand grain culling and billboard renderer
//! (`grain_cull.comp` + `grain.vert` + `grain.frag`).
use crate::{Dispatch, Kernel};
use watery_core::uniforms::Globals;

pub struct SandRenderer {
    cull: Kernel,
    pipeline: wgpu::RenderPipeline,
    globals: wgpu::Buffer,
    visible: wgpu::Buffer,
    draw_args: wgpu::Buffer,
    capacity: u32,
}

pub struct SandDrawGroups {
    main: wgpu::BindGroup,
    empty: wgpu::BindGroup,
    samplers: wgpu::BindGroup,
}

impl SandRenderer {
    pub fn new(
        device: &wgpu::Device,
        capacity: u32,
        color_format: wgpu::TextureFormat,
    ) -> Result<Self, &'static str> {
        if capacity == 0 {
            return Err("sand renderer capacity must be non-zero");
        }
        let limits = device.limits();
        crate::validation::limits(&limits, 5)?;
        let visible_bytes = (capacity as u64)
            .checked_mul(48)
            .ok_or("visible sand buffer overflow")?;
        if visible_bytes > limits.max_buffer_size
            || visible_bytes > limits.max_storage_buffer_binding_size as u64
        {
            return Err("visible sand buffer exceeds device limits");
        }
        let cull = Kernel::new(
            device,
            "grain_cull",
            include_str!("../../data/shaders/grain_cull.wgsl"),
        );

        let buf_entry = |binding, visibility, storage| wgpu::BindGroupLayoutEntry {
            binding,
            visibility,
            ty: wgpu::BindingType::Buffer {
                ty: if storage {
                    wgpu::BufferBindingType::Storage { read_only: true }
                } else {
                    wgpu::BufferBindingType::Uniform
                },
                has_dynamic_offset: false,
                min_binding_size: None,
            },
            count: None,
        };
        let tex_bindings = [3u32, 5, 6, 7, 8];
        let mut entries = vec![
            buf_entry(0, wgpu::ShaderStages::VERTEX_FRAGMENT, false),
            buf_entry(1, wgpu::ShaderStages::VERTEX, true),
            buf_entry(2, wgpu::ShaderStages::FRAGMENT, true),
            buf_entry(4, wgpu::ShaderStages::FRAGMENT, true),
        ];
        entries.extend(tex_bindings.map(|binding| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Texture {
                sample_type: wgpu::TextureSampleType::Float { filterable: false },
                view_dimension: wgpu::TextureViewDimension::D2,
                multisampled: false,
            },
            count: None,
        }));
        let group0 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Watery sand grains group0"),
            entries: &entries,
        });
        let group1 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: None,
            entries: &[],
        });
        let group2 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Watery sand grains samplers"),
            entries: &tex_bindings.map(|binding| wgpu::BindGroupLayoutEntry {
                binding,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::NonFiltering),
                count: None,
            }),
        });
        let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Watery sand grains"),
            bind_group_layouts: &[Some(&group0), Some(&group1), Some(&group2)],
            immediate_size: 0,
        });
        let module = |source: &'static str| {
            device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("Watery sand grains"),
                source: wgpu::ShaderSource::Wgsl(source.into()),
            })
        };
        let vs = module(include_str!("../../data/shaders/grain_vert.wgsl"));
        let fs = module(include_str!("../../data/shaders/grain_frag.wgsl"));
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Watery sand grains"),
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
                targets: &[crate::render::target(color_format, false)],
            }),
            primitive: Default::default(),
            depth_stencil: Some(wgpu::DepthStencilState {
                format: wgpu::TextureFormat::Depth32Float,
                depth_write_enabled: Some(true),
                depth_compare: Some(wgpu::CompareFunction::GreaterEqual),
                stencil: Default::default(),
                bias: Default::default(),
            }),
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        let globals = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Watery sand renderer globals"),
            size: Globals::BYTE_SIZE as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let visible = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Watery visible sand grains"),
            size: visible_bytes,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        // Separate from `Sand::args_buffer()` so `grain_cull` never aliases an
        // indirect-dispatch buffer with a writable storage binding in one pass.
        let draw_args = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Watery sand grain draw args"),
            size: 112,
            usage: wgpu::BufferUsages::STORAGE
                | wgpu::BufferUsages::INDIRECT
                | wgpu::BufferUsages::COPY_DST
                | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        Ok(Self {
            cull,
            pipeline,
            globals,
            visible,
            draw_args,
            capacity,
        })
    }

    pub fn capacity(&self) -> u32 {
        self.capacity
    }

    pub fn draw_args_buffer(&self) -> &wgpu::Buffer {
        &self.draw_args
    }

    /// Upload `Globals` and reset `draw_args[20..24]` (`vertex_count = 6 * child_grains`, `instance_count = 0`).
    pub fn upload(
        &self,
        queue: &wgpu::Queue,
        g: &Globals,
        child_grains: u32,
    ) -> Result<(), &'static str> {
        if child_grains == 0 || child_grains > 256 {
            return Err("invalid sand child grain count");
        }
        let mut bytes = vec![0u8; Globals::BYTE_SIZE];
        g.write_le(&mut bytes).map_err(|_| "globals size")?;
        queue.write_buffer(&self.globals, 0, &bytes);
        let args = [6u32 * child_grains, 0, 0, 0];
        let args_bytes: Vec<u8> = args.into_iter().flat_map(u32::to_le_bytes).collect();
        queue.write_buffer(&self.draw_args, 80, &args_bytes);
        Ok(())
    }

    /// Textures in binding order `[3, 5, 6, 7, 8]`: shadow, lightmap, SK A, SK B, SK tint.
    pub fn bind(
        &self,
        device: &wgpu::Device,
        sand_tex: &wgpu::Buffer,
        region_light: &wgpu::Buffer,
        textures: [&wgpu::TextureView; 5],
    ) -> SandDrawGroups {
        let tex_bindings = [3u32, 5, 6, 7, 8];
        let mut entries = vec![
            wgpu::BindGroupEntry {
                binding: 0,
                resource: self.globals.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: self.visible.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 2,
                resource: sand_tex.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 4,
                resource: region_light.as_entire_binding(),
            },
        ];
        entries.extend(tex_bindings.into_iter().zip(textures).map(|(binding, view)| {
            wgpu::BindGroupEntry {
                binding,
                resource: wgpu::BindingResource::TextureView(view),
            }
        }));
        let mk_group = |index, entries: &[wgpu::BindGroupEntry<'_>]| {
            device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &self.pipeline.get_bind_group_layout(index),
                entries,
            })
        };
        let main = mk_group(0, &entries);
        let empty = mk_group(1, &[]);
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor::default());
        let samplers = mk_group(
            2,
            &tex_bindings.map(|binding| wgpu::BindGroupEntry {
                binding,
                resource: wgpu::BindingResource::Sampler(&sampler),
            }),
        );
        SandDrawGroups {
            main,
            empty,
            samplers,
        }
    }

    /// Record `grain_cull` followed by indirect instanced grain billboard rendering.
    pub fn record(
        &self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        sand: &crate::sand::Sand,
        density: &wgpu::Buffer,
        groups: &SandDrawGroups,
        color: &wgpu::TextureView,
        depth: &wgpu::TextureView,
    ) {
        let cull_bound = self.cull.bind(
            device,
            &[
                &self.globals,
                sand.particle_buffer(),
                density,
                &self.visible,
                &self.draw_args,
                sand.counter_buffer(),
            ],
            &[sand.current_counter() as u32, 0, 0, 0, 0, 0, 0, 0],
        );
        cull_bound.record(encoder, Dispatch::Indirect(sand.args_buffer()));

        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Watery sand grains"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: color,
                resolve_target: None,
                depth_slice: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: depth,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                }),
                stencil_ops: None,
            }),
            ..Default::default()
        });
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &groups.main, &[]);
        pass.set_bind_group(1, &groups.empty, &[]);
        pass.set_bind_group(2, &groups.samplers, &[]);
        pass.draw_indirect(&self.draw_args, 80);
    }
}
