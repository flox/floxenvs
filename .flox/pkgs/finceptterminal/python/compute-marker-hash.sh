#!/usr/bin/env bash
# Mirrors PythonSetupManager::compute_requirements_hash() in
# fincept-qt/src/python/PythonSetupManager.cpp (v4.0.3).
#
# Upstream:
#     QFile file(path);
#     file.open(QIODevice::ReadOnly);
#     QByteArray content = file.readAll();
#     QString hash = QString(
#         QCryptographicHash::hash(content,
#                                  QCryptographicHash::Sha256).toHex());
#
# i.e. QCryptographicHash::Sha256 over the file's raw bytes, encoded
# as lowercase hex via QByteArray::toHex(). No line-ending
# normalization, no trimming -- what Qt reads from disk is exactly
# what gets hashed.
#
# The marker file at <install_dir>/<venv>/.packages_installed stores
# "<hex>\n" (write_marker_hash appends a newline; read_marker_hash
# uses .trimmed() before comparing). The newline emitted by awk
# below matches that convention, so the output of this script can
# be redirected directly into .packages_installed.
#
# Usage: compute-marker-hash.sh <requirements-file>
#   prints lowercase hex sha256 (plus trailing newline) to stdout
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <requirements-file>" >&2
    exit 2
fi

if [ ! -f "$1" ]; then
    echo "$0: not a file: $1" >&2
    exit 1
fi

# sha256sum on Linux emits "<hex>  <filename>\n"
# shasum -a 256 on macOS emits "<hex>  <filename>\n"
# Both produce the same hex as Qt's QCryptographicHash::Sha256
# over the same bytes.
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
else
    shasum -a 256 "$1" | awk '{print $1}'
fi
