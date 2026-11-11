//! PressureSolver constructor layout from Watery 1.2.2.
//! Offsets are in cells, and include level zero in every multilevel buffer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Level {
    pub dims: [u32; 3],
    pub offset: u32,
    pub cells: u32,
}

pub fn hierarchy(dims: [u32; 3]) -> Result<Vec<Level>, &'static str> {
    if dims.contains(&0) {
        return Err("empty pressure grid");
    }
    let mut levels = Vec::new();
    let mut dims = dims;
    let mut offset = 0u32;
    loop {
        let cells = dims
            .into_iter()
            .try_fold(1u32, |n, d| n.checked_mul(d))
            .ok_or("pressure grid overflow")?;
        let end = offset
            .checked_add(cells)
            .ok_or("pressure offset overflow")?;
        // Shader indices, dimensions and offsets use signed 32-bit integers.
        if end > i32::MAX as u32 {
            return Err("pressure shader index overflow");
        }
        levels.push(Level {
            dims,
            offset,
            cells,
        });
        if cells <= 512 || levels.len() == 14 {
            return Ok(levels);
        }
        offset = end;
        dims = dims.map(|d| d.div_ceil(2));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn original_threshold_and_odd_dimension_rounding() {
        let levels = hierarchy([17, 9, 7]).unwrap();
        assert_eq!(
            levels,
            vec![
                Level {
                    dims: [17, 9, 7],
                    offset: 0,
                    cells: 1071
                },
                Level {
                    dims: [9, 5, 4],
                    offset: 1071,
                    cells: 180
                },
            ]
        );
        assert_eq!(hierarchy([8, 8, 8]).unwrap().len(), 1);
        let levels = hierarchy([24, 24, 24]).unwrap();
        assert_eq!(
            levels.iter().map(|l| l.dims).collect::<Vec<_>>(),
            vec![[24, 24, 24], [12, 12, 12], [6, 6, 6]]
        );
        assert_eq!(levels.last().unwrap().offset, 13824 + 1728);
    }
    #[test]
    fn rejects_unrepresentable_shader_indices() {
        for dims in [[0, 8, 8], [u32::MAX, 2, 2], [i32::MAX as u32, 1, 1]] {
            assert!(hierarchy(dims).is_err());
        }
    }
}
