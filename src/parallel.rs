//! Bounded scoped CPU work for independent snapshots, not direct world/GPU mutation.
//! This primitive is not yet connected to Horizon. It creates threads per call;
//! a production per-frame adapter must use Horizon's persistent worker pool.
use std::num::NonZeroUsize;

/// Mutates disjoint slices; every item is visited once and original indices are stable.
/// `minimum_chunk` avoids spawning a worker for each small item. Closure order across
/// chunks is unspecified: use only for independent work, never ordered reductions.
pub fn for_each_independent<T: Send, F: Fn(usize, &mut T) + Sync>(
    items: &mut [T],
    requested: NonZeroUsize,
    minimum_chunk: NonZeroUsize,
    work: F,
) {
    if items.is_empty() {
        return;
    }
    let hardware = std::thread::available_parallelism().map_or(1, |v| v.get());
    let workers = requested
        .get()
        .min(hardware)
        .min(items.len().div_ceil(minimum_chunk.get()));
    if workers <= 1 {
        for (i, item) in items.iter_mut().enumerate() {
            work(i, item);
        }
        return;
    }
    let chunk_size = items.len().div_ceil(workers);
    std::thread::scope(|scope| {
        let work = &work;
        for (chunk, slice) in items.chunks_mut(chunk_size).enumerate() {
            scope.spawn(move || {
                for (local, item) in slice.iter_mut().enumerate() {
                    work(chunk * chunk_size + local, item);
                }
            });
        }
    });
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn independent_work_is_identical_at_every_requested_worker_count() {
        for len in [0, 1, 17, 4099] {
            let expected: Vec<u32> = (0..len).map(|i| crate::shader_hash(i as u32)).collect();
            for workers in [1, 2, 3, 8, 64] {
                let mut actual = vec![0; len];
                for_each_independent(
                    &mut actual,
                    NonZeroUsize::new(workers).unwrap(),
                    NonZeroUsize::new(32).unwrap(),
                    |i, v| *v = crate::shader_hash(i as u32),
                );
                assert_eq!(actual, expected);
            }
        }
    }
}
