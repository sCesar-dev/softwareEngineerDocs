# Software Engineer Docs

This project is a small Python benchmarking example used to explore how execution time changes as the size of a workload grows. It includes a simple timing script, an interactive notebook, and supporting documentation images.

## Project purpose

The repository demonstrates a basic performance experiment:

- measuring runtime for different input sizes
- comparing execution costs across workloads
- documenting software engineering concepts related to performance and complexity

## Repository structure

- `src/execution_time.py` — standalone script that measures execution time for several values of `n`
- `src/execution.ipynb` — notebook version for interactive exploration and visualization
- `docs/` — images and supporting documentation
- `requirements.txt` — Python dependencies
- `LICENSE` — project license

## Getting started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd softwareEngineerDocs
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the benchmark script:
   ```bash
   python src/execution_time.py
   ```

## Example output

The script prints elapsed time for each input size, for example:

```text
n: 1000 tempo: 0.000123
n: 10000 tempo: 0.001234
n: 100000 tempo: 0.012345
```

## Notes

This project is intentionally simple and is designed for learning and documentation rather than production use. It is useful as a reference for discussing runtime trends, basic benchmarking, and practical examples in software engineering.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
