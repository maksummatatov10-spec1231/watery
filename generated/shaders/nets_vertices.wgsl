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

struct Dens {
    dens: array<f32>,
}

struct VertexId {
    vertexId: array<u32>,
}

struct Verts {
    verts: array<vec4<f32>>,
}

struct MeshCounters {
    meshCounters: array<u32>,
}

struct Static {
    staticSolid: array<u32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

struct MeshCounters_1 {
    meshCounters: array<atomic<u32>>,
}

const FP_SCALE: f32 = 65536f;
const EDGES: array<vec2<i32>, 12> = array<vec2<i32>, 12>(vec2<i32>(0i, 1i), vec2<i32>(2i, 3i), vec2<i32>(4i, 5i), vec2<i32>(6i, 7i), vec2<i32>(0i, 2i), vec2<i32>(1i, 3i), vec2<i32>(4i, 6i), vec2<i32>(5i, 7i), vec2<i32>(0i, 4i), vec2<i32>(1i, 5i), vec2<i32>(2i, 6i), vec2<i32>(3i, 7i));
const E: f32 = 0.75f;

@group(0) @binding(0)
var<uniform> G: Globals;
@group(0) @binding(1)
var<storage> global: Dens;
@group(0) @binding(2)
var<storage, read_write> global_1: VertexId;
@group(0) @binding(3)
var<storage, read_write> global_2: Verts;
@group(0) @binding(4)
var<storage, read_write> global_3: MeshCounters_1;
@group(0) @binding(5)
var<storage> global_4: Static;
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

fn densAt(p_7: vec3<i32>) -> f32 {
    var p_8: vec3<i32>;
    var local_20: f32;

    p_8 = p_7;
    let _e125: vec3<i32> = p_8;
    let _e126: bool = inFine(_e125);
    if _e126 {
        let _e127: vec3<i32> = p_8;
        let _e128: i32 = fineIndex(_e127);
        let _e130: f32 = global.dens[_e128];
        local_20 = _e130;
    } else {
        local_20 = 0f;
    }
    let _e133: f32 = local_20;
    return _e133;
}

fn densTri(p_9: vec3<f32>) -> f32 {
    var p_10: vec3<f32>;
    var b: vec3<i32>;
    var f_6: vec3<f32>;
    var r: f32 = 0f;
    var k: i32 = 0i;
    var o: vec3<i32>;
    var w: vec3<f32>;

    p_10 = p_9;
    let _e125: vec3<f32> = p_10;
    b = vec3<i32>(floor(_e125));
    let _e129: vec3<f32> = p_10;
    let _e130: vec3<i32> = b;
    f_6 = (_e129 - vec3<f32>(_e130));
    loop {
        let _e138: i32 = k;
        if !((_e138 < 8i)) {
            break;
        }
        {
            let _e145: i32 = k;
            let _e148: i32 = k;
            let _e154: i32 = k;
            o = vec3<i32>((_e145 & 1i), ((_e148 >> 1u) & 1i), ((_e154 >> 2u) & 1i));
            let _e163: vec3<f32> = f_6;
            let _e166: vec3<f32> = f_6;
            let _e167: vec3<i32> = o;
            w = mix((vec3(1f) - _e163), _e166, vec3<f32>(_e167));
            let _e171: f32 = r;
            let _e172: vec3<f32> = w;
            let _e174: vec3<f32> = w;
            let _e177: vec3<f32> = w;
            let _e180: vec3<i32> = b;
            let _e181: vec3<i32> = o;
            let _e183: f32 = densAt((_e180 + _e181));
            r = (_e171 + (((_e172.x * _e174.y) * _e177.z) * _e183));
        }
        continuing {
            let _e142: i32 = k;
            k = (_e142 + 1i);
        }
    }
    let _e186: f32 = r;
    return _e186;
}

fn solidNear(simPos: vec3<f32>) -> bool {
    var simPos_1: vec3<f32>;
    var k_1: i32 = 0i;
    var local_21: f32;
    var local_22: f32;
    var local_23: f32;
    var local_24: f32;
    var local_25: f32;
    var local_26: f32;
    var local_27: vec3<f32>;
    var o_1: vec3<f32>;
    var c_8: vec3<i32>;

    simPos_1 = simPos;
    loop {
        let _e127: i32 = k_1;
        if !((_e127 < 7i)) {
            break;
        }
        {
            let _e134: i32 = k_1;
            if (_e134 == 0i) {
                local_27 = vec3(0f);
            } else {
                let _e139: i32 = k_1;
                if (_e139 == 1i) {
                    local_22 = 0.6f;
                } else {
                    let _e143: i32 = k_1;
                    if (_e143 == 2i) {
                        local_21 = -0.6f;
                    } else {
                        local_21 = 0f;
                    }
                    let _e150: f32 = local_21;
                    local_22 = _e150;
                }
                let _e152: f32 = local_22;
                let _e153: i32 = k_1;
                if (_e153 == 3i) {
                    local_24 = 0.6f;
                } else {
                    let _e157: i32 = k_1;
                    if (_e157 == 4i) {
                        local_23 = -0.6f;
                    } else {
                        local_23 = 0f;
                    }
                    let _e164: f32 = local_23;
                    local_24 = _e164;
                }
                let _e166: f32 = local_24;
                let _e167: i32 = k_1;
                if (_e167 == 5i) {
                    local_26 = 0.6f;
                } else {
                    let _e171: i32 = k_1;
                    if (_e171 == 6i) {
                        local_25 = -0.6f;
                    } else {
                        local_25 = 0f;
                    }
                    let _e178: f32 = local_25;
                    local_26 = _e178;
                }
                let _e180: f32 = local_26;
                local_27 = vec3<f32>(_e152, _e166, _e180);
            }
            let _e183: vec3<f32> = local_27;
            o_1 = _e183;
            let _e185: vec3<f32> = simPos_1;
            let _e186: vec3<f32> = o_1;
            c_8 = vec3<i32>(floor((_e185 + _e186)));
            let _e191: vec3<i32> = c_8;
            let _e192: bool = inGrid(_e191);
            let _e193: vec3<i32> = c_8;
            let _e194: i32 = cellIndex(_e193);
            let _e196: u32 = global_4.staticSolid[_e194];
            if (_e192 && (_e196 != 0u)) {
                {
                    return true;
                }
            }
        }
        continuing {
            let _e131: i32 = k_1;
            k_1 = (_e131 + 1i);
        }
    }
    return false;
}

fn main_1() {
    var dim: vec3<i32>;
    var t_4: i32;
    var bd: vec3<i32>;
    var c_9: vec3<i32>;
    var id: i32;
    var iso: f32;
    var d_5: array<f32, 8>;
    var mask: u32 = 0u;
    var k_2: i32 = 0i;
    var sum: vec3<f32> = vec3(0f);
    var n_4: f32 = 0f;
    var e_9: i32 = 0i;
    var local_28: array<vec2<i32>, 12> = EDGES;
    var a: i32;
    var local_29: array<vec2<i32>, 12> = EDGES;
    var b_1: i32;
    var t_5: f32;
    var pa: vec3<f32>;
    var pb: vec3<f32>;
    var local_30: vec3<f32>;
    var at: vec3<f32>;
    var grad: vec3<f32>;
    var local_31: vec3<f32>;
    var normal: vec3<f32>;
    var vi: u32;
    var simPos_2: vec3<f32>;

    let _e125: vec4<i32> = G.fine;
    dim = (_e125.xyz + vec3(1i));
    let _e133: vec3<u32> = gl_GlobalInvocationID_1;
    let _e135: vec3<u32> = gl_GlobalInvocationID_1;
    let _e137: vec3<u32> = gl_NumWorkGroups_1;
    t_4 = i32((_e133.x + ((_e135.y * _e137.x) * 256u)));
    let _e145: i32 = t_4;
    let _e147: vec4<i32> = G.fineBoxMax;
    if (_e145 >= _e147.w) {
        {
            return;
        }
    }
    let _e151: vec4<i32> = G.fineBoxMax;
    let _e154: vec4<i32> = G.fineBoxMin;
    bd = ((_e151.xyz - _e154.xyz) + vec3(1i));
    let _e162: vec4<i32> = G.fineBoxMin;
    let _e167: i32 = t_4;
    let _e168: vec3<i32> = bd;
    let _e171: i32 = t_4;
    let _e172: vec3<i32> = bd;
    let _e175: vec3<i32> = bd;
    let _e178: i32 = t_4;
    let _e179: vec3<i32> = bd;
    let _e181: vec3<i32> = bd;
    c_9 = ((_e162.xyz - vec3(1i)) + vec3<i32>((_e167 % _e168.x), ((_e171 / _e172.x) % _e175.y), (_e178 / (_e179.x * _e181.y))));
    let _e188: vec3<i32> = c_9;
    let _e192: vec3<i32> = dim;
    let _e194: vec3<i32> = c_9;
    let _e198: vec3<i32> = dim;
    let _e200: vec3<i32> = c_9;
    id = ((_e188.x + 1i) + (_e192.x * ((_e194.y + 1i) + (_e198.y * (_e200.z + 1i)))));
    let _e210: vec4<f32> = G.surf;
    iso = _e210.x;
    loop {
        let _e218: i32 = k_2;
        if !((_e218 < 8i)) {
            break;
        }
        {
            let _e225: i32 = k_2;
            let _e227: vec3<i32> = c_9;
            let _e228: i32 = k_2;
            let _e231: i32 = k_2;
            let _e237: i32 = k_2;
            let _e245: f32 = densAt((_e227 + vec3<i32>((_e228 & 1i), ((_e231 >> 1u) & 1i), ((_e237 >> 2u) & 1i))));
            d_5[_e225] = _e245;
            let _e246: i32 = k_2;
            let _e248: f32 = d_5[_e246];
            let _e249: f32 = iso;
            if (_e248 > _e249) {
                {
                    let _e251: u32 = mask;
                    let _e253: i32 = k_2;
                    mask = (_e251 | (1u << u32(_e253)));
                }
            }
        }
        continuing {
            let _e222: i32 = k_2;
            k_2 = (_e222 + 1i);
        }
    }
    let _e257: u32 = mask;
    let _e260: u32 = mask;
    if ((_e257 == 0u) || (_e260 == 255u)) {
        {
            let _e264: i32 = id;
            global_1.vertexId[_e264] = 4294967295u;
            return;
        }
    }
    loop {
        let _e274: i32 = e_9;
        if !((_e274 < 12i)) {
            break;
        }
        {
            let _e281: i32 = e_9;
            let _e285: vec2<i32> = local_28[_e281];
            a = _e285.x;
            let _e288: i32 = e_9;
            let _e292: vec2<i32> = local_29[_e288];
            b_1 = _e292.y;
            let _e295: u32 = mask;
            let _e296: i32 = a;
            let _e301: u32 = mask;
            let _e302: i32 = b_1;
            if (((_e295 >> u32(_e296)) & 1u) != ((_e301 >> u32(_e302)) & 1u)) {
                {
                    let _e308: f32 = iso;
                    let _e309: i32 = a;
                    let _e311: f32 = d_5[_e309];
                    let _e313: i32 = b_1;
                    let _e315: f32 = d_5[_e313];
                    let _e316: i32 = a;
                    let _e318: f32 = d_5[_e316];
                    t_5 = clamp(((_e308 - _e311) / (_e315 - _e318)), 0f, 1f);
                    let _e325: i32 = a;
                    let _e328: i32 = a;
                    let _e334: i32 = a;
                    pa = vec3<f32>(f32((_e325 & 1i)), f32(((_e328 >> 1u) & 1i)), f32(((_e334 >> 2u) & 1i)));
                    let _e345: i32 = b_1;
                    let _e348: i32 = b_1;
                    let _e354: i32 = b_1;
                    pb = vec3<f32>(f32((_e345 & 1i)), f32(((_e348 >> 1u) & 1i)), f32(((_e354 >> 2u) & 1i)));
                    let _e365: vec3<f32> = sum;
                    let _e366: vec3<f32> = pa;
                    let _e367: vec3<f32> = pb;
                    let _e368: f32 = t_5;
                    sum = (_e365 + mix(_e366, _e367, vec3(_e368)));
                    let _e372: f32 = n_4;
                    n_4 = (_e372 + 1f);
                }
            }
        }
        continuing {
            let _e278: i32 = e_9;
            e_9 = (_e278 + 1i);
        }
    }
    let _e375: vec3<f32> = sum;
    let _e376: f32 = n_4;
    local_30 = (_e375 / vec3(_e376));
    let _e380: vec3<i32> = c_9;
    let _e382: vec3<f32> = local_30;
    at = (vec3<f32>(_e380) + _e382);
    let _e387: vec3<f32> = at;
    let _e393: f32 = densTri((_e387 + vec3<f32>(0.75f, 0f, 0f)));
    let _e394: vec3<f32> = at;
    let _e400: f32 = densTri((_e394 - vec3<f32>(0.75f, 0f, 0f)));
    let _e402: vec3<f32> = at;
    let _e408: f32 = densTri((_e402 + vec3<f32>(0f, 0.75f, 0f)));
    let _e409: vec3<f32> = at;
    let _e415: f32 = densTri((_e409 - vec3<f32>(0f, 0.75f, 0f)));
    let _e417: vec3<f32> = at;
    let _e423: f32 = densTri((_e417 + vec3<f32>(0f, 0f, 0.75f)));
    let _e424: vec3<f32> = at;
    let _e430: f32 = densTri((_e424 - vec3<f32>(0f, 0f, 0.75f)));
    grad = vec3<f32>((_e393 - _e400), (_e408 - _e415), (_e423 - _e430));
    let _e434: vec3<f32> = grad;
    let _e435: vec3<f32> = grad;
    if (dot(_e434, _e435) < 0.0000000001f) {
        {
            let _e441: f32 = d_5[1];
            let _e444: f32 = d_5[3];
            let _e448: f32 = d_5[5];
            let _e452: f32 = d_5[7];
            let _e456: f32 = d_5[0];
            let _e459: f32 = d_5[2];
            let _e463: f32 = d_5[4];
            let _e467: f32 = d_5[6];
            let _e472: f32 = d_5[2];
            let _e475: f32 = d_5[3];
            let _e479: f32 = d_5[6];
            let _e483: f32 = d_5[7];
            let _e487: f32 = d_5[0];
            let _e490: f32 = d_5[1];
            let _e494: f32 = d_5[4];
            let _e498: f32 = d_5[5];
            let _e503: f32 = d_5[4];
            let _e506: f32 = d_5[5];
            let _e510: f32 = d_5[6];
            let _e514: f32 = d_5[7];
            let _e518: f32 = d_5[0];
            let _e521: f32 = d_5[1];
            let _e525: f32 = d_5[2];
            let _e529: f32 = d_5[3];
            grad = vec3<f32>(((((_e441 + _e444) + _e448) + _e452) - (((_e456 + _e459) + _e463) + _e467)), ((((_e472 + _e475) + _e479) + _e483) - (((_e487 + _e490) + _e494) + _e498)), ((((_e503 + _e506) + _e510) + _e514) - (((_e518 + _e521) + _e525) + _e529)));
        }
    }
    let _e533: vec3<f32> = grad;
    let _e534: vec3<f32> = grad;
    if (dot(_e533, _e534) > 0.000000000001f) {
        let _e538: vec3<f32> = grad;
        local_31 = -(normalize(_e538));
    } else {
        local_31 = vec3<f32>(0f, 1f, 0f);
    }
    let _e546: vec3<f32> = local_31;
    normal = _e546;
    let _e554: u32 = atomicAdd((&global_3.meshCounters[0i]), 1u);
    vi = _e554;
    let _e556: u32 = vi;
    let _e558: vec4<i32> = pc.a;
    if (_e556 >= u32(_e558.x)) {
        {
            let _e562: i32 = id;
            global_1.vertexId[_e562] = 4294967295u;
            return;
        }
    }
    let _e565: vec3<i32> = c_9;
    let _e567: vec3<f32> = local_30;
    let _e573: vec4<i32> = G.fine;
    simPos_2 = (((vec3<f32>(_e565) + _e567) + vec3(0.5f)) / vec3(f32(_e573.w)));
    let _e579: u32 = vi;
    let _e581: vec3<f32> = simPos_2;
    let _e582: vec3<f32> = normal;
    let _e583: vec3<f32> = simPos_2;
    let _e584: bool = solidNear(_e583);
    let _e585: u32 = packNormal(_e582, _e584);
    global_2.verts[_e579] = vec4<f32>(_e581.x, _e581.y, _e581.z, bitcast<f32>(_e585));
    let _e591: i32 = id;
    let _e593: u32 = vi;
    global_1.vertexId[_e591] = _e593;
    return;
}

@compute @workgroup_size(256, 1, 1)
fn main(@builtin(global_invocation_id) gl_GlobalInvocationID: vec3<u32>, @builtin(num_workgroups) gl_NumWorkGroups: vec3<u32>) {
    gl_GlobalInvocationID_1 = gl_GlobalInvocationID;
    gl_NumWorkGroups_1 = gl_NumWorkGroups;
    main_1();
    return;
}
