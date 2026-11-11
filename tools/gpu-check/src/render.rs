//! Build and execute original graphics stages offscreen, not just WGSL parsing.
use watery_core::uniforms::Globals;
pub fn run(device:&wgpu::Device, queue:&wgpu::Queue)->Result<(),Box<dyn std::error::Error>> {
 let scope=device.push_error_scope(wgpu::ErrorFilter::Validation);
 let renderer=watery_gpu::render::MeshRenderer::new(device);
 let buffer=|size|device.create_buffer(&wgpu::BufferDescriptor{label:None,size,usage:wgpu::BufferUsages::STORAGE|wgpu::BufferUsages::COPY_DST|wgpu::BufferUsages::INDIRECT,mapped_at_creation:false});
 let vertices=buffer(16*3);let quads=buffer(16);let light=buffer(8);let args=buffer(32);
 let texture=|format|device.create_texture(&wgpu::TextureDescriptor{label:None,size:wgpu::Extent3d{width:16,height:16,depth_or_array_layers:1},mip_level_count:1,sample_count:1,dimension:wgpu::TextureDimension::D2,format,usage:wgpu::TextureUsages::TEXTURE_BINDING|wgpu::TextureUsages::RENDER_ATTACHMENT,view_formats:&[]}).create_view(&Default::default());
 let scene=texture(wgpu::TextureFormat::R32Float);let gb=texture(wgpu::TextureFormat::Rgba16Float);let mat=texture(wgpu::TextureFormat::Rgba16Float);let depth=texture(wgpu::TextureFormat::Depth32Float);let thickness=texture(wgpu::TextureFormat::R16Float);
 let groups=renderer.bind(device,&vertices,&quads,&light,&scene);
 let mut g=Globals::zeroed();g.screen=[16.0,16.0,1.0/16.0,1.0/16.0];g.camGrid[3]=1.0;
 renderer.upload(queue,&g,false)?;
 let mut encoder=device.create_command_encoder(&Default::default());
 renderer.record(&mut encoder,&groups,&args,&gb,&mat,&depth,&thickness);queue.submit([encoder.finish()]);
 let composite=watery_gpu::composite::Composite::new(device,wgpu::TextureFormat::Rgba16Float);
 let slime=buffer(12);
 let output=texture(wgpu::TextureFormat::Rgba16Float);
 let groups=composite.bind(device,[&gb,&thickness,&mat,&scene,&gb,&mat,&scene,&mat,&mat,&mat,&mat],&slime);
 g.proj=std::array::from_fn(|i|std::array::from_fn(|j|if i==j{1.0}else{0.0}));g.invProj=g.proj;g.view=g.proj;g.invView=g.proj;
 for material in [0,2,3] {for underwater in [false,true] {
 composite.upload(queue,&g,underwater,material)?;
 let mut encoder=device.create_command_encoder(&Default::default());
 composite.record(&mut encoder,&groups,&output,&depth);queue.submit([encoder.finish()]);
 }}
 device.poll(wgpu::PollType::wait_indefinitely())?;
 if let Some(e)=pollster::block_on(scope.pop()) {return Err(e.into());}
 println!("GPU graphics: original mesh front/thickness pipelines and offscreen passes PASS");Ok(())
}
