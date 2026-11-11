//! Host-independent full-domain uniform construction from Watery's defaults.
//! Camera, entities, sources and environment lighting are supplied by the adapter.
use crate::{grid::Grid, material::Material, settings::Settings, uniforms::Globals};

pub fn globals(settings:&Settings, material:Material, dims:[i32;3], capacity:u32,
    dt:f32, time:f32)->Result<Globals,&'static str> {
    if dims.iter().any(|&v|v<5) || capacity==0 || capacity>i32::MAX as u32
        || !dt.is_finite() || dt<=0.0 || !time.is_finite() {return Err("invalid region input");}
    let grid=Grid::new(dims.map(|v|v as usize)).ok_or("region overflow")?;
    let (res,flip,speed,correction,film,stranded,neighbors,depth,smoothing)=match material {
        Material::Water=>(settings.resolution,settings.flipRatio,settings.maxSpeed,settings.volumeCorrection,settings.filmFriction,settings.strandedTime,settings.strandedNeighbors,settings.filmDepth,settings.surfaceSmoothing),
        Material::Lava=>(settings.lavaResolution,settings.lavaFlipRatio,settings.lavaMaxSpeed,settings.volumeCorrection,settings.lavaFilmFriction,settings.lavaStrandedTime,settings.lavaStrandedNeighbors,settings.lavaFilmDepth,settings.lavaSurfaceSmoothing),
        Material::Slime=>(settings.slimeResolution,settings.slimeFlipRatio,settings.slimeMaxSpeed,settings.slimeVolumeCorrection,settings.slimeFilmFriction,settings.slimeStrandedTime,settings.slimeStrandedNeighbors,settings.slimeFilmDepth,settings.slimeSurfaceSmoothing),
        Material::Sand=>(settings.sandResolution,settings.flipRatio,settings.maxSpeed,settings.volumeCorrection,0.0,0.0,0,0.0,settings.sandSurfaceSmoothing),
    };
    if res<=0 || settings.surfaceSubdivision<=0 || !flip.is_finite() || !(0.0..=1.0).contains(&flip) {return Err("invalid material resolution/FLIP ratio");}
    let r=res as f32;
    let subdivision=settings.surfaceSubdivision;
    let fine=dims.map(|v|v.checked_mul(subdivision));
    let [Some(fx),Some(fy),Some(fz)]=fine else {return Err("fine dimension overflow")};
    let fine=[fx,fy,fz];
    let voxels=fine.iter().try_fold(1i32,|a,&b|a.checked_mul(b)).ok_or("fine voxel overflow")?;
    let cubes=fine.iter().try_fold(1i32,|a,&b|b.checked_add(1).and_then(|b|a.checked_mul(b))).ok_or("fine cube overflow")?;
    let mut g=Globals::zeroed();
    g.dims=[dims[0],dims[1],dims[2],grid.cells() as i32];
    g.faces=[((dims[0]+1) as i64*dims[1] as i64*dims[2] as i64) as i32,(dims[0] as i64*(dims[1]+1) as i64*dims[2] as i64) as i32,(dims[0] as i64*dims[1] as i64*(dims[2]+1) as i64) as i32,grid.total_faces() as i32];
    g.caps=[capacity as i32,capacity as i32,0,0];
    g.flags=[i32::from(material.uses_whitewater()&&settings.whitewater),0,0,settings.wwCellLimit];
    g.gravityDt=[0.0,-settings.gravity*r,0.0,dt];
    g.simA=[flip.powf(dt*60.0),8.0,correction,0.0];
    g.simB=[speed*r,1.0/r,time,0.0];
    g.wwA=[settings.wwTrappedAirRate,settings.wwWaveCrestRate,settings.wwEnergyMin,settings.wwEnergyMax];
    g.wwB=[settings.wwTrappedAirMin,settings.wwTrappedAirMax,settings.wwWaveCrestMin,settings.wwWaveCrestMax];
    g.wwC=[settings.wwFoamLifeMin,settings.wwFoamLifeMax,settings.wwBubbleBuoyancy,settings.wwBubbleDrag];
    g.wwD=[settings.wwSprayDrag,settings.wwSprayThreshold,settings.wwBubbleThreshold,settings.wwMaxPerParticle as f32];
    g.camGrid[3]=r;
    g.misc[0]=if material==Material::Lava{settings.lavaUnderwaterFog}else if material==Material::Slime{settings.slimeFogDistance}else{settings.underwaterFog};
    g.waterA=[settings.particleRadius/r,settings.thicknessScale,if material==Material::Lava{settings.lavaRefraction}else if material==Material::Slime{0.0}else{settings.refraction},smoothing];
    g.absorb=if material==Material::Lava{[settings.lavaAbsorbR,settings.lavaAbsorbG,settings.lavaAbsorbB,0.0]}else{[settings.absorbR,settings.absorbG,settings.absorbB,0.0]};
    g.scatter=if material==Material::Lava{[settings.lavaScatterR,settings.lavaScatterG,settings.lavaScatterB,settings.lavaScatterDensity]}else{[settings.scatterR,settings.scatterG,settings.scatterB,settings.scatterDensity]};
    g.foamA=[settings.wwRadius,settings.foamCoverage,settings.bubbleAlpha,settings.sprayAlpha];
    g.fine=[fx,fy,fz,subdivision];
    g.surf=[if material==Material::Sand{settings.sandSurfaceIso}else{settings.surfaceIso},8.0/(subdivision as f32).powi(3),settings.nearCull,settings.dropletThreshold];
    g.boxMin=[0,0,0,grid.cells() as i32];g.boxMax=[dims[0],dims[1],dims[2],grid.total_faces() as i32];
    g.fineBoxMin=[0,0,0,voxels];g.fineBoxMax=[fx,fy,fz,cubes];
    g.killInfo=[-1.0e6,64.0,0.0,0.0];
    g.shadeA=[if material==Material::Lava{settings.lavaDetailStrength}else if material==Material::Slime{0.0}else{settings.detailStrength},settings.detailScale,settings.detailSpeed,if material==Material::Lava{settings.lavaRoughness}else{settings.roughness}];
    g.shadeB=[if material==Material::Lava{settings.lavaSpecular}else if material==Material::Slime{0.0}else{settings.specular},settings.wetDarkening,settings.filmShading,settings.foamBubbleSize];
    if material==Material::Sand {
        let sin=(settings.sandFrictionAngle as f64).to_radians().sin();
        let alpha=(2.0*(2.0f64/3.0).sqrt()*sin/(3.0-sin)) as f32;
        let stiffness=8.0*settings.sandStiffness*r*r;
        g.matA=[material.shader_id(),alpha,settings.sandCohesion,1.0];
        g.matB=[stiffness/2.6,stiffness*0.3/0.5199999,settings.sandGrainsPerParticle.max(1) as f32,settings.sandGrainSize];
        g.matC=[settings.sandWallFriction,0.125,settings.sandImpactDamping*0.25/dt.max(1e-5),settings.sandImpactRate];
    } else {
        g.matA=[material.shader_id(),if material==Material::Slime{settings.slimeAdhesion}else{0.0},if material==Material::Slime{settings.slimeEntityStick.clamp(0.0,1.0)}else{0.0},1.0];
        g.matB=[film,stranded,neighbors as f32,depth*r];
        if material==Material::Slime {g.matC=[settings.slimeRestSpeed*r,settings.slimeRestTime,settings.slimeWakeSpeed*r,0.0];}
    }
    g.matD=if material==Material::Slime{[0.0,settings.slimeBrightness,settings.slimeInsideOpacity,settings.slimeOpacity]}else{[settings.sandGrainMinPixels,settings.sandBrightness,settings.sandGrainSpread,0.0]};
    g.matE=[settings.sandRestSpeed*r,settings.sandRestTime,settings.sandWakeAccel*settings.gravity*r*dt,(1.0-settings.sandImpactCompression).max(0.01).ln()];
    g.compat=[0.0,1.0,30.0,0.0];g.compatB=[settings.sandShaderSun,settings.sandShaderSky,settings.shaderShadowBias,0.0];
    Ok(g)
}
#[cfg(test)]
mod tests {
 use super::*;
 #[test]fn material_units_and_default_contracts(){
 let s=Settings::default();
 for m in [Material::Water,Material::Sand,Material::Lava,Material::Slime] {
 let g=globals(&s,m,[8;3],512,1.0/60.0,1.0).unwrap();
 assert_eq!(g.matA[0],m.shader_id());assert_eq!(g.dims[3],512);
 assert_eq!(g.fineBoxMax[3],(g.fine[0]+1).pow(3));
 assert_eq!(g.gravityDt[1],-s.gravity*g.camGrid[3]);
 assert!((g.simA[0]-match m{Material::Lava=>s.lavaFlipRatio,Material::Slime=>s.slimeFlipRatio,_=>s.flipRatio}).abs()<1e-6);
 }
 }
 #[test]fn rejects_overflow_and_invalid_input(){let s=Settings::default();assert!(globals(&s,Material::Water,[i32::MAX;3],1,0.01,0.0).is_err());assert!(globals(&s,Material::Water,[8;3],1,f32::NAN,0.0).is_err());}
}
