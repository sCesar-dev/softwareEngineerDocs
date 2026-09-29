import time
import gc
import json
import os

try:
    os.sched_setaffinity(0, {13})
except AttributeError:
    pass

n = 100
R = 100000
results = {}

operations = [
    "cte_int_eq_cte_int",
    "var_int_eq_cte_int",
    "var_int_eq_var_int",
    "var_float_eq_var_float",
    "var_int_neq_var_int",
    "var_int_gt_var_int",
    "var_float_lt_cte_float"
]

for op in operations:
    results[op] = []
    
    a_int = 5
    b_int = 10
    a_float = 5.5
    b_float = 10.5
    
    gc.collect()
    gc.disable()
    try:
        if op == "cte_int_eq_cte_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (5 == 5)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_eq_cte_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_int == 5)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_eq_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_int == b_int)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_eq_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_float == b_float)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_neq_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_int != b_int)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_gt_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_int > b_int)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_lt_cte_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = (a_float < 5.0)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
    finally:
        gc.enable()

with open("times_Comp.json", "w") as f:
    json.dump(results, f, indent=2)
print("Execução finalizada: times_Comp.json gerado.")
