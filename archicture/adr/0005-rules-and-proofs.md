# 0005 - Pure kernels proven with RULES.al
Status: accepted
Context: Escaping, the EAL static/dynamic split, fan-out and pagination must never be wrong. Alice proves pure rules by exhaustion. Its purity inference rejects `case`, module constants, `Substring`, `chr`, `to_s`; `alice prove` compiles only the files given (no package deps).
Decision: correctness-deciding logic lives in pure, dependency-free kernels (`if` chains, `pure def` accessors instead of constants, `.as(Char)`). Fast paths (StringBuilder etc.) call the kernels. Each package's `RULES.al` declares its kernel files on `# prove-with:`; `bunny prove --check` runs in CI (`scripts/test.sh`); `PROOF.al` is committed.
Consequences: some code is written in a restricted style; proofs cover the stated finite domains only.
