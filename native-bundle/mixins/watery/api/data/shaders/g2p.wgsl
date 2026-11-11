struct Particle {
    pos: vec4<f32>,
    vel: vec4<f32>,
}

struct Globals {
    dims: vec4<i32>,
    faces: vec4<i32>,
    caps: vec4<i32>,
    flags: vec4<i32>,
    gravityDt: vec4<f32>,
    simA: vec4<f32>,
    simB: vec4<f32>,
    wwA: vec4<f32>,
    wwB: vec4<f32>,
    wwC: vec4<f32>,
    wwD: vec4<f32>,
    proj: mat4x4<f32>,
    view: mat4x4<f32>,
    invProj: mat4x4<f32>,
    invView: mat4x4<f32>,
    domainOrigin: vec4<f32>,
    screen: vec4<f32>,
    sunDir: vec4<f32>,
    skyColor: vec4<f32>,
    fogColor: vec4<f32>,
    waterA: vec4<f32>,
    absorb: vec4<f32>,
    scatter: vec4<f32>,
    foamA: vec4<f32>,
    ent: array<vec4<f32>, 96>,
    sources: array<vec4<f32>, 64>,
    camGrid: vec4<f32>,
    misc: vec4<f32>,
    fine: vec4<i32>,
    surf: vec4<f32>,
    boxMin: vec4<i32>,
    boxMax: vec4<i32>,
    fineBoxMin: vec4<i32>,
    fineBoxMax: vec4<i32>,
    removeInfo: vec4<i32>,
    removeBox: array<vec4<f32>, 32>,
    killInfo: vec4<f32>,
    shadeA: vec4<f32>,
    shadeB: vec4<f32>,
    matA: vec4<f32>,
    matB: vec4<f32>,
    matC: vec4<f32>,
    matD: vec4<f32>,
    matE: vec4<f32>,
    compat: vec4<f32>,
    shadowNear: mat4x4<f32>,
    shadowMid: mat4x4<f32>,
    shadowFar: mat4x4<f32>,
    compatB: vec4<f32>,
    lightA: vec4<f32>,
    lightB: vec4<f32>,
    lightC: vec4<f32>,
    lightColors: array<vec4<f32>, 8>,
}

struct Src {
    src: array<Particle>,
}

struct Dst {
    dst: array<Particle>,
}

struct Counters {
    counters: array<u32>,
}

struct Vel {
    vel: array<f32>,
}

struct VelOld {
    velOld: array<f32>,
}

struct Flags {
    cellFlags: array<u32>,
}

struct Static {
    staticSolid: array<u32>,
}

struct Pot {
    potential: array<vec2<f32>>,
}

struct WwDst {
    wwDst: array<Particle>,
}

struct WwCount {
    wwCount: array<i32>,
}

struct Count {
    cellCount: array<i32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

struct Counters_1 {
    counters: array<atomic<u32>>,
}

const FP_SCALE: f32 = 65536f;
const SIDES: array<vec3<f32>, 6> = array<vec3<f32>, 6>(vec3<f32>(0.6f, 0f, 0f), vec3<f32>(-0.6f, 0f, 0f), vec3<f32>(0f, 0.6f, 0f), vec3<f32>(0f, -0.6f, 0f), vec3<f32>(0f, 0f, 0.6f), vec3<f32>(0f, 0f, -0.6f));
const OUT: array<vec3<i32>, 6> = array<vec3<i32>, 6>(vec3<i32>(0i, 1i, 0i), vec3<i32>(1i, 0i, 0i), vec3<i32>(-1i, 0i, 0i), vec3<i32>(0i, 0i, 1i), vec3<i32>(0i, 0i, -1i), vec3<i32>(0i, -1i, 0i));
const ORDER: array<i32, 3> = array<i32, 3>(1i, 0i, 2i);

@group(0) @binding(0)
var<uniform> G: Globals;
@group(0) @binding(1)
var<storage> global: Src;
@group(0) @binding(2)
var<storage, read_write> global_1: Dst;
@group(0) @binding(3)
var<storage, read_write> global_2: Counters_1;
@group(0) @binding(4)
var<storage> global_3: Vel;
@group(0) @binding(5)
var<storage> global_4: VelOld;
@group(0) @binding(6)
var<storage> global_5: Flags;
@group(0) @binding(7)
var<storage> global_6: Static;
@group(0) @binding(8)
var<storage> global_7: Pot;
@group(0) @binding(9)
var<storage, read_write> global_8: WwDst;
@group(0) @binding(10)
var<storage> global_9: WwCount;
@group(0) @binding(11)
var<storage> global_10: Count;
@group(1) @binding(0)
var<uniform> pc: PC;
var<private> gl_GlobalInvocationID_1: vec3<u32>;
var<private> gl_NumWorkGroups_1: vec3<u32>;
var<private> gl_SubgroupInvocationID_1: u32;

fn wateryIsNan(v: vec3<f32>) -> vec3<bool> {
    var v_1: vec3<f32>;

    v_1 = v;
    let _e2: vec3<f32> = v_1;
    return ((bitcast<vec3<u32>>(_e2) & vec3(2147483647u)) > vec3(2139095040u));
}

fn wateryIsInf(v_2: vec3<f32>) -> vec3<bool> {
    var v_3: vec3<f32>;

    v_3 = v_2;
    let _e2: vec3<f32> = v_3;
    return ((bitcast<vec3<u32>>(_e2) & vec3(2147483647u)) == vec3(2139095040u));
}

fn isSand() -> bool {
    let _e108: vec4<f32> = G.matA;
    let _e113: vec4<f32> = G.matA;
    return ((_e108.x > 0.5f) && (_e113.x < 1.5f));
}

fn isLava() -> bool {
    let _e108: vec4<f32> = G.matA;
    return (abs((_e108.x - 2f)) < 0.5f);
}

fn isSlime() -> bool {
    let _e108: vec4<f32> = G.matA;
    return (_e108.x > 2.5f);
}

fn cellIndex(c: vec3<i32>) -> i32 {
    var c_1: vec3<i32>;

    c_1 = c;
    let _e110: vec3<i32> = c_1;
    let _e113: vec4<i32> = G.dims;
    let _e115: vec3<i32> = c_1;
    let _e118: vec4<i32> = G.dims;
    let _e120: vec3<i32> = c_1;
    return (_e110.x + (_e113.x * (_e115.y + (_e118.y * _e120.z))));
}

fn inGrid(c_2: vec3<i32>) -> bool {
    var c_3: vec3<i32>;

    c_3 = c_2;
    let _e110: vec3<i32> = c_3;
    let _e114: vec3<i32> = c_3;
    let _e119: vec3<i32> = c_3;
    let _e124: vec3<i32> = c_3;
    let _e127: vec4<i32> = G.dims;
    let _e131: vec3<i32> = c_3;
    let _e134: vec4<i32> = G.dims;
    let _e138: vec3<i32> = c_3;
    let _e141: vec4<i32> = G.dims;
    return ((((((_e110.x >= 0i) && (_e114.y >= 0i)) && (_e119.z >= 0i)) && (_e124.x < _e127.x)) && (_e131.y < _e134.y)) && (_e138.z < _e141.z));
}

fn cellCoord(i: i32) -> vec3<i32> {
    var i_1: i32;

    i_1 = i;
    let _e110: i32 = i_1;
    let _e112: vec4<i32> = G.dims;
    let _e115: i32 = i_1;
    let _e117: vec4<i32> = G.dims;
    let _e121: vec4<i32> = G.dims;
    let _e124: i32 = i_1;
    let _e126: vec4<i32> = G.dims;
    let _e129: vec4<i32> = G.dims;
    return vec3<i32>((_e110 % _e112.x), ((_e115 / _e117.x) % _e121.y), (_e124 / (_e126.x * _e129.y)));
}

fn faceDims(comp: i32) -> vec3<i32> {
    var comp_1: i32;
    var local: i32;
    var local_1: i32;
    var local_2: i32;

    comp_1 = comp;
    let _e111: vec4<i32> = G.dims;
    let _e114: vec4<i32> = G.dims;
    let _e117: vec4<i32> = G.dims;
    let _e120: i32 = comp_1;
    if (_e120 == 0i) {
        local = 1i;
    } else {
        local = 0i;
    }
    let _e126: i32 = local;
    let _e127: i32 = comp_1;
    if (_e127 == 1i) {
        local_1 = 1i;
    } else {
        local_1 = 0i;
    }
    let _e133: i32 = local_1;
    let _e134: i32 = comp_1;
    if (_e134 == 2i) {
        local_2 = 1i;
    } else {
        local_2 = 0i;
    }
    let _e140: i32 = local_2;
    return (vec3<i32>(_e111.x, _e114.y, _e117.z) + vec3<i32>(_e126, _e133, _e140));
}

fn faceBase(comp_2: i32) -> i32 {
    var comp_3: i32;
    var local_3: i32;
    var local_4: i32;

    comp_3 = comp_2;
    let _e110: i32 = comp_3;
    if (_e110 == 0i) {
        local_4 = 0i;
    } else {
        let _e114: i32 = comp_3;
        if (_e114 == 1i) {
            let _e118: vec4<i32> = G.faces;
            local_3 = _e118.x;
        } else {
            let _e121: vec4<i32> = G.faces;
            let _e124: vec4<i32> = G.faces;
            local_3 = (_e121.x + _e124.y);
        }
        let _e128: i32 = local_3;
        local_4 = _e128;
    }
    let _e130: i32 = local_4;
    return _e130;
}

fn faceIndex(comp_4: i32, f: vec3<i32>) -> i32 {
    var comp_5: i32;
    var f_1: vec3<i32>;
    var d: vec3<i32>;

    comp_5 = comp_4;
    f_1 = f;
    let _e112: i32 = comp_5;
    let _e113: vec3<i32> = faceDims(_e112);
    d = _e113;
    let _e115: i32 = comp_5;
    let _e116: i32 = faceBase(_e115);
    let _e117: vec3<i32> = f_1;
    let _e120: vec3<i32> = d;
    let _e122: vec3<i32> = f_1;
    let _e124: vec3<i32> = d;
    let _e126: vec3<i32> = f_1;
    return ((_e116 + _e117.x) + (_e120.x * (_e122.y + (_e124.y * _e126.z))));
}

fn faceOffset(comp_6: i32) -> vec3<f32> {
    var comp_7: i32;
    var local_5: f32;
    var local_6: f32;
    var local_7: f32;

    comp_7 = comp_6;
    let _e110: i32 = comp_7;
    if (_e110 == 0i) {
        local_5 = 0f;
    } else {
        local_5 = 0.5f;
    }
    let _e116: f32 = local_5;
    let _e117: i32 = comp_7;
    if (_e117 == 1i) {
        local_6 = 0f;
    } else {
        local_6 = 0.5f;
    }
    let _e123: f32 = local_6;
    let _e124: i32 = comp_7;
    if (_e124 == 2i) {
        local_7 = 0f;
    } else {
        local_7 = 0.5f;
    }
    let _e130: f32 = local_7;
    return vec3<f32>(_e116, _e123, _e130);
}

fn axisVec(comp_8: i32) -> vec3<i32> {
    var comp_9: i32;
    var local_8: i32;
    var local_9: i32;
    var local_10: i32;

    comp_9 = comp_8;
    let _e110: i32 = comp_9;
    if (_e110 == 0i) {
        local_8 = 1i;
    } else {
        local_8 = 0i;
    }
    let _e116: i32 = local_8;
    let _e117: i32 = comp_9;
    if (_e117 == 1i) {
        local_9 = 1i;
    } else {
        local_9 = 0i;
    }
    let _e123: i32 = local_9;
    let _e124: i32 = comp_9;
    if (_e124 == 2i) {
        local_10 = 1i;
    } else {
        local_10 = 0i;
    }
    let _e130: i32 = local_10;
    return vec3<i32>(_e116, _e123, _e130);
}

fn decodeFace(i_2: i32, comp_10: ptr<function, i32>, f_2: ptr<function, vec3<i32>>) {
    var i_3: i32;
    var d_1: vec3<i32>;

    i_3 = i_2;
    let _e112: i32 = i_3;
    let _e114: vec4<i32> = G.faces;
    if (_e112 < _e114.x) {
        {
            (*comp_10) = 0i;
        }
    } else {
        let _e118: i32 = i_3;
        let _e120: vec4<i32> = G.faces;
        let _e123: vec4<i32> = G.faces;
        if (_e118 < (_e120.x + _e123.y)) {
            {
                (*comp_10) = 1i;
                let _e128: i32 = i_3;
                let _e130: vec4<i32> = G.faces;
                i_3 = (_e128 - _e130.x);
            }
        } else {
            {
                (*comp_10) = 2i;
                let _e134: i32 = i_3;
                let _e136: vec4<i32> = G.faces;
                let _e139: vec4<i32> = G.faces;
                i_3 = (_e134 - (_e136.x + _e139.y));
            }
        }
    }
    let _e143: i32 = (*comp_10);
    let _e144: vec3<i32> = faceDims(_e143);
    d_1 = _e144;
    let _e146: i32 = i_3;
    let _e147: vec3<i32> = d_1;
    let _e150: i32 = i_3;
    let _e151: vec3<i32> = d_1;
    let _e154: vec3<i32> = d_1;
    let _e157: i32 = i_3;
    let _e158: vec3<i32> = d_1;
    let _e160: vec3<i32> = d_1;
    (*f_2) = vec3<i32>((_e146 % _e147.x), ((_e150 / _e151.x) % _e154.y), (_e157 / (_e158.x * _e160.y)));
    return;
}

fn boxDims() -> vec3<i32> {
    let _e109: vec4<i32> = G.boxMax;
    let _e112: vec4<i32> = G.boxMin;
    return (_e109.xyz - _e112.xyz);
}

fn inBox(c_4: vec3<i32>) -> bool {
    var c_5: vec3<i32>;

    c_5 = c_4;
    let _e110: vec3<i32> = c_5;
    let _e112: vec4<i32> = G.boxMin;
    let _e116: vec3<i32> = c_5;
    let _e118: vec4<i32> = G.boxMax;
    return (all((_e110 >= _e112.xyz)) && all((_e116 < _e118.xyz)));
}

fn boxIndex(c_6: vec3<i32>) -> i32 {
    var c_7: vec3<i32>;
    var d_2: vec3<i32>;
    var l: vec3<i32>;

    c_7 = c_6;
    let _e110: vec3<i32> = boxDims();
    d_2 = _e110;
    let _e112: vec3<i32> = c_7;
    let _e114: vec4<i32> = G.boxMin;
    l = (_e112 - _e114.xyz);
    let _e118: vec3<i32> = l;
    let _e120: vec3<i32> = d_2;
    let _e122: vec3<i32> = l;
    let _e124: vec3<i32> = d_2;
    let _e126: vec3<i32> = l;
    return (_e118.x + (_e120.x * (_e122.y + (_e124.y * _e126.z))));
}

fn inInnerBox(x: vec3<f32>) -> bool {
    var x_1: vec3<f32>;

    x_1 = x;
    let _e110: vec3<f32> = x_1;
    let _e112: vec4<i32> = G.boxMin;
    let _e120: vec3<f32> = x_1;
    let _e122: vec4<i32> = G.boxMax;
    return (all((_e110 >= (vec3<f32>(_e112.xyz) + vec3(2f)))) && all((_e120 < (vec3<f32>(_e122.xyz) - vec3(2f)))));
}

fn boxCell(t: i32) -> vec3<i32> {
    var t_1: i32;
    var d_3: vec3<i32>;

    t_1 = t;
    let _e110: vec3<i32> = boxDims();
    d_3 = _e110;
    let _e113: vec4<i32> = G.boxMin;
    let _e115: i32 = t_1;
    let _e116: vec3<i32> = d_3;
    let _e119: i32 = t_1;
    let _e120: vec3<i32> = d_3;
    let _e123: vec3<i32> = d_3;
    let _e126: i32 = t_1;
    let _e127: vec3<i32> = d_3;
    let _e129: vec3<i32> = d_3;
    return (_e113.xyz + vec3<i32>((_e115 % _e116.x), ((_e119 / _e120.x) % _e123.y), (_e126 / (_e127.x * _e129.y))));
}

fn faceInBox(comp_11: i32, f_3: vec3<i32>) -> bool {
    var comp_12: i32;
    var f_4: vec3<i32>;

    comp_12 = comp_11;
    f_4 = f_3;
    let _e112: vec3<i32> = f_4;
    let _e114: vec4<i32> = G.boxMin;
    let _e118: vec3<i32> = f_4;
    let _e120: vec4<i32> = G.boxMax;
    let _e122: i32 = comp_12;
    let _e123: vec3<i32> = axisVec(_e122);
    return (all((_e112 >= _e114.xyz)) && all((_e118 < (_e120.xyz + _e123))));
}

fn boxFace(t_2: i32, comp_13: ptr<function, i32>, f_5: ptr<function, vec3<i32>>) -> bool {
    var t_3: i32;
    var d_4: vec3<i32>;
    var fd: vec3<i32>;
    var n: i32;

    t_3 = t_2;
    let _e112: vec3<i32> = boxDims();
    d_4 = _e112;
    (*comp_13) = 0i;
    loop {
        let _e115: i32 = (*comp_13);
        if !((_e115 < 3i)) {
            break;
        }
        {
            let _e122: vec3<i32> = d_4;
            let _e123: i32 = (*comp_13);
            let _e124: vec3<i32> = axisVec(_e123);
            fd = (_e122 + _e124);
            let _e127: vec3<i32> = fd;
            let _e129: vec3<i32> = fd;
            let _e132: vec3<i32> = fd;
            n = ((_e127.x * _e129.y) * _e132.z);
            let _e136: i32 = t_3;
            let _e137: i32 = n;
            if (_e136 < _e137) {
                {
                    let _e140: vec4<i32> = G.boxMin;
                    let _e142: i32 = t_3;
                    let _e143: vec3<i32> = fd;
                    let _e146: i32 = t_3;
                    let _e147: vec3<i32> = fd;
                    let _e150: vec3<i32> = fd;
                    let _e153: i32 = t_3;
                    let _e154: vec3<i32> = fd;
                    let _e156: vec3<i32> = fd;
                    (*f_5) = (_e140.xyz + vec3<i32>((_e142 % _e143.x), ((_e146 / _e147.x) % _e150.y), (_e153 / (_e154.x * _e156.y))));
                    return true;
                }
            }
            let _e163: i32 = t_3;
            let _e164: i32 = n;
            t_3 = (_e163 - _e164);
        }
        continuing {
            let _e119: i32 = (*comp_13);
            (*comp_13) = (_e119 + 1i);
        }
    }
    (*f_5) = vec3(0i);
    return false;
}

fn numEntities() -> i32 {
    let _e109: vec4<i32> = G.caps;
    return _e109.z;
}

fn entMin(e: i32) -> vec3<f32> {
    var e_1: i32;

    e_1 = e;
    let _e110: i32 = e_1;
    let _e115: vec4<f32> = G.ent[(_e110 * 3i)];
    return _e115.xyz;
}

fn entMax(e_2: i32) -> vec3<f32> {
    var e_3: i32;

    e_3 = e_2;
    let _e110: i32 = e_3;
    let _e117: vec4<f32> = G.ent[((_e110 * 3i) + 1i)];
    return _e117.xyz;
}

fn entVel(e_4: i32) -> vec3<f32> {
    var e_5: i32;

    e_5 = e_4;
    let _e110: i32 = e_5;
    let _e117: vec4<f32> = G.ent[((_e110 * 3i) + 2i)];
    return _e117.xyz;
}

fn entityAt(p: vec3<f32>) -> i32 {
    var p_1: vec3<f32>;
    var e_6: i32 = 0i;

    p_1 = p;
    loop {
        let _e112: i32 = e_6;
        let _e113: i32 = numEntities();
        if !((_e112 < _e113)) {
            break;
        }
        {
            let _e119: vec3<f32> = p_1;
            let _e120: i32 = e_6;
            let _e121: vec3<f32> = entMin(_e120);
            let _e124: vec3<f32> = p_1;
            let _e125: i32 = e_6;
            let _e126: vec3<f32> = entMax(_e125);
            if (all((_e119 >= _e121)) && all((_e124 <= _e126))) {
                {
                    let _e130: i32 = e_6;
                    return _e130;
                }
            }
        }
        continuing {
            let _e116: i32 = e_6;
            e_6 = (_e116 + 1i);
        }
    }
    return -1i;
}

fn hash(x_2: u32) -> u32 {
    var x_3: u32;

    x_3 = x_2;
    let _e110: u32 = x_3;
    let _e111: u32 = x_3;
    x_3 = (_e110 ^ (_e111 >> 16u));
    let _e116: u32 = x_3;
    x_3 = (_e116 * 2146121005u);
    let _e119: u32 = x_3;
    let _e120: u32 = x_3;
    x_3 = (_e119 ^ (_e120 >> 15u));
    let _e125: u32 = x_3;
    x_3 = (_e125 * 2221713035u);
    let _e128: u32 = x_3;
    let _e129: u32 = x_3;
    x_3 = (_e128 ^ (_e129 >> 16u));
    let _e134: u32 = x_3;
    return _e134;
}

fn rand(state: ptr<function, u32>) -> f32 {
    let _e109: u32 = (*state);
    let _e112: u32 = hash((_e109 + 2654435769u));
    (*state) = _e112;
    let _e113: u32 = (*state);
    return (f32((_e113 >> 8u)) * 0.000000059604645f);
}

fn randInSphere(state_1: ptr<function, u32>) -> vec3<f32> {
    var i_4: i32 = 0i;
    var local_11: u32;
    var local_12: u32;
    var local_13: u32;
    var p_2: vec3<f32>;

    loop {
        let _e111: i32 = i_4;
        if !((_e111 < 8i)) {
            break;
        }
        {
            let _e119: u32 = (*state_1);
            local_11 = _e119;
            let _e121: f32 = rand((&local_11));
            let _e122: u32 = local_11;
            (*state_1) = _e122;
            let _e124: u32 = (*state_1);
            local_12 = _e124;
            let _e126: f32 = rand((&local_12));
            let _e127: u32 = local_12;
            (*state_1) = _e127;
            let _e129: u32 = (*state_1);
            local_13 = _e129;
            let _e131: f32 = rand((&local_13));
            let _e132: u32 = local_13;
            (*state_1) = _e132;
            p_2 = ((vec3<f32>(_e121, _e126, _e131) * 2f) - vec3(1f));
            let _e140: vec3<f32> = p_2;
            let _e141: vec3<f32> = p_2;
            if (dot(_e140, _e141) <= 1f) {
                {
                    let _e145: vec3<f32> = p_2;
                    return _e145;
                }
            }
        }
        continuing {
            let _e115: i32 = i_4;
            i_4 = (_e115 + 1i);
        }
    }
    return vec3(0f);
}

fn clampPhi(v_4: f32, lo: f32, hi: f32) -> f32 {
    var v_5: f32;
    var lo_1: f32;
    var hi_1: f32;

    v_5 = v_4;
    lo_1 = lo;
    hi_1 = hi;
    let _e114: f32 = v_5;
    let _e115: f32 = lo_1;
    let _e117: f32 = hi_1;
    let _e118: f32 = lo_1;
    return clamp(((_e114 - _e115) / max((_e117 - _e118), 0.000001f)), 0f, 1f);
}

fn fineIndex(p_3: vec3<i32>) -> i32 {
    var p_4: vec3<i32>;

    p_4 = p_3;
    let _e110: vec3<i32> = p_4;
    let _e113: vec4<i32> = G.fine;
    let _e115: vec3<i32> = p_4;
    let _e118: vec4<i32> = G.fine;
    let _e120: vec3<i32> = p_4;
    return (_e110.x + (_e113.x * (_e115.y + (_e118.y * _e120.z))));
}

fn inFine(p_5: vec3<i32>) -> bool {
    var p_6: vec3<i32>;

    p_6 = p_5;
    let _e110: vec3<i32> = p_6;
    let _e112: vec4<i32> = G.fineBoxMin;
    let _e116: vec3<i32> = p_6;
    let _e118: vec4<i32> = G.fineBoxMax;
    return (all((_e110 >= _e112.xyz)) && all((_e116 < _e118.xyz)));
}

fn packNormal(n_1: vec3<f32>, flag: bool) -> u32 {
    var n_2: vec3<f32>;
    var flag_1: bool;
    var local_14: f32;
    var local_15: f32;
    var local_16: vec2<f32>;
    var e_7: vec2<f32>;
    var q: vec2<u32>;
    var local_17: u32;

    n_2 = n_1;
    flag_1 = flag;
    let _e112: vec3<f32> = n_2;
    let _e113: vec3<f32> = n_2;
    let _e116: vec3<f32> = n_2;
    let _e120: vec3<f32> = n_2;
    n_2 = (_e112 / vec3(((abs(_e113.x) + abs(_e116.y)) + abs(_e120.z))));
    let _e126: vec3<f32> = n_2;
    if (_e126.z >= 0f) {
        let _e130: vec3<f32> = n_2;
        local_16 = _e130.xy;
    } else {
        let _e133: vec3<f32> = n_2;
        let _e138: vec3<f32> = n_2;
        if (_e138.x >= 0f) {
            local_14 = 1f;
        } else {
            local_14 = -1f;
        }
        let _e146: f32 = local_14;
        let _e147: vec3<f32> = n_2;
        if (_e147.y >= 0f) {
            local_15 = 1f;
        } else {
            local_15 = -1f;
        }
        let _e155: f32 = local_15;
        local_16 = ((vec2(1f) - abs(_e133.yx)) * vec2<f32>(_e146, _e155));
    }
    let _e159: vec2<f32> = local_16;
    e_7 = _e159;
    let _e161: vec2<f32> = e_7;
    q = vec2<u32>(((clamp(((_e161 * 0.5f) + vec2(0.5f)), vec2(0f), vec2(1f)) * 32767f) + vec2(0.5f)));
    let _e179: vec2<u32> = q;
    let _e181: vec2<u32> = q;
    let _e187: bool = flag_1;
    if _e187 {
        local_17 = 1073741824u;
    } else {
        local_17 = 0u;
    }
    let _e191: u32 = local_17;
    return ((_e179.x | (_e181.y << 15u)) | _e191);
}

fn unpackNormal(v_6: u32, flag_2: ptr<function, bool>) -> vec3<f32> {
    var v_7: u32;
    var e_8: vec2<f32>;
    var n_3: vec3<f32>;
    var local_18: f32;
    var local_19: f32;

    v_7 = v_6;
    let _e111: u32 = v_7;
    (*flag_2) = ((_e111 & 1073741824u) != 0u);
    let _e116: u32 = v_7;
    let _e120: u32 = v_7;
    e_8 = (((vec2<f32>(f32((_e116 & 32767u)), f32(((_e120 >> 15u) & 32767u))) / vec2(32767f)) * 2f) - vec2(1f));
    let _e137: vec2<f32> = e_8;
    let _e139: vec2<f32> = e_8;
    let _e143: vec2<f32> = e_8;
    n_3 = vec3<f32>(_e137.x, _e137.y, ((1f - abs(_e139.x)) - abs(_e143.y)));
    let _e151: vec3<f32> = n_3;
    if (_e151.z < 0f) {
        {
            let _e155: vec3<f32> = n_3;
            let _e158: vec3<f32> = n_3;
            let _e163: vec3<f32> = n_3;
            if (_e163.x >= 0f) {
                local_18 = 1f;
            } else {
                local_18 = -1f;
            }
            let _e171: f32 = local_18;
            let _e172: vec3<f32> = n_3;
            if (_e172.y >= 0f) {
                local_19 = 1f;
            } else {
                local_19 = -1f;
            }
            let _e180: f32 = local_19;
            let _e182: vec2<f32> = ((vec2(1f) - abs(_e158.yx)) * vec2<f32>(_e171, _e180));
            n_3.x = _e182.x;
            n_3.y = _e182.y;
        }
    }
    let _e187: vec3<f32> = n_3;
    return normalize(_e187);
}

fn sampleFace(comp_14: i32, x_4: vec3<f32>, old: bool) -> f32 {
    var comp_15: i32;
    var x_5: vec3<f32>;
    var old_1: bool;
    var d_5: vec3<i32>;
    var g: vec3<f32>;
    var b: vec3<i32>;
    var f_6: vec3<f32>;
    var base: i32;
    var r: f32 = 0f;
    var k: i32 = 0i;
    var j: i32;
    var i_5: i32;
    var c_8: vec3<i32>;
    var local_20: f32;
    var local_21: f32;
    var local_22: f32;
    var w: f32;
    var idx: i32;
    var local_23: f32;

    comp_15 = comp_14;
    x_5 = x_4;
    old_1 = old;
    let _e141: i32 = comp_15;
    let _e142: vec3<i32> = faceDims(_e141);
    d_5 = _e142;
    let _e144: vec3<f32> = x_5;
    let _e145: i32 = comp_15;
    let _e146: vec3<f32> = faceOffset(_e145);
    let _e150: vec3<i32> = d_5;
    g = clamp((_e144 - _e146), vec3(0f), vec3<f32>((_e150 - vec3(1i))));
    let _e157: vec3<f32> = g;
    let _e160: vec3<i32> = d_5;
    b = min(vec3<i32>(floor(_e157)), max((_e160 - vec3(2i)), vec3(0i)));
    let _e169: vec3<f32> = g;
    let _e170: vec3<i32> = b;
    f_6 = (_e169 - vec3<f32>(_e170));
    let _e174: i32 = comp_15;
    let _e175: i32 = faceBase(_e174);
    base = _e175;
    loop {
        let _e181: i32 = k;
        if !((_e181 < 2i)) {
            break;
        }
        {
            j = 0i;
            loop {
                let _e190: i32 = j;
                if !((_e190 < 2i)) {
                    break;
                }
                {
                    i_5 = 0i;
                    loop {
                        let _e199: i32 = i_5;
                        if !((_e199 < 2i)) {
                            break;
                        }
                        {
                            let _e206: vec3<i32> = b;
                            let _e207: i32 = i_5;
                            let _e208: i32 = j;
                            let _e209: i32 = k;
                            c_8 = (_e206 + vec3<i32>(_e207, _e208, _e209));
                            let _e213: i32 = i_5;
                            if (_e213 == 1i) {
                                let _e216: vec3<f32> = f_6;
                                local_20 = _e216.x;
                            } else {
                                let _e219: vec3<f32> = f_6;
                                local_20 = (1f - _e219.x);
                            }
                            let _e223: f32 = local_20;
                            let _e224: i32 = j;
                            if (_e224 == 1i) {
                                let _e227: vec3<f32> = f_6;
                                local_21 = _e227.y;
                            } else {
                                let _e230: vec3<f32> = f_6;
                                local_21 = (1f - _e230.y);
                            }
                            let _e234: f32 = local_21;
                            let _e236: i32 = k;
                            if (_e236 == 1i) {
                                let _e239: vec3<f32> = f_6;
                                local_22 = _e239.z;
                            } else {
                                let _e242: vec3<f32> = f_6;
                                local_22 = (1f - _e242.z);
                            }
                            let _e246: f32 = local_22;
                            w = ((_e223 * _e234) * _e246);
                            let _e249: i32 = base;
                            let _e250: vec3<i32> = c_8;
                            let _e253: vec3<i32> = d_5;
                            let _e255: vec3<i32> = c_8;
                            let _e257: vec3<i32> = d_5;
                            let _e259: vec3<i32> = c_8;
                            idx = ((_e249 + _e250.x) + (_e253.x * (_e255.y + (_e257.y * _e259.z))));
                            let _e266: f32 = r;
                            let _e267: f32 = w;
                            let _e268: bool = old_1;
                            if _e268 {
                                let _e269: i32 = idx;
                                let _e271: f32 = global_4.velOld[_e269];
                                local_23 = _e271;
                            } else {
                                let _e272: i32 = idx;
                                let _e274: f32 = global_3.vel[_e272];
                                local_23 = _e274;
                            }
                            let _e276: f32 = local_23;
                            r = (_e266 + (_e267 * _e276));
                        }
                        continuing {
                            let _e203: i32 = i_5;
                            i_5 = (_e203 + 1i);
                        }
                    }
                }
                continuing {
                    let _e194: i32 = j;
                    j = (_e194 + 1i);
                }
            }
        }
        continuing {
            let _e185: i32 = k;
            k = (_e185 + 1i);
        }
    }
    let _e279: f32 = r;
    return _e279;
}

fn sampleVel(x_6: vec3<f32>) -> vec3<f32> {
    var x_7: vec3<f32>;

    x_7 = x_6;
    let _e138: vec3<f32> = x_7;
    let _e140: f32 = sampleFace(0i, _e138, false);
    let _e142: vec3<f32> = x_7;
    let _e144: f32 = sampleFace(1i, _e142, false);
    let _e146: vec3<f32> = x_7;
    let _e148: f32 = sampleFace(2i, _e146, false);
    return vec3<f32>(_e140, _e144, _e148);
}

fn sampleVelOld(x_8: vec3<f32>) -> vec3<f32> {
    var x_9: vec3<f32>;

    x_9 = x_8;
    let _e138: vec3<f32> = x_9;
    let _e140: f32 = sampleFace(0i, _e138, true);
    let _e142: vec3<f32> = x_9;
    let _e144: f32 = sampleFace(1i, _e142, true);
    let _e146: vec3<f32> = x_9;
    let _e148: f32 = sampleFace(2i, _e146, true);
    return vec3<f32>(_e140, _e144, _e148);
}

fn solidAt(p_7: vec3<f32>) -> bool {
    var p_8: vec3<f32>;
    var c_9: vec3<i32>;

    p_8 = p_7;
    let _e137: vec3<f32> = p_8;
    c_9 = vec3<i32>(floor(_e137));
    let _e141: vec3<i32> = c_9;
    let _e142: bool = inGrid(_e141);
    let _e143: vec3<i32> = c_9;
    let _e144: i32 = cellIndex(_e143);
    let _e146: u32 = global_6.staticSolid[_e144];
    return (_e142 && (_e146 != 0u));
}

fn countAt(c_10: vec3<i32>) -> i32 {
    var c_11: vec3<i32>;
    var local_24: i32;

    c_11 = c_10;
    let _e137: vec3<i32> = c_11;
    let _e138: bool = inBox(_e137);
    if _e138 {
        let _e139: vec3<i32> = c_11;
        let _e140: i32 = cellIndex(_e139);
        let _e142: i32 = global_10.cellCount[_e140];
        local_24 = _e142;
    } else {
        local_24 = 0i;
    }
    let _e145: i32 = local_24;
    return _e145;
}

fn waterFilm(x_10: vec3<f32>, v_8: ptr<function, vec3<f32>>, dx: ptr<function, vec3<f32>>, dryness: ptr<function, f32>) -> bool {
    var x_11: vec3<f32>;
    var c_12: vec3<i32>;
    var n27_: i32 = 0i;
    var column: i32 = 0i;
    var k_1: i32 = 0i;
    var o: vec3<i32>;
    var n_4: i32;
    var local_25: i32;
    var depth: f32;
    var thin: f32;
    var speed: f32;
    var groundAhead: bool;
    var damp: f32;
    var res: f32;

    x_11 = x_10;
    let _e140: vec3<f32> = x_11;
    c_12 = vec3<i32>(floor(_e140));
    loop {
        let _e150: i32 = k_1;
        if !((_e150 < 27i)) {
            break;
        }
        {
            let _e157: i32 = k_1;
            let _e160: i32 = k_1;
            let _e165: i32 = k_1;
            o = (vec3<i32>((_e157 % 3i), ((_e160 / 3i) % 3i), (_e165 / 9i)) - vec3(1i));
            let _e173: vec3<i32> = c_12;
            let _e174: vec3<i32> = o;
            let _e176: i32 = countAt((_e173 + _e174));
            n_4 = _e176;
            let _e178: i32 = n27_;
            let _e179: i32 = n_4;
            n27_ = (_e178 + _e179);
            let _e181: i32 = column;
            let _e182: vec3<i32> = o;
            if (_e182.y >= 0i) {
                let _e186: i32 = n_4;
                local_25 = _e186;
            } else {
                local_25 = 0i;
            }
            let _e189: i32 = local_25;
            column = (_e181 + _e189);
        }
        continuing {
            let _e154: i32 = k_1;
            k_1 = (_e154 + 1i);
        }
    }
    let _e191: vec3<f32> = x_11;
    let _e197: bool = solidAt((_e191 - vec3<f32>(0f, 1f, 0f)));
    if _e197 {
        {
            let _e198: i32 = column;
            let _e202: vec4<f32> = G.simA;
            depth = (f32(_e198) / (9f * _e202.y));
            let _e208: f32 = depth;
            let _e210: vec4<f32> = G.matB;
            thin = clamp((1f - (_e208 / max(_e210.w, 0.001f))), 0f, 1f);
            let _e220: vec3<f32> = (*v_8);
            speed = length(_e220.xz);
            let _e224: f32 = speed;
            let _e227: vec3<f32> = x_11;
            let _e228: vec3<f32> = (*v_8);
            let _e230: f32 = speed;
            let _e234: vec3<f32> = (*v_8);
            let _e236: f32 = speed;
            let _e240: bool = solidAt((_e227 + vec3<f32>((_e228.x / _e230), -1f, (_e234.z / _e236))));
            groundAhead = ((_e224 < 0.001f) || _e240);
            let _e243: f32 = thin;
            let _e246: bool = groundAhead;
            if ((_e243 > 0f) && _e246) {
                {
                    let _e249: vec4<f32> = G.matB;
                    let _e252: f32 = thin;
                    let _e255: vec4<f32> = G.gravityDt;
                    damp = exp(((-(_e249.x) * _e252) * _e255.w));
                    let _e260: vec3<f32> = (*v_8);
                    let _e262: vec3<f32> = (*v_8);
                    let _e264: f32 = damp;
                    let _e265: vec2<f32> = (_e262.xz * _e264);
                    (*v_8).x = _e265.x;
                    (*v_8).z = _e265.y;
                    let _e270: vec3<f32> = (*dx);
                    let _e272: vec3<f32> = (*dx);
                    let _e274: f32 = damp;
                    let _e275: vec2<f32> = (_e272.xz * _e274);
                    (*dx).x = _e275.x;
                    (*dx).z = _e275.y;
                }
            }
        }
    }
    let _e281: vec4<f32> = G.camGrid;
    res = _e281.w;
    let _e284: i32 = n27_;
    let _e286: vec4<f32> = G.matB;
    let _e290: vec3<f32> = (*v_8);
    let _e293: f32 = res;
    if ((_e284 < i32(_e286.z)) && (length(_e290) < (1.5f * _e293))) {
        {
            let _e297: f32 = (*dryness);
            let _e299: vec4<f32> = G.gravityDt;
            let _e302: vec4<f32> = G.matB;
            (*dryness) = (_e297 + (_e299.w / max(_e302.y, 0.001f)));
        }
    } else {
        {
            (*dryness) = 0f;
        }
    }
    let _e309: f32 = (*dryness);
    return (_e309 < 1f);
}

fn slimeAdhere(x_12: vec3<f32>, v_9: ptr<function, vec3<f32>>, dx_1: ptr<function, vec3<f32>>) {
    var x_13: vec3<f32>;
    var k_2: i32 = 0i;
    var local_26: array<vec3<f32>, 6> = SIDES;
    var damp_1: f32;

    x_13 = x_12;
    loop {
        let _e170: i32 = k_2;
        if !((_e170 < 6i)) {
            break;
        }
        {
            let _e177: vec3<f32> = x_13;
            let _e178: i32 = k_2;
            let _e182: vec3<f32> = local_26[_e178];
            let _e184: bool = solidAt((_e177 + _e182));
            if _e184 {
                {
                    let _e186: vec4<f32> = G.matA;
                    let _e190: vec4<f32> = G.gravityDt;
                    damp_1 = exp((-(_e186.y) * _e190.w));
                    let _e195: vec3<f32> = (*v_9);
                    let _e196: f32 = damp_1;
                    (*v_9) = (_e195 * _e196);
                    let _e198: vec3<f32> = (*dx_1);
                    let _e199: f32 = damp_1;
                    (*dx_1) = (_e198 * _e199);
                    return;
                }
            }
        }
        continuing {
            let _e174: i32 = k_2;
            k_2 = (_e174 + 1i);
        }
    }
    return;
}

fn slimeSupported(x_14: vec3<f32>) -> bool {
    var x_15: vec3<f32>;
    var c_13: vec3<i32>;
    var k_3: i32 = 1i;
    var b_1: vec3<i32>;

    x_15 = x_14;
    let _e137: vec3<f32> = x_15;
    c_13 = vec3<i32>(floor(_e137));
    loop {
        let _e143: i32 = k_3;
        if !((_e143 <= 32i)) {
            break;
        }
        {
            let _e150: vec3<i32> = c_13;
            let _e152: i32 = k_3;
            b_1 = (_e150 - vec3<i32>(0i, _e152, 0i));
            let _e157: vec3<i32> = b_1;
            let _e158: bool = inGrid(_e157);
            if !(_e158) {
                {
                    return false;
                }
            }
            let _e161: vec3<i32> = b_1;
            let _e162: i32 = cellIndex(_e161);
            let _e164: u32 = global_6.staticSolid[_e162];
            if (_e164 != 0u) {
                {
                    return true;
                }
            }
            let _e168: vec3<i32> = b_1;
            let _e169: i32 = countAt(_e168);
            if (_e169 == 0i) {
                {
                    return false;
                }
            }
        }
        continuing {
            let _e147: i32 = k_3;
            k_3 = (_e147 + 1i);
        }
    }
    return true;
}

fn collideStatic(x_16: vec3<f32>, xn: vec3<f32>, v_10: ptr<function, vec3<f32>>) -> vec3<f32> {
    var x_17: vec3<f32>;
    var xn_1: vec3<f32>;
    var c_14: vec3<i32>;
    var k_4: i32 = 0i;
    var local_27: array<vec3<i32>, 6> = OUT;
    var nc: vec3<i32>;
    var local_28: array<vec3<i32>, 6> = OUT;
    var r_1: vec3<f32>;
    var k_5: i32 = 0i;
    var local_29: array<i32, 3> = ORDER;
    var a: i32;
    var t_4: vec3<f32>;
    var local_30: f32;
    var edge: f32;

    x_17 = x_16;
    xn_1 = xn;
    let _e140: vec3<f32> = x_17;
    let _e141: bool = solidAt(_e140);
    if _e141 {
        {
            let _e142: vec3<f32> = x_17;
            c_14 = vec3<i32>(floor(_e142));
            loop {
                let _e177: i32 = k_4;
                if !((_e177 < 6i)) {
                    break;
                }
                {
                    let _e184: vec3<i32> = c_14;
                    let _e185: i32 = k_4;
                    let _e189: vec3<i32> = local_27[_e185];
                    nc = (_e184 + _e189);
                    let _e192: vec3<i32> = nc;
                    let _e193: bool = inGrid(_e192);
                    let _e195: vec3<i32> = nc;
                    let _e196: i32 = cellIndex(_e195);
                    let _e198: u32 = global_6.staticSolid[_e196];
                    if (!(_e193) || (_e198 == 0u)) {
                        {
                            let _e202: i32 = k_4;
                            let _e206: vec3<i32> = local_28[_e202];
                            (*v_10) = (vec3<f32>(_e206) * 2f);
                            let _e210: vec3<i32> = nc;
                            return (vec3<f32>(_e210) + vec3(0.5f));
                        }
                    }
                }
                continuing {
                    let _e181: i32 = k_4;
                    k_4 = (_e181 + 1i);
                }
            }
            let _e215: vec3<f32> = x_17;
            return _e215;
        }
    }
    let _e216: vec3<f32> = x_17;
    r_1 = _e216;
    loop {
        let _e225: i32 = k_5;
        if !((_e225 < 3i)) {
            break;
        }
        {
            let _e232: i32 = k_5;
            let _e236: i32 = local_29[_e232];
            a = _e236;
            let _e238: vec3<f32> = r_1;
            t_4 = _e238;
            let _e240: i32 = a;
            let _e242: i32 = a;
            let _e244: f32 = xn_1[_e242];
            t_4[_e240] = _e244;
            let _e245: vec3<f32> = t_4;
            let _e246: bool = solidAt(_e245);
            if !(_e246) {
                {
                    let _e248: vec3<f32> = t_4;
                    r_1 = _e248;
                }
            } else {
                {
                    let _e249: i32 = a;
                    let _e251: f32 = xn_1[_e249];
                    let _e252: i32 = a;
                    let _e254: f32 = r_1[_e252];
                    if (_e251 > _e254) {
                        let _e256: i32 = a;
                        let _e258: f32 = r_1[_e256];
                        local_30 = (floor(_e258) + 0.999f);
                    } else {
                        let _e262: i32 = a;
                        let _e264: f32 = r_1[_e262];
                        local_30 = (floor(_e264) + 0.001f);
                    }
                    let _e269: f32 = local_30;
                    edge = _e269;
                    let _e271: i32 = a;
                    let _e273: f32 = edge;
                    t_4[_e271] = _e273;
                    let _e274: vec3<f32> = t_4;
                    let _e275: bool = solidAt(_e274);
                    if !(_e275) {
                        {
                            let _e277: vec3<f32> = t_4;
                            r_1 = _e277;
                        }
                    }
                    let _e278: i32 = a;
                    (*v_10)[_e278] = 0f;
                }
            }
        }
        continuing {
            let _e229: i32 = k_5;
            k_5 = (_e229 + 1i);
        }
    }
    let _e281: vec3<f32> = r_1;
    return _e281;
}

fn collideEntities(x_18: vec3<f32>, v_11: ptr<function, vec3<f32>>) -> vec3<f32> {
    var x_19: vec3<f32>;
    var e_9: i32 = 0i;
    var lo_2: vec3<f32>;
    var hi_2: vec3<f32>;
    var dLo: vec3<f32>;
    var dHi: vec3<f32>;
    var ve: vec3<f32>;
    var axis: i32;
    var best: f32;
    var dir: f32;
    var a_1: i32;
    var local_31: f32;

    x_19 = x_18;
    loop {
        let _e140: i32 = e_9;
        let _e141: i32 = numEntities();
        if !((_e140 < _e141)) {
            break;
        }
        {
            let _e147: i32 = e_9;
            let _e148: vec3<f32> = entMin(_e147);
            lo_2 = _e148;
            let _e150: i32 = e_9;
            let _e151: vec3<f32> = entMax(_e150);
            hi_2 = _e151;
            let _e153: vec3<f32> = x_19;
            let _e154: vec3<f32> = lo_2;
            let _e157: vec3<f32> = x_19;
            let _e158: vec3<f32> = hi_2;
            if (any((_e153 < _e154)) || any((_e157 > _e158))) {
                {
                    continue;
                }
            }
            let _e162: vec3<f32> = x_19;
            let _e163: vec3<f32> = lo_2;
            dLo = (_e162 - _e163);
            let _e166: vec3<f32> = hi_2;
            let _e167: vec3<f32> = x_19;
            dHi = (_e166 - _e167);
            let _e170: i32 = e_9;
            let _e171: vec3<f32> = entVel(_e170);
            ve = _e171;
            axis = 0i;
            best = 1000000000f;
            dir = 1f;
            a_1 = 0i;
            loop {
                let _e181: i32 = a_1;
                if !((_e181 < 3i)) {
                    break;
                }
                {
                    let _e188: i32 = a_1;
                    let _e190: f32 = dLo[_e188];
                    let _e191: f32 = best;
                    if (_e190 < _e191) {
                        {
                            let _e193: i32 = a_1;
                            let _e195: f32 = dLo[_e193];
                            best = _e195;
                            let _e196: i32 = a_1;
                            axis = _e196;
                            dir = -1f;
                        }
                    }
                    let _e199: i32 = a_1;
                    let _e201: f32 = dHi[_e199];
                    let _e202: f32 = best;
                    if (_e201 < _e202) {
                        {
                            let _e204: i32 = a_1;
                            let _e206: f32 = dHi[_e204];
                            best = _e206;
                            let _e207: i32 = a_1;
                            axis = _e207;
                            dir = 1f;
                        }
                    }
                }
                continuing {
                    let _e185: i32 = a_1;
                    a_1 = (_e185 + 1i);
                }
            }
            let _e209: i32 = axis;
            let _e211: f32 = dir;
            if (_e211 > 0f) {
                let _e214: i32 = axis;
                let _e216: f32 = hi_2[_e214];
                local_31 = (_e216 + 0.01f);
            } else {
                let _e219: i32 = axis;
                let _e221: f32 = lo_2[_e219];
                local_31 = (_e221 - 0.01f);
            }
            let _e225: f32 = local_31;
            x_19[_e209] = _e225;
            let _e226: i32 = axis;
            let _e228: f32 = dir;
            let _e229: f32 = dir;
            let _e230: i32 = axis;
            let _e232: f32 = (*v_11)[_e230];
            let _e234: f32 = dir;
            let _e235: i32 = axis;
            let _e237: f32 = ve[_e235];
            (*v_11)[_e226] = (_e228 * max((_e229 * _e232), (_e234 * _e237)));
            let _e241: bool = isSlime();
            if _e241 {
                {
                    let _e242: vec3<f32> = (*v_11);
                    let _e243: vec3<f32> = ve;
                    let _e245: vec4<f32> = G.matA;
                    (*v_11) = mix(_e242, _e243, vec3(_e245.z));
                }
            }
        }
        continuing {
            let _e144: i32 = e_9;
            e_9 = (_e144 + 1i);
        }
    }
    let _e249: vec3<f32> = x_19;
    return _e249;
}

fn emitWhitewater(id: u32, x_20: vec3<f32>, v_12: vec3<f32>) {
    var id_1: u32;
    var x_21: vec3<f32>;
    var v_13: vec3<f32>;
    var c_15: vec3<i32>;
    var pot: vec2<f32>;
    var speed_1: f32;
    var energy: f32;
    var iTA: f32;
    var iWC: f32;
    var iK: f32;
    var amount: f32;
    var seed: u32;
    var local_32: i32;
    var count: i32;
    var k_6: i32 = 0i;
    var o_1: u32;
    var offset: vec3<f32>;
    var life: f32;
    var jitter: vec3<f32>;

    id_1 = id;
    x_21 = x_20;
    v_13 = v_12;
    let _e141: vec3<f32> = x_21;
    c_15 = vec3<i32>(floor(_e141));
    let _e145: vec3<i32> = c_15;
    let _e146: bool = inBox(_e145);
    if !(_e146) {
        {
            return;
        }
    }
    let _e148: vec3<i32> = c_15;
    let _e149: i32 = cellIndex(_e148);
    let _e151: vec2<f32> = global_7.potential[_e149];
    pot = _e151;
    let _e153: vec3<f32> = v_13;
    let _e156: vec4<f32> = G.simB;
    speed_1 = (length(_e153) * _e156.y);
    let _e161: f32 = speed_1;
    let _e163: f32 = speed_1;
    energy = ((0.5f * _e161) * _e163);
    let _e166: vec2<f32> = pot;
    let _e169: vec4<f32> = G.wwB;
    let _e172: vec4<f32> = G.wwB;
    let _e174: f32 = clampPhi(_e166.x, _e169.x, _e172.y);
    iTA = _e174;
    let _e176: vec2<f32> = pot;
    let _e179: vec4<f32> = G.simB;
    let _e183: vec4<f32> = G.wwB;
    let _e186: vec4<f32> = G.wwB;
    let _e188: f32 = clampPhi((_e176.y * _e179.y), _e183.z, _e186.w);
    iWC = _e188;
    let _e190: f32 = energy;
    let _e192: vec4<f32> = G.wwA;
    let _e195: vec4<f32> = G.wwA;
    let _e197: f32 = clampPhi(_e190, _e192.z, _e195.w);
    iK = _e197;
    let _e199: f32 = iK;
    let _e201: vec4<f32> = G.wwA;
    let _e203: f32 = iTA;
    let _e206: vec4<f32> = G.wwA;
    let _e208: f32 = iWC;
    let _e213: vec4<f32> = G.gravityDt;
    amount = ((_e199 * ((_e201.x * _e203) + (_e206.y * _e208))) * _e213.w);
    let _e217: f32 = amount;
    let _e220: vec3<i32> = c_15;
    let _e221: i32 = cellIndex(_e220);
    let _e223: i32 = global_9.wwCount[_e221];
    let _e226: vec4<i32> = G.flags;
    amount = (_e217 * max(0f, (1f - (f32(_e223) / f32(max(_e226.w, 1i))))));
    let _e235: f32 = amount;
    if (_e235 <= 0f) {
        {
            return;
        }
    }
    let _e238: u32 = id_1;
    let _e242: vec4<i32> = pc.a;
    let _e246: u32 = hash(((_e238 * 1664525u) + u32(_e242.w)));
    seed = _e246;
    let _e248: f32 = amount;
    let _e252: f32 = rand((&seed));
    let _e253: f32 = amount;
    if (_e252 < fract(_e253)) {
        local_32 = 1i;
    } else {
        local_32 = 0i;
    }
    let _e259: i32 = local_32;
    count = (i32(_e248) + _e259);
    let _e262: i32 = count;
    let _e264: vec4<f32> = G.wwD;
    count = min(_e262, i32(_e264.w));
    loop {
        let _e270: i32 = k_6;
        let _e271: i32 = count;
        if !((_e270 < _e271)) {
            break;
        }
        {
            let _e278: vec4<i32> = pc.b;
            let _e284: vec4<i32> = pc.b;
            let _e287: u32 = atomicAdd((&global_2.counters[_e284.x]), 1u);
            o_1 = _e287;
            let _e289: u32 = o_1;
            let _e291: vec4<i32> = G.caps;
            if (_e289 >= u32(_e291.y)) {
                {
                    return;
                }
            }
            let _e297: vec3<f32> = randInSphere((&seed));
            offset = (_e297 * 0.6f);
            let _e302: vec4<f32> = G.wwC;
            let _e305: vec4<f32> = G.wwC;
            let _e309: f32 = rand((&seed));
            life = mix(_e302.x, _e305.y, _e309);
            let _e314: vec3<f32> = randInSphere((&seed));
            let _e317: vec3<f32> = v_13;
            jitter = ((_e314 * 0.15f) * length(_e317));
            let _e321: u32 = o_1;
            let _e323: vec3<f32> = x_21;
            let _e324: vec3<f32> = offset;
            let _e325: vec3<f32> = (_e323 + _e324);
            let _e326: f32 = life;
            let _e331: vec3<f32> = v_13;
            let _e332: vec3<f32> = jitter;
            let _e333: vec3<f32> = (_e331 + _e332);
            global_8.wwDst[_e321] = Particle(vec4<f32>(_e325.x, _e325.y, _e325.z, _e326), vec4<f32>(_e333.x, _e333.y, _e333.z, 1f));
        }
        continuing {
            let _e274: i32 = k_6;
            k_6 = (_e274 + 1i);
        }
    }
    return;
}

fn main_1() {
    var i_6: u32;
    var p_9: Particle;
    var x_22: vec3<f32>;
    var v_14: vec3<f32>;
    var tag: f32;
    var rest: f32 = 0f;
    var maxSpeed: f32;
    var gridded: bool;
    var dx_2: vec3<f32>;
    var uNew: vec3<f32>;
    var uOld: vec3<f32>;
    var squeezed: bool;
    var frozen: bool;
    var local_33: bool;
    var holding: bool;
    var local_34: f32;
    var s: f32;
    var dl: f32;
    var maxStep: f32;
    var xn_2: vec3<f32>;
    var killMargin: f32;
    var groupTotal: u32;
    var prefix: u32;
    var groupMax: f32;
    var base_1: u32 = 0u;
    var o_2: u32;
    var cell: vec3<u32>;
    var lo_3: vec3<u32>;
    var hi_3: vec3<u32>;

    let _e137: vec3<u32> = gl_GlobalInvocationID_1;
    let _e139: vec3<u32> = gl_GlobalInvocationID_1;
    let _e141: vec3<u32> = gl_NumWorkGroups_1;
    i_6 = (_e137.x + ((_e139.y * _e141.x) * 256u));
    let _e148: u32 = i_6;
    let _e150: vec4<i32> = pc.a;
    let _e153: u32 = atomicLoad((&global_2.counters[_e150.x]));
    if (_e148 >= _e153) {
        {
            return;
        }
    }
    let _e155: u32 = i_6;
    let _e157: Particle = global.src[_e155];
    p_9 = _e157;
    let _e160: vec4<f32> = p_9.pos;
    if (_e160.w < 0f) {
        {
            return;
        }
    }
    let _e165: vec4<f32> = p_9.pos;
    x_22 = _e165.xyz;
    let _e169: vec4<f32> = p_9.vel;
    v_14 = _e169.xyz;
    let _e173: vec4<f32> = p_9.pos;
    tag = _e173.w;
    let _e179: vec4<f32> = G.simB;
    maxSpeed = _e179.x;
    let _e182: vec3<f32> = x_22;
    let _e183: bool = inInnerBox(_e182);
    gridded = _e183;
    let _e186: bool = gridded;
    if _e186 {
        {
            let _e187: vec3<f32> = x_22;
            let _e188: vec3<f32> = sampleVel(_e187);
            uNew = _e188;
            let _e190: vec3<f32> = x_22;
            let _e191: vec3<f32> = sampleVelOld(_e190);
            uOld = _e191;
            let _e193: vec3<f32> = uNew;
            let _e194: vec3<f32> = v_14;
            let _e195: vec3<f32> = uNew;
            let _e196: vec3<f32> = uOld;
            let _e200: vec4<f32> = G.simA;
            v_14 = mix(_e193, (_e194 + (_e195 - _e196)), vec3(_e200.x));
            let _e205: vec4<f32> = G.gravityDt;
            let _e207: vec3<f32> = x_22;
            let _e210: vec4<f32> = G.gravityDt;
            let _e213: vec3<f32> = uNew;
            let _e216: vec3<f32> = sampleVel((_e207 + ((0.5f * _e210.w) * _e213)));
            dx_2 = (_e205.w * _e216);
            let _e218: vec3<f32> = x_22;
            let _e225: bool = waterFilm(_e218, (&v_14), (&dx_2), (&tag));
            if !(_e225) {
                {
                    return;
                }
            }
            let _e227: bool = isSlime();
            let _e228: vec3<f32> = x_22;
            let _e231: i32 = countAt(vec3<i32>(floor(_e228)));
            let _e234: vec4<f32> = G.simA;
            squeezed = (_e227 && (f32(_e231) > (_e234.y * 1.5f)));
            let _e241: bool = isSlime();
            let _e242: bool = squeezed;
            if (_e241 && _e242) {
                {
                    rest = 0f;
                }
            } else {
                let _e245: bool = isSlime();
                if _e245 {
                    {
                        let _e246: vec3<f32> = x_22;
                        slimeAdhere(_e246, (&v_14), (&dx_2));
                        let _e252: vec4<f32> = p_9.vel;
                        rest = _e252.w;
                        let _e254: f32 = rest;
                        let _e256: vec4<f32> = G.matC;
                        frozen = (_e254 >= _e256.y);
                        let _e260: bool = frozen;
                        if _e260 {
                            let _e261: vec3<f32> = uNew;
                            let _e264: vec4<f32> = G.matC;
                            local_33 = (length(_e261) <= _e264.z);
                        } else {
                            let _e267: vec3<f32> = v_14;
                            let _e270: vec4<f32> = G.matC;
                            local_33 = (length(_e267) < _e270.x);
                        }
                        let _e274: bool = local_33;
                        holding = _e274;
                        let _e276: bool = holding;
                        let _e277: vec3<f32> = x_22;
                        let _e278: bool = slimeSupported(_e277);
                        if (_e276 && _e278) {
                            let _e280: f32 = rest;
                            let _e282: vec4<f32> = G.gravityDt;
                            local_34 = (_e280 + _e282.w);
                        } else {
                            local_34 = 0f;
                        }
                        let _e287: f32 = local_34;
                        rest = _e287;
                        let _e288: f32 = rest;
                        let _e290: vec4<f32> = G.matC;
                        if (_e288 >= _e290.y) {
                            {
                                let _e294: vec4<f32> = G.matC;
                                rest = _e294.y;
                                v_14 = vec3(0f);
                                dx_2 = vec3(0f);
                            }
                        }
                    }
                }
            }
        }
    } else {
        {
            let _e300: vec3<f32> = v_14;
            let _e302: vec4<f32> = G.gravityDt;
            let _e305: vec4<f32> = G.gravityDt;
            v_14 = (_e300 + (_e302.xyz * _e305.w));
            let _e310: vec4<f32> = G.gravityDt;
            let _e312: vec3<f32> = v_14;
            dx_2 = (_e310.w * _e312);
        }
    }
    let _e314: vec3<f32> = v_14;
    s = length(_e314);
    let _e317: f32 = s;
    let _e318: f32 = maxSpeed;
    if (_e317 > _e318) {
        {
            let _e320: vec3<f32> = v_14;
            let _e321: f32 = maxSpeed;
            let _e322: f32 = s;
            v_14 = (_e320 * (_e321 / _e322));
        }
    }
    let _e325: vec3<f32> = dx_2;
    dl = length(_e325);
    let _e328: f32 = maxSpeed;
    let _e330: vec4<f32> = G.gravityDt;
    maxStep = (_e328 * _e330.w);
    let _e334: f32 = dl;
    let _e335: f32 = maxStep;
    if (_e334 > _e335) {
        {
            let _e337: vec3<f32> = dx_2;
            let _e338: f32 = maxStep;
            let _e339: f32 = dl;
            dx_2 = (_e337 * (_e338 / _e339));
        }
    }
    let _e342: vec3<f32> = x_22;
    let _e343: vec3<f32> = x_22;
    let _e344: vec3<f32> = dx_2;
    let _e348: vec3<f32> = collideStatic(_e342, (_e343 + _e344), (&v_14));
    xn_2 = _e348;
    let _e350: vec3<f32> = xn_2;
    let _e353: vec3<f32> = collideEntities(_e350, (&v_14));
    xn_2 = _e353;
    let _e354: vec3<f32> = xn_2;
    let _e355: vec3<bool> = wateryIsNan(_e354);
    let _e357: vec3<f32> = xn_2;
    let _e358: vec3<bool> = wateryIsInf(_e357);
    let _e361: vec3<f32> = v_14;
    let _e362: vec3<bool> = wateryIsNan(_e361);
    if ((any(_e355) || any(_e358)) || any(_e362)) {
        {
            return;
        }
    }
    let _e366: vec4<f32> = G.killInfo;
    killMargin = _e366.y;
    let _e369: vec3<f32> = xn_2;
    let _e370: f32 = killMargin;
    let _e375: vec3<f32> = xn_2;
    let _e377: vec4<i32> = G.dims;
    let _e380: vec4<i32> = G.dims;
    let _e383: vec4<i32> = G.dims;
    let _e389: f32 = killMargin;
    let _e395: vec3<f32> = xn_2;
    let _e398: vec4<f32> = G.killInfo;
    if ((any((_e369 < vec3(-(_e370)))) || any((_e375 >= (vec3<f32>(f32(_e377.x), f32(_e380.y), f32(_e383.z)) + vec3(_e389))))) || (_e395.y < _e398.x)) {
        {
            return;
        }
    }
    let _e403: u32 = subgroupAdd(1u);
    groupTotal = _e403;
    let _e406: u32 = subgroupExclusiveAdd(1u);
    prefix = _e406;
    let _e408: vec3<f32> = v_14;
    let _e410: f32 = subgroupMax(length(_e408));
    groupMax = _e410;
    let _e415: u32 = gl_SubgroupInvocationID_1;
    let _e416: u32 = gl_SubgroupInvocationID_1;
    let _e417: u32 = subgroupBroadcastFirst(_e416);
    if (_e415 == _e417) {
        {
            let _e420: vec4<i32> = pc.a;
            let _e424: u32 = groupTotal;
            let _e426: vec4<i32> = pc.a;
            let _e429: u32 = atomicAdd((&global_2.counters[_e426.y]), _e424);
            base_1 = _e429;
            let _e433: f32 = groupMax;
            let _e437: u32 = atomicMax((&global_2.counters[6i]), bitcast<u32>(_e433));
        }
    }
    let _e438: u32 = base_1;
    let _e439: u32 = subgroupBroadcastFirst(_e438);
    let _e440: u32 = prefix;
    o_2 = (_e439 + _e440);
    let _e443: u32 = o_2;
    let _e445: vec4<i32> = G.caps;
    if (_e443 >= u32(_e445.x)) {
        {
            return;
        }
    }
    let _e449: u32 = o_2;
    let _e451: vec3<f32> = xn_2;
    let _e452: f32 = tag;
    let _e457: vec3<f32> = v_14;
    let _e458: f32 = rest;
    global_1.dst[_e449] = Particle(vec4<f32>(_e451.x, _e451.y, _e451.z, _e452), vec4<f32>(_e457.x, _e457.y, _e457.z, _e458));
    let _e464: vec3<f32> = xn_2;
    cell = vec3<u32>((vec3<i32>(floor(_e464)) + vec3(1048576i)));
    let _e472: vec3<u32> = cell;
    let _e474: u32 = subgroupMin(_e472.x);
    let _e475: vec3<u32> = cell;
    let _e477: u32 = subgroupMin(_e475.y);
    let _e478: vec3<u32> = cell;
    let _e480: u32 = subgroupMin(_e478.z);
    lo_3 = vec3<u32>(_e474, _e477, _e480);
    let _e483: vec3<u32> = cell;
    let _e485: u32 = subgroupMax(_e483.x);
    let _e486: vec3<u32> = cell;
    let _e488: u32 = subgroupMax(_e486.y);
    let _e489: vec3<u32> = cell;
    let _e491: u32 = subgroupMax(_e489.z);
    hi_3 = vec3<u32>(_e485, _e488, _e491);
    let _e494: u32 = gl_SubgroupInvocationID_1;
    let _e495: u32 = gl_SubgroupInvocationID_1;
    let _e496: u32 = subgroupBroadcastFirst(_e495);
    if (_e494 == _e496) {
        {
            let _e501: vec3<u32> = lo_3;
            let _e505: u32 = atomicMin((&global_2.counters[8i]), _e501.x);
            let _e509: vec3<u32> = lo_3;
            let _e513: u32 = atomicMin((&global_2.counters[9i]), _e509.y);
            let _e517: vec3<u32> = lo_3;
            let _e521: u32 = atomicMin((&global_2.counters[10i]), _e517.z);
            let _e525: vec3<u32> = hi_3;
            let _e529: u32 = atomicMax((&global_2.counters[11i]), _e525.x);
            let _e533: vec3<u32> = hi_3;
            let _e537: u32 = atomicMax((&global_2.counters[12i]), _e533.y);
            let _e541: vec3<u32> = hi_3;
            let _e545: u32 = atomicMax((&global_2.counters[13i]), _e541.z);
        }
    }
    let _e547: vec4<i32> = pc.b;
    let _e551: bool = gridded;
    if ((_e547.y != 0i) && _e551) {
        {
            let _e553: u32 = i_6;
            let _e554: vec3<f32> = xn_2;
            let _e555: vec3<f32> = v_14;
            emitWhitewater(_e553, _e554, _e555);
            return;
        }
    } else {
        return;
    }
}

@compute @workgroup_size(256, 1, 1)
fn main(@builtin(global_invocation_id) gl_GlobalInvocationID: vec3<u32>, @builtin(num_workgroups) gl_NumWorkGroups: vec3<u32>, @builtin(subgroup_invocation_id) gl_SubgroupInvocationID: u32) {
    gl_GlobalInvocationID_1 = gl_GlobalInvocationID;
    gl_NumWorkGroups_1 = gl_NumWorkGroups;
    gl_SubgroupInvocationID_1 = gl_SubgroupInvocationID;
    main_1();
    return;
}
