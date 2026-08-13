/**
 * Grammar analysis for the Nucleus specification and related research.
 *
 * It reads an EBNF grammar, expands it mechanically into BNF,
 * computes nullable, FIRST and FOLLOW to a fixed point, finds left recursion
 * through a left-corner graph that accounts for nullable prefixes, builds an
 * LL(1) prediction table and reports every collision.
 *
 * It performs no transformation to make the report clean. It does not
 * left-factor, does not eliminate left recursion, does not reorder
 * alternatives and does not insert predicates. Those belong to named
 * candidate grammars with a visible diff from the canonical file.
 */
export declare const EPSILON = "\u03B5";
export declare const END = "\u22A3";
export interface Production {
    readonly name: string;
    readonly source: string;
    readonly uses: boolean;
    readonly predicates: readonly string[];
    readonly example: string;
    readonly ebnf: string;
}
/** One BNF alternative: a nonterminal and the symbols it expands to. */
export interface Rule {
    readonly lhs: string;
    readonly rhs: readonly string[];
    /** The canonical production this came from, before expansion. */
    readonly origin: string;
}
export interface Grammar {
    readonly productions: readonly Production[];
    readonly rules: readonly Rule[];
    readonly nonterminals: ReadonlySet<string>;
    readonly terminals: ReadonlySet<string>;
    readonly start: string;
}
export declare function readGrammar(path: string): readonly Production[];
export declare function expand(productions: readonly Production[]): Grammar;
export declare function nullableSet(g: Grammar): ReadonlySet<string>;
export declare function firstSets(g: Grammar, nullable: ReadonlySet<string>): Map<string, Set<string>>;
/** FIRST of a symbol sequence, with EPSILON when the whole sequence is nullable. */
export declare function firstOf(sequence: readonly string[], first: ReadonlyMap<string, Set<string>>, nullable: ReadonlySet<string>): Set<string>;
export declare function followSets(g: Grammar, first: ReadonlyMap<string, Set<string>>, nullable: ReadonlySet<string>): Map<string, Set<string>>;
export interface Cycle {
    readonly members: readonly string[];
}
export declare function leftCorners(g: Grammar, nullable: ReadonlySet<string>): Map<string, Set<string>>;
/** Strongly connected components of the left-corner graph, Tarjan's method. */
export declare function leftRecursionCycles(edges: ReadonlyMap<string, Set<string>>): Cycle[];
export interface Collision {
    readonly nonterminal: string;
    readonly lookahead: string;
    readonly rules: readonly Rule[];
    readonly kind: "FIRST/FIRST" | "FIRST/FOLLOW";
    /** The named predicates the colliding productions declare, if any. */
    readonly predicates: readonly string[];
}
export interface Analysis {
    readonly grammar: Grammar;
    readonly nullable: ReadonlySet<string>;
    readonly first: ReadonlyMap<string, Set<string>>;
    readonly follow: ReadonlyMap<string, Set<string>>;
    readonly cycles: readonly Cycle[];
    readonly collisions: readonly Collision[];
    readonly unreachable: readonly string[];
    readonly unproductive: readonly string[];
}
export declare function analyze(productions: readonly Production[]): Analysis;
/** A shortest terminal string derivable from a symbol, for a witness. */
export declare function shortestWitness(grammar: Grammar, symbol: string, seen?: ReadonlySet<string>): string[] | undefined;
