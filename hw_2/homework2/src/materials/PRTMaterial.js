class PRTMaterial extends Material {
    constructor(prtLight, vertexShader, fragmentShader) {
        super({
            'uprtLight_0': { type: 'prtLight_0', value: prtLight[0] },
            'uprtLight_1': { type: 'prtLight_1', value: prtLight[1] },
            'uprtLight_2': { type: 'prtLight_2', value: prtLight[2] },
            'uprtLight_3': { type: 'prtLight_3', value: prtLight[3] },
            'uprtLight_4': { type: 'prtLight_4', value: prtLight[4] },
            'uprtLight_5': { type: 'prtLight_5', value: prtLight[5] },
            'uprtLight_6': { type: 'prtLight_6', value: prtLight[6] },
            'uprtLight_7': { type: 'prtLight_7', value: prtLight[7] },
            'uprtLight_8': { type: 'prtLight_8', value: prtLight[8] }
        }, ["aPrecomputeLT"], vertexShader, fragmentShader, null);
    }
}

async function buildPRTMaterial(prtLight, vertexPath, fragmentPath) {
    console.log("load prt material with precompute light: " + prtLight);
    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(prtLight, vertexShader, fragmentShader);
}