use crate::execution::read;
use watery_core::{Particle, uniforms::Globals};
use wgpu::util::DeviceExt;
pub fn run(device:&wgpu::Device,queue:&wgpu::Queue)->Result<(),Box<dyn std::error::Error>> {
 let scope=device.push_error_scope(wgpu::ErrorFilter::Validation);
 let mut g=Globals::zeroed();
 g.dims=[8,8,8,512]; g.faces=[576,576,576,1728]; g.caps=[512,1,0,0];
 g.boxMin=[0,0,0,512];g.boxMax=[8,8,8,0];
 g.fine=[16,16,16,2];g.fineBoxMin=[0,0,0,4096];g.fineBoxMax=[16,16,16,4913];
 g.gravityDt=[0.0,-9.81,0.0,0.01];g.simA=[0.99,8.0,1.0,1.0];
 g.simB=[100.0,1.0,0.0,0.0];g.camGrid[3]=1.0;
 g.surf=[0.3,1.0,0.0,0.0];g.waterA[3]=0.5;
 let mut particles=Vec::new();
 for z in 0..8 { for y in 0..8 { for x in 0..8 {
 particles.push(Particle{position:[2.125+x as f32*0.25,2.125+y as f32*0.25,2.125+z as f32*0.25,0.0],velocity:[0.0;4]});
 }}}
 let bytes:Vec<_>=particles.iter().flat_map(|p|p.position.into_iter().chain(p.velocity)).flat_map(f32::to_le_bytes).collect();
 let parts=device.create_buffer_init(&wgpu::util::BufferInitDescriptor{label:None,contents:&bytes,usage:wgpu::BufferUsages::STORAGE});
 let counts=device.create_buffer_init(&wgpu::util::BufferInitDescriptor{label:None,contents:&[512u32,0,0,0].into_iter().flat_map(u32::to_le_bytes).collect::<Vec<_>>(),usage:wgpu::BufferUsages::STORAGE|wgpu::BufferUsages::COPY_DST});
 let solids=device.create_buffer_init(&wgpu::util::BufferInitDescriptor{label:None,contents:&[0;2048],usage:wgpu::BufferUsages::STORAGE});
 let args=device.create_buffer_init(&wgpu::util::BufferInitDescriptor{label:None,contents:&[2u32,1,1,0].into_iter().flat_map(u32::to_le_bytes).collect::<Vec<_>>(),usage:wgpu::BufferUsages::INDIRECT});
 let surface=watery_gpu::surface::Surface::new(
  device,&g,&parts,&counts,&solids,0,4096,12288,watery_gpu::surface::SurfaceOptions::default()
 )?;
 surface.upload_globals(queue,&g)?;
 for field in 0..3 {
  let mut invalid=g;
  match field {0=>invalid.caps[0]+=1,1=>invalid.fine[3]+=1,_=>invalid.fineBoxMax[3]+=1}
  assert!(surface.upload_globals(queue,&invalid).is_err(),"changed allocation contract accepted");
 }
 let mut encoder=device.create_command_encoder(&Default::default());surface.record(&mut encoder,&args,false,false);queue.submit([encoder.finish()]);
 let c=read(device,queue,&surface.counters)?;
 if let Some(e)=pollster::block_on(scope.pop()) {return Err(e.into());}
 let scope=device.push_error_scope(wgpu::ErrorFilter::Validation);
 let u:Vec<_>=c.chunks_exact(4).map(|b|u32::from_le_bytes(b.try_into().unwrap())).collect();
 assert!(u[0]>0 && u[0]<=4096,"no bounded surface vertices: {u:?}");
 assert!(u[1]>0 && u[1]<=12288,"no bounded quads: {u:?}");
 assert_eq!(u[4],u[1]*6);assert_eq!(u[5],1);
 let vertices=read(device,queue,&surface.vertices)?;
 for row in vertices[..u[0] as usize*16].chunks_exact(16) {for f in row[..12].chunks_exact(4) {assert!(f32::from_le_bytes(f.try_into()?).is_finite());}}
 let quads=read(device,queue,&surface.quads)?;
 for id in quads[..u[1] as usize*16].chunks_exact(4) {assert!(u32::from_le_bytes(id.try_into()?)<u[0]);}
 queue.write_buffer(&counts,0,&[0;16]);
 let mut encoder=device.create_command_encoder(&Default::default());surface.record(&mut encoder,&args,true,true);queue.submit([encoder.finish()]);
 let c=read(device,queue,&surface.counters)?;assert_eq!(&c[..8],&[0;8],"empty rebuild retained geometry");
 if let Some(e)=pollster::block_on(scope.pop()) {return Err(e.into());}
 println!("GPU surface: field, blur, finite vertices, indexed topology and empty rebuild PASS");Ok(())
}
