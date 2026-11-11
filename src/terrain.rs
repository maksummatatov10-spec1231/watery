//! Deterministic voxelization of immutable block-local collision boxes.
//! World access stays on the host thread. This pure stage may run in its worker pool.
pub fn voxelize(dims: [usize; 3], resolution: usize, blocks: &[Vec<[f64; 6]>]) -> Result<Vec<u32>, &'static str> {
    if resolution == 0 || dims.contains(&0) { return Err("invalid terrain dimensions"); }
    let n = dims.into_iter().try_fold(1usize, |a,b| a.checked_mul(b)).ok_or("terrain overflow")?;
    if n != blocks.len() || blocks.iter().flatten().any(|b|
        b.iter().any(|v| !v.is_finite()) || (0..3).any(|i| b[i] > b[i+3])) { return Err("invalid terrain boxes"); }
    let fine = dims.map(|v| v.checked_mul(resolution));
    let [Some(nx), Some(ny), Some(nz)] = fine else { return Err("terrain overflow"); };
    let count = nx.checked_mul(ny).and_then(|n| n.checked_mul(nz)).ok_or("terrain overflow")?;
    if count > i32::MAX as usize { return Err("terrain shader index overflow"); }
    let mut out=vec![0;count];
    for z in 0..nz {for y in 0..ny {for x in 0..nx {
        let block=x/resolution + dims[0]*(y/resolution + dims[1]*(z/resolution));
        let p=[x,y,z].map(|v| (v%resolution) as f64/resolution as f64 + 0.5/resolution as f64);
        out[x+nx*(y+ny*z)]=u32::from(blocks[block].iter().any(|b|(0..3).all(|i|p[i]>=b[i]&&p[i]<b[i+3])));
    }}}
    Ok(out)
}
#[cfg(test)] mod tests {
 use super::*;
 #[test] fn slab_and_air_x_fastest() {
  let mask=voxelize([2,1,1],2,&[vec![[0.,0.,0.,1.,0.5,1.]],vec![]]).unwrap();
  assert_eq!(mask,vec![1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0]);
 }
 #[test] fn rejects_invalid_and_overflow() {
  assert!(voxelize([1;3],0,&[vec![]]).is_err());
  assert!(voxelize([1;3],1,&[vec![[0.,0.,0.,f64::NAN,1.,1.]]]).is_err());
  assert!(voxelize([1;3],usize::MAX,&[vec![]]).is_err());
 }
}
