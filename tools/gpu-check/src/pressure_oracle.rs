//! Independent double-precision dense solve on occupied fluid cells.
//! Checks A p = divergence, rather than duplicating the multigrid algorithm.
pub fn compare(dims: [i32; 3], flags: &[u32], rhs: &[f32], pressure: &[f32]) {
    let active: Vec<_> = flags
        .iter()
        .enumerate()
        .filter_map(|(i, &f)| ((f & 255) == 1).then_some(i))
        .collect();
    assert!(!active.is_empty(), "pressure oracle needs fluid cells");
    assert!(
        active.len() <= 64,
        "dense oracle limited to this regression population"
    );
    let n = active.len();
    let mut matrix = vec![vec![0.0f64; n + 1]; n];
    let [nx, ny, nz] = dims;
    for (row, &i) in active.iter().enumerate() {
        let c = [i as i32 % nx, (i as i32 / nx) % ny, i as i32 / (nx * ny)];
        for axis in 0..3 {
            for sign in [-1, 1] {
                let mut neighbor = c;
                neighbor[axis] += sign;
                let [x, y, z] = neighbor;
                if x < 0 || x >= nx || y < 0 || y >= ny || z < 0 || z >= nz {
                    matrix[row][row] += 1.0;
                    continue;
                }
                let j = (x + nx * (y + ny * z)) as usize;
                // Original constants: air=0, fluid=1, solid=2.
                if flags[j] & 255 == 2 {
                    continue;
                }
                matrix[row][row] += 1.0;
                if let Ok(col) = active.binary_search(&j) {
                    matrix[row][col] -= 1.0;
                }
            }
        }
        matrix[row][n] = rhs[i] as f64;
    }
    // Gaussian elimination with pivoting: deliberately unlike GPU MG/CG.
    for col in 0..n {
        let pivot = (col..n)
            .max_by(|&a, &b| matrix[a][col].abs().total_cmp(&matrix[b][col].abs()))
            .unwrap();
        matrix.swap(col, pivot);
        let scale = matrix[col][col];
        assert!(scale.abs() > 1e-12, "singular oracle test scene");
        for j in col..=n {
            matrix[col][j] /= scale;
        }
        for row in 0..n {
            if row == col {
                continue;
            }
            let scale = matrix[row][col];
            for j in col..=n {
                matrix[row][j] -= scale * matrix[col][j];
            }
        }
    }
    for (row, &i) in active.iter().enumerate() {
        let expected = matrix[row][n];
        let actual = pressure[i] as f64;
        assert!(
            (actual - expected).abs() < 0.001 * expected.abs().max(1.0),
            "pressure disagrees with independent solve: cell={i} GPU={actual} CPU={expected}"
        );
    }
}
