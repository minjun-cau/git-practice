#!/bin/bash
# Octave 로 전체 과제 실행 (헤드리스 서버용). MATLAB 에서는 각 task*.m 을 그냥 실행하면 됨.
cd "$(dirname "$0")"
for f in "$@"; do
  xvfb-run -a octave -q --no-gui --eval "graphics_toolkit qt; run('$f');" 2>&1 | grep -v -E "^warning: (called from|.*iconv)|__axis_label__|title at line|^\s*$"
done
