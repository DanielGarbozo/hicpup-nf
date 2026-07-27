#!/usr/bin/env python3
"""Emit a single-sample hicpup config YAML for one Nextflow task.

hicpup's CLI is config-driven: `expected` and `pileup` take a `--config` YAML
declaring every cooler, and loop over all (strain, replicate) x view
combinations internally. This pipeline fans out one task per sample instead,
so each task gets a YAML declaring exactly one cooler.

Nextflow stages every input flat into the task working directory, so
`data_root: "."` plus bare filenames is all the resolution hicpup needs -
config.py resolves `coolers` against `data_root` and `chromsizes`/`features`
against the directory holding the YAML, which here are the same place.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml

# io.load_features' default BED layout. Passed explicitly so the pipeline
# does not silently depend on hicpup's defaults staying put.
_BED_SCHEMA = {"sep": "\t", "header": None, "names": ["chrom", "start", "end", "strength"]}


def build_config(
    strain: str,
    replicate: str,
    cool: str,
    chromsizes: str,
    resolution: int | None,
    fountains_x: str | None,
    fountains_a: str | None,
) -> dict:
    features = {}
    feature_schema = {}
    # pileup only ever looks up fountains_x/fountains_a (pileup._VIEW_FEATURE_KEYS);
    # a view whose key is absent here is skipped with a warning, which is how
    # an X-only run stays valid rather than failing.
    for key, path in (("fountains_x", fountains_x), ("fountains_a", fountains_a)):
        if path:
            features[key] = Path(path).name
            feature_schema[key] = dict(_BED_SCHEMA)

    config = {
        "data_root": ".",
        "coolers": {strain: {replicate: Path(cool).name}},
        "chromsizes": Path(chromsizes).name,
        "features": features,
        "feature_schema": feature_schema,
    }
    if resolution is not None:
        # io.load_coolers validates this against clr.binsize, so an mcool
        # converted at the wrong resolution fails loudly instead of silently
        # producing a pileup at the wrong scale.
        config["resolution"] = resolution
    return config


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strain", required=True)
    parser.add_argument("--replicate", required=True)
    parser.add_argument("--cool", required=True)
    parser.add_argument("--chromsizes", required=True)
    parser.add_argument("--resolution", type=int, default=None)
    parser.add_argument("--fountains-x", default=None)
    parser.add_argument("--fountains-a", default=None)
    parser.add_argument("--output", default="hicpup_config.yaml")
    args = parser.parse_args()

    config = build_config(
        strain=args.strain,
        replicate=args.replicate,
        cool=args.cool,
        chromsizes=args.chromsizes,
        resolution=args.resolution,
        fountains_x=args.fountains_x,
        fountains_a=args.fountains_a,
    )

    with open(args.output, "w") as f:
        yaml.safe_dump(config, f, sort_keys=False)


if __name__ == "__main__":
    main()
