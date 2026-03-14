{ pkgs }:

let
  inherit (pkgs) lib;

  # ── Benchmark functions defined once in Nix ─────────────────────────
  fibonacci = n: if n < 2 then n else fibonacci (n - 1) + fibonacci (n - 2);

  factorial = n: if n < 2 then 1 else n * factorial (n - 1);

  ackermann =
    m: n:
    if m == 0 then
      n + 1
    else if n == 0 then
      ackermann (m - 1) 1
    else
      ackermann (m - 1) (ackermann m (n - 1));

  # ── Translate at Nix-eval time ──────────────────────────────────────
  fibCpp = pkgs.lib.toCpp fibonacci;
  fibJS = pkgs.lib.toJS fibonacci;
  factCpp = pkgs.lib.toCpp factorial;
  factJS = pkgs.lib.toJS factorial;
  ackCpp = pkgs.lib.toCpp ackermann;
  ackJS = pkgs.lib.toJS ackermann;

  coreHpp = ../src/lib/cpp/core.hpp;

  # ── Helpers to generate translated source files ─────────────────────
  mkTranslatedCppSrc =
    {
      name,
      translatedCode,
      call,
    }:
    pkgs.writeText "translated-${name}.cpp" ''
      #include "core.hpp"
      #include <chrono>
      #include <cstdlib>
      #include <iostream>
      using Value = GestaltCore::Value;
      int main(int argc, char* argv[]) {
          int iterations = argc > 1 ? std::atoi(argv[1]) : 100;
          Value func = ${translatedCode};
          ${call};
          auto start = std::chrono::high_resolution_clock::now();
          Value result;
          for (int i = 0; i < iterations; i++) { result = ${call}; }
          auto end = std::chrono::high_resolution_clock::now();
          auto time_us = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
          std::cerr << "result=" << result.asInt() << std::endl;
          std::cout << time_us << std::endl;
          return 0;
      }
    '';

  mkTranslatedJsSrc =
    {
      name,
      translatedCode,
      call,
    }:
    pkgs.writeText "translated-${name}.js" ''
      const iterations = parseInt(process.argv[2]) || 10;
      const func = ${translatedCode};
      ${call};
      const start = performance.now();
      let result;
      for (let i = 0; i < iterations; i++) { result = ${call}; }
      const end = performance.now();
      process.stderr.write("result=" + result + "\n");
      console.log(Math.round((end - start) * 1000));
    '';

  translatedFibCpp = mkTranslatedCppSrc {
    name = "fibonacci";
    translatedCode = fibCpp;
    call = "func(Value::fromInt(30))";
  };
  translatedFactCpp = mkTranslatedCppSrc {
    name = "factorial";
    translatedCode = factCpp;
    call = "func(Value::fromInt(20))";
  };
  translatedAckCpp = mkTranslatedCppSrc {
    name = "ackermann";
    translatedCode = ackCpp;
    call = "func(Value::fromInt(3))(Value::fromInt(7))";
  };

  translatedFibJS = mkTranslatedJsSrc {
    name = "fibonacci";
    translatedCode = fibJS;
    call = "func(30)";
  };
  translatedFactJS = mkTranslatedJsSrc {
    name = "factorial";
    translatedCode = factJS;
    call = "func(20)";
  };
  translatedAckJS = mkTranslatedJsSrc {
    name = "ackermann";
    translatedCode = ackJS;
    call = "func(3)(7)";
  };

  nixExprFib = "let fib = n: if n < 2 then n else fib (n - 1) + fib (n - 2); in fib 30";
  nixExprFact = "let fact = n: if n < 2 then 1 else n * fact (n - 1); in fact 20";
  nixExprAck = "let ack = m: n: if m == 0 then n + 1 else if n == 0 then ack (m - 1) 1 else ack (m - 1) (ack m (n - 1)); in ack 3 7";

  RUNS = "5";

  runnerScript = pkgs.writeShellScript "run-benchmarks" ''
    set -euo pipefail

    BINS="$1"
    JS="$2"
    SOURCES="$3"
    NIX_EXPRS="$4"
    OUT="$5"
    NODE="${pkgs.nodejs}/bin/node"
    NIX_INST="${pkgs.nix}/bin/nix-instantiate"
    RUNS=${RUNS}

    count_loc() {
      grep -cve '^\s*$' -e '^\s*//' -e '^\s*#' -e '^\s*\*' -e '^\s*/\*' "$1" 2>/dev/null || echo 0
    }

    max_nesting() {
      awk 'BEGIN{max=0;d=0}{for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c=="{"||c=="(")d++;if(c=="}"||c==")")d--;if(d>max)max=d}}END{print max}' "$1"
    }

    run_cpp_bench() {
      local exe="$1" iters="$2"
      shift 2
      local times=()
      for r in $(seq 1 "$RUNS"); do
        t=$("$exe" "$iters" "$@" 2>/dev/null)
        times+=("$t")
      done
      printf '%s\n' "''${times[@]}" | sort -n | sed -n "$(( (RUNS+1)/2 ))p"
    }

    run_js_bench() {
      local script="$1" iters="$2"
      shift 2
      local times=()
      for r in $(seq 1 "$RUNS"); do
        t=$("$NODE" "$script" "$iters" "$@" 2>/dev/null)
        times+=("$t")
      done
      printf '%s\n' "''${times[@]}" | sort -n | sed -n "$(( (RUNS+1)/2 ))p"
    }

    run_nix_bench() {
      local expr="$1" iters="$2"
      local start_ns end_ns
      start_ns=$(date +%s%N)
      for i in $(seq 1 "$iters"); do
        "$NIX_INST" --eval --strict --expr "$expr" > /dev/null 2>&1
      done
      end_ns=$(date +%s%N)
      echo $(( (end_ns - start_ns) / 1000 ))
    }

    run_row() {
      local func="$1" variant="$2" input="$3" iters="$4" time_us loc nesting src

      case "$variant" in
        handwritten-cpp)
          time_us=$(run_cpp_bench "$BINS/bench-''${func}-handwritten-cpp" "$iters" $input)
          src="$SOURCES/''${func}-handwritten.cpp"
          ;;
        translated-cpp)
          time_us=$(run_cpp_bench "$BINS/bench-''${func}-translated-cpp" "$iters" $input)
          src="$SOURCES/''${func}-translated.cpp"
          ;;
        handwritten-js)
          time_us=$(run_js_bench "$JS/bench-''${func}-handwritten.js" "$iters" $input)
          src="$SOURCES/''${func}-handwritten.js"
          ;;
        translated-js)
          time_us=$(run_js_bench "$JS/bench-''${func}-translated.js" "$iters" $input)
          src="$SOURCES/''${func}-translated.js"
          ;;
        nix-eval)
          local nix_expr
          nix_expr=$(cat "$NIX_EXPRS/''${func}.nix")
          time_us=$(run_nix_bench "$nix_expr" "$iters")
          src="$NIX_EXPRS/''${func}.nix"
          ;;
      esac

      loc=$(count_loc "$src")
      nesting=$(max_nesting "$src")
      local per_iter=$(( time_us / iters ))

      echo "''${func},''${variant},''${input},''${iters},''${time_us},''${per_iter},''${loc},''${nesting}"
    }

    {
      echo "function,variant,input,iterations,median_total_time_us,time_per_iteration_us,lines_of_code,max_nesting_depth"

      echo "  fibonacci / handwritten-cpp ..." >&2
      run_row "fibonacci" "handwritten-cpp" "30" "100"
      echo "  fibonacci / translated-cpp ..." >&2
      run_row "fibonacci" "translated-cpp" "30" "100"
      echo "  fibonacci / handwritten-js ..." >&2
      run_row "fibonacci" "handwritten-js" "30" "10"
      echo "  fibonacci / translated-js ..." >&2
      run_row "fibonacci" "translated-js" "30" "10"
      echo "  fibonacci / nix-eval ..." >&2
      run_row "fibonacci" "nix-eval" "30" "3"

      echo "  factorial / handwritten-cpp ..." >&2
      run_row "factorial" "handwritten-cpp" "20" "10000"
      echo "  factorial / translated-cpp ..." >&2
      run_row "factorial" "translated-cpp" "20" "10000"
      echo "  factorial / handwritten-js ..." >&2
      run_row "factorial" "handwritten-js" "20" "1000"
      echo "  factorial / translated-js ..." >&2
      run_row "factorial" "translated-js" "20" "1000"
      echo "  factorial / nix-eval ..." >&2
      run_row "factorial" "nix-eval" "20" "100"

      echo "  ackermann / handwritten-cpp ..." >&2
      run_row "ackermann" "handwritten-cpp" "3 7" "1000"
      echo "  ackermann / translated-cpp ..." >&2
      run_row "ackermann" "translated-cpp" "3 7" "10"
      echo "  ackermann / handwritten-js ..." >&2
      run_row "ackermann" "handwritten-js" "3 7" "100"
      echo "  ackermann / translated-js ..." >&2
      run_row "ackermann" "translated-js" "3 7" "10"
      echo "  ackermann / nix-eval ..." >&2
      run_row "ackermann" "nix-eval" "3 7" "3"
    } > "$OUT"

    echo "Done." >&2
  '';

in
pkgs.stdenv.mkDerivation {
  pname = "gestalt-performance-metrics";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    pkgs.nlohmann_json
    pkgs.nodejs
    pkgs.nix
    pkgs.coreutils
  ];

  buildInputs = [
    pkgs.nlohmann_json
  ];

  # ── Compile all C++ benchmarks ──────────────────────────────────────
  buildPhase = ''
    runHook preBuild

    echo "=== Compiling benchmarks ==="
    mkdir -p bins js sources nix-exprs

    cp ${coreHpp} core.hpp

    # Handwritten C++
    for func in fibonacci factorial ackermann; do
      echo "  Compiling handwritten $func ..."
      $CXX -O2 -std=c++17 -I. $src/handwritten/$func.cpp -o bins/bench-$func-handwritten-cpp
    done

    # Translated C++
    cp ${translatedFibCpp}  translated_fibonacci.cpp
    cp ${translatedFactCpp} translated_factorial.cpp
    cp ${translatedAckCpp}  translated_ackermann.cpp
    for func in fibonacci factorial ackermann; do
      echo "  Compiling translated $func ..."
      $CXX -O2 -std=c++17 -I. translated_$func.cpp -o bins/bench-$func-translated-cpp
    done

    # JS scripts
    cp $src/handwritten/fibonacci.js js/bench-fibonacci-handwritten.js
    cp $src/handwritten/factorial.js js/bench-factorial-handwritten.js
    cp $src/handwritten/ackermann.js js/bench-ackermann-handwritten.js
    cp ${translatedFibJS}  js/bench-fibonacci-translated.js
    cp ${translatedFactJS} js/bench-factorial-translated.js
    cp ${translatedAckJS}  js/bench-ackermann-translated.js

    # Source files for LOC / nesting metrics
    cp $src/handwritten/*.cpp $src/handwritten/*.js sources/
    for f in fibonacci factorial ackermann; do
      cp sources/$f.cpp sources/$f-handwritten.cpp
      cp sources/$f.js  sources/$f-handwritten.js
      rm sources/$f.cpp sources/$f.js
    done
    cp ${translatedFibCpp}  sources/fibonacci-translated.cpp
    cp ${translatedFactCpp} sources/factorial-translated.cpp
    cp ${translatedAckCpp}  sources/ackermann-translated.cpp
    cp ${translatedFibJS}   sources/fibonacci-translated.js
    cp ${translatedFactJS}  sources/factorial-translated.js
    cp ${translatedAckJS}   sources/ackermann-translated.js

    # Nix expressions
    echo '${nixExprFib}'  > nix-exprs/fibonacci.nix
    echo '${nixExprFact}' > nix-exprs/factorial.nix
    echo '${nixExprAck}'  > nix-exprs/ackermann.nix

    echo "=== Compilation complete ==="
    runHook postBuild
  '';

  # ── Run benchmarks and write CSV as $out ────────────────────────────
  installPhase = ''
    runHook preInstall

    echo "=== Running benchmarks ==="
    ${runnerScript} "$PWD/bins" "$PWD/js" "$PWD/sources" "$PWD/nix-exprs" "$out"

    runHook postInstall
  '';

  meta = {
    description = "CSV with performance metrics comparing Gestalt-translated vs handwritten vs nix-eval code";
  };
}
