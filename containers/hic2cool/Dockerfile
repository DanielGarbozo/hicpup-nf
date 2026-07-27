# Image for the HIC2COOL process (used only by -profile full).
#
#   docker build -t ghcr.io/danielgarbozo/hicpup-nf-hic2cool:0.1.0 containers/hic2cool
#
# Kept separate from the hicpup image: hic2cool pulls its own straw-h5py/cooler
# stack and is only needed at the front of the `full` run, so the image the four
# analysis processes pull stays small.
FROM python:3.11-slim

LABEL org.opencontainers.image.source="https://github.com/DanielGarbozo/hicpup-nf"
LABEL org.opencontainers.image.description="hic2cool: Juicer .hic -> cooler"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir hic2cool cooler

RUN hic2cool --help > /dev/null && echo "hic2cool CLI OK"
