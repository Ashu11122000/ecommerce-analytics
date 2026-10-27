
"""
Main pipeline orchestrator for the e-commerce analytics engineering project.

Pipeline:
    1. Generate synthetic raw data and SQL.
    2. Check the PostgreSQL database connection and RAW tables.
    3. Load generated data into PostgreSQL RAW tables.

Run from the project root:
    python scripts\\run_pipeline.py

Preview the generated SQL without loading data:
    python scripts\\run_pipeline.py --dry-run

Skip data generation:
    python scripts\\run_pipeline.py --skip-generation

Skip the database connection check:
    python scripts\\run_pipeline.py --skip-connection-check

Automatically confirm replacement of RAW data:
    python scripts\\run_pipeline.py --yes

IMPORTANT:
    The loading step can truncate existing RAW tables.
    Review the generated SQL and database configuration before running.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


# ------------------------------------------------------------
# PROJECT CONFIGURATION
# ------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"

GENERATE_SCRIPT = SCRIPTS_DIR / "generate_raw_data.py"
CHECK_DATABASE_SCRIPT = SCRIPTS_DIR / "check_database_connection.py"
LOAD_SCRIPT = SCRIPTS_DIR / "load_raw_data.py"


# ------------------------------------------------------------
# PIPELINE UTILITIES
# ------------------------------------------------------------

def validate_script_paths() -> bool:
    """Check that the required scripts exist before starting."""
    required_scripts = [
        GENERATE_SCRIPT,
        CHECK_DATABASE_SCRIPT,
        LOAD_SCRIPT,
    ]

    missing_scripts = [
        script for script in required_scripts
        if not script.is_file()
    ]

    if missing_scripts:
        print("\nERROR: Required pipeline scripts are missing.")

        for script in missing_scripts:
            print(f"  - {script}")

        return False

    return True


def run_step(
    step_name: str,
    script_path: Path,
    extra_args: list[str] | None = None,
) -> bool:
    """
    Run one Python script as a subprocess.

    Returns True when the script exits successfully.
    Returns False if the script fails or cannot be started.
    """
    command = [
        sys.executable,
        str(script_path),
    ]

    if extra_args:
        command.extend(extra_args)

    print("\n" + "=" * 65)
    print(f"PIPELINE STEP: {step_name}")
    print("=" * 65)
    print(f"Command: {' '.join(command)}")
    print("-" * 65)

    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            check=False,
        )

    except OSError as exc:
        print(f"\nERROR: Could not start step '{step_name}'.")
        print(exc)
        return False

    if result.returncode != 0:
        print(f"\nFAILED: {step_name}")
        print(f"Exit code: {result.returncode}")
        print("Pipeline stopped. Fix this step before continuing.")
        return False

    print(f"\nSUCCESS: {step_name}")
    return True


# ------------------------------------------------------------
# ARGUMENTS
# ------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    """Parse pipeline options."""
    parser = argparse.ArgumentParser(
        description=(
            "Run the e-commerce analytics raw-data pipeline."
        )
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Generate the SQL and preview the load without connecting "
            "to PostgreSQL or changing database data."
        ),
    )

    parser.add_argument(
        "--skip-generation",
        action="store_true",
        help=(
            "Use the existing generated SQL file instead of "
            "running generate_raw_data.py."
        ),
    )

    parser.add_argument(
        "--skip-connection-check",
        action="store_true",
        help=(
            "Skip check_database_connection.py. "
            "Use only when you understand the implications."
        ),
    )

    parser.add_argument(
        "--yes",
        action="store_true",
        help=(
            "Pass automatic confirmation to load_raw_data.py. "
            "Existing RAW data may be replaced."
        ),
    )

    return parser.parse_args()


# ------------------------------------------------------------
# MAIN PIPELINE
# ------------------------------------------------------------

def main() -> int:
    """Execute pipeline steps in order and stop on failure."""
    args = parse_args()

    print("=" * 65)
    print(" E-COMMERCE ANALYTICS ENGINEERING PIPELINE")
    print("=" * 65)
    print(f"Project root: {PROJECT_ROOT}")
    print(f"Python executable: {sys.executable}")

    if not validate_script_paths():
        return 1

    total_steps = 3
    completed_steps = 0

    # --------------------------------------------------------
    # STEP 1: GENERATE SYNTHETIC DATA
    # --------------------------------------------------------

    if args.skip_generation:
        print("\nSTEP 1 SKIPPED: Using existing generated SQL.")
    else:
        if not run_step(
            "Generate synthetic RAW data",
            GENERATE_SCRIPT,
        ):
            return 1

        completed_steps += 1

    # --------------------------------------------------------
    # STEP 2: CHECK DATABASE CONNECTION
    # --------------------------------------------------------

    if args.dry_run:
        print(
            "\nSTEP 2 SKIPPED: Dry-run mode does not connect "
            "to PostgreSQL."
        )
    elif args.skip_connection_check:
        print(
            "\nSTEP 2 SKIPPED: Database connection check disabled "
            "by command-line option."
        )
    else:
        if not run_step(
            "Check PostgreSQL connection and RAW tables",
            CHECK_DATABASE_SCRIPT,
        ):
            return 1

        completed_steps += 1

    # --------------------------------------------------------
    # STEP 3: LOAD OR PREVIEW RAW DATA
    # --------------------------------------------------------

    load_args: list[str] = []

    if args.dry_run:
        load_args.append("--dry-run")

    if args.yes and not args.dry_run:
        load_args.append("--yes")

    if not run_step(
        "Preview or load generated RAW data",
        LOAD_SCRIPT,
        load_args,
    ):
        return 1

    completed_steps += 1

    # --------------------------------------------------------
    # PIPELINE SUMMARY
    # --------------------------------------------------------

    print("\n" + "=" * 65)
    print("PIPELINE FINISHED")
    print("=" * 65)

    if args.dry_run:
        print(
            "Dry run completed. SQL was generated and previewed; "
            "no database data was loaded."
        )
    else:
        print("All executed pipeline steps completed successfully.")

    print(f"Successful steps: {completed_steps} / {total_steps}")
    print(
        "\nNext stage: validate the RAW data, then run the "
        "Bronze, Silver, and Gold dbt models."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
