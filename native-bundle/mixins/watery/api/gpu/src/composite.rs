//! Original fullscreen fluid shading with explicit baseline texture layouts.
use watery_core::uniforms::Globals;
pub struct Composite {
    pipeline: wgpu::RenderPipeline,
    globals: wgpu::Buffer,
    view: wgpu::Buffer,
    filter: wgpu::Buffer,
}
pub struct CompositeGroups { textures:wgpu::BindGroup, constants:wgpu::BindGroup, samplers:wgpu::BindGroup }
impl Composite {
    pub fn new(device:&wgpu::Device, format:wgpu::TextureFormat)->Self {
        let b=|binding,storage|wgpu::BindGroupLayoutEntry{binding,visibility:wgpu::ShaderStages::FRAGMENT,
            ty:wgpu::BindingType::Buffer{ty:if storage {wgpu::BufferBindingType::Storage{read_only:true}}else{wgpu::BufferBindingType::Uniform},has_dynamic_offset:false,min_binding_size:None},count:None};
        let texture_bindings=[1,2,3,4,5,6,8,10,11,12,13];
        let mut entries=vec![b(0,false),b(7,true),b(9,true)];
        entries.extend(texture_bindings.map(|binding|wgpu::BindGroupLayoutEntry{binding,visibility:wgpu::ShaderStages::FRAGMENT,
            ty:wgpu::BindingType::Texture{sample_type:wgpu::TextureSampleType::Float{filterable:false},view_dimension:wgpu::TextureViewDimension::D2,multisampled:false},count:None}));
        let a=device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor{label:None,entries:&entries});
        let c=device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor{label:None,entries:&[b(0,false)]});
        let s=device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor{label:None,entries:&texture_bindings.map(|binding|wgpu::BindGroupLayoutEntry{binding,visibility:wgpu::ShaderStages::FRAGMENT,ty:wgpu::BindingType::Sampler(wgpu::SamplerBindingType::NonFiltering),count:None})});
        let layout=device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor{label:Some("Watery composite"),bind_group_layouts:&[Some(&a),Some(&c),Some(&s)],immediate_size:0});
        let module=|source:&'static str|device.create_shader_module(wgpu::ShaderModuleDescriptor{label:None,source:wgpu::ShaderSource::Wgsl(source.into())});
        let vs=module(include_str!("../../data/shaders/fullscreen_vert.wgsl"));
        let fs=module(include_str!("../../data/shaders/composite_frag.wgsl"));
        let pipeline=device.create_render_pipeline(&wgpu::RenderPipelineDescriptor{label:Some("Watery composite"),layout:Some(&layout),
            vertex:wgpu::VertexState{module:&vs,entry_point:Some("main"),compilation_options:Default::default(),buffers:&[]},
            fragment:Some(wgpu::FragmentState{module:&fs,entry_point:Some("main"),compilation_options:Default::default(),targets:&[crate::render::target(format,false)]}),
            primitive:Default::default(),depth_stencil:Some(wgpu::DepthStencilState{format:wgpu::TextureFormat::Depth32Float,depth_write_enabled:Some(true),depth_compare:Some(wgpu::CompareFunction::Always),stencil:Default::default(),bias:Default::default()}),multisample:Default::default(),multiview_mask:None,cache:None});
        let buffer=|size|device.create_buffer(&wgpu::BufferDescriptor{label:None,size,usage:wgpu::BufferUsages::STORAGE|wgpu::BufferUsages::UNIFORM|wgpu::BufferUsages::COPY_DST,mapped_at_creation:false});
        Self{pipeline,globals:buffer(Globals::BYTE_SIZE as u64),view:buffer(16),filter:buffer(16)}
    }
    /// Textures in original binding order: G-buffer, thickness, scene color,
    /// scene depth (R32Float), foam, material, shadow, lightmap, SK A/B/tint.
    /// Inputs must not alias the output attachment.
    pub fn bind(&self,device:&wgpu::Device,textures:[&wgpu::TextureView;11],slime:&wgpu::Buffer)->CompositeGroups {
        self.bind_with_view(device,textures,slime,&self.view)
    }
    pub fn bind_with_view(&self,device:&wgpu::Device,textures:[&wgpu::TextureView;11],slime:&wgpu::Buffer,view_state:&wgpu::Buffer)->CompositeGroups {
        fn b(binding:u32,buffer:&wgpu::Buffer)->wgpu::BindGroupEntry<'_>{wgpu::BindGroupEntry{binding,resource:buffer.as_entire_binding()}}
        let bindings=[1,2,3,4,5,6,8,10,11,12,13];
        let mut entries=vec![b(0,&self.globals),b(7,view_state),b(9,slime)];
        entries.extend(bindings.into_iter().zip(textures).map(|(binding,view)|wgpu::BindGroupEntry{binding,resource:wgpu::BindingResource::TextureView(view)}));
        let bind=|group,entries:&[wgpu::BindGroupEntry<'_>]|device.create_bind_group(&wgpu::BindGroupDescriptor{label:None,layout:&self.pipeline.get_bind_group_layout(group),entries});
        let textures=bind(0,&entries);
        let constants=bind(1,&[b(0,&self.filter)]);
        let sampler=device.create_sampler(&Default::default());
        let samplers=bind(2,&bindings.map(|binding|wgpu::BindGroupEntry{binding,resource:wgpu::BindingResource::Sampler(&sampler)}));
        CompositeGroups{textures,constants,samplers}
    }
    pub fn upload(&self,queue:&wgpu::Queue,g:&Globals,underwater:bool,material:u8)->Result<(), &'static str>{
        if !matches!(material,0|2|3) {return Err("composite material must be water, lava or slime");}
        let mut bytes=vec![0;Globals::BYTE_SIZE];g.write_le(&mut bytes).map_err(|_|"globals size")?;
        queue.write_buffer(&self.globals,0,&bytes);
        queue.write_buffer(&self.view,0,&(if underwater{1.0f32}else{0.0}).to_le_bytes());
        queue.write_buffer(&self.filter,0,&(material as f32).to_le_bytes());Ok(())
    }
    pub fn record(&self,encoder:&mut wgpu::CommandEncoder,groups:&CompositeGroups,color:&wgpu::TextureView,depth:&wgpu::TextureView){
        let mut pass=encoder.begin_render_pass(&wgpu::RenderPassDescriptor{label:Some("Watery composition"),color_attachments:&[Some(wgpu::RenderPassColorAttachment{view:color,resolve_target:None,depth_slice:None,ops:wgpu::Operations{load:wgpu::LoadOp::Load,store:wgpu::StoreOp::Store}})],depth_stencil_attachment:Some(wgpu::RenderPassDepthStencilAttachment{view:depth,depth_ops:Some(wgpu::Operations{load:wgpu::LoadOp::Load,store:wgpu::StoreOp::Store}),stencil_ops:None}),..Default::default()});
        pass.set_pipeline(&self.pipeline);pass.set_bind_group(0,&groups.textures,&[]);pass.set_bind_group(1,&groups.constants,&[]);pass.set_bind_group(2,&groups.samplers,&[]);pass.draw(0..3,0..1);
    }
}
