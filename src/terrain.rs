//! Deterministic voxelization of immutable block-local collision boxes.
//! World access stays on the host thread. This pure stage may run in its worker pool.

/// Convert block collision boxes into a fine-grid solid mask.
///
/// The traversal is block-major: each block's collision list and subcell centers
/// are reused, and resolutions up to 64 combine per-axis occupancy masks instead
/// of retesting every box for every fine cell. Empty blocks are skipped and full
/// cubes are filled by rows; larger resolutions keep the direct cell traversal.
pub fn voxelize(
    dims: [usize; 3],
    resolution: usize,
    blocks: &[Vec<[f64; 6]>],
) -> Result<Vec<u32>, &'static str> {
    if resolution == 0 || dims.contains(&0) {
        return Err("invalid terrain dimensions");
    }
    let block_count = dims
        .into_iter()
        .try_fold(1usize, |a, b| a.checked_mul(b))
        .ok_or("terrain overflow")?;
    if block_count != blocks.len()
        || blocks
            .iter()
            .flatten()
            .any(|b| b.iter().any(|v| !v.is_finite()) || (0..3).any(|i| b[i] > b[i + 3]))
    {
        return Err("invalid terrain boxes");
    }

    let fine = dims.map(|v| v.checked_mul(resolution));
    let [Some(nx), Some(ny), Some(nz)] = fine else {
        return Err("terrain overflow");
    };
    let count = nx
        .checked_mul(ny)
        .and_then(|n| n.checked_mul(nz))
        .ok_or("terrain overflow")?;
    if count > i32::MAX as usize {
        return Err("terrain shader index overflow");
    }

    let mut out = vec![0; count];
    let resolution_f64 = resolution as f64;
    let half_step = 0.5 / resolution_f64;
    // Keep the original operation order exactly: i / res + 0.5 / res.
    let centers: Vec<f64> = (0..resolution)
        .map(|i| i as f64 / resolution_f64 + half_step)
        .collect();
    let plane = nx * ny; // Safe because nx * ny * nz was checked above and nz > 0.
    let full_axis_mask = match resolution {
        64 => u64::MAX,
        1..=63 => (1u64 << resolution) - 1,
        _ => 0,
    };

    for bz in 0..dims[2] {
        let fine_z = bz * resolution;
        let plane_offset = fine_z * plane;
        for by in 0..dims[1] {
            let fine_y = by * resolution;
            let row_offset = plane_offset + fine_y * nx;
            for bx in 0..dims[0] {
                let block_index = bx + dims[0] * (by + dims[1] * bz);
                let boxes = &blocks[block_index];
                if boxes.is_empty() {
                    continue;
                }

                let fine_x = bx * resolution;
                if boxes.iter().any(|b| {
                    b[0] <= 0.0
                        && b[1] <= 0.0
                        && b[2] <= 0.0
                        && b[3] >= 1.0
                        && b[4] >= 1.0
                        && b[5] >= 1.0
                }) {
                    for z in 0..resolution {
                        let z_row = row_offset + z * plane;
                        for y in 0..resolution {
                            let start = z_row + y * nx + fine_x;
                            out[start..start + resolution].fill(1);
                        }
                    }
                    continue;
                }

                if resolution <= 64 {
                    let mut full = false;
                    for b in boxes {
                        let mut axes = [0u64; 3];
                        for (axis, mask) in axes.iter_mut().enumerate() {
                            for (i, &center) in centers.iter().enumerate() {
                                if center >= b[axis] && center < b[axis + 3] {
                                    *mask |= 1u64 << i;
                                }
                            }
                        }
                        if axes.contains(&0) {
                            continue;
                        }
                        if axes.iter().all(|&mask| mask == full_axis_mask) {
                            full = true;
                            break;
                        }

                        // A half-open interval selects a contiguous run of ordered
                        // sample centers on each axis, so walk those ranges directly
                        // instead of extracting every set bit with trailing_zeros.
                        let x_start = axes[0].trailing_zeros() as usize;
                        let x_end = x_start + axes[0].count_ones() as usize;
                        let y_start = axes[1].trailing_zeros() as usize;
                        let y_end = y_start + axes[1].count_ones() as usize;
                        let z_start = axes[2].trailing_zeros() as usize;
                        let z_end = z_start + axes[2].count_ones() as usize;
                        for z in z_start..z_end {
                            for y in y_start..y_end {
                                let row = row_offset + z * plane + y * nx + fine_x;
                                for x in x_start..x_end {
                                    out[row + x] = 1;
                                }
                            }
                        }
                    }
                    if full {
                        for z in 0..resolution {
                            let z_row = row_offset + z * plane;
                            for y in 0..resolution {
                                let start = z_row + y * nx + fine_x;
                                out[start..start + resolution].fill(1);
                            }
                        }
                    }
                } else {
                    for z in 0..resolution {
                        let pz = centers[z];
                        let z_row = row_offset + z * plane;
                        for y in 0..resolution {
                            let py = centers[y];
                            let row = z_row + y * nx + fine_x;
                            for (x, &px) in centers.iter().enumerate() {
                                if boxes.iter().any(|b| {
                                    px >= b[0]
                                        && py >= b[1]
                                        && pz >= b[2]
                                        && px < b[3]
                                        && py < b[4]
                                        && pz < b[5]
                                }) {
                                    out[row + x] = 1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Kept as a deliberately simple oracle for the original cell-major algorithm.
    fn reference_voxelize(
        dims: [usize; 3],
        resolution: usize,
        blocks: &[Vec<[f64; 6]>],
    ) -> Vec<u32> {
        let [nx, ny, nz] = dims.map(|v| v * resolution);
        let mut out = vec![0; nx * ny * nz];
        for z in 0..nz {
            for y in 0..ny {
                for x in 0..nx {
                    let block =
                        x / resolution + dims[0] * (y / resolution + dims[1] * (z / resolution));
                    let p = [x, y, z].map(|v| {
                        (v % resolution) as f64 / resolution as f64 + 0.5 / resolution as f64
                    });
                    out[x + nx * (y + ny * z)] = u32::from(
                        blocks[block]
                            .iter()
                            .any(|b| (0..3).all(|i| p[i] >= b[i] && p[i] < b[i + 3])),
                    );
                }
            }
        }
        out
    }

    #[test]
    fn slab_and_air_x_fastest() {
        let mask = voxelize([2, 1, 1], 2, &[vec![[0., 0., 0., 1., 0.5, 1.]], vec![]]).unwrap();
        assert_eq!(mask, vec![1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0]);
    }

    #[test]
    fn block_major_output_matches_original_cell_major_reference() {
        let shapes = [
            vec![],
            vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
            vec![[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]],
            vec![[0.25, 0.25, 0.25, 0.75, 0.75, 0.75]],
            vec![
                [-0.25, 0.2, 0.8, 0.5, 1.2, 1.5],
                [0.5, 0.5, 0.5, 0.5, 0.9, 0.9],
            ],
        ];
        let dims = [3, 2, 2];
        let blocks: Vec<_> = (0..dims.iter().product::<usize>())
            .map(|i| shapes[i % shapes.len()].clone())
            .collect();

        for resolution in [1, 2, 3, 4, 7] {
            assert_eq!(
                voxelize(dims, resolution, &blocks).unwrap(),
                reference_voxelize(dims, resolution, &blocks),
                "resolution {resolution}"
            );
        }
    }

    #[test]
    fn bitmask_edges_at_63_64_and_fallback_resolution_match_reference() {
        let shapes = [
            Vec::new(),
            vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
            vec![[0.001, 0.001, 0.001, 0.999, 0.999, 0.999]],
            vec![[0.0, 0.25, 0.5, 0.5, 0.75, 1.0]],
            vec![[0.34, 0.0, 0.0, 0.35, 1.0, 1.0]],
            vec![
                [-0.25, 0.0, 0.0, 0.5, 1.0, 0.75],
                [0.5, 0.25, 0.25, 1.25, 0.75, 1.0],
            ],
        ];
        for resolution in [63, 64, 65] {
            for shape in &shapes {
                let blocks = [shape.clone()];
                assert_eq!(
                    voxelize([1; 3], resolution, &blocks).unwrap(),
                    reference_voxelize([1; 3], resolution, &blocks),
                    "resolution {resolution}, shape {shape:?}"
                );
            }
        }
    }

    #[test]
    fn rejects_invalid_and_overflow() {
        assert!(voxelize([1; 3], 0, &[vec![]]).is_err());
        assert!(voxelize([1; 3], 1, &[vec![[0., 0., 0., f64::NAN, 1., 1.]]]).is_err());
        assert!(voxelize([1; 3], usize::MAX, &[vec![]]).is_err());
    }
}
