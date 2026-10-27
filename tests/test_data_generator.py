
"""
Tests for the e-commerce synthetic data generator.

Target:
    scripts/random_data_generator.py

Run from the project root:
    python -m pytest tests/test_data_generator.py -v
"""

import ast
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
GENERATOR_PATH = PROJECT_ROOT / "scripts" / "random_data_generator.py"


class TestDataGenerator(unittest.TestCase):
    """Basic structural checks for the data generator script."""

    def test_generator_script_exists(self):
        """The generator script must exist at the expected path."""
        self.assertTrue(
            GENERATOR_PATH.is_file(),
            f"Generator script not found: {GENERATOR_PATH}",
        )

    def test_generator_script_is_not_empty(self):
        """The generator script must contain Python code."""
        source = GENERATOR_PATH.read_text(encoding="utf-8")
        self.assertTrue(source.strip(), "Generator script is empty.")

    def test_generator_script_has_valid_python_syntax(self):
        """The generator script must parse successfully."""
        source = GENERATOR_PATH.read_text(encoding="utf-8")

        try:
            ast.parse(source, filename=str(GENERATOR_PATH))
        except SyntaxError as exc:
            self.fail(f"Generator script has invalid Python syntax: {exc}")

    def test_generator_defines_at_least_one_function(self):
        """The generator should expose at least one Python function."""
        source = GENERATOR_PATH.read_text(encoding="utf-8")
        syntax_tree = ast.parse(source, filename=str(GENERATOR_PATH))

        functions = [
            node
            for node in ast.walk(syntax_tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        ]

        self.assertTrue(
            functions,
            "No functions found. Check how the generator is structured.",
        )


if __name__ == "__main__":
    unittest.main()
