export declare const rewriteSemanticTracePolicy: "operation-start";
export declare const rewriteSemanticOperations: readonly [{
    readonly id: 1;
    readonly name: "DefineProgramU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "initial";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "defineProgramU8";
        readonly index: 0;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "none";
    readonly trace: "operation-start";
}, {
    readonly id: 2;
    readonly name: "DeclareLocalU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "declareLocalU8";
        readonly index: 1;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "none";
    readonly trace: "operation-start";
}, {
    readonly id: 3;
    readonly name: "LoadProgramU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadProgramU8";
        readonly index: 2;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 4;
    readonly name: "LoadLocalU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadLocalU8";
        readonly index: 3;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 5;
    readonly name: "StoreProgramU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeProgramU8";
        readonly index: 4;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 6;
    readonly name: "StoreLocalU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeLocalU8";
        readonly index: 5;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 7;
    readonly name: "DefineProgram16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "initial";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "defineProgram16";
        readonly index: 6;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "none";
    readonly trace: "operation-start";
}, {
    readonly id: 8;
    readonly name: "DeclareLocal16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "declareLocal16";
        readonly index: 7;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "none";
    readonly trace: "operation-start";
}, {
    readonly id: 9;
    readonly name: "Literal16";
    readonly operands: readonly [{
        readonly name: "value";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "literal16";
        readonly index: 8;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 10;
    readonly name: "LoadProgram16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadProgram16";
        readonly index: 9;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 11;
    readonly name: "LoadLocal16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadLocal16";
        readonly index: 10;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 12;
    readonly name: "Add8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 13;
    readonly name: "Subtract8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 14;
    readonly name: "Multiply8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 15;
    readonly name: "And8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 16;
    readonly name: "Or8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 17;
    readonly name: "Xor8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary8";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 18;
    readonly name: "Negate8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "unary8";
        readonly index: 12;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 19;
    readonly name: "Not8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "unary8";
        readonly index: 12;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 20;
    readonly name: "Add16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 21;
    readonly name: "Subtract16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 22;
    readonly name: "Multiply16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 23;
    readonly name: "And16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 24;
    readonly name: "Or16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 25;
    readonly name: "Xor16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "binary16";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 26;
    readonly name: "Negate16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "unary16";
        readonly index: 14;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 27;
    readonly name: "Not16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "unary16";
        readonly index: 14;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 28;
    readonly name: "NotBoolean";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "notBoolean";
        readonly index: 15;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 29;
    readonly name: "Divide8";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "divideUnsigned";
        readonly index: 0;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 30;
    readonly name: "Divide16";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "divideUnsigned";
        readonly index: 0;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 31;
    readonly name: "Modulo8";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "divideUnsigned";
        readonly index: 0;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 32;
    readonly name: "Modulo16";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "divideUnsigned";
        readonly index: 0;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 33;
    readonly name: "Compare8";
    readonly operands: readonly [{
        readonly name: "comparison";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "compare";
        readonly index: 16;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 34;
    readonly name: "Compare16";
    readonly operands: readonly [{
        readonly name: "comparison";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "compare";
        readonly index: 16;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 35;
    readonly name: "CompareBoolean";
    readonly operands: readonly [{
        readonly name: "comparison";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "compare";
        readonly index: 16;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 36;
    readonly name: "NarrowU8";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "narrowU8";
        readonly index: 1;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 37;
    readonly name: "StoreProgram16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeProgram16";
        readonly index: 17;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 38;
    readonly name: "StoreLocal16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeLocal16";
        readonly index: 18;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 39;
    readonly name: "BeginBooleanAnd";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "booleanBegin";
        readonly index: 2;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 40;
    readonly name: "BeginBooleanOr";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "booleanBegin";
        readonly index: 2;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 41;
    readonly name: "EndBoolean";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "booleanEnd";
        readonly index: 3;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 42;
    readonly name: "ControlLabelDirect";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "controlLabel";
        readonly index: 19;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 43;
    readonly name: "ControlLabelEnclosing";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "controlLabel";
        readonly index: 19;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 44;
    readonly name: "BranchFalse";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "branchFalse";
        readonly index: 20;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 45;
    readonly name: "JumpDirect";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "jump";
        readonly index: 21;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 46;
    readonly name: "JumpEnclosing";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "jump";
        readonly index: 21;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 47;
    readonly name: "ForSetup";
    readonly operands: readonly [{
        readonly name: "counter";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "mode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "forSetup";
        readonly index: 4;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 0;
        readonly encoded: 32;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 48;
    readonly name: "ForTest";
    readonly operands: readonly [{
        readonly name: "counter";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "mode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "exitLabel";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "forTest";
        readonly index: 5;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 49;
    readonly name: "ForNext";
    readonly operands: readonly [{
        readonly name: "testLabel";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "exitLabel";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "counter";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }, {
        readonly name: "mode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 3;
        readonly recordOffset: 4;
    }, {
        readonly name: "step";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 4;
        readonly recordOffset: 5;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 6;
        readonly recordOffset: 7;
    }];
    readonly width: 9;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "forNext";
        readonly index: 6;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 50;
    readonly name: "ForCleanup";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "forCleanup";
        readonly index: 7;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 51;
    readonly name: "LoadParameter8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadLocalU8";
        readonly index: 3;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 52;
    readonly name: "LoadParameter16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadLocal16";
        readonly index: 10;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 53;
    readonly name: "ReturnScalar";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "returnScalar";
        readonly index: 22;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 54;
    readonly name: "StoreParameter8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeLocalU8";
        readonly index: 5;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 55;
    readonly name: "StoreParameter16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeLocal16";
        readonly index: 18;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 56;
    readonly name: "BeginGeneralRoutine";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "parameterCount";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "bank";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "beginRoutine";
        readonly index: 8;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 57;
    readonly name: "BindParameter";
    readonly operands: readonly [{
        readonly name: "type";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "localOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "argumentOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "bindParameter";
        readonly index: 9;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "none";
    readonly trace: "operation-start";
}, {
    readonly id: 58;
    readonly name: "CallSource";
    readonly operands: readonly [{
        readonly name: "selector";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "argumentWords";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "resultType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }, {
        readonly name: "routineFlags";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 3;
        readonly recordOffset: 4;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 4;
        readonly recordOffset: 5;
    }, {
        readonly name: "callMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 6;
        readonly recordOffset: 7;
    }, {
        readonly name: "handlerLabel";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 7;
        readonly recordOffset: 8;
    }, {
        readonly name: "retainedCarriers";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 8;
        readonly recordOffset: 9;
    }];
    readonly width: 10;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "callSource";
        readonly index: 10;
    };
    readonly stack: {
        readonly in: "dynamic";
        readonly out: "dynamic";
        readonly encoded: 255;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 59;
    readonly name: "CallService";
    readonly operands: readonly [{
        readonly name: "selector";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "callMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 3;
        readonly recordOffset: 4;
    }, {
        readonly name: "handlerLabel";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 4;
        readonly recordOffset: 5;
    }, {
        readonly name: "retainedCarriers";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 5;
        readonly recordOffset: 6;
    }];
    readonly width: 7;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "callService";
        readonly index: 11;
    };
    readonly stack: {
        readonly in: "dynamic";
        readonly out: "dynamic";
        readonly encoded: 255;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 60;
    readonly name: "ReturnAggregate";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "returnScalar";
        readonly index: 22;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 61;
    readonly name: "EndGeneralRoutineDirect";
    readonly operands: readonly [{
        readonly name: "resultType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "endRoutine";
        readonly index: 12;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 62;
    readonly name: "EndGeneralRoutineEnclosing";
    readonly operands: readonly [{
        readonly name: "resultType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "endRoutine";
        readonly index: 12;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 63;
    readonly name: "LoadProgramAlias";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadProgramAlias";
        readonly index: 23;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 64;
    readonly name: "LoadParameterAlias";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadParameterAlias";
        readonly index: 24;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 65;
    readonly name: "SelectField";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "selectField";
        readonly index: 25;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 66;
    readonly name: "SelectIndex";
    readonly operands: readonly [{
        readonly name: "count";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "elementExtent";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 2;
        readonly recordOffset: 3;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 4;
        readonly recordOffset: 5;
    }];
    readonly width: 7;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "selectIndex";
        readonly index: 13;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 67;
    readonly name: "LoadIndirect8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadIndirect8";
        readonly index: 26;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 68;
    readonly name: "LoadIndirect16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadIndirect16";
        readonly index: 27;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 69;
    readonly name: "StoreIndirect8";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeIndirect8";
        readonly index: 28;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 0;
        readonly encoded: 32;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 70;
    readonly name: "StoreIndirect16";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeIndirect16";
        readonly index: 29;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 0;
        readonly encoded: 32;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 71;
    readonly name: "CopyAggregate";
    readonly operands: readonly [{
        readonly name: "extent";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 5;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "copyAggregate";
        readonly index: 14;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 0;
        readonly encoded: 32;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 72;
    readonly name: "StringLength";
    readonly operands: readonly [{
        readonly name: "capacity";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "stringLength";
        readonly index: 30;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 73;
    readonly name: "StringIndex";
    readonly operands: readonly [{
        readonly name: "capacity";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "stringIndex";
        readonly index: 31;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 74;
    readonly name: "FailRoutine";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "failRoutine";
        readonly index: 15;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 75;
    readonly name: "FailMain";
    readonly operands: readonly [{
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "failMain";
        readonly index: 16;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 76;
    readonly name: "ReturnFailableScalar";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "returnFailable";
        readonly index: 17;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 77;
    readonly name: "ReturnFailableAggregate";
    readonly operands: readonly [];
    readonly width: 1;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "returnFailable";
        readonly index: 17;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 78;
    readonly name: "EndFailableRoutineDirect";
    readonly operands: readonly [{
        readonly name: "resultType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "endFailableRoutine";
        readonly index: 18;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 79;
    readonly name: "EndFailableRoutineEnclosing";
    readonly operands: readonly [{
        readonly name: "resultType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "endFailableRoutine";
        readonly index: 18;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 80;
    readonly name: "SkipHandler";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "skipHandler";
        readonly index: 19;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 81;
    readonly name: "BeginHandlerProgram";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "symbolInfo";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "address";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 5;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "beginHandler";
        readonly index: 20;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 82;
    readonly name: "BeginHandlerLocal";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "symbolInfo";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "offset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "beginHandler";
        readonly index: 20;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 83;
    readonly name: "EndHandler";
    readonly operands: readonly [{
        readonly name: "label";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "endHandler";
        readonly index: 21;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "enclosing";
    readonly trace: "operation-start";
}, {
    readonly id: 84;
    readonly name: "BeginCallableMain";
    readonly operands: readonly [{
        readonly name: "flags";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "bank";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "beginCallableMain";
        readonly index: 22;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 0;
        readonly encoded: 0;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 85;
    readonly name: "LoadReadOnlyAlias";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadReadOnlyAlias";
        readonly index: 32;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 86;
    readonly name: "OpenStringLength";
    readonly operands: readonly [{
        readonly name: "capacityOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "openStringLength";
        readonly index: 23;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 87;
    readonly name: "OpenStringIndex";
    readonly operands: readonly [{
        readonly name: "capacityOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "openStringIndex";
        readonly index: 24;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 88;
    readonly name: "PrepareOpenStringDirect";
    readonly operands: readonly [{
        readonly name: "argumentMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "capacity";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "prepareOpenArgument";
        readonly index: 25;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 2;
        readonly encoded: 18;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 89;
    readonly name: "PrepareOpenStringForward";
    readonly operands: readonly [{
        readonly name: "argumentMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "capacityOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "prepareOpenArgument";
        readonly index: 25;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 2;
        readonly encoded: 18;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 90;
    readonly name: "PrepareOpenArrayDirect";
    readonly operands: readonly [{
        readonly name: "argumentMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "count";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "prepareOpenArgument";
        readonly index: 25;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 2;
        readonly encoded: 18;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 91;
    readonly name: "PrepareOpenArrayForward";
    readonly operands: readonly [{
        readonly name: "argumentMode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "countOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "prepareOpenArgument";
        readonly index: 25;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 2;
        readonly encoded: 18;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 92;
    readonly name: "OpenStringCapacity";
    readonly operands: readonly [{
        readonly name: "capacityOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "openStringCapacity";
        readonly index: 33;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 93;
    readonly name: "OpenStringResize";
    readonly operands: readonly [{
        readonly name: "capacityOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "openStringResize";
        readonly index: 26;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 0;
        readonly encoded: 32;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 94;
    readonly name: "ArrayLength";
    readonly operands: readonly [{
        readonly name: "count";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "arrayLength";
        readonly index: 34;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 95;
    readonly name: "OpenArrayLength";
    readonly operands: readonly [{
        readonly name: "countOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "openArrayLength";
        readonly index: 35;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 96;
    readonly name: "OpenArrayIndex";
    readonly operands: readonly [{
        readonly name: "countOffset";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "elementExtent";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 3;
        readonly recordOffset: 4;
    }];
    readonly width: 6;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "openArrayIndex";
        readonly index: 27;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 97;
    readonly name: "ConvertInteger";
    readonly operands: readonly [{
        readonly name: "sourceType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "targetType";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 1;
        readonly recordOffset: 2;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 2;
        readonly recordOffset: 3;
    }];
    readonly width: 5;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "convertInteger";
        readonly index: 28;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 1;
        readonly encoded: 17;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 98;
    readonly name: "DivideSigned";
    readonly operands: readonly [{
        readonly name: "mode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }, {
        readonly name: "sourceOffset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 1;
        readonly recordOffset: 2;
    }];
    readonly width: 4;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "divideSigned";
        readonly index: 29;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 1;
        readonly encoded: 33;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 99;
    readonly name: "PromoteI8Pair";
    readonly operands: readonly [{
        readonly name: "mode";
        readonly kind: "byte";
        readonly width: 1;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 2;
    readonly backend: {
        readonly kind: "escape";
        readonly name: "promoteI8Pair";
        readonly index: 30;
    };
    readonly stack: {
        readonly in: 2;
        readonly out: 2;
        readonly encoded: 34;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 100;
    readonly name: "LoadBssU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadBssU8";
        readonly index: 36;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 101;
    readonly name: "LoadBss16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "loadBss16";
        readonly index: 37;
    };
    readonly stack: {
        readonly in: 0;
        readonly out: 1;
        readonly encoded: 1;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 102;
    readonly name: "StoreBssU8";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeBssU8";
        readonly index: 38;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}, {
    readonly id: 103;
    readonly name: "StoreBss16";
    readonly operands: readonly [{
        readonly name: "offset";
        readonly kind: "word";
        readonly width: 2;
        readonly offset: 0;
        readonly recordOffset: 1;
    }];
    readonly width: 3;
    readonly backend: {
        readonly kind: "recipe";
        readonly name: "storeBss16";
        readonly index: 39;
    };
    readonly stack: {
        readonly in: 1;
        readonly out: 0;
        readonly encoded: 16;
    };
    readonly source: "direct";
    readonly trace: "operation-start";
}];
export declare const rewriteSemanticOperationMaximumWidth = 10;
export declare const rewriteSemanticOperationKeys: (payload: Uint8Array, operationCount: number) => readonly number[];
export declare const assertRewriteSemanticOperationKeys: (payload: Uint8Array, operationCount: number, observedKeys: readonly number[]) => void;
