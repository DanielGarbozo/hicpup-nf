# Image for the four hicpup Module A processes.
#
#   docker build -t ghcr.io/danielgarbozo/hicpup-nf:0.1.0 .
#
# procps is not decoration: Nextflow shells out to `ps` to collect per-task CPU
# and memory metrics, and silently reports nothing without it.
FROM python:3.11-slim

LABEL org.opencontainers.image.source="https://github.com/DanielGarbozo/hicpup-nf"
LABEL org.opencontainers.image.description="hicpup Module A: fountain cone profiles"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && apt-get install -y --no-install-recommends git procps gcc g++ libc6-dev \
    && rm -rf /var/lib/apt/lists/*

ARG HICPUP_REF=main
RUN pip install --no-cache-dir "hicpup @ git+https://github.com/DanielGarbozo/hicpup.git@${HICPUP_REF}"

# Matplotlib needs a writable config dir; Nextflow runs the container as the
# host UID, which has no home directory inside the image.
ENV MPLCONFIGDIR=/tmp/matplotlib
ENV MPLBACKEND=Agg

RUN hicpup --help > /dev/null && echo "hicpup CLI OK"
