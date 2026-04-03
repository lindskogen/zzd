#!/usr/bin/env bash

out="$(echo -n abcdefghiabcdefghiabcdefghiabcdefghi | bun run index.ts)"
expected="00000000: 6162 6364 6566 6768 6961 6263 6465 6667  abcdefghiabcdefg
00000010: 6869 6162 6364 6566 6768 6961 6263 6465  hiabcdefghiabcde
00000020: 6667 6869                                fghi"

if [[ "$expected" = "$out" ]]; then
    echo OK
    exit 0
else
    echo FAILED
    echo "$out does not match:"
    echo "$expected"
    exit 1
fi
