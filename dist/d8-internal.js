const requireSemanticBytes = (payload, key, width) => {
    if (key + width > payload.length) {
        throw new Error(`semantic operation at key ${key} extends beyond the transcript payload`);
    }
    return width;
};
const semanticOperationWidth = (payload, key) => {
    const operation = payload[key];
    switch (operation) {
        case 21:
        case 31:
        case 37:
        case 38:
        case 39:
        case 40:
        case 41:
        case 42:
        case 45:
        case 46:
        case 47:
        case 48:
        case 49:
        case 50:
        case 51:
        case 52:
        case 53:
        case 54:
        case 55:
        case 64:
        case 65:
        case 66:
        case 73:
        case 78:
        case 81:
        case 85:
        case 91:
        case 92:
        case 93:
        case 94:
        case 100:
        case 101:
            return 1;
        case 22:
        case 25:
        case 29:
        case 33:
        case 36:
        case 58:
        case 59:
        case 60:
        case 63:
        case 67:
        case 68:
        case 69:
        case 75:
        case 76:
        case 79:
        case 80:
        case 86:
        case 88:
        case 102:
        case 103:
        case 105:
            return requireSemanticBytes(payload, key, 2);
        case 20:
        case 24:
        case 28:
        case 30:
        case 34:
        case 35:
        case 43:
        case 44:
        case 56:
        case 57:
        case 61:
        case 62:
        case 70:
        case 74:
        case 87:
        case 89:
        case 98:
        case 99:
        case 106:
        case 107:
        case 110:
            return requireSemanticBytes(payload, key, 3);
        case 32:
        case 71:
        case 82:
        case 83:
        case 96:
        case 97:
        case 108:
        case 109:
            return requireSemanticBytes(payload, key, 4);
        case 77:
        case 95:
            return requireSemanticBytes(payload, key, 5);
        case 90:
            return requireSemanticBytes(payload, key, 7);
        case 72:
            return requireSemanticBytes(payload, key, 9);
        case 84: {
            requireSemanticBytes(payload, key, 2);
            const callable = payload[key + 1] ?? 0;
            return requireSemanticBytes(payload, key, (callable & 0x80) === 0 ? 10 : 7);
        }
        case 104: {
            requireSemanticBytes(payload, key, 3);
            const symbolInfo = payload[key + 2] ?? 0;
            return requireSemanticBytes(payload, key, (symbolInfo & 0x0c) === 0x04 ? 5 : 4);
        }
        default:
            throw new Error(`semantic operation ${operation ?? "missing"} at key ${key} is not in the production dispatch table`);
    }
};
export const nucleusSemanticOperationKeys = (payload, operationCount) => {
    const keys = [];
    let key = 0;
    for (let index = 0; index < operationCount; index += 1) {
        keys.push(key);
        key += semanticOperationWidth(payload, key);
    }
    if (key !== payload.length) {
        throw new Error(`semantic transcript ends at ${payload.length}, expected decoded end ${key}`);
    }
    return keys;
};
export const assertNucleusSemanticOperationKeys = (payload, operationCount, observedKeys) => {
    if (observedKeys.length !== operationCount) {
        throw new Error(`semantic operation count ${operationCount} differs from ${observedKeys.length} trace events`);
    }
    const expectedKeys = nucleusSemanticOperationKeys(payload, operationCount);
    expectedKeys.forEach((expected, index) => {
        const observed = observedKeys[index];
        if (observed !== expected) {
            throw new Error(`semantic trace ${index} used key ${observed ?? "missing"}, expected operation boundary ${expected}`);
        }
    });
};
export const nucleusD8SourceName = (name) => name.split("\\").join("/");
