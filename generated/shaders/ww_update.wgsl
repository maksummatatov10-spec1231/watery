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

struct Count {
    cellCount: array<i32>,
}

struct Static {
    staticSolid: array<u32>,
}

struct WwCount {
    wwCount: array<i32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

struct Counters_1 {
    counters: array<atomic<u32>>,
}

struct WwCount_1 {
    wwCount: array<atomic<i32>>,
}

const FP_SCALE: f32 = 65536f;

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
var<storage> global_4: Count;
@group(0) @binding(6)
var<storage> global_5: Static;
@group(0) @binding(7)
var<storage, read_write> global_6: WwCount_1;
@group(1) @binding(0)
var<uniform> pc: PC;
var<private> gl_GlobalInvocationID_1: vec3<u32>;
var<private> gl_NumWorkGroups_1: vec3<u32>;

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

fn clampPhi(v: f32, lo: f32, hi: f32) -> f32 {
    var v_1: f32;
    var lo_1: f32;
    var hi_1: f32;

    v_1 = v;
    lo_1 = lo;
    hi_1 = hi;
    let _e114: f32 = v_1;
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

fn unpackNormal(v_2: u32, flag_2: ptr<function, bool>) -> vec3<f32> {
    var v_3: u32;
    var e_8: vec2<f32>;
    var n_3: vec3<f32>;
    var local_18: f32;
    var local_19: f32;

    v_3 = v_2;
    let _e111: u32 = v_3;
    (*flag_2) = ((_e111 & 1073741824u) != 0u);
    let _e116: u32 = v_3;
    let _e120: u32 = v_3;
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

    comp_15 = comp_14;
    x_5 = x_4;
    old_1 = old;
    let _e133: i32 = comp_15;
    let _e134: vec3<i32> = faceDims(_e133);
    d_5 = _e134;
    let _e136: vec3<f32> = x_5;
    let _e137: i32 = comp_15;
    let _e138: vec3<f32> = faceOffset(_e137);
    let _e142: vec3<i32> = d_5;
    g = clamp((_e136 - _e138), vec3(0f), vec3<f32>((_e142 - vec3(1i))));
    let _e149: vec3<f32> = g;
    let _e152: vec3<i32> = d_5;
    b = min(vec3<i32>(floor(_e149)), max((_e152 - vec3(2i)), vec3(0i)));
    let _e161: vec3<f32> = g;
    let _e162: vec3<i32> = b;
    f_6 = (_e161 - vec3<f32>(_e162));
    let _e166: i32 = comp_15;
    let _e167: i32 = faceBase(_e166);
    base = _e167;
    loop {
        let _e173: i32 = k;
        if !((_e173 < 2i)) {
            break;
        }
        {
            j = 0i;
            loop {
                let _e182: i32 = j;
                if !((_e182 < 2i)) {
                    break;
                }
                {
                    i_5 = 0i;
                    loop {
                        let _e191: i32 = i_5;
                        if !((_e191 < 2i)) {
                            break;
                        }
                        {
                            let _e198: vec3<i32> = b;
                            let _e199: i32 = i_5;
                            let _e200: i32 = j;
                            let _e201: i32 = k;
                            c_8 = (_e198 + vec3<i32>(_e199, _e200, _e201));
                            let _e205: i32 = i_5;
                            if (_e205 == 1i) {
                                let _e208: vec3<f32> = f_6;
                                local_20 = _e208.x;
                            } else {
                                let _e211: vec3<f32> = f_6;
                                local_20 = (1f - _e211.x);
                            }
                            let _e215: f32 = local_20;
                            let _e216: i32 = j;
                            if (_e216 == 1i) {
                                let _e219: vec3<f32> = f_6;
                                local_21 = _e219.y;
                            } else {
                                let _e222: vec3<f32> = f_6;
                                local_21 = (1f - _e222.y);
                            }
                            let _e226: f32 = local_21;
                            let _e228: i32 = k;
                            if (_e228 == 1i) {
                                let _e231: vec3<f32> = f_6;
                                local_22 = _e231.z;
                            } else {
                                let _e234: vec3<f32> = f_6;
                                local_22 = (1f - _e234.z);
                            }
                            let _e238: f32 = local_22;
                            w = ((_e215 * _e226) * _e238);
                            let _e241: i32 = base;
                            let _e242: vec3<i32> = c_8;
                            let _e245: vec3<i32> = d_5;
                            let _e247: vec3<i32> = c_8;
                            let _e249: vec3<i32> = d_5;
                            let _e251: vec3<i32> = c_8;
                            idx = ((_e241 + _e242.x) + (_e245.x * (_e247.y + (_e249.y * _e251.z))));
                            let _e258: f32 = r;
                            let _e259: f32 = w;
                            let _e260: i32 = idx;
                            let _e262: f32 = global_3.vel[_e260];
                            r = (_e258 + (_e259 * _e262));
                        }
                        continuing {
                            let _e195: i32 = i_5;
                            i_5 = (_e195 + 1i);
                        }
                    }
                }
                continuing {
                    let _e186: i32 = j;
                    j = (_e186 + 1i);
                }
            }
        }
        continuing {
            let _e177: i32 = k;
            k = (_e177 + 1i);
        }
    }
    let _e265: f32 = r;
    return _e265;
}

fn sampleVel(x_6: vec3<f32>) -> vec3<f32> {
    var x_7: vec3<f32>;

    x_7 = x_6;
    let _e130: vec3<f32> = x_7;
    let _e132: f32 = sampleFace(0i, _e130, false);
    let _e134: vec3<f32> = x_7;
    let _e136: f32 = sampleFace(1i, _e134, false);
    let _e138: vec3<f32> = x_7;
    let _e140: f32 = sampleFace(2i, _e138, false);
    return vec3<f32>(_e132, _e136, _e140);
}

fn solidAt(p_7: vec3<f32>) -> bool {
    var p_8: vec3<f32>;
    var c_9: vec3<i32>;

    p_8 = p_7;
    let _e129: vec3<f32> = p_8;
    c_9 = vec3<i32>(floor(_e129));
    let _e133: vec3<i32> = c_9;
    let _e134: bool = inGrid(_e133);
    let _e135: vec3<i32> = c_9;
    let _e136: i32 = cellIndex(_e135);
    let _e138: u32 = global_5.staticSolid[_e136];
    return (_e134 && (_e138 != 0u));
}

fn countAt(c_10: vec3<i32>) -> i32 {
    var c_11: vec3<i32>;
    var local_23: i32;

    c_11 = c_10;
    let _e129: vec3<i32> = c_11;
    let _e130: bool = inBox(_e129);
    if _e130 {
        let _e131: vec3<i32> = c_11;
        let _e132: i32 = cellIndex(_e131);
        let _e134: i32 = global_4.cellCount[_e132];
        local_23 = _e134;
    } else {
        local_23 = 0i;
    }
    let _e137: i32 = local_23;
    return _e137;
}

fn main_1() {
    var i_6: u32;
    var p_9: Particle;
    var x_8: vec3<f32>;
    var life: f32;
    var v_4: vec3<f32>;
    var c_12: vec3<i32>;
    var n_4: i32;
    var above: i32;
    var g_1: vec3<f32>;
    var type_33: f32;
    var uf: vec3<f32>;
    var xn: vec3<f32>;
    var local_24: f32;
    var o: u32;
    var cn: vec3<i32>;

    let _e129: vec3<u32> = gl_GlobalInvocationID_1;
    let _e131: vec3<u32> = gl_GlobalInvocationID_1;
    let _e133: vec3<u32> = gl_NumWorkGroups_1;
    i_6 = (_e129.x + ((_e131.y * _e133.x) * 256u));
    let _e140: u32 = i_6;
    let _e142: vec4<i32> = pc.a;
    let _e145: u32 = atomicLoad((&global_2.counters[_e142.x]));
    if (_e140 >= _e145) {
        {
            return;
        }
    }
    let _e147: u32 = i_6;
    let _e149: Particle = global.src[_e147];
    p_9 = _e149;
    let _e152: vec4<f32> = p_9.pos;
    x_8 = _e152.xyz;
    let _e156: vec4<f32> = p_9.pos;
    life = _e156.w;
    let _e160: vec4<f32> = p_9.vel;
    v_4 = _e160.xyz;
    let _e163: vec3<f32> = x_8;
    c_12 = vec3<i32>(floor(_e163));
    let _e167: vec3<i32> = c_12;
    let _e168: i32 = countAt(_e167);
    let _e169: vec3<i32> = c_12;
    let _e175: i32 = countAt((_e169 + vec3<i32>(1i, 0i, 0i)));
    let _e177: vec3<i32> = c_12;
    let _e183: i32 = countAt((_e177 - vec3<i32>(1i, 0i, 0i)));
    let _e185: vec3<i32> = c_12;
    let _e191: i32 = countAt((_e185 + vec3<i32>(0i, 1i, 0i)));
    let _e193: vec3<i32> = c_12;
    let _e199: i32 = countAt((_e193 - vec3<i32>(0i, 1i, 0i)));
    let _e201: vec3<i32> = c_12;
    let _e207: i32 = countAt((_e201 + vec3<i32>(0i, 0i, 1i)));
    let _e209: vec3<i32> = c_12;
    let _e215: i32 = countAt((_e209 - vec3<i32>(0i, 0i, 1i)));
    n_4 = ((((((_e168 + _e175) + _e183) + _e191) + _e199) + _e207) + _e215);
    let _e218: vec3<i32> = c_12;
    let _e224: i32 = countAt((_e218 + vec3<i32>(0i, 1i, 0i)));
    let _e225: vec3<i32> = c_12;
    let _e231: i32 = countAt((_e225 + vec3<i32>(0i, 2i, 0i)));
    above = (_e224 + _e231);
    let _e235: vec4<f32> = G.gravityDt;
    g_1 = _e235.xyz;
    let _e239: i32 = n_4;
    let _e242: vec4<f32> = G.wwD;
    let _e245: vec3<f32> = x_8;
    let _e246: bool = inInnerBox(_e245);
    if ((f32(_e239) < _e242.y) || !(_e246)) {
        {
            type_33 = 0f;
            let _e250: vec3<f32> = v_4;
            let _e251: vec3<f32> = g_1;
            let _e253: vec4<f32> = G.gravityDt;
            v_4 = (_e250 + (_e251 * _e253.w));
            let _e257: vec3<f32> = v_4;
            let _e261: vec4<f32> = G.wwD;
            let _e264: vec4<f32> = G.gravityDt;
            v_4 = (_e257 * max(0f, (1f - (_e261.x * _e264.w))));
            let _e270: f32 = life;
            let _e272: vec4<f32> = G.gravityDt;
            life = (_e270 - _e272.w);
        }
    } else {
        let _e275: i32 = above;
        let _e278: vec4<f32> = G.wwD;
        if (f32(_e275) > _e278.z) {
            {
                type_33 = 2f;
                let _e282: vec3<f32> = x_8;
                let _e283: vec3<f32> = sampleVel(_e282);
                uf = _e283;
                let _e285: vec3<f32> = v_4;
                let _e287: vec4<f32> = G.wwC;
                let _e290: vec3<f32> = g_1;
                let _e293: vec4<f32> = G.gravityDt;
                let _e297: vec4<f32> = G.wwC;
                let _e299: vec3<f32> = uf;
                let _e300: vec3<f32> = v_4;
                v_4 = (_e285 + (((-(_e287.z) * _e290) * _e293.w) + (_e297.w * (_e299 - _e300))));
            }
        } else {
            {
                type_33 = 1f;
                let _e306: vec3<f32> = x_8;
                let _e307: vec3<f32> = sampleVel(_e306);
                v_4 = _e307;
                let _e309: vec3<f32> = v_4;
                let _e312: vec3<f32> = v_4;
                v_4.y = min(_e309.y, ((0.5f * length(_e312.xz)) + 1f));
                let _e319: f32 = life;
                let _e321: vec4<f32> = G.gravityDt;
                life = (_e319 - _e321.w);
            }
        }
    }
    let _e324: vec3<f32> = x_8;
    let _e325: vec3<f32> = v_4;
    let _e327: vec4<f32> = G.gravityDt;
    xn = (_e324 + (_e325 * _e327.w));
    let _e332: vec3<f32> = xn;
    let _e333: bool = solidAt(_e332);
    if _e333 {
        {
            let _e334: vec3<f32> = x_8;
            xn = _e334;
            v_4 = vec3(0f);
            let _e337: f32 = life;
            let _e338: f32 = type_33;
            if (_e338 < 0.5f) {
                local_24 = 1f;
            } else {
                let _e343: vec4<f32> = G.gravityDt;
                local_24 = (_e343.w * 4f);
            }
            let _e348: f32 = local_24;
            life = (_e337 - _e348);
        }
    }
    let _e350: f32 = life;
    let _e353: vec3<f32> = xn;
    let _e359: vec3<f32> = xn;
    let _e361: vec4<i32> = G.dims;
    let _e364: vec4<i32> = G.dims;
    let _e367: vec4<i32> = G.dims;
    if (((_e350 <= 0f) || any((_e353 < vec3(0f)))) || any((_e359 >= vec3<f32>(f32(_e361.x), f32(_e364.y), f32(_e367.z))))) {
        {
            return;
        }
    }
    let _e377: vec4<i32> = pc.a;
    let _e383: vec4<i32> = pc.a;
    let _e386: u32 = atomicAdd((&global_2.counters[_e383.y]), 1u);
    o = _e386;
    let _e388: u32 = o;
    let _e390: vec4<i32> = G.caps;
    if (_e388 >= u32(_e390.y)) {
        {
            return;
        }
    }
    let _e394: u32 = o;
    let _e396: vec3<f32> = xn;
    let _e397: f32 = life;
    let _e402: vec3<f32> = v_4;
    let _e403: f32 = type_33;
    global_1.dst[_e394] = Particle(vec4<f32>(_e396.x, _e396.y, _e396.z, _e397), vec4<f32>(_e402.x, _e402.y, _e402.z, _e403));
    let _e409: vec3<f32> = xn;
    cn = vec3<i32>(floor(_e409));
    let _e413: vec3<i32> = cn;
    let _e414: bool = inBox(_e413);
    if _e414 {
        {
            let _e415: vec3<i32> = cn;
            let _e416: i32 = cellIndex(_e415);
            let _e420: vec3<i32> = cn;
            let _e421: i32 = cellIndex(_e420);
            let _e423: i32 = atomicAdd((&global_6.wwCount[_e421]), 1i);
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
