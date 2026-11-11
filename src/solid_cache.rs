//! Chunk-section collision mask cache (`me.blue.client.water.SolidCache`).
//!
//! Caches per-block collision masks inside 16×16×16 world sections as `EMPTY`,
//! `FULL`, or a 64-bit `PARTIAL` subcell bitset (`res` in `{1, 2, 4}`, so at
//! most `4^3 = 64` subcells per block). Avoids re-voxelizing unchanged chunk
//! sections every tick while keeping bit-exact parity with `terrain::voxelize`.
use std::collections::HashMap;

const EMPTY: u8 = 0;
const FULL: u8 = 1;
const PARTIAL: u8 = 2;
const SECTION_BLOCKS: usize = 16 * 16 * 16;

#[derive(Clone, Debug)]
struct Section {
    kind: Box<[u8; SECTION_BLOCKS]>,
    partial: HashMap<u16, u64>,
}

impl Default for Section {
    fn default() -> Self {
        Self {
            kind: Box::new([EMPTY; SECTION_BLOCKS]),
            partial: HashMap::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct SolidCache {
    res: usize,
    sections: HashMap<[i32; 3], Section>,
}

#[inline]
pub fn section_of(pos: [i32; 3]) -> [i32; 3] {
    [
        pos[0].div_euclid(16),
        pos[1].div_euclid(16),
        pos[2].div_euclid(16),
    ]
}

#[inline]
fn local_index(x: i32, y: i32, z: i32) -> usize {
    ((x.rem_euclid(16) as usize) & 15)
        | (((y.rem_euclid(16) as usize) & 15) << 4)
        | (((z.rem_euclid(16) as usize) & 15) << 8)
}

fn classify_block(res: usize, boxes: &[[f32; 6]]) -> Result<(u8, u64), &'static str> {
    if boxes.is_empty() {
        return Ok((EMPTY, 0));
    }
    for b in boxes {
        if b.iter().any(|v| !v.is_finite()) {
            return Err("non-finite collision box");
        }
    }
    if boxes.len() == 1 {
        let b = boxes[0];
        if b[0] <= 0.0 && b[1] <= 0.0 && b[2] <= 0.0 && b[3] >= 1.0 && b[4] >= 1.0 && b[5] >= 1.0 {
            return Ok((FULL, u64::MAX));
        }
    }
    let step = 1.0 / res as f32;
    let total = res * res * res;
    let mut bits = 0u64;
    let mut count = 0usize;
    for sz in 0..res {
        for sy in 0..res {
            for sx in 0..res {
                let min = [sx as f32 * step, sy as f32 * step, sz as f32 * step];
                let max = [min[0] + step, min[1] + step, min[2] + step];
                let solid = boxes.iter().any(|b| {
                    (0..3).all(|a| b[a] < b[a + 3] && b[a + 3] > min[a] && b[a] < max[a])
                });
                if solid {
                    let bit = sx + res * (sy + res * sz);
                    bits |= 1u64 << bit;
                    count += 1;
                }
            }
        }
    }
    if count == 0 {
        Ok((EMPTY, 0))
    } else if count == total {
        Ok((FULL, u64::MAX))
    } else {
        Ok((PARTIAL, bits))
    }
}

impl SolidCache {
    pub fn new(res: usize) -> Result<Self, &'static str> {
        if !matches!(res, 1 | 2 | 4) {
            return Err("unsupported solid cache resolution");
        }
        Ok(Self {
            res,
            sections: HashMap::new(),
        })
    }

    pub fn resolution(&self) -> usize {
        self.res
    }

    pub fn len(&self) -> usize {
        self.sections.len()
    }

    pub fn is_empty(&self) -> bool {
        self.sections.is_empty()
    }

    pub fn clear(&mut self) {
        self.sections.clear();
    }

    pub fn has_section(&self, section: [i32; 3]) -> bool {
        self.sections.contains_key(&section)
    }

    /// Drop every cached 16×16×16 section in chunk column `(cx, cz)`.
    pub fn invalidate_chunk(&mut self, cx: i32, cz: i32) -> usize {
        let before = self.sections.len();
        self.sections.retain(|k, _| k[0] != cx || k[2] != cz);
        before - self.sections.len()
    }

    /// Update a single block inside an already-cached section.
    /// Returns `Ok(true)` if the cached subcell mask changed, or `Ok(false)` if
    /// the section is not cached or the block's subcell occupancy did not change.
    pub fn update_block(
        &mut self,
        pos: [i32; 3],
        boxes: &[[f32; 6]],
    ) -> Result<bool, &'static str> {
        let (new_kind, new_bits) = classify_block(self.res, boxes)?;
        let Some(sec) = self.sections.get_mut(&section_of(pos)) else {
            return Ok(false);
        };
        let idx = local_index(pos[0], pos[1], pos[2]);
        let old_kind = sec.kind[idx];
        let old_bits = if old_kind == PARTIAL {
            sec.partial.get(&(idx as u16)).copied().unwrap_or(0)
        } else {
            0
        };
        sec.kind[idx] = new_kind;
        if new_kind == PARTIAL {
            sec.partial.insert(idx as u16, new_bits);
        } else {
            sec.partial.remove(&(idx as u16));
        }
        Ok(old_kind != new_kind || (new_kind == PARTIAL && old_bits != new_bits))
    }

    /// Insert a pre-queried 16×16×16 section (`local_index(x, y, z)` order: x fastest, then y, then z).
    pub fn insert_section(
        &mut self,
        section: [i32; 3],
        blocks: &[Vec<[f32; 6]>],
    ) -> Result<(), &'static str> {
        if blocks.len() != SECTION_BLOCKS {
            return Err("section requires 4096 block collision entries");
        }
        let mut sec = Section::default();
        for (idx, boxes) in blocks.iter().enumerate() {
            let (kind, bits) = classify_block(self.res, boxes)?;
            sec.kind[idx] = kind;
            if kind == PARTIAL {
                sec.partial.insert(idx as u16, bits);
            }
        }
        self.sections.insert(section, sec);
        Ok(())
    }

    /// Insert an all-empty (all-air) 16×16×16 section without per-block iteration.
    pub fn insert_empty_section(&mut self, section: [i32; 3]) {
        self.sections.insert(section, Section::default());
    }

    /// Return all 16×16×16 section coordinates overlapped by `[origin .. origin + dims_blocks]`
    /// that are not currently cached.
    pub fn missing_sections(&self, origin: [i32; 3], dims_blocks: [usize; 3]) -> Vec<[i32; 3]> {
        if dims_blocks.contains(&0) {
            return Vec::new();
        }
        let min_s = section_of(origin);
        let max_s = section_of([
            origin[0] + dims_blocks[0] as i32 - 1,
            origin[1] + dims_blocks[1] as i32 - 1,
            origin[2] + dims_blocks[2] as i32 - 1,
        ]);
        let mut missing = Vec::new();
        for sz in min_s[2]..=max_s[2] {
            for sy in min_s[1]..=max_s[1] {
                for sx in min_s[0]..=max_s[0] {
                    let key = [sx, sy, sz];
                    if !self.sections.contains_key(&key) {
                        missing.push(key);
                    }
                }
            }
        }
        missing
    }

    /// Extract the `(dims_blocks * res)` `staticSolid` field (`0` or `1` per cell)
    /// in simulation grid order (`x + gx * (y + gy * z)`).
    /// When `unloaded_solid` is true, uncached sections default to solid (`1`) so
    /// fluid cannot leak out of unloaded chunks.
    pub fn extract_region(
        &self,
        origin: [i32; 3],
        dims_blocks: [usize; 3],
        unloaded_solid: bool,
    ) -> Result<Vec<u32>, &'static str> {
        let res = self.res;
        let [gx, gy, gz] = [
            dims_blocks[0].checked_mul(res).ok_or("grid x overflow")?,
            dims_blocks[1].checked_mul(res).ok_or("grid y overflow")?,
            dims_blocks[2].checked_mul(res).ok_or("grid z overflow")?,
        ];
        let total = gx
            .checked_mul(gy)
            .and_then(|v| v.checked_mul(gz))
            .ok_or("grid size overflow")?;
        let mut out = vec![0u32; total];
        for bz in 0..dims_blocks[2] {
            let wz = origin[2] + bz as i32;
            for by in 0..dims_blocks[1] {
                let wy = origin[1] + by as i32;
                for bx in 0..dims_blocks[0] {
                    let wx = origin[0] + bx as i32;
                    let sec_key = section_of([wx, wy, wz]);
                    let (kind, bits) = match self.sections.get(&sec_key) {
                        Some(sec) => {
                            let idx = local_index(wx, wy, wz);
                            let k = sec.kind[idx];
                            let b = if k == PARTIAL {
                                sec.partial.get(&(idx as u16)).copied().unwrap_or(0)
                            } else if k == FULL {
                                u64::MAX
                            } else {
                                0
                            };
                            (k, b)
                        }
                        None if unloaded_solid => (FULL, u64::MAX),
                        None => (EMPTY, 0),
                    };
                    if kind == EMPTY {
                        continue;
                    }
                    for sz in 0..res {
                        let cz = bz * res + sz;
                        for sy in 0..res {
                            let cy = by * res + sy;
                            let row = gx * (cy + gy * cz) + bx * res;
                            if kind == FULL {
                                out[row..row + res].fill(1);
                            } else {
                                for sx in 0..res {
                                    let bit = sx + res * (sy + res * sz);
                                    if (bits >> bit) & 1 != 0 {
                                        out[row + sx] = 1;
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
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_terrain_voxelize_across_section_boundaries_and_partial_shapes() {
        let res = 4;
        let mut cache = SolidCache::new(res).unwrap();
        let origin = [14, 63, -2];
        let dims = [4, 4, 4];
        for sec in cache.missing_sections(origin, dims) {
            let mut section_blocks = vec![Vec::new(); SECTION_BLOCKS];
            for lz in 0..16 {
                for ly in 0..16 {
                    for lx in 0..16 {
                        let wx = sec[0] * 16 + lx;
                        let wy = sec[1] * 16 + ly;
                        let wz = sec[2] * 16 + lz;
                        let idx = local_index(wx, wy, wz);
                        if wy == 63 {
                            section_blocks[idx] = vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]];
                        } else if (wx, wy, wz) == (16, 64, 0) {
                            // Bottom slab + stair step
                            section_blocks[idx] = vec![
                                [0.0, 0.0, 0.0, 1.0, 0.5, 1.0],
                                [0.5, 0.5, 0.0, 1.0, 1.0, 1.0],
                            ];
                        }
                    }
                }
            }
            cache.insert_section(sec, &section_blocks).unwrap();
        }
        assert!(cache.missing_sections(origin, dims).is_empty());

        let mut direct_boxes = Vec::with_capacity(64);
        for bz in 0..dims[2] {
            for by in 0..dims[1] {
                for bx in 0..dims[0] {
                    let (wx, wy, wz) = (
                        origin[0] + bx as i32,
                        origin[1] + by as i32,
                        origin[2] + bz as i32,
                    );
                    if wy == 63 {
                        direct_boxes.push(vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]]);
                    } else if (wx, wy, wz) == (16, 64, 0) {
                        direct_boxes.push(vec![
                            [0.0, 0.0, 0.0, 1.0, 0.5, 1.0],
                            [0.5, 0.5, 0.0, 1.0, 1.0, 1.0],
                        ]);
                    } else {
                        direct_boxes.push(Vec::new());
                    }
                }
            }
        }
        let expected = crate::terrain::voxelize(dims, res, &direct_boxes).unwrap();
        let actual = cache.extract_region(origin, dims, true).unwrap();
        assert_eq!(actual, expected);
    }

    #[test]
    fn update_block_and_chunk_invalidation() {
        let mut cache = SolidCache::new(2).unwrap();
        cache.insert_empty_section([0, 4, 0]);
        cache.insert_empty_section([0, 5, 0]);
        cache.insert_empty_section([1, 4, 0]);
        assert!(!cache.update_block([3, 64, 3], &[]).unwrap());
        assert!(
            cache
                .update_block([3, 64, 3], &[[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]])
                .unwrap()
        );
        assert!(
            !cache
                .update_block([3, 64, 3], &[[0.0, 0.0, 0.0, 1.0, 0.5, 1.0]])
                .unwrap()
        );
        assert_eq!(cache.invalidate_chunk(0, 0), 2);
        assert_eq!(cache.len(), 1);
        assert!(cache.has_section([1, 4, 0]));
    }
}
