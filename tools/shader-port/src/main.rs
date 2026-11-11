//! Compile original GLSL into validated WGSL using Horizon's pinned Naga.
//! Does not execute shaders. Failures are reported individually, never silently dropped.
use std::{
    fs,
    path::{Path, PathBuf},
};

fn expand(path: &Path, chain: &mut Vec<PathBuf>) -> Result<String, String> {
    if chain.iter().any(|p| p == path) || chain.len() > 16 {
        return Err(format!("recursive include: {}", path.display()));
    }
    chain.push(path.to_owned());
    let text = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let mut out = String::new();
    for line in text.lines() {
        if let Some(name) = line
            .trim()
            .strip_prefix("#include \"")
            .and_then(|s| s.strip_suffix('"'))
        {
            if name.contains(['/', '\\', ':']) || name.contains("..") {
                return Err("include outside shader folder".into());
            }
            out.push_str(&expand(&path.parent().unwrap().join(name), chain)?);
        } else {
            out.push_str(line);
            out.push('\n');
        }
    }
    chain.pop();
    Ok(out)
}

fn convert(path: &Path) -> Result<String, String> {
    let source = expand(path, &mut Vec::new())?;
    convert_source(path, source, "")
}

fn convert_source(path: &Path, source: String, extra_defines: &str) -> Result<String, String> {
    // All supplied kernels declare a literal one-dimensional local size. WGSL
    // has no WorkGroupSize input, so use that same compile-time constant.
    let stage = match path.extension().and_then(|e| e.to_str()) {
        Some("vert") => naga::ShaderStage::Vertex,
        Some("frag") => naga::ShaderStage::Fragment,
        _ => naga::ShaderStage::Compute,
    };
    let size = source
        .lines()
        .find_map(|line| {
            line.strip_prefix("layout(local_size_x = ")
                .and_then(|s| s.strip_suffix(") in;"))
                .and_then(|s| s.parse::<u32>().ok())
        })
        .unwrap_or(1);
    let mut source = source.replace("gl_WorkGroupSize.x", &format!("{size}u"));
    // WGSL lacks isnan/isinf. For these two scalar guards, inspect IEEE-754
    // exponent/mantissa bits, preserving NaN and either signed infinity.
    let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
    let guard = match name {
        "cg_direction.comp" => Some("beta"),
        "cg_update.comp" => Some("alpha"),
        "mg_solve_small.comp" => Some("r"),
        _ => None,
    };
    if let Some(value) = guard {
        let old = format!("isnan({value}) || isinf({value})");
        if source.matches(&old).count() != 1 {
            return Err("original scalar nonfinite guard changed".into());
        }
        source = source.replace(
            &old,
            &format!("((floatBitsToUint({value}) & 0x7f800000u) == 0x7f800000u)"),
        );
    }
    if matches!(name, "g2p.comp" | "mpm_g2p.comp") {
        // Elect the first *active* invocation, not lane zero (which may have
        // returned). Preserve the subgroup reductions and atomic reservation.
        source = source.replace(
            "subgroupElect()",
            "(gl_SubgroupInvocationID == subgroupBroadcastFirst(gl_SubgroupInvocationID))",
        );
        source = source
            .replace("isnan(", "wateryIsNan(")
            .replace("isinf(", "wateryIsInf(");
        let helpers = "bvec3 wateryIsNan(vec3 v) { return greaterThan(floatBitsToUint(v) & uvec3(0x7fffffffu), uvec3(0x7f800000u)); }\nbvec3 wateryIsInf(vec3 v) { return equal(floatBitsToUint(v) & uvec3(0x7fffffffu), uvec3(0x7f800000u)); }\n";
        source = source.replacen("#version 450\n", &format!("#version 450\n{helpers}"), 1);
    }
    if name == "mpm_g2p.comp" {
        let original = "outerProduct(g.xyz, dpos)";
        if source.matches(original).count() != 1 {
            return Err("original MPM outer product changed".into());
        }
        // GLSL outerProduct(c, r) has columns c*r.x, c*r.y, c*r.z.
        source = source.replace(
            original,
            "mat3(g.xyz * dpos.x, g.xyz * dpos.y, g.xyz * dpos.z)",
        );
    }
    // WGSL storage is coherent across storageBarrier(). Original explicit
    // memoryBarrierBuffer()/barrier() calls remain intact in the translated IR.
    if matches!(name, "mg_bottom.comp" | "mg_solve_small.comp") {
        source = source.replace("coherent buffer", "buffer");
    }
    // Naga accepts separate Vulkan textures/samplers, not combined GLSL
    // samplers. Keep texture bindings intact; put matching samplers in group 2.
    let mut separate = String::new();
    for line in source.lines() {
        if let Some((layout, tail)) = line.split_once(") uniform sampler2D ") {
            let name = tail.trim_end_matches(';');
            let binding = layout.strip_prefix("layout(binding = ")
                .ok_or("unexpected combined sampler layout")?;
            separate.push_str(&format!("layout(set=0, binding={binding}) uniform texture2D {name}_texture;\nlayout(set=2, binding={binding}) uniform sampler {name}_sampler;\n#define {name} sampler2D({name}_texture, {name}_sampler)\n"));
        } else {
            separate.push_str(line);
            separate.push('\n');
        }
    }
    source = separate;
    if !extra_defines.is_empty() {
        source = source.replacen("#version 450\n", &format!("#version 450\n{extra_defines}"), 1);
    } else if name == "particle.vert" {
        source = source.replacen("#version 450\n", "#version 450\n#define VIEW_BINDING 4\n", 1);
    }
    let mut module = naga::front::glsl::Frontend::default()
        .parse(
            &naga::front::glsl::Options::from(stage),
            &source,
        )
        .map_err(|e| format!("GLSL: {}", e.emit_to_string(&source)))?;
    // WebGPU storage buffers permit read or read_write, not write-only.
    // Widen the binding access without adding any reads or changing code.
    if module
        .global_variables
        .iter()
        .any(|(_, global)| global.binding.as_ref().is_some_and(|b| b.group == 1))
    {
        return Err("group 1 reserved for original push constants".into());
    }
    for (_, global) in module.global_variables.iter_mut() {
        if global.space == naga::AddressSpace::Immediate {
            global.space = naga::AddressSpace::Uniform;
            global.binding = Some(naga::ResourceBinding {
                group: 1,
                binding: 0,
            });
        }
        if let naga::AddressSpace::Storage { access } = &mut global.space {
            if access.contains(naga::StorageAccess::STORE) {
                *access |= naga::StorageAccess::LOAD;
            }
        }
    }
    let mut validator = naga::valid::Validator::new(
        naga::valid::ValidationFlags::all(),
        naga::valid::Capabilities::all(),
    );
    let info = validator
        .validate(&module)
        .map_err(|e| format!("IR: {e:?}"))?;
    let wgsl = naga::back::wgsl::write_string(
        &module,
        &info,
        naga::back::wgsl::WriterFlags::EXPLICIT_TYPES,
    )
    .map_err(|e| format!("WGSL export: {e}"))?;
    // Naga emits trailing spaces after a few WGSL attributes. Keep generated
    // files clean and make the exact output stable across platforms.
    let wgsl = format!(
        "{}\n",
        wgsl.lines().map(str::trim_end).collect::<Vec<_>>().join("\n")
    );
    let reparsed = naga::front::wgsl::parse_str(&wgsl)
        .map_err(|e| format!("WGSL parse: {}", e.emit_to_string(&wgsl)))?;
    validator
        .validate(&reparsed)
        .map_err(|e| format!("WGSL validation: {e:?}"))?;
    Ok(wgsl)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let input = root.join("reference/original/assets/watery/shaders");
    let output = root.join("generated/shaders");
    fs::create_dir_all(&output)?;
    let mut paths: Vec<_> = fs::read_dir(&input)?
        .map(|e| e.map(|e| e.path()))
        .collect::<Result<_, _>>()?;
    paths.sort();
    let (mut ok, mut failed) = (0, 0);
    let mut report = String::from(
        "# Original GLSL → Horizon Naga → WGSL validation\n\nThis is offline compilation, not GPU or game verification. Capabilities are unrestricted during validation; target device limits still need checking.\n\n",
    );
    for path in paths
        .into_iter()
        .filter(|p| p.extension().is_some_and(|e| e == "comp" || e == "vert" || e == "frag"))
    {
        let name = path.file_name().unwrap().to_string_lossy();
        // This stale resource is not referenced by WaterRenderer or SandRenderer;
        // it calls a removed three-argument sandLight overload. Preserve it in
        // reference/original rather than silently inventing replacement shading.
        if name == "sand_mesh.frag" {
            report.push_str("UNUSED sand_mesh.frag: original resource has unresolved bindings and a removed sandLight overload; original SandRenderer uses grain.vert/grain.frag. Not translated.\n\n");
            continue;
        }
        let dest = output
            .join(if path.extension().is_some_and(|e| e == "comp") {
                path.file_stem().unwrap().to_string_lossy().into_owned()
            } else {
                path.file_name().unwrap().to_string_lossy().replace('.', "_")
            })
            .with_extension("wgsl");
        match convert(&path) {
            Ok(wgsl) => {
                fs::write(&dest, wgsl)?;
                report.push_str(&format!("PASS {name}\n\n"));
                ok += 1;
            }
            Err(error) => {
                if dest.exists() {
                    fs::remove_file(&dest)?;
                }
                report.push_str(&format!("FAIL {name}\n```text\n{error}\n```\n\n"));
                failed += 1;
            }
        }
    }
    let particle = input.join("particle.vert");
    match convert_source(
        &particle,
        expand(&particle, &mut Vec::new())?,
        "#define VIEW_BINDING 3\n#define DROPLETS 1\n",
    ) {
        Ok(wgsl) => {
            fs::write(output.join("droplet_vert.wgsl"), wgsl)?;
            report.push_str("PASS particle.vert (DROPLETS, VIEW_BINDING=3)\n\n");
            ok += 1;
        }
        Err(e) => {
            report.push_str(&format!("FAIL droplet variant: {e}\n"));
            failed += 1;
        }
    }
    let blockfill = input.join("blockfill.comp");
    match convert_source(
        &blockfill,
        expand(&blockfill, &mut Vec::new())?,
        "#define MPM 1\n",
    ) {
        Ok(wgsl) => {
            fs::write(output.join("blockfill_mpm.wgsl"), wgsl)?;
            report.push_str("PASS blockfill.comp (MPM=1)\n\n");
            ok += 1;
        }
        Err(e) => {
            report.push_str(&format!("FAIL blockfill MPM variant: {e}\n"));
            failed += 1;
        }
    }
    report.push_str(&format!("Total: {ok} passed, {failed} failed.\n"));
    fs::write(root.join("reference/shader-port-report.md"), report)?;
    println!(
        "Shader translation: {ok} passed, {failed} failed; see reference/shader-port-report.md"
    );
    if failed != 0 {
        std::process::exit(1);
    }
    Ok(())
}
