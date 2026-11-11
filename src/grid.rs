//! Checked MAC-grid indexing corresponding to common.glsl.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Grid {
    dims: [usize; 3],
    cells: usize,
    faces: [usize; 3],
    total_faces: usize,
}
fn volume(d: [usize; 3]) -> Option<usize> {
    d[0].checked_mul(d[1])?.checked_mul(d[2])
}
impl Grid {
    /// Reject dimensions that cannot be indexed by the original signed 32-bit shaders.
    pub fn new(dims: [usize; 3]) -> Option<Self> {
        if dims.contains(&0) {
            return None;
        }
        let cells = volume(dims)?;
        let mut faces = [0; 3];
        for axis in 0..3 {
            let mut d = dims;
            d[axis] = d[axis].checked_add(1)?;
            faces[axis] = volume(d)?;
        }
        let total_faces = faces[0].checked_add(faces[1])?.checked_add(faces[2])?;
        // p2g indexes accum[2 * face_index + 1].
        if cells > i32::MAX as usize || total_faces > (i32::MAX as usize) / 2 {
            return None;
        }
        Some(Self {
            dims,
            cells,
            faces,
            total_faces,
        })
    }
    pub const fn cells(self) -> usize {
        self.cells
    }
    pub const fn total_faces(self) -> usize {
        self.total_faces
    }
    pub fn cell_index(self, c: [usize; 3]) -> Option<usize> {
        if (0..3).any(|a| c[a] >= self.dims[a]) {
            return None;
        }
        Some(c[0] + self.dims[0] * (c[1] + self.dims[1] * c[2]))
    }
    pub fn cell_coord(self, index: usize) -> Option<[usize; 3]> {
        if index >= self.cells {
            return None;
        }
        Some([
            index % self.dims[0],
            (index / self.dims[0]) % self.dims[1],
            index / (self.dims[0] * self.dims[1]),
        ])
    }
    pub fn face_index(self, axis: usize, c: [usize; 3]) -> Option<usize> {
        if axis >= 3 {
            return None;
        }
        let mut d = self.dims;
        d[axis] += 1;
        if (0..3).any(|a| c[a] >= d[a]) {
            return None;
        }
        let base: usize = self.faces[..axis].iter().sum();
        Some(base + c[0] + d[0] * (c[1] + d[1] * c[2]))
    }
    pub fn decode_face(self, mut index: usize) -> Option<(usize, [usize; 3])> {
        if index >= self.total_faces {
            return None;
        }
        for axis in 0..3 {
            if index < self.faces[axis] {
                let mut d = self.dims;
                d[axis] += 1;
                return Some((
                    axis,
                    [index % d[0], (index / d[0]) % d[1], index / (d[0] * d[1])],
                ));
            }
            index -= self.faces[axis];
        }
        None
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn all_cells_and_faces_roundtrip() {
        for dims in [[1, 1, 1], [2, 3, 5], [11, 7, 3]] {
            let grid = Grid::new(dims).unwrap();
            for i in 0..grid.cells() {
                assert_eq!(grid.cell_index(grid.cell_coord(i).unwrap()), Some(i));
            }
            for i in 0..grid.total_faces() {
                let (axis, c) = grid.decode_face(i).unwrap();
                assert_eq!(grid.face_index(axis, c), Some(i));
            }
            assert_eq!(grid.cell_coord(grid.cells()), None);
            assert_eq!(grid.decode_face(grid.total_faces()), None);
            assert_eq!(grid.cell_index(dims), None);
            assert_eq!(grid.face_index(3, [0; 3]), None);
        }
    }
    #[test]
    fn refuses_overflow_and_empty_dimensions() {
        assert!(Grid::new([0, 1, 1]).is_none());
        assert!(Grid::new([usize::MAX, 2, 2]).is_none());
        assert!(Grid::new([65536, 65536, 1]).is_none());
    }
}
