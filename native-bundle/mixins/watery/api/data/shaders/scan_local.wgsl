struct Data {
    data: array<u32>,
}

struct Sums {
    sums: array<u32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

@group(0) @binding(0)
var<storage, read_write> global: Data;
@group(0) @binding(1)
var<storage, read_write> global_1: Sums;
@group(1) @binding(0)
var<uniform> pc: PC;
var<workgroup> partial: array<u32, 256>;
var<private> gl_LocalInvocationID_1: vec3<u32>;
var<private> gl_WorkGroupID_1: vec3<u32>;
var<private> gl_NumWorkGroups_1: vec3<u32>;

fn main_1() {
    var lid: u32;
    var base: u32;
    var v: array<u32, 4>;
    var sum: u32 = 0u;
    var k: u32 = 0u;
    var i: u32;
    var local: u32;
    var offset: u32 = 1u;
    var local_1: u32;
    var add: u32;
    var running: u32;
    var k_1: u32 = 0u;
    var i_1: u32;

    let _e11: vec3<u32> = gl_LocalInvocationID_1;
    lid = _e11.x;
    let _e16: vec3<u32> = gl_WorkGroupID_1;
    let _e18: vec3<u32> = gl_WorkGroupID_1;
    let _e20: vec3<u32> = gl_NumWorkGroups_1;
    let _e26: u32 = lid;
    base = (((_e16.x + (_e18.y * _e20.x)) * 1024u) + (_e26 * 4u));
    loop {
        let _e36: u32 = k;
        if !((_e36 < 4u)) {
            break;
        }
        {
            let _e43: u32 = base;
            let _e44: u32 = k;
            i = (_e43 + _e44);
            let _e47: u32 = k;
            let _e49: u32 = i;
            let _e51: vec4<i32> = pc.a;
            if (_e49 < u32(_e51.y)) {
                let _e56: vec4<i32> = pc.a;
                let _e58: u32 = i;
                let _e62: u32 = global.data[(u32(_e56.x) + _e58)];
                local = _e62;
            } else {
                local = 0u;
            }
            let _e65: u32 = local;
            v[_e47] = _e65;
            let _e66: u32 = sum;
            let _e67: u32 = k;
            let _e69: u32 = v[_e67];
            sum = (_e66 + _e69);
        }
        continuing {
            let _e40: u32 = k;
            k = (_e40 + 1u);
        }
    }
    let _e71: u32 = lid;
    let _e73: u32 = sum;
    partial[_e71] = _e73;
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    loop {
        let _e76: u32 = offset;
        if !((_e76 < 256u)) {
            break;
        }
        {
            let _e84: u32 = lid;
            let _e85: u32 = offset;
            if (_e84 >= _e85) {
                let _e87: u32 = lid;
                let _e88: u32 = offset;
                let _e91: u32 = partial[(_e87 - _e88)];
                local_1 = _e91;
            } else {
                local_1 = 0u;
            }
            let _e94: u32 = local_1;
            add = _e94;
            storageBarrier();
            workgroupBarrier();
            textureBarrier();
            let _e96: u32 = lid;
            let _e98: u32 = lid;
            let _e100: u32 = partial[_e98];
            let _e101: u32 = add;
            partial[_e96] = (_e100 + _e101);
            storageBarrier();
            workgroupBarrier();
            textureBarrier();
        }
        continuing {
            let _e80: u32 = offset;
            offset = (_e80 << 1u);
        }
    }
    let _e103: u32 = lid;
    let _e105: u32 = partial[_e103];
    let _e106: u32 = sum;
    running = (_e105 - _e106);
    loop {
        let _e111: u32 = k_1;
        if !((_e111 < 4u)) {
            break;
        }
        {
            let _e118: u32 = base;
            let _e119: u32 = k_1;
            i_1 = (_e118 + _e119);
            let _e122: u32 = i_1;
            let _e124: vec4<i32> = pc.a;
            if (_e122 < u32(_e124.y)) {
                {
                    let _e129: vec4<i32> = pc.a;
                    let _e131: u32 = i_1;
                    let _e135: u32 = running;
                    global.data[(u32(_e129.x) + _e131)] = _e135;
                }
            }
            let _e136: u32 = running;
            let _e137: u32 = k_1;
            let _e139: u32 = v[_e137];
            running = (_e136 + _e139);
        }
        continuing {
            let _e115: u32 = k_1;
            k_1 = (_e115 + 1u);
        }
    }
    let _e141: u32 = lid;
    if (_e141 == 255u) {
        {
            let _e145: vec4<i32> = pc.a;
            let _e147: vec3<u32> = gl_WorkGroupID_1;
            let _e149: vec3<u32> = gl_WorkGroupID_1;
            let _e151: vec3<u32> = gl_NumWorkGroups_1;
            let _e160: u32 = partial[255];
            global_1.sums[(u32(_e145.z) + (_e147.x + (_e149.y * _e151.x)))] = _e160;
            return;
        }
    } else {
        return;
    }
}

@compute @workgroup_size(256, 1, 1)
fn main(@builtin(local_invocation_id) gl_LocalInvocationID: vec3<u32>, @builtin(workgroup_id) gl_WorkGroupID: vec3<u32>, @builtin(num_workgroups) gl_NumWorkGroups: vec3<u32>) {
    gl_LocalInvocationID_1 = gl_LocalInvocationID;
    gl_WorkGroupID_1 = gl_WorkGroupID;
    gl_NumWorkGroups_1 = gl_NumWorkGroups;
    main_1();
    return;
}
