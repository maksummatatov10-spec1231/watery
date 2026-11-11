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
var<storage> global_1: Sums;
@group(1) @binding(0)
var<uniform> pc: PC;
var<private> gl_GlobalInvocationID_1: vec3<u32>;
var<private> gl_NumWorkGroups_1: vec3<u32>;

fn main_1() {
    var i: u32;

    let _e11: vec3<u32> = gl_GlobalInvocationID_1;
    let _e13: vec3<u32> = gl_GlobalInvocationID_1;
    let _e15: vec3<u32> = gl_NumWorkGroups_1;
    i = (_e11.x + ((_e13.y * _e15.x) * 256u));
    let _e22: u32 = i;
    let _e24: vec4<i32> = pc.a;
    if (_e22 < u32(_e24.y)) {
        {
            let _e29: vec4<i32> = pc.a;
            let _e31: u32 = i;
            let _e36: vec4<i32> = pc.a;
            let _e38: u32 = i;
            let _e42: u32 = global.data[(u32(_e36.x) + _e38)];
            let _e44: vec4<i32> = pc.a;
            let _e46: u32 = i;
            let _e52: u32 = global_1.sums[(u32(_e44.z) + (_e46 / 1024u))];
            global.data[(u32(_e29.x) + _e31)] = (_e42 + _e52);
            return;
        }
    } else {
        return;
    }
}

@compute @workgroup_size(256, 1, 1)
fn main(@builtin(global_invocation_id) gl_GlobalInvocationID: vec3<u32>, @builtin(num_workgroups) gl_NumWorkGroups: vec3<u32>) {
    gl_GlobalInvocationID_1 = gl_GlobalInvocationID;
    gl_NumWorkGroups_1 = gl_NumWorkGroups;
    main_1();
    return;
}
